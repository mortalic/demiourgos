//! The Demiourgos MCP server: state and the full tool surface.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use demiourgos_mesh::Mesh;
use demiourgos_scad::{Define, ExportFormat, OpenScad, RenderOptions, RunOutput, View};
use demiourgos_tolerance::{
    clearance_steps, coupon_scad, CouponSpec, Feature, FitClass, Measurement, Outcome, Profile,
    Store, Verdict,
};
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{
    CallToolResult, Implementation, ProtocolVersion, ServerCapabilities, ServerInfo,
};
use rmcp::{tool, tool_handler, tool_router, ErrorData as McpError, ServerHandler};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::config::Config;
use crate::geometry::{self, Axis, Transform};
use crate::params::{self, parse_projection, parse_view};
use crate::render::{self, Cell};
use crate::result::{
    base64_encode, encode_png, image_result, internal, invalid, json_error, json_result,
};
use crate::workspace::{ModelName, Workspace};

/// Server version, surfaced by `health`.
const VERSION: &str = env!("CARGO_PKG_VERSION");

/// The Demiourgos server state.
#[derive(Clone)]
pub struct Demiourgos {
    config: Config,
    workspace: Workspace,
    /// `None` when OpenSCAD could not be discovered at startup; `health` still
    /// works and reports the problem, other tools return a clear error.
    openscad: Option<OpenScad>,
    openscad_error: Option<String>,
    /// Persistent tolerance store (material/printer profiles + outcome log).
    store: Store,
}

impl Demiourgos {
    /// Build the server from resolved config, an OpenSCAD discovery result, and
    /// an opened tolerance store.
    pub fn new(
        config: Config,
        workspace: Workspace,
        openscad: Result<OpenScad, String>,
        store: Store,
    ) -> Demiourgos {
        let (openscad, openscad_error) = match openscad {
            Ok(s) => (Some(s), None),
            Err(e) => (None, Some(e)),
        };
        Demiourgos {
            config,
            workspace,
            openscad,
            openscad_error,
            store,
        }
    }

    fn scad(&self) -> Result<&OpenScad, McpError> {
        self.openscad.as_ref().ok_or_else(|| {
            internal(format!(
                "OpenSCAD is not available: {}",
                self.openscad_error.as_deref().unwrap_or("not found")
            ))
        })
    }

    /// Resolve and require an existing model, returning its validated name.
    fn require_model(&self, name: &str) -> Result<ModelName, McpError> {
        let model = Workspace::validate_name(name).map_err(invalid)?;
        if !self.workspace.model_exists(&model) {
            return Err(invalid(format!(
                "model '{}' does not exist in the workspace",
                model.file_name()
            )));
        }
        Ok(model)
    }

    fn defines(&self, overrides: &Option<BTreeMap<String, Value>>) -> Vec<Define> {
        overrides
            .as_ref()
            .map(params::defines_from_map)
            .unwrap_or_default()
    }

    /// Optionally assess a `fit_check` gap against a tolerance profile. Returns
    /// `Ok(None)` unless both `material` and `fit_class` were supplied.
    fn assess_fit(
        &self,
        args: &FitCheckArgs,
        collides: bool,
        min_distance: Option<f64>,
    ) -> Result<Option<Value>, McpError> {
        let (Some(material), Some(fit_class)) = (&args.material, &args.fit_class) else {
            return Ok(None);
        };
        let class: FitClass = fit_class.parse().map_err(invalid)?;
        let printer = args.printer.as_deref().unwrap_or("default");
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let profile = self
            .store
            .effective(printer, material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        let needed = profile.clearance(class);

        // Small tolerance band so "exactly recommended" reads as OK.
        let band = 0.03_f64;
        let (meets, verdict) = if collides {
            match class {
                FitClass::Press | FitClass::Snap => (
                    true,
                    format!("interference present, expected for a {class} fit"),
                ),
                _ => (
                    false,
                    format!("parts intersect — too tight for a {class} fit"),
                ),
            }
        } else if let Some(gap) = min_distance {
            match class {
                FitClass::Press => (
                    gap <= needed + band,
                    if gap <= needed + band {
                        format!("gap {gap:.3} mm is tight enough for a press fit")
                    } else {
                        format!("gap {gap:.3} mm is too loose for a press fit (want ≈{needed:.3})")
                    },
                ),
                _ => {
                    if gap + band < needed {
                        (false, format!("gap {gap:.3} mm < recommended {needed:.3} mm/side — too tight for a {class} fit"))
                    } else if gap > needed * 2.0 + 0.3 {
                        (true, format!("gap {gap:.3} mm is well above recommended {needed:.3} mm/side — may be loose"))
                    } else {
                        (true, format!("gap {gap:.3} mm meets recommended {needed:.3} mm/side for a {class} fit"))
                    }
                }
            }
        } else {
            (true, "parts are disjoint; no measurable gap".to_string())
        };

        Ok(Some(json!({
            "profile_id": profile.key(),
            "fit_class": class.to_string(),
            "recommended_clearance_mm": needed,
            "measured_gap_mm": min_distance,
            "meets_spec": meets,
            "verdict": verdict,
            "source": source_str(&profile),
        })))
    }

    /// Export a model to STL at `out`, returning the run output. The caller
    /// inspects success and whether the file was produced.
    async fn export_stl(
        &self,
        model: &ModelName,
        out: &Path,
        fn_: Option<u32>,
        defines: &[Define],
    ) -> Result<RunOutput, McpError> {
        let scad = self.scad()?;
        let model_path = self.workspace.model_path(model);
        scad.export(
            &model_path,
            out,
            ExportFormat::BinStl,
            fn_,
            defines,
            self.config.export_timeout,
        )
        .await
        .map_err(|e| internal(e.to_string()))
    }

    /// Render a single image with the given options, returning the PNG bytes.
    async fn render_one(
        &self,
        opts: &RenderOptions<'_>,
    ) -> Result<Result<Vec<u8>, RunOutput>, McpError> {
        let scad = self.scad()?;
        let run = scad
            .render(opts, self.config.render_timeout)
            .await
            .map_err(|e| internal(e.to_string()))?;
        if !run.success || !opts.output_png.is_file() {
            return Ok(Err(run));
        }
        let bytes = std::fs::read(opts.output_png)
            .map_err(|e| internal(format!("failed to read rendered PNG: {e}")))?;
        Ok(Ok(bytes))
    }

    /// Render a model variant straight to a decoded RGBA image.
    #[allow(clippy::too_many_arguments)]
    async fn render_rgba(
        &self,
        model_path: &Path,
        out_png: &Path,
        view: View,
        width: u32,
        height: u32,
        fn_: Option<u32>,
        defines: &[Define],
    ) -> Result<Result<image::RgbaImage, RunOutput>, McpError> {
        let mut opts = RenderOptions::for_view(model_path, out_png, view);
        opts.width = width;
        opts.height = height;
        opts.fn_ = fn_;
        opts.defines = defines;
        match self.render_one(&opts).await? {
            Ok(bytes) => Ok(Ok(image::load_from_memory(&bytes)
                .map_err(|e| internal(format!("failed to decode render: {e}")))?
                .to_rgba8())),
            Err(run) => Ok(Err(run)),
        }
    }
}

/// Build a structured payload describing a failed OpenSCAD run.
fn failure_payload(stage: &str, run: &RunOutput) -> Value {
    json!({
        "success": false,
        "stage": stage,
        "exit_code": run.exit_code,
        "errors": run.parsed.errors().collect::<Vec<_>>(),
        "warnings": run.parsed.warnings().collect::<Vec<_>>(),
        "echo": run.parsed.echos,
        "stderr": run.stderr,
    })
}

fn failure_summary(stage: &str, run: &RunOutput) -> String {
    let first = run
        .parsed
        .errors()
        .next()
        .map(|d| d.message.clone())
        .or_else(|| run.stderr.lines().last().map(|s| s.to_string()))
        .unwrap_or_else(|| "no diagnostics captured".to_string());
    format!("OpenSCAD {stage} failed: {first}")
}

// ===========================================================================
// Tool argument types
// ===========================================================================

type Overrides = Option<BTreeMap<String, Value>>;

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct WriteModelArgs {
    /// Model name (the `.scad` extension is added if omitted).
    pub name: String,
    /// Full OpenSCAD source for the file.
    pub source: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct NameArgs {
    /// Model name.
    pub name: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CompileCheckArgs {
    /// Model name.
    pub name: String,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct RenderArgs {
    /// Model name.
    pub name: String,
    /// A single named view: front, back, left, right, top, bottom, iso.
    #[serde(default)]
    pub view: Option<String>,
    /// Multiple named views to composite into a labeled contact sheet.
    #[serde(default)]
    pub views: Option<Vec<String>>,
    /// Image width in pixels (per cell for contact sheets). Default 800.
    #[serde(default)]
    pub width: Option<u32>,
    /// Image height in pixels (per cell for contact sheets). Default 600.
    #[serde(default)]
    pub height: Option<u32>,
    /// Projection: "ortho" (default) or "perspective".
    #[serde(default)]
    pub projection: Option<String>,
    /// Optional `$fn` override for curve smoothness.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
    /// Raw OpenSCAD camera string for power users (bypasses named views).
    #[serde(default)]
    pub advanced_camera: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct MeasureArgs {
    /// Model name.
    pub name: String,
    /// Optional `$fn` override (affects faceting and thus volume).
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ExportArgs {
    /// Model name.
    pub name: String,
    /// Output format: stl, 3mf, off, amf, dxf, or svg.
    pub format: String,
    /// For STL only: binary (default true) or ASCII.
    #[serde(default)]
    pub binary: Option<bool>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CrossSectionArgs {
    /// Model name.
    pub name: String,
    /// Cut-plane axis: x, y, or z.
    pub axis: String,
    /// Offset of the cut plane along the axis, in mm.
    pub offset: f64,
    /// Image width in pixels. Default 800.
    #[serde(default)]
    pub width: Option<u32>,
    /// Image height in pixels. Default 600.
    #[serde(default)]
    pub height: Option<u32>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct FitCheckArgs {
    /// First part's model name.
    pub part_a: String,
    /// Second part's model name.
    pub part_b: String,
    /// Optional translation [x, y, z] applied to part B, in mm.
    #[serde(default)]
    pub translation: Option<[f64; 3]>,
    /// Optional rotation [x, y, z] applied to part B, in degrees.
    #[serde(default)]
    pub rotation: Option<[f64; 3]>,
    /// Optional `$fn` override applied to both parts.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed to both parts via `-D`.
    #[serde(default)]
    pub defines: Overrides,
    /// Optional: assess the measured gap against a tolerance profile. Provide
    /// material + fit_class (and optionally printer/nozzle) to have the result
    /// say whether the clearance matches the recommended fit.
    #[serde(default)]
    pub material: Option<String>,
    /// Printer for the tolerance assessment (default "default").
    #[serde(default)]
    pub printer: Option<String>,
    /// Nozzle for the tolerance assessment, mm (default 0.4).
    #[serde(default)]
    pub nozzle_mm: Option<f64>,
    /// Fit class for the tolerance assessment: slip, snug, press, or snap.
    #[serde(default)]
    pub fit_class: Option<String>,
}

// ===========================================================================
// Tools
// ===========================================================================

#[tool_router]
impl Demiourgos {
    #[tool(
        description = "Report server version, the resolved OpenSCAD binary path and version, the \
                       workspace path, and whether the BOSL2 library is available."
    )]
    async fn health(&self) -> Result<CallToolResult, McpError> {
        let (binary, scad_version, scad_ok) = match &self.openscad {
            Some(s) => (
                Some(s.binary.display().to_string()),
                Some(s.version.clone()),
                true,
            ),
            None => (None, None, false),
        };
        let bosl2 = self
            .openscad
            .as_ref()
            .map(|s| s.libraries.iter().any(|l| l == "BOSL2"))
            .unwrap_or(false);

        let payload = json!({
            "demiourgos_version": VERSION,
            "openscad_available": scad_ok,
            "openscad_binary": binary,
            "openscad_version": scad_version,
            "openscad_error": self.openscad_error,
            "workspace": self.workspace.root().display().to_string(),
            "artifacts": self.workspace.artifacts_dir().display().to_string(),
            "libraries": { "BOSL2": bosl2 },
            "timeouts_secs": {
                "render": self.config.render_timeout.as_secs(),
                "export": self.config.export_timeout.as_secs(),
                "check": self.config.check_timeout.as_secs(),
            },
        });
        let summary = if scad_ok {
            format!(
                "Demiourgos {VERSION} — OpenSCAD {} ready; workspace at {}",
                scad_version.unwrap_or_default(),
                self.workspace.root().display()
            )
        } else {
            format!(
                "Demiourgos {VERSION} — OpenSCAD NOT available: {}",
                self.openscad_error.as_deref().unwrap_or("not found")
            )
        };
        Ok(json_result(summary, payload))
    }

    #[tool(
        description = "Create or overwrite a named .scad model in the workspace. Returns its path."
    )]
    async fn write_model(
        &self,
        Parameters(args): Parameters<WriteModelArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = Workspace::validate_name(&args.name).map_err(invalid)?;
        let path = self
            .workspace
            .write_model(&name, &args.source)
            .map_err(|e| internal(format!("failed to write model: {e}")))?;
        Ok(json_result(
            format!("Wrote {} ({} bytes)", name.file_name(), args.source.len()),
            json!({ "name": name.file_name(), "path": path.display().to_string(), "bytes": args.source.len() }),
        ))
    }

    #[tool(description = "Return the source of a named model.")]
    async fn read_model(
        &self,
        Parameters(args): Parameters<NameArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let source = self
            .workspace
            .read_model(&name)
            .map_err(|e| internal(format!("failed to read model: {e}")))?;
        Ok(json_result(
            format!("{} ({} bytes)", name.file_name(), source.len()),
            json!({ "name": name.file_name(), "source": source }),
        ))
    }

    #[tool(description = "List all .scad models in the workspace.")]
    async fn list_models(&self) -> Result<CallToolResult, McpError> {
        let models = self
            .workspace
            .list_models()
            .map_err(|e| internal(format!("failed to list models: {e}")))?;
        Ok(json_result(
            format!("{} model(s)", models.len()),
            json!({ "models": models }),
        ))
    }

    #[tool(
        description = "Fast validation without a full render: compile the model to CSG and report \
                       success, all errors/warnings (with line numbers when available), and ECHO \
                       output. This is the cheap inner-loop check."
    )]
    async fn compile_check(
        &self,
        Parameters(args): Parameters<CompileCheckArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let scad = self.scad()?;
        let defines = self.defines(&args.defines);
        let out_csg = self
            .workspace
            .artifact_path(&format!("{}.check.csg", name.stem()));
        let run = scad
            .compile_check(
                &self.workspace.model_path(&name),
                &out_csg,
                &defines,
                self.config.check_timeout,
            )
            .await
            .map_err(|e| internal(e.to_string()))?;

        let success = run.success && !run.parsed.has_errors();
        let payload = json!({
            "success": success,
            "exit_code": run.exit_code,
            "errors": run.parsed.errors().collect::<Vec<_>>(),
            "warnings": run.parsed.warnings().collect::<Vec<_>>(),
            "echo": run.parsed.echos,
        });
        let summary = if success {
            let w = run.parsed.warnings().count();
            format!("OK — compiled with {w} warning(s)")
        } else {
            failure_summary("compile", &run)
        };
        Ok(if success {
            json_result(summary, payload)
        } else {
            json_error(summary, payload)
        })
    }

    #[tool(
        description = "Render a PNG of a model from a named view (front/back/left/right/top/bottom/\
                       iso), or composite several views into a labeled contact sheet via the \
                       `views` array. Returns the image and its path."
    )]
    async fn render(
        &self,
        Parameters(args): Parameters<RenderArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let model_path = self.workspace.model_path(&name);
        let width = args.width.unwrap_or(800);
        let height = args.height.unwrap_or(600);
        let projection = match &args.projection {
            Some(p) => parse_projection(p).map_err(invalid)?,
            None => demiourgos_scad::Projection::Ortho,
        };
        let defines = self.defines(&args.defines);

        // Contact sheet path.
        if let Some(view_names) = &args.views {
            if view_names.is_empty() {
                return Err(invalid("`views` must not be empty"));
            }
            let views: Vec<View> = view_names
                .iter()
                .map(|v| parse_view(v))
                .collect::<Result<_, _>>()
                .map_err(invalid)?;

            let mut cells = Vec::new();
            for view in &views {
                let out =
                    self.workspace
                        .artifact_path(&format!("{}_{}.png", name.stem(), view.label()));
                let mut opts = RenderOptions::for_view(&model_path, &out, *view);
                opts.width = width;
                opts.height = height;
                opts.projection = projection;
                opts.fn_ = args.fn_n;
                opts.defines = &defines;
                match self.render_one(&opts).await? {
                    Ok(bytes) => {
                        let img = image::load_from_memory(&bytes)
                            .map_err(|e| internal(format!("failed to decode render: {e}")))?
                            .to_rgba8();
                        cells.push(Cell {
                            label: view.label().to_string(),
                            image: img,
                        });
                    }
                    Err(run) => {
                        return Ok(json_error(
                            failure_summary("render", &run),
                            failure_payload("render", &run),
                        ));
                    }
                }
            }

            let sheet = render::contact_sheet(&cells);
            let png = encode_png(&sheet)?;
            let sheet_path = self
                .workspace
                .artifact_path(&format!("{}_contact.png", name.stem()));
            std::fs::write(&sheet_path, &png)
                .map_err(|e| internal(format!("failed to write contact sheet: {e}")))?;

            let summary = format!(
                "Contact sheet for {} ({})",
                name.file_name(),
                views
                    .iter()
                    .map(|v| v.label())
                    .collect::<Vec<_>>()
                    .join(", ")
            );
            return Ok(image_result(
                summary,
                base64_encode(&png),
                json!({
                    "model": name.file_name(),
                    "views": views.iter().map(|v| v.label()).collect::<Vec<_>>(),
                    "path": sheet_path.display().to_string(),
                    "width": sheet.width(),
                    "height": sheet.height(),
                }),
            ));
        }

        // Single render.
        let out = self
            .workspace
            .artifact_path(&format!("{}_render.png", name.stem()));
        let (camera, view_label) = match &args.advanced_camera {
            Some(c) => (Some(c.clone()), "advanced".to_string()),
            None => {
                let view = match &args.view {
                    Some(v) => parse_view(v).map_err(invalid)?,
                    None => View::Iso,
                };
                (
                    Some(demiourgos_scad::camera_string(
                        view,
                        demiourgos_scad::camera::DEFAULT_DISTANCE,
                    )),
                    view.label().to_string(),
                )
            }
        };
        let opts = RenderOptions {
            file: &model_path,
            output_png: &out,
            width,
            height,
            projection,
            camera,
            // Advanced cameras are absolute; don't reframe them.
            viewall: args.advanced_camera.is_none(),
            autocenter: args.advanced_camera.is_none(),
            render_full: true,
            fn_: args.fn_n,
            defines: &defines,
            colorscheme: None,
        };
        match self.render_one(&opts).await? {
            Ok(bytes) => Ok(image_result(
                format!("Rendered {} ({view_label})", name.file_name()),
                base64_encode(&bytes),
                json!({
                    "model": name.file_name(),
                    "view": view_label,
                    "path": out.display().to_string(),
                    "width": width,
                    "height": height,
                }),
            )),
            Err(run) => Ok(json_error(
                failure_summary("render", &run),
                failure_payload("render", &run),
            )),
        }
    }

    #[tool(
        description = "Export the model to a binary STL, then measure it: axis-aligned bounding box \
                       (min/max/size), volume in mm^3, center of mass, triangle count, and whether \
                       it is watertight. Accepts -D overrides to measure across parameter values."
    )]
    async fn measure(
        &self,
        Parameters(args): Parameters<MeasureArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let defines = self.defines(&args.defines);
        let stl = self
            .workspace
            .artifact_path(&format!("{}.measure.stl", name.stem()));
        let run = self.export_stl(&name, &stl, args.fn_n, &defines).await?;
        if !run.success || !stl.is_file() {
            return Ok(json_error(
                failure_summary("export", &run),
                failure_payload("export", &run),
            ));
        }
        let mesh =
            Mesh::from_stl_path(&stl).map_err(|e| internal(format!("failed to load STL: {e}")))?;
        let analysis = mesh
            .analyze()
            .map_err(|e| internal(format!("failed to analyze mesh: {e}")))?;

        let bb = &analysis.bounding_box;
        let summary = format!(
            "{}: {:.2} × {:.2} × {:.2} mm, {:.2} mm^3, {} (com {:.2},{:.2},{:.2})",
            name.file_name(),
            bb.size[0],
            bb.size[1],
            bb.size[2],
            analysis.volume,
            if analysis.watertight {
                "watertight"
            } else {
                "NOT watertight"
            },
            analysis.center_of_mass[0],
            analysis.center_of_mass[1],
            analysis.center_of_mass[2],
        );
        Ok(json_result(
            summary,
            serde_json::to_value(&analysis).unwrap_or(json!({})),
        ))
    }

    #[tool(
        description = "Export the model to STL/3MF/OFF/AMF/DXF/SVG with optional $fn and (for STL) \
                       binary/ASCII selection. Returns the artifact path."
    )]
    async fn export(
        &self,
        Parameters(args): Parameters<ExportArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let scad = self.scad()?;
        let binary = args.binary.unwrap_or(true);
        let format = match args.format.trim().to_ascii_lowercase().as_str() {
            "stl" if binary => ExportFormat::BinStl,
            "stl" => ExportFormat::AsciiStl,
            "3mf" => ExportFormat::ThreeMf,
            "off" => ExportFormat::Off,
            "amf" => ExportFormat::Amf,
            "dxf" => ExportFormat::Dxf,
            "svg" => ExportFormat::Svg,
            other => {
                return Err(invalid(format!(
                    "unsupported format '{other}' (expected stl, 3mf, off, amf, dxf, or svg)"
                )))
            }
        };
        let defines = self.defines(&args.defines);
        let out = self
            .workspace
            .artifact_path(&format!("{}.{}", name.stem(), format.extension()));
        let run = scad
            .export(
                &self.workspace.model_path(&name),
                &out,
                format,
                args.fn_n,
                &defines,
                self.config.export_timeout,
            )
            .await
            .map_err(|e| internal(e.to_string()))?;
        if !run.success || !out.is_file() {
            return Ok(json_error(
                failure_summary("export", &run),
                failure_payload("export", &run),
            ));
        }
        let bytes = std::fs::metadata(&out).map(|m| m.len()).unwrap_or(0);
        Ok(json_result(
            format!("Exported {} ({bytes} bytes)", out.display()),
            json!({ "model": name.file_name(), "format": args.format, "path": out.display().to_string(), "bytes": bytes }),
        ))
    }

    #[tool(
        description = "Render the 2D cross-section of a model at a cut plane (axis x/y/z and offset \
                       in mm) using projection(cut=true). Use this to inspect internal geometry and \
                       wall thickness. Returns the section image."
    )]
    async fn cross_section(
        &self,
        Parameters(args): Parameters<CrossSectionArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let axis: Axis = args.axis.parse().map_err(invalid)?;
        let defines = self.defines(&args.defines);

        // Export the solid to STL, then slice the STL in a wrapper.
        let stl = self
            .workspace
            .artifact_path(&format!("{}.section.stl", name.stem()));
        let run = self.export_stl(&name, &stl, args.fn_n, &defines).await?;
        if !run.success || !stl.is_file() {
            return Ok(json_error(
                failure_summary("export", &run),
                failure_payload("export", &run),
            ));
        }

        let wrapper_src = geometry::cross_section_scad(&stl, axis, args.offset);
        let wrapper = self
            .workspace
            .artifact_path(&format!("{}.section.scad", name.stem()));
        std::fs::write(&wrapper, &wrapper_src)
            .map_err(|e| internal(format!("failed to write section wrapper: {e}")))?;

        let out = self
            .workspace
            .artifact_path(&format!("{}_section.png", name.stem()));
        let opts = RenderOptions::for_view(&wrapper, &out, View::Top); // top-down on the 2D slice
        let mut opts = opts;
        opts.width = args.width.unwrap_or(800);
        opts.height = args.height.unwrap_or(600);
        match self.render_one(&opts).await? {
            Ok(bytes) => Ok(image_result(
                format!(
                    "Cross-section of {} at {}={}",
                    name.file_name(),
                    args.axis,
                    args.offset
                ),
                base64_encode(&bytes),
                json!({
                    "model": name.file_name(),
                    "axis": args.axis,
                    "offset": args.offset,
                    "path": out.display().to_string(),
                }),
            )),
            Err(run) => Ok(json_error(
                failure_summary("render", &run),
                failure_payload("render", &run),
            )),
        }
    }

    #[tool(
        description = "Fit/collision check between two parts. Optionally transform part B \
                       (translation in mm, rotation in degrees), compute the intersection volume \
                       (≈0 means no collision), and report each part's bounding box, the per-axis \
                       gap when disjoint, and the true minimum surface distance."
    )]
    async fn fit_check(
        &self,
        Parameters(args): Parameters<FitCheckArgs>,
    ) -> Result<CallToolResult, McpError> {
        let part_a = self.require_model(&args.part_a)?;
        let part_b = self.require_model(&args.part_b)?;
        let defines = self.defines(&args.defines);
        let transform = match (args.translation, args.rotation) {
            (None, None) => Transform::IDENTITY,
            (t, r) => Transform {
                translation: t.unwrap_or([0.0; 3]),
                rotation: r.unwrap_or([0.0; 3]),
            },
        };

        // Export both parts.
        let a_stl = self
            .workspace
            .artifact_path(&format!("{}.fitA.stl", part_a.stem()));
        let b_stl = self
            .workspace
            .artifact_path(&format!("{}.fitB.stl", part_b.stem()));
        let run_a = self
            .export_stl(&part_a, &a_stl, args.fn_n, &defines)
            .await?;
        if !run_a.success || !a_stl.is_file() {
            return Ok(json_error(
                failure_summary("export part_a", &run_a),
                failure_payload("export", &run_a),
            ));
        }
        let run_b = self
            .export_stl(&part_b, &b_stl, args.fn_n, &defines)
            .await?;
        if !run_b.success || !b_stl.is_file() {
            return Ok(json_error(
                failure_summary("export part_b", &run_b),
                failure_payload("export", &run_b),
            ));
        }

        // Load meshes; apply transform to B in Rust to keep bbox/distance in sync.
        let mesh_a = Mesh::from_stl_path(&a_stl).map_err(|e| internal(format!("load A: {e}")))?;
        let mesh_b_raw =
            Mesh::from_stl_path(&b_stl).map_err(|e| internal(format!("load B: {e}")))?;
        let mesh_b = transform.apply_to_mesh(&mesh_b_raw);

        let bb_a = mesh_a
            .bounding_box()
            .ok_or_else(|| internal("part A is empty"))?;
        let bb_b = mesh_b
            .bounding_box()
            .ok_or_else(|| internal("part B is empty"))?;
        let gaps = geometry::axis_gaps(&bb_a, &bb_b);
        let min_distance = demiourgos_mesh::min_distance(&mesh_a, &mesh_b);

        // Compute the precise intersection volume via OpenSCAD.
        let wrapper_src = geometry::fit_check_scad(&a_stl, &b_stl, &transform);
        let pair = format!("{}__{}", part_a.stem(), part_b.stem());
        let wrapper = self
            .workspace
            .artifact_path(&format!("{pair}.intersection.scad"));
        std::fs::write(&wrapper, &wrapper_src)
            .map_err(|e| internal(format!("failed to write fit_check wrapper: {e}")))?;
        let inter_stl = self
            .workspace
            .artifact_path(&format!("{pair}.intersection.stl"));
        let scad = self.scad()?;
        let run_i = scad
            .export(
                &wrapper,
                &inter_stl,
                ExportFormat::BinStl,
                None,
                &[],
                self.config.export_timeout,
            )
            .await
            .map_err(|e| internal(e.to_string()))?;

        // An empty intersection legitimately produces no/empty STL — treat as 0.
        let intersection_volume = if run_i.success && inter_stl.is_file() {
            match Mesh::from_stl_path(&inter_stl) {
                Ok(m) if !m.is_empty() => m.volume(),
                _ => 0.0,
            }
        } else {
            0.0
        };

        const EPS: f64 = 1e-6;
        let collides = intersection_volume > EPS;

        // Optional tolerance assessment: compare the measured gap to the profile's
        // recommended per-side clearance for the requested fit class.
        let assessment = self.assess_fit(&args, collides, min_distance)?;

        let summary = if collides {
            format!(
                "COLLISION: {} and {} overlap by {:.4} mm^3",
                part_a.file_name(),
                part_b.file_name(),
                intersection_volume
            )
        } else {
            let gap_str = min_distance
                .map(|d| format!("{d:.3} mm min gap"))
                .unwrap_or_else(|| "disjoint".to_string());
            let verdict = assessment
                .as_ref()
                .and_then(|a| a.get("verdict"))
                .and_then(|v| v.as_str())
                .map(|v| format!(" — {v}"))
                .unwrap_or_default();
            format!(
                "NO collision: {} and {} are clear ({gap_str}){verdict}",
                part_a.file_name(),
                part_b.file_name()
            )
        };
        Ok(json_result(
            summary,
            json!({
                "collides": collides,
                "intersection_volume_mm3": intersection_volume,
                "min_distance_mm": min_distance,
                "axis_gaps_mm": { "x": gaps[0], "y": gaps[1], "z": gaps[2] },
                "fit_assessment": assessment,
                "part_a": { "name": part_a.file_name(), "bounding_box": bb_a },
                "part_b": {
                    "name": part_b.file_name(),
                    "bounding_box": bb_b,
                    "transform": { "translation": transform.translation, "rotation": transform.rotation },
                },
            }),
        ))
    }

    // -----------------------------------------------------------------------
    // Tolerance engine: profiles, calibration, coupons, and DFM.
    // -----------------------------------------------------------------------

    #[tool(
        description = "List all known material/printer tolerance profiles with their calibrated \
                       per-fit-class clearances and dimensional offsets."
    )]
    async fn list_profiles(&self) -> Result<CallToolResult, McpError> {
        let profiles = self
            .store
            .list_effective()
            .map_err(|e| internal(e.to_string()))?;
        let arr: Vec<Value> = profiles.iter().map(profile_json).collect();
        Ok(json_result(
            format!("{} tolerance profile(s)", profiles.len()),
            json!({ "profiles": arr }),
        ))
    }

    #[tool(
        description = "Get the effective (calibrated) tolerance profile for a printer + material + \
                       nozzle: per-fit-class clearances, dimensional offsets, and how many outcomes \
                       informed it."
    )]
    async fn get_profile(
        &self,
        Parameters(args): Parameters<ProfileArgs>,
    ) -> Result<CallToolResult, McpError> {
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let p = self
            .store
            .effective(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        Ok(json_result(profile_summary(&p), profile_json(&p)))
    }

    #[tool(
        description = "Create or manually edit a tolerance profile baseline. Unset fields keep their \
                       current/default values. Manual edits are the starting point that recorded \
                       outcomes refine."
    )]
    async fn set_profile(
        &self,
        Parameters(args): Parameters<SetProfileArgs>,
    ) -> Result<CallToolResult, McpError> {
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let id = Profile::id(&args.printer, &args.material, nozzle);
        let mut base = self
            .store
            .baseline(&id)
            .map_err(|e| internal(e.to_string()))?
            .unwrap_or_else(|| Profile::default_for(&args.printer, &args.material, nozzle));

        if let Some(v) = args.slip {
            base.clearances_mm.slip = v;
        }
        if let Some(v) = args.snug {
            base.clearances_mm.snug = v;
        }
        if let Some(v) = args.press {
            base.clearances_mm.press = v;
        }
        if let Some(v) = args.snap {
            base.clearances_mm.snap = v;
        }
        if let Some(v) = args.xy_offset_mm {
            base.xy_offset_mm = v;
        }
        if let Some(v) = args.hole_offset_mm {
            base.hole_offset_mm = v;
        }
        if let Some(v) = args.elephant_foot_mm {
            base.elephant_foot_mm = v;
        }

        self.store
            .save_baseline(&base)
            .map_err(|e| internal(e.to_string()))?;
        let effective = self
            .store
            .effective(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        Ok(json_result(
            format!("Saved profile {id}"),
            profile_json(&effective),
        ))
    }

    #[tool(
        description = "Recommend the per-side clearance (mm) for a fit class (slip/snug/press/snap) \
                       on a given printer + material, using the calibrated profile when available."
    )]
    async fn recommend_clearance(
        &self,
        Parameters(args): Parameters<RecommendArgs>,
    ) -> Result<CallToolResult, McpError> {
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let class: FitClass = args.fit_class.parse().map_err(invalid)?;
        let p = self
            .store
            .effective(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        let clearance = p.clearance(class);
        Ok(json_result(
            format!(
                "{} {} fit: {:.3} mm/side ({}) — hole = peg + {:.3} mm diametral",
                p.key(),
                class,
                clearance,
                source_str(&p),
                clearance * 2.0
            ),
            json!({
                "profile_id": p.key(),
                "fit_class": class.to_string(),
                "clearance_per_side_mm": clearance,
                "clearance_diametral_mm": clearance * 2.0,
                "source": source_str(&p),
                "samples": p.samples,
            }),
        ))
    }

    #[tool(
        description = "Generate and save a fit-test coupon model: a plate of holes stepped across a \
                       clearance range plus a reference peg. Print it once, find the tightest hole \
                       the peg gives the desired fit, then call record_outcome to calibrate. Returns \
                       the model name and the clearance steps."
    )]
    async fn gen_fit_coupon(
        &self,
        Parameters(args): Parameters<CouponArgs>,
    ) -> Result<CallToolResult, McpError> {
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let default_spec = CouponSpec::default();
        let peg = args.peg_diameter_mm.unwrap_or(default_spec.peg_diameter_mm);
        let plate_t = args
            .plate_thickness_mm
            .unwrap_or(default_spec.plate_thickness_mm);

        let clearances = match (args.min_clearance_mm, args.max_clearance_mm, args.step_mm) {
            (Some(min), Some(max), Some(step)) => clearance_steps(min, max, step),
            _ => default_spec.clearances_mm.clone(),
        };
        if clearances.is_empty() {
            return Err(invalid(
                "clearance range is empty; check min/max/step (need step > 0 and max >= min)",
            ));
        }

        let spec = CouponSpec {
            peg_diameter_mm: peg,
            clearances_mm: clearances.clone(),
            plate_thickness_mm: plate_t,
        };
        let scad = coupon_scad(&spec);

        let raw_name = args
            .name
            .clone()
            .unwrap_or_else(|| format!("{}_fit_coupon", args.material.to_ascii_lowercase()));
        let name = Workspace::validate_name(&raw_name).map_err(invalid)?;
        let path = self
            .workspace
            .write_model(&name, &scad)
            .map_err(|e| internal(format!("failed to write coupon: {e}")))?;

        // Ensure the profile exists so outcomes have somewhere to land.
        self.store
            .register(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;

        Ok(json_result(
            format!(
                "Wrote fit coupon '{}' ({} steps: {:.2}–{:.2} mm, peg {:.1} mm). Render/export it, print, then record_outcome.",
                name.file_name(),
                clearances.len(),
                clearances.first().copied().unwrap_or(0.0),
                clearances.last().copied().unwrap_or(0.0),
                peg
            ),
            json!({
                "model": name.file_name(),
                "path": path.display().to_string(),
                "profile_id": Profile::id(&args.printer, &args.material, nozzle),
                "peg_diameter_mm": peg,
                "clearance_steps_mm": clearances,
            }),
        ))
    }

    #[tool(
        description = "Record a real-world print outcome to calibrate a profile. kind='coupon' \
                       (fit_class + best_clearance_mm from a fit-test coupon), kind='caliper' \
                       (feature outer/hole + nominal_mm + measured_mm), or kind='fit' (fit_class + \
                       clearance_mm + verdict loose/good/tight/jam). Returns the updated profile."
    )]
    async fn record_outcome(
        &self,
        Parameters(args): Parameters<OutcomeArgs>,
    ) -> Result<CallToolResult, McpError> {
        let nozzle = nozzle_or_default(args.nozzle_mm);
        let profile_id = Profile::id(&args.printer, &args.material, nozzle);

        let measurement = match args.kind.trim().to_ascii_lowercase().as_str() {
            "coupon" => {
                let class: FitClass = args
                    .fit_class
                    .as_deref()
                    .ok_or_else(|| invalid("kind='coupon' requires fit_class"))?
                    .parse()
                    .map_err(invalid)?;
                let best = args
                    .best_clearance_mm
                    .ok_or_else(|| invalid("kind='coupon' requires best_clearance_mm"))?;
                Measurement::Coupon {
                    fit_class: class,
                    best_clearance_mm: best,
                }
            }
            "caliper" => {
                let feature = match args
                    .feature
                    .as_deref()
                    .map(|s| s.to_ascii_lowercase())
                    .as_deref()
                {
                    Some("hole") => Feature::Hole,
                    Some("outer") => Feature::Outer,
                    _ => return Err(invalid("kind='caliper' requires feature 'outer' or 'hole'")),
                };
                let nominal = args
                    .nominal_mm
                    .ok_or_else(|| invalid("kind='caliper' requires nominal_mm"))?;
                let measured = args
                    .measured_mm
                    .ok_or_else(|| invalid("kind='caliper' requires measured_mm"))?;
                Measurement::Caliper {
                    feature,
                    nominal_mm: nominal,
                    measured_mm: measured,
                }
            }
            "fit" => {
                let class: FitClass = args
                    .fit_class
                    .as_deref()
                    .ok_or_else(|| invalid("kind='fit' requires fit_class"))?
                    .parse()
                    .map_err(invalid)?;
                let clearance = args
                    .clearance_mm
                    .ok_or_else(|| invalid("kind='fit' requires clearance_mm"))?;
                let verdict: Verdict = args
                    .verdict
                    .as_deref()
                    .ok_or_else(|| invalid("kind='fit' requires verdict"))?
                    .parse()
                    .map_err(invalid)?;
                Measurement::Fit {
                    fit_class: class,
                    clearance_mm: clearance,
                    verdict,
                }
            }
            other => {
                return Err(invalid(format!(
                    "unknown outcome kind '{other}' (expected coupon, caliper, or fit)"
                )))
            }
        };

        // Make sure the profile exists, then record and recompute.
        self.store
            .register(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        let outcome = Outcome {
            profile_id: profile_id.clone(),
            measurement,
            note: args.note.clone(),
            timestamp: None,
        };
        self.store
            .append_outcome(&outcome)
            .map_err(|e| internal(e.to_string()))?;

        let p = self
            .store
            .effective(&args.printer, &args.material, nozzle)
            .map_err(|e| internal(e.to_string()))?;
        Ok(json_result(
            format!("Recorded outcome for {profile_id}. {}", profile_summary(&p)),
            profile_json(&p),
        ))
    }

    #[tool(
        description = "Design-for-manufacturing pre-flight on a model: export to STL and report \
                       unsupported overhang area, the steepest overhang, bed-contact footprint, an \
                       estimated minimum wall thickness, and actionable warnings. Catches most \
                       reprint causes geometrically, before printing."
    )]
    async fn dfm_check(
        &self,
        Parameters(args): Parameters<DfmArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let defines = self.defines(&args.defines);
        let stl = self
            .workspace
            .artifact_path(&format!("{}.dfm.stl", name.stem()));
        let run = self.export_stl(&name, &stl, args.fn_n, &defines).await?;
        if !run.success || !stl.is_file() {
            return Ok(json_error(
                failure_summary("export", &run),
                failure_payload("export", &run),
            ));
        }
        let mesh =
            Mesh::from_stl_path(&stl).map_err(|e| internal(format!("failed to load STL: {e}")))?;
        let report = match args.overhang_threshold_deg {
            Some(t) => mesh.dfm_report_with(t),
            None => mesh.dfm_report(),
        };
        let summary = if report.warnings.is_empty() {
            format!("{}: no DFM warnings", name.file_name())
        } else {
            format!(
                "{}: {} warning(s) — {}",
                name.file_name(),
                report.warnings.len(),
                report.warnings.join("; ")
            )
        };
        Ok(json_result(
            summary,
            serde_json::to_value(&report).unwrap_or(json!({})),
        ))
    }

    #[tool(
        description = "Build an interactive 3D viewer for a model: export the mesh and write a \
                       self-contained HTML page (Three.js) you can open in a browser to orbit, \
                       zoom, and inspect the actual geometry. Returns the HTML file path. Use this \
                       to *show* a model interactively; use `render` for inline still images."
    )]
    async fn view_3d(
        &self,
        Parameters(args): Parameters<ViewArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let defines = self.defines(&args.defines);
        let stl = self
            .workspace
            .artifact_path(&format!("{}.view.stl", name.stem()));
        let run = self.export_stl(&name, &stl, args.fn_n, &defines).await?;
        if !run.success || !stl.is_file() {
            return Ok(json_error(
                failure_summary("export", &run),
                failure_payload("export", &run),
            ));
        }

        let bytes =
            std::fs::read(&stl).map_err(|e| internal(format!("failed to read STL: {e}")))?;
        let analysis = Mesh::from_stl_path(&stl)
            .ok()
            .and_then(|m| m.analyze().ok());
        let meta = match &analysis {
            Some(a) => format!(
                "{:.1} × {:.1} × {:.1} mm · {} triangles · {}",
                a.bounding_box.size[0],
                a.bounding_box.size[1],
                a.bounding_box.size[2],
                a.triangle_count,
                if a.watertight {
                    "watertight"
                } else {
                    "not watertight"
                }
            ),
            None => format!("{} (mesh analysis unavailable)", name.file_name()),
        };
        let theme = args
            .color
            .as_deref()
            .map(|c| c.trim_start_matches('#').to_string())
            .filter(|c| c.len() == 6 && c.chars().all(|ch| ch.is_ascii_hexdigit()))
            .unwrap_or_else(|| "d9a441".to_string());

        let html =
            crate::viewer::viewer_html(name.file_name(), &meta, &base64_encode(&bytes), &theme);
        let out = self
            .workspace
            .artifact_path(&format!("{}.view.html", name.stem()));
        std::fs::write(&out, &html)
            .map_err(|e| internal(format!("failed to write viewer: {e}")))?;

        Ok(json_result(
            format!(
                "Interactive 3D viewer for {} — open in a browser:\n{}",
                name.file_name(),
                out.display()
            ),
            json!({
                "model": name.file_name(),
                "viewer_html": out.display().to_string(),
                "open_url": format!("file://{}", out.display()),
                "meta": meta,
            }),
        ))
    }

    #[tool(
        description = "Render a model across several values of one variable and composite the \
                       results into a single labeled grid — a customizer preset grid or tolerance \
                       contact sheet. Great for previewing how a parameter changes the shape."
    )]
    async fn param_sweep(
        &self,
        Parameters(args): Parameters<ParamSweepArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name = self.require_model(&args.name)?;
        let model_path = self.workspace.model_path(&name);
        if args.values.is_empty() {
            return Err(invalid("`values` must not be empty"));
        }
        if args.values.len() > 36 {
            return Err(invalid("too many values (max 36)"));
        }
        let view = match &args.view {
            Some(v) => parse_view(v).map_err(invalid)?,
            None => View::Iso,
        };
        let width = args.width.unwrap_or(360);
        let height = args.height.unwrap_or(360);
        let base_defines = self.defines(&args.defines);

        let mut cells = Vec::new();
        for (i, val) in args.values.iter().enumerate() {
            let mut defs = base_defines.clone();
            defs.push(Define::new(args.parameter.clone(), params::scad_value(val)));
            let out = self
                .workspace
                .artifact_path(&format!("{}_sweep_{i}.png", name.stem()));
            match self
                .render_rgba(&model_path, &out, view, width, height, args.fn_n, &defs)
                .await?
            {
                Ok(img) => cells.push(Cell {
                    label: format!("{}={}", args.parameter, params::value_label(val)),
                    image: img,
                }),
                Err(run) => {
                    return Ok(json_error(
                        failure_summary("render", &run),
                        failure_payload("render", &run),
                    ))
                }
            }
        }

        let sheet = render::contact_sheet(&cells);
        let png = encode_png(&sheet)?;
        let out = self
            .workspace
            .artifact_path(&format!("{}_sweep.png", name.stem()));
        std::fs::write(&out, &png).map_err(|e| internal(format!("failed to write sweep: {e}")))?;

        Ok(image_result(
            format!(
                "Swept {} over {} value(s) of '{}'",
                name.file_name(),
                args.values.len(),
                args.parameter
            ),
            base64_encode(&png),
            json!({
                "model": name.file_name(),
                "parameter": args.parameter,
                "values": args.values,
                "path": out.display().to_string(),
            }),
        ))
    }

    #[tool(
        description = "Visually diff two variants of a model (e.g. before/after a parameter change): \
                       render both from the same view, highlight the changed pixels in red, and \
                       report how much changed. Returns an A | B | diff panel."
    )]
    async fn visual_diff(
        &self,
        Parameters(args): Parameters<VisualDiffArgs>,
    ) -> Result<CallToolResult, McpError> {
        let name_a = self.require_model(&args.name)?;
        let name_b = match &args.name_b {
            Some(n) => self.require_model(n)?,
            None => name_a.clone(),
        };
        let view = match &args.view {
            Some(v) => parse_view(v).map_err(invalid)?,
            None => View::Iso,
        };
        let width = args.width.unwrap_or(400);
        let height = args.height.unwrap_or(400);
        let defs_a = self.defines(&args.defines_a);
        let defs_b = self.defines(&args.defines_b);

        let out_a = self
            .workspace
            .artifact_path(&format!("{}_diff_a.png", name_a.stem()));
        let a = match self
            .render_rgba(
                &self.workspace.model_path(&name_a),
                &out_a,
                view,
                width,
                height,
                args.fn_n,
                &defs_a,
            )
            .await?
        {
            Ok(img) => img,
            Err(run) => {
                return Ok(json_error(
                    failure_summary("render A", &run),
                    failure_payload("render", &run),
                ))
            }
        };
        let out_b = self
            .workspace
            .artifact_path(&format!("{}_diff_b.png", name_b.stem()));
        let b = match self
            .render_rgba(
                &self.workspace.model_path(&name_b),
                &out_b,
                view,
                width,
                height,
                args.fn_n,
                &defs_b,
            )
            .await?
        {
            Ok(img) => img,
            Err(run) => {
                return Ok(json_error(
                    failure_summary("render B", &run),
                    failure_payload("render", &run),
                ))
            }
        };

        let (diff, frac) = render::diff_image(&a, &b, 24);
        let cells = vec![
            Cell {
                label: "A (before)".into(),
                image: a,
            },
            Cell {
                label: "B (after)".into(),
                image: b,
            },
            Cell {
                label: "diff".into(),
                image: diff,
            },
        ];
        let sheet = render::grid_sheet(&cells, 3);
        let png = encode_png(&sheet)?;
        let out = self
            .workspace
            .artifact_path(&format!("{}_diff.png", name_a.stem()));
        std::fs::write(&out, &png).map_err(|e| internal(format!("failed to write diff: {e}")))?;

        Ok(image_result(
            format!(
                "{} vs {}: {:.2}% of pixels changed",
                name_a.file_name(),
                name_b.file_name(),
                frac * 100.0
            ),
            base64_encode(&png),
            json!({
                "model_a": name_a.file_name(),
                "model_b": name_b.file_name(),
                "changed_fraction": frac,
                "path": out.display().to_string(),
            }),
        ))
    }

    #[tool(
        description = "Discover installed OpenSCAD libraries (e.g. BOSL2): report the library search \
                       paths, which libraries are present, and — for a named library — its modules \
                       and functions, optionally filtered by a search substring."
    )]
    async fn library_info(
        &self,
        Parameters(args): Parameters<LibraryInfoArgs>,
    ) -> Result<CallToolResult, McpError> {
        let scad = self.scad()?;
        let paths = &scad.library_paths;

        // Top-level: which library folders exist under each search path.
        let mut libraries: Vec<Value> = Vec::new();
        for dir in paths {
            if let Ok(entries) = std::fs::read_dir(dir) {
                for e in entries.flatten() {
                    if e.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                        if let Some(n) = e.file_name().to_str() {
                            libraries
                                .push(json!({ "name": n, "path": e.path().display().to_string() }));
                        }
                    }
                }
            }
        }

        // Optional deep dive into one library: list modules/functions.
        let mut modules: Vec<String> = Vec::new();
        let mut functions: Vec<String> = Vec::new();
        if let Some(lib) = &args.library {
            let lib_dir = paths.iter().map(|p| p.join(lib)).find(|p| p.is_dir());
            match lib_dir {
                Some(dir) => {
                    let mut files = Vec::new();
                    collect_scad_files(&dir, &mut files, 0, 400);
                    let filter = args.search.as_deref().map(|s| s.to_ascii_lowercase());
                    for f in &files {
                        if let Ok(src) = std::fs::read_to_string(f) {
                            scan_defs(&src, &filter, &mut modules, &mut functions);
                        }
                    }
                    modules.sort();
                    modules.dedup();
                    modules.truncate(300);
                    functions.sort();
                    functions.dedup();
                    functions.truncate(300);
                }
                None => {
                    return Err(invalid(format!(
                        "library '{lib}' not found under the OpenSCAD library paths"
                    )))
                }
            }
        }

        let summary = if let Some(lib) = &args.library {
            format!(
                "{lib}: {} module(s), {} function(s){}",
                modules.len(),
                functions.len(),
                args.search
                    .as_deref()
                    .map(|s| format!(" matching '{s}'"))
                    .unwrap_or_default()
            )
        } else {
            format!(
                "{} librar(ies) found across the search paths",
                libraries.len()
            )
        };

        Ok(json_result(
            summary,
            json!({
                "library_paths": paths.iter().map(|p| p.display().to_string()).collect::<Vec<_>>(),
                "libraries": libraries,
                "modules": modules,
                "functions": functions,
            }),
        ))
    }
}

#[tool_handler]
impl ServerHandler for Demiourgos {
    fn get_info(&self) -> ServerInfo {
        let mut server_info = Implementation::from_build_env();
        server_info.name = "demiourgos".to_string();
        server_info.version = VERSION.to_string();

        let mut info = ServerInfo::default();
        info.protocol_version = ProtocolVersion::default();
        info.capabilities = ServerCapabilities::builder().enable_tools().build();
        info.server_info = server_info;
        info.instructions = Some(
            "Demiourgos gives you eyes (render), a compiler (compile_check), a tape measure \
             (measure, fit_check, cross_section), and a memory of what actually prints \
             (tolerance profiles + calibration). Inner loop: write_model -> compile_check -> \
             render/measure. Before printing, run dfm_check for overhang/wall warnings and use \
             recommend_clearance for the right per-side gap on your printer+material. Calibrate a \
             printer/material once with gen_fit_coupon, print it, then record_outcome — every \
             future design reuses the learned clearances. Models are referenced by name; artifacts \
             live under the workspace's artifacts directory."
                .to_string(),
        );
        info
    }
}

// ===========================================================================
// Tolerance-tool argument types and helpers
// ===========================================================================

/// Default nozzle diameter when the caller omits it.
fn nozzle_or_default(n: Option<f64>) -> f64 {
    n.unwrap_or(0.4)
}

fn source_str(p: &Profile) -> &'static str {
    match p.source {
        demiourgos_tolerance::ProfileSource::Default => "default",
        demiourgos_tolerance::ProfileSource::Calibrated => "calibrated",
    }
}

/// Full JSON view of a profile (its serde form plus its id).
fn profile_json(p: &Profile) -> Value {
    let mut v = serde_json::to_value(p).unwrap_or_else(|_| json!({}));
    if let Some(obj) = v.as_object_mut() {
        obj.insert("id".to_string(), json!(p.key()));
    }
    v
}

fn profile_summary(p: &Profile) -> String {
    let c = &p.clearances_mm;
    format!(
        "{} [{}, {} sample(s)] clearances/side mm: slip {:.2}, snug {:.2}, press {:.2}, snap {:.2}",
        p.key(),
        source_str(p),
        p.samples,
        c.slip,
        c.snug,
        c.press,
        c.snap
    )
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ProfileArgs {
    /// Printer name (e.g. "ender3").
    pub printer: String,
    /// Material (e.g. "PLA", "PETG", "ABS", "TPU").
    pub material: String,
    /// Nozzle diameter in mm (default 0.4).
    #[serde(default, rename = "nozzle_mm")]
    pub nozzle_mm: Option<f64>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct SetProfileArgs {
    /// Printer name.
    pub printer: String,
    /// Material.
    pub material: String,
    /// Nozzle diameter in mm (default 0.4).
    #[serde(default)]
    pub nozzle_mm: Option<f64>,
    /// Per-side slip-fit clearance (mm).
    #[serde(default)]
    pub slip: Option<f64>,
    /// Per-side snug-fit clearance (mm).
    #[serde(default)]
    pub snug: Option<f64>,
    /// Per-side press-fit clearance (mm).
    #[serde(default)]
    pub press: Option<f64>,
    /// Per-side snap-fit clearance (mm).
    #[serde(default)]
    pub snap: Option<f64>,
    /// Signed XY dimensional offset (printed − nominal), mm.
    #[serde(default)]
    pub xy_offset_mm: Option<f64>,
    /// Signed hole-diameter offset (printed − nominal), mm.
    #[serde(default)]
    pub hole_offset_mm: Option<f64>,
    /// Elephant's-foot first-layer widening, mm.
    #[serde(default)]
    pub elephant_foot_mm: Option<f64>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct RecommendArgs {
    /// Printer name.
    pub printer: String,
    /// Material.
    pub material: String,
    /// Nozzle diameter in mm (default 0.4).
    #[serde(default)]
    pub nozzle_mm: Option<f64>,
    /// Fit class: slip, snug, press, or snap.
    pub fit_class: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CouponArgs {
    /// Printer name.
    pub printer: String,
    /// Material.
    pub material: String,
    /// Nozzle diameter in mm (default 0.4).
    #[serde(default)]
    pub nozzle_mm: Option<f64>,
    /// Model name to write (default "<material>_fit_coupon").
    #[serde(default)]
    pub name: Option<String>,
    /// Reference peg diameter in mm (default 10).
    #[serde(default)]
    pub peg_diameter_mm: Option<f64>,
    /// Smallest per-side clearance to test (mm). Provide min+max+step together.
    #[serde(default)]
    pub min_clearance_mm: Option<f64>,
    /// Largest per-side clearance to test (mm).
    #[serde(default)]
    pub max_clearance_mm: Option<f64>,
    /// Clearance step between holes (mm).
    #[serde(default)]
    pub step_mm: Option<f64>,
    /// Plate / hole depth in mm (default 4).
    #[serde(default)]
    pub plate_thickness_mm: Option<f64>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct OutcomeArgs {
    /// Printer name.
    pub printer: String,
    /// Material.
    pub material: String,
    /// Nozzle diameter in mm (default 0.4).
    #[serde(default)]
    pub nozzle_mm: Option<f64>,
    /// Outcome kind: "coupon", "caliper", or "fit".
    pub kind: String,
    /// Fit class (for kind coupon/fit): slip, snug, press, snap.
    #[serde(default)]
    pub fit_class: Option<String>,
    /// Best per-side clearance from a coupon (for kind="coupon").
    #[serde(default)]
    pub best_clearance_mm: Option<f64>,
    /// Feature measured (for kind="caliper"): "outer" or "hole".
    #[serde(default)]
    pub feature: Option<String>,
    /// Nominal designed dimension (for kind="caliper"), mm.
    #[serde(default)]
    pub nominal_mm: Option<f64>,
    /// Measured printed dimension (for kind="caliper"), mm.
    #[serde(default)]
    pub measured_mm: Option<f64>,
    /// Clearance that was used (for kind="fit"), mm/side.
    #[serde(default)]
    pub clearance_mm: Option<f64>,
    /// Fit verdict (for kind="fit"): loose, good, tight, jam.
    #[serde(default)]
    pub verdict: Option<String>,
    /// Optional free-text note.
    #[serde(default)]
    pub note: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct DfmArgs {
    /// Model name.
    pub name: String,
    /// Overhang threshold in degrees from horizontal (default 45).
    #[serde(default)]
    pub overhang_threshold_deg: Option<f64>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ViewArgs {
    /// Model name.
    pub name: String,
    /// Optional surface color as a hex string (e.g. "#2e9bd6"); defaults to a warm filament tone.
    #[serde(default)]
    pub color: Option<String>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Optional variable overrides passed via `-D`.
    #[serde(default)]
    pub defines: Overrides,
}

// ===========================================================================
// param_sweep / visual_diff / library_info argument types and helpers
// ===========================================================================

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ParamSweepArgs {
    /// Model name.
    pub name: String,
    /// Variable to sweep (passed via `-D <parameter>=<value>` per cell).
    pub parameter: String,
    /// Values to render — numbers or strings (max 36).
    pub values: Vec<Value>,
    /// View for every cell (default iso).
    #[serde(default)]
    pub view: Option<String>,
    /// Per-cell image width (default 360).
    #[serde(default)]
    pub width: Option<u32>,
    /// Per-cell image height (default 360).
    #[serde(default)]
    pub height: Option<u32>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
    /// Other fixed variable overrides applied to every cell.
    #[serde(default)]
    pub defines: Overrides,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct VisualDiffArgs {
    /// Model name (variant A; also B unless `name_b` is given).
    pub name: String,
    /// Optional second model to compare against (defaults to `name`).
    #[serde(default)]
    pub name_b: Option<String>,
    /// Variable overrides for variant A.
    #[serde(default)]
    pub defines_a: Overrides,
    /// Variable overrides for variant B.
    #[serde(default)]
    pub defines_b: Overrides,
    /// View for both renders (default iso).
    #[serde(default)]
    pub view: Option<String>,
    /// Image width (default 400).
    #[serde(default)]
    pub width: Option<u32>,
    /// Image height (default 400).
    #[serde(default)]
    pub height: Option<u32>,
    /// Optional `$fn` override.
    #[serde(default, rename = "fn")]
    pub fn_n: Option<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct LibraryInfoArgs {
    /// Optional library to inspect (e.g. "BOSL2"); omit to just list libraries.
    #[serde(default)]
    pub library: Option<String>,
    /// Optional substring filter for module/function names.
    #[serde(default)]
    pub search: Option<String>,
}

/// Recursively collect `.scad` files under `dir`, bounded by depth and count.
fn collect_scad_files(dir: &Path, out: &mut Vec<PathBuf>, depth: usize, cap: usize) {
    if depth > 4 || out.len() >= cap {
        return;
    }
    if let Ok(entries) = std::fs::read_dir(dir) {
        for e in entries.flatten() {
            if out.len() >= cap {
                return;
            }
            let p = e.path();
            if p.is_dir() {
                collect_scad_files(&p, out, depth + 1, cap);
            } else if p.extension().and_then(|x| x.to_str()) == Some("scad") {
                out.push(p);
            }
        }
    }
}

/// Identifier that precedes a `(` (an OpenSCAD module/function name).
fn ident_before_paren(s: &str) -> Option<String> {
    let name: String = s
        .chars()
        .take_while(|c| c.is_alphanumeric() || *c == '_')
        .collect();
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

/// Scan SCAD source for `module`/`function` definitions, applying an optional
/// lowercase substring filter.
fn scan_defs(
    src: &str,
    filter: &Option<String>,
    modules: &mut Vec<String>,
    functions: &mut Vec<String>,
) {
    let keep = |name: &str| match filter {
        Some(f) => name.to_ascii_lowercase().contains(f),
        None => true,
    };
    for line in src.lines() {
        let t = line.trim_start();
        if let Some(rest) = t.strip_prefix("module ") {
            if let Some(name) = ident_before_paren(rest.trim_start()) {
                if keep(&name) {
                    modules.push(name);
                }
            }
        } else if let Some(rest) = t.strip_prefix("function ") {
            if let Some(name) = ident_before_paren(rest.trim_start()) {
                if keep(&name) {
                    functions.push(name);
                }
            }
        }
    }
}
