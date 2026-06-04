//! High-level OpenSCAD operations: pure argument builders plus thin async
//! wrappers that run them. Keeping the argument construction pure makes it
//! unit-testable without invoking OpenSCAD.

use std::ffi::OsString;
use std::path::Path;
use std::time::Duration;

use crate::camera::{self, View};
use crate::run::{OpenScad, RunOutput, ScadError};

/// Projection mode for renders.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Projection {
    Ortho,
    Perspective,
}

impl Projection {
    /// OpenSCAD's `--projection` value (`o` or `p`).
    pub fn flag(self) -> &'static str {
        match self {
            Projection::Ortho => "o",
            Projection::Perspective => "p",
        }
    }
}

/// A single `-D name=expr` predefinition. `expr` is raw OpenSCAD source
/// (numbers bare, strings already quoted).
#[derive(Debug, Clone)]
pub struct Define {
    pub name: String,
    pub expr: String,
}

impl Define {
    pub fn new(name: impl Into<String>, expr: impl Into<String>) -> Self {
        Define {
            name: name.into(),
            expr: expr.into(),
        }
    }

    fn arg(&self) -> OsString {
        OsString::from(format!("{}={}", self.name, self.expr))
    }
}

/// Push `-D name=expr` for each define onto `args`.
fn push_defines(args: &mut Vec<OsString>, defines: &[Define]) {
    for d in defines {
        args.push(OsString::from("-D"));
        args.push(d.arg());
    }
}

/// Push a `$fn=N` override (as a define) when requested.
fn push_fn(args: &mut Vec<OsString>, fn_: Option<u32>) {
    if let Some(n) = fn_ {
        args.push(OsString::from("-D"));
        args.push(OsString::from(format!("$fn={n}")));
    }
}

/// Build argv for a fast compile check that emits a throwaway `.csg`.
pub fn compile_check_args(file: &Path, output_csg: &Path, defines: &[Define]) -> Vec<OsString> {
    let mut args = vec![OsString::from("-o"), output_csg.into()];
    push_defines(&mut args, defines);
    args.push(file.into());
    args
}

/// Options for a PNG render.
#[derive(Debug, Clone)]
pub struct RenderOptions<'a> {
    pub file: &'a Path,
    pub output_png: &'a Path,
    pub width: u32,
    pub height: u32,
    pub projection: Projection,
    /// Full `--camera` string (no prefix). When `None`, no `--camera` is passed.
    pub camera: Option<String>,
    pub viewall: bool,
    pub autocenter: bool,
    /// Force full CGAL render (clean geometry) rather than preview.
    pub render_full: bool,
    pub fn_: Option<u32>,
    pub defines: &'a [Define],
    pub colorscheme: Option<&'a str>,
}

impl<'a> RenderOptions<'a> {
    /// Construct render options for a named view with sensible defaults.
    pub fn for_view(file: &'a Path, output_png: &'a Path, view: View) -> Self {
        RenderOptions {
            file,
            output_png,
            width: 800,
            height: 600,
            projection: Projection::Ortho,
            camera: Some(camera::camera_string(view, camera::DEFAULT_DISTANCE)),
            viewall: true,
            autocenter: true,
            render_full: true,
            fn_: None,
            defines: &[],
            colorscheme: None,
        }
    }
}

/// Build argv for a PNG render.
pub fn render_args(opts: &RenderOptions) -> Vec<OsString> {
    let mut args = vec![OsString::from("-o"), opts.output_png.into()];

    args.push(OsString::from(format!(
        "--imgsize={},{}",
        opts.width, opts.height
    )));
    args.push(OsString::from(format!(
        "--projection={}",
        opts.projection.flag()
    )));

    if let Some(cam) = &opts.camera {
        args.push(OsString::from(format!("--camera={cam}")));
    }
    if opts.viewall {
        args.push(OsString::from("--viewall"));
    }
    if opts.autocenter {
        args.push(OsString::from("--autocenter"));
    }
    if opts.render_full {
        // Force full (CGAL) geometry evaluation instead of a preview. OpenSCAD's
        // `--render` option takes a value (a CSG element limit; empty means "all"),
        // so it must be passed as a separate, empty argument — a bare `--render`
        // makes the option parser reject the command line.
        args.push(OsString::from("--render"));
        args.push(OsString::from(""));
    }
    if let Some(scheme) = opts.colorscheme {
        args.push(OsString::from(format!("--colorscheme={scheme}")));
    }

    push_fn(&mut args, opts.fn_);
    push_defines(&mut args, opts.defines);

    args.push(opts.file.into());
    args
}

/// Export formats Demiourgos can produce.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFormat {
    BinStl,
    AsciiStl,
    ThreeMf,
    Off,
    Amf,
    Dxf,
    Svg,
}

impl ExportFormat {
    /// Output file extension for this format.
    pub fn extension(self) -> &'static str {
        match self {
            ExportFormat::BinStl | ExportFormat::AsciiStl => "stl",
            ExportFormat::ThreeMf => "3mf",
            ExportFormat::Off => "off",
            ExportFormat::Amf => "amf",
            ExportFormat::Dxf => "dxf",
            ExportFormat::Svg => "svg",
        }
    }

    /// Explicit `--export-format` value, when one is needed to disambiguate
    /// (only STL has an ascii/binary choice the extension can't express).
    pub fn export_format_flag(self) -> Option<&'static str> {
        match self {
            ExportFormat::BinStl => Some("binstl"),
            ExportFormat::AsciiStl => Some("asciistl"),
            _ => None,
        }
    }
}

/// Build argv for an export to `output` in `format`.
pub fn export_args(
    file: &Path,
    output: &Path,
    format: ExportFormat,
    fn_: Option<u32>,
    defines: &[Define],
) -> Vec<OsString> {
    let mut args = vec![OsString::from("-o"), output.into()];
    if let Some(fmt) = format.export_format_flag() {
        args.push(OsString::from("--export-format"));
        args.push(OsString::from(fmt));
    }
    push_fn(&mut args, fn_);
    push_defines(&mut args, defines);
    args.push(file.into());
    args
}

impl OpenScad {
    /// Run a fast compile check, returning the parsed diagnostics.
    pub async fn compile_check(
        &self,
        file: &Path,
        output_csg: &Path,
        defines: &[Define],
        timeout: Duration,
    ) -> Result<RunOutput, ScadError> {
        self.run(compile_check_args(file, output_csg, defines), timeout)
            .await
    }

    /// Render a PNG.
    pub async fn render(
        &self,
        opts: &RenderOptions<'_>,
        timeout: Duration,
    ) -> Result<RunOutput, ScadError> {
        self.run(render_args(opts), timeout).await
    }

    /// Export to a mesh/vector format.
    pub async fn export(
        &self,
        file: &Path,
        output: &Path,
        format: ExportFormat,
        fn_: Option<u32>,
        defines: &[Define],
        timeout: Duration,
    ) -> Result<RunOutput, ScadError> {
        self.run(export_args(file, output, format, fn_, defines), timeout)
            .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn strs(args: &[OsString]) -> Vec<String> {
        args.iter()
            .map(|s| s.to_string_lossy().into_owned())
            .collect()
    }

    #[test]
    fn compile_check_args_emit_csg_output_last_file() {
        let args = compile_check_args(
            &PathBuf::from("part.scad"),
            &PathBuf::from("/tmp/out.csg"),
            &[Define::new("h", "10")],
        );
        assert_eq!(
            strs(&args),
            vec!["-o", "/tmp/out.csg", "-D", "h=10", "part.scad"]
        );
    }

    #[test]
    fn render_args_include_camera_imgsize_projection_and_render() {
        let file = PathBuf::from("part.scad");
        let out = PathBuf::from("out.png");
        let opts = RenderOptions::for_view(&file, &out, View::Iso);
        let args = strs(&render_args(&opts));
        assert!(args.contains(&"--imgsize=800,600".to_string()));
        assert!(args.contains(&"--projection=o".to_string()));
        assert!(args.contains(&"--camera=0,0,0,55,0,25,500".to_string()));
        assert!(args.contains(&"--viewall".to_string()));
        assert!(args.contains(&"--autocenter".to_string()));
        // `--render` is followed by its (empty) value argument.
        let ri = args.iter().position(|a| a == "--render").unwrap();
        assert_eq!(args[ri + 1], "");
        // File comes last.
        assert_eq!(args.last().unwrap(), "part.scad");
    }

    #[test]
    fn render_args_apply_fn_override() {
        let file = PathBuf::from("p.scad");
        let out = PathBuf::from("o.png");
        let mut opts = RenderOptions::for_view(&file, &out, View::Front);
        opts.fn_ = Some(128);
        let args = strs(&render_args(&opts));
        let i = args.iter().position(|a| a == "-D").unwrap();
        assert_eq!(args[i + 1], "$fn=128");
    }

    #[test]
    fn export_args_binstl_set_format_flag() {
        let args = strs(&export_args(
            &PathBuf::from("p.scad"),
            &PathBuf::from("o.stl"),
            ExportFormat::BinStl,
            None,
            &[],
        ));
        assert_eq!(
            args,
            vec!["-o", "o.stl", "--export-format", "binstl", "p.scad"]
        );
    }

    #[test]
    fn export_args_off_has_no_format_flag() {
        let args = strs(&export_args(
            &PathBuf::from("p.scad"),
            &PathBuf::from("o.off"),
            ExportFormat::Off,
            Some(64),
            &[],
        ));
        assert_eq!(args, vec!["-o", "o.off", "-D", "$fn=64", "p.scad"]);
    }
}
