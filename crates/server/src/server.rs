//! The Demiourgos MCP server: state and the full tool surface.

use std::collections::BTreeMap;
use std::path::Path;

use demiourgos_mesh::Mesh;
use demiourgos_scad::{Define, ExportFormat, OpenScad, RenderOptions, RunOutput, View};
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
}

impl Demiourgos {
    /// Build the server from resolved config and an OpenSCAD discovery result.
    pub fn new(
        config: Config,
        workspace: Workspace,
        openscad: Result<OpenScad, String>,
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
            format!(
                "NO collision: {} and {} are clear ({gap_str})",
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
                "part_a": { "name": part_a.file_name(), "bounding_box": bb_a },
                "part_b": {
                    "name": part_b.file_name(),
                    "bounding_box": bb_b,
                    "transform": { "translation": transform.translation, "rotation": transform.rotation },
                },
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
            "Demiourgos gives you eyes (render), a compiler (compile_check), and a tape measure \
             (measure, fit_check) for OpenSCAD. Write models with write_model, validate cheaply \
             with compile_check in your inner loop, then render or measure. Tools reference \
             models by name; rendered images and meshes are saved under the workspace's \
             artifacts directory."
                .to_string(),
        );
        info
    }
}
