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

#[tokio::main]
async fn main() -> anyhow::Result<()> {
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
