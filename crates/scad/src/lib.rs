//! `demiurge-scad` — a thin, async wrapper around the OpenSCAD command-line
//! binary.
//!
//! It provides three things Demiurge needs:
//!
//! - [`OpenScad`] — discovery of the `openscad` binary (honoring the
//!   `OPENSCAD_BINARY` env var), version probing, and library detection, plus
//!   running it with a hard timeout and process-group kill on expiry.
//! - [`camera`] — named-view ("front", "iso", …) camera-string generation, so
//!   callers never write raw `--camera` values.
//! - [`diagnostics`] — parsing OpenSCAD's stderr into structured warnings,
//!   errors (with line numbers), and `ECHO:` output.
//!
//! Nothing in this crate writes to stdout — that channel belongs to the MCP
//! transport in the server crate.

pub mod camera;
pub mod diagnostics;
pub mod ops;
pub mod run;

pub use camera::{camera_string, View};
pub use diagnostics::{Diagnostic, ParsedOutput, Severity};
pub use ops::{
    compile_check_args, export_args, render_args, Define, ExportFormat, Projection, RenderOptions,
};
pub use run::{OpenScad, RunOutput, ScadError};
