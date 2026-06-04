//! Runtime configuration, resolved from environment variables at startup.

use std::path::PathBuf;
use std::time::Duration;

/// Default render timeout (seconds).
const DEFAULT_RENDER_TIMEOUT: u64 = 60;
/// Default export timeout (seconds).
const DEFAULT_EXPORT_TIMEOUT: u64 = 120;
/// Default compile-check timeout (seconds) — the cheap inner loop.
const DEFAULT_CHECK_TIMEOUT: u64 = 30;

/// Server configuration.
#[derive(Debug, Clone)]
pub struct Config {
    /// Root of the `.scad` workspace.
    pub workspace_root: PathBuf,
    /// Directory for the tolerance store (profiles + outcomes).
    pub data_dir: PathBuf,
    pub render_timeout: Duration,
    pub export_timeout: Duration,
    pub check_timeout: Duration,
}

impl Config {
    /// Resolve configuration from the environment.
    ///
    /// - `DEMIOURGOS_WORKSPACE` — workspace directory (default `./workspace`).
    /// - `DEMIOURGOS_DATA` — tolerance store directory (default
    ///   `<workspace>/.demiourgos`).
    /// - `DEMIOURGOS_RENDER_TIMEOUT` / `DEMIOURGOS_EXPORT_TIMEOUT` /
    ///   `DEMIOURGOS_CHECK_TIMEOUT` — timeouts in seconds.
    pub fn from_env() -> Config {
        let workspace_root = std::env::var_os("DEMIOURGOS_WORKSPACE")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("workspace"));

        let data_dir = std::env::var_os("DEMIOURGOS_DATA")
            .map(PathBuf::from)
            .unwrap_or_else(|| workspace_root.join(".demiourgos"));

        Config {
            workspace_root,
            data_dir,
            render_timeout: secs_from_env("DEMIOURGOS_RENDER_TIMEOUT", DEFAULT_RENDER_TIMEOUT),
            export_timeout: secs_from_env("DEMIOURGOS_EXPORT_TIMEOUT", DEFAULT_EXPORT_TIMEOUT),
            check_timeout: secs_from_env("DEMIOURGOS_CHECK_TIMEOUT", DEFAULT_CHECK_TIMEOUT),
        }
    }
}

fn secs_from_env(key: &str, default: u64) -> Duration {
    let secs = std::env::var(key)
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .filter(|&s| s > 0)
        .unwrap_or(default);
    Duration::from_secs(secs)
}
