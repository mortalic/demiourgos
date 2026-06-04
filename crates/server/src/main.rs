//! Demiourgos — an MCP server that gives an AI assistant eyes (render), a compiler
//! (compile_check), and a tape measure (measure, fit_check) for OpenSCAD.
//!
//! Transport is stdio: stdout carries the JSON-RPC MCP stream, so **all** human
//! logging goes to stderr via `tracing`.

mod config;
mod font;
mod geometry;
mod params;
mod render;
mod result;
mod server;
mod workspace;

use anyhow::Context;
use demiourgos_scad::OpenScad;
use rmcp::transport::stdio;
use rmcp::ServiceExt;
use tracing_subscriber::EnvFilter;

use crate::config::Config;
use crate::server::Demiourgos;
use crate::workspace::Workspace;

/// Package version, baked in at compile time.
const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Handle `--version`/`--help` before doing anything else, printing to stdout
/// and exiting. These are the only CLI flags; normally the process just speaks
/// MCP over stdio.
fn handle_cli_flags() {
    for arg in std::env::args().skip(1) {
        match arg.as_str() {
            "-V" | "--version" => {
                println!("demiourgos {VERSION}");
                std::process::exit(0);
            }
            "-h" | "--help" => {
                println!(
                    "demiourgos {VERSION}\n\
                     An MCP server (stdio) that gives an AI assistant eyes, a compiler,\n\
                     and a tape measure for OpenSCAD.\n\n\
                     USAGE:\n    \
                     demiourgos            Start the MCP server on stdio (normal use)\n    \
                     demiourgos --version  Print version and exit\n    \
                     demiourgos --help     Print this help and exit\n\n\
                     ENVIRONMENT:\n    \
                     DEMIOURGOS_WORKSPACE        Workspace directory (default ./workspace)\n    \
                     OPENSCAD_BINARY             Path to the openscad binary (default: PATH)\n    \
                     DEMIOURGOS_RENDER_TIMEOUT   Render timeout, seconds (default 60)\n    \
                     DEMIOURGOS_EXPORT_TIMEOUT   Export timeout, seconds (default 120)\n    \
                     DEMIOURGOS_CHECK_TIMEOUT    compile_check timeout, seconds (default 30)\n    \
                     DEMIOURGOS_LOG              tracing log filter (default info; logs to stderr)"
                );
                std::process::exit(0);
            }
            _ => {}
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    handle_cli_flags();

    // Logs go to stderr only — stdout is the MCP transport.
    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
        .with_env_filter(
            EnvFilter::try_from_env("DEMIOURGOS_LOG").unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_ansi(false)
        .init();

    let config = Config::from_env();
    tracing::info!(workspace = %config.workspace_root.display(), "starting Demiourgos");

    let workspace = Workspace::open(&config.workspace_root).with_context(|| {
        format!(
            "failed to open workspace at {}",
            config.workspace_root.display()
        )
    })?;

    // OpenSCAD discovery is non-fatal: the server still starts so `health` can
    // report the problem and clients get actionable errors from other tools.
    let openscad = match OpenScad::discover().await {
        Ok(s) => {
            tracing::info!(binary = %s.binary.display(), version = %s.version, "found OpenSCAD");
            Ok(s)
        }
        Err(e) => {
            tracing::warn!(error = %e, "OpenSCAD not available");
            Err(e.to_string())
        }
    };

    let service = Demiourgos::new(config, workspace, openscad)
        .serve(stdio())
        .await
        .context("failed to start MCP service over stdio")?;

    tracing::info!("Demiourgos MCP server ready");
    service.waiting().await.context("MCP service error")?;
    Ok(())
}
