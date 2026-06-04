//! Process orchestration: discover the OpenSCAD binary and run it with a hard
//! timeout, capturing and parsing its output.
//!
//! stdout of *this* process is reserved for the MCP transport, so nothing here
//! ever writes to it — OpenSCAD's own stdout/stderr are captured into buffers.

use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::Duration;

use tokio::io::AsyncReadExt;
use tokio::process::Command;

use crate::diagnostics::{self, ParsedOutput};

/// Errors that can arise while locating or running OpenSCAD.
#[derive(Debug, thiserror::Error)]
pub enum ScadError {
    #[error(
        "OpenSCAD binary not found. Install OpenSCAD and ensure `openscad` is on PATH, \
         or set the OPENSCAD_BINARY environment variable to its full path."
    )]
    NotFound,

    #[error("failed to launch OpenSCAD ({binary}): {source}")]
    Spawn {
        binary: String,
        #[source]
        source: std::io::Error,
    },

    #[error("OpenSCAD timed out after {0:.1}s and was killed")]
    Timeout(f64),

    #[error("I/O error while running OpenSCAD: {0}")]
    Io(#[from] std::io::Error),
}

/// Outcome of a single OpenSCAD invocation.
#[derive(Debug, Clone)]
pub struct RunOutput {
    /// Whether OpenSCAD exited with status 0.
    pub success: bool,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    /// Diagnostics and ECHO output parsed from stderr+stdout.
    pub parsed: ParsedOutput,
}

/// A discovered OpenSCAD installation.
#[derive(Debug, Clone)]
pub struct OpenScad {
    /// Absolute or PATH-resolvable command used to invoke OpenSCAD.
    pub binary: PathBuf,
    /// Version string as reported by `openscad --version` (e.g. `2021.01`).
    pub version: String,
    /// Library directories OpenSCAD will search (best-effort).
    pub library_paths: Vec<PathBuf>,
    /// Names of notable libraries detected (currently just `BOSL2`).
    pub libraries: Vec<String>,
}

impl OpenScad {
    /// Locate OpenSCAD, honoring `OPENSCAD_BINARY`, and probe its version and
    /// available libraries.
    pub async fn discover() -> Result<Self, ScadError> {
        let binary = match std::env::var_os("OPENSCAD_BINARY") {
            Some(v) if !v.is_empty() => PathBuf::from(v),
            _ => PathBuf::from("openscad"),
        };

        // Probe version. This also validates that the binary is runnable.
        let out = run_capture(
            &binary,
            &[OsString::from("--version")],
            Duration::from_secs(10),
        )
        .await
        .map_err(|e| match e {
            ScadError::Io(io) if io.kind() == std::io::ErrorKind::NotFound => ScadError::NotFound,
            other => other,
        })?;

        // `--version` prints to stderr: "OpenSCAD version 2021.01".
        let version = parse_version(&out.stderr)
            .or_else(|| parse_version(&out.stdout))
            .unwrap_or_else(|| "unknown".to_string());

        let library_paths = library_search_paths();
        let libraries = detect_libraries(&library_paths);

        Ok(OpenScad {
            binary,
            version,
            library_paths,
            libraries,
        })
    }

    /// Run OpenSCAD with the given arguments under a hard timeout. On timeout
    /// the whole process group is killed and [`ScadError::Timeout`] is returned.
    pub async fn run<I, S>(&self, args: I, timeout: Duration) -> Result<RunOutput, ScadError>
    where
        I: IntoIterator<Item = S>,
        S: Into<OsString>,
    {
        let args: Vec<OsString> = args.into_iter().map(Into::into).collect();
        run_capture(&self.binary, &args, timeout).await
    }
}

/// Spawn `binary args...`, capture stdout/stderr, enforce `timeout`.
async fn run_capture(
    binary: &Path,
    args: &[OsString],
    timeout: Duration,
) -> Result<RunOutput, ScadError> {
    let mut cmd = Command::new(binary);
    cmd.args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);

    // Put the child in its own process group so we can kill any grandchildren
    // (e.g. helper processes) on timeout, not just OpenSCAD itself.
    #[cfg(unix)]
    cmd.process_group(0);

    let mut child = cmd.spawn().map_err(|source| match source.kind() {
        std::io::ErrorKind::NotFound => ScadError::Io(source),
        _ => ScadError::Spawn {
            binary: binary.display().to_string(),
            source,
        },
    })?;

    let mut stdout_pipe = child.stdout.take();
    let mut stderr_pipe = child.stderr.take();

    let mut stdout_buf = Vec::new();
    let mut stderr_buf = Vec::new();

    let read_out = async {
        if let Some(p) = stdout_pipe.as_mut() {
            let _ = p.read_to_end(&mut stdout_buf).await;
        }
    };
    let read_err = async {
        if let Some(p) = stderr_pipe.as_mut() {
            let _ = p.read_to_end(&mut stderr_buf).await;
        }
    };

    let wait = async {
        // Drain pipes concurrently with waiting to avoid deadlock on full pipes.
        let (_, _, status) = tokio::join!(read_out, read_err, child.wait());
        status
    };

    let status = match tokio::time::timeout(timeout, wait).await {
        Ok(status) => status?,
        Err(_) => {
            kill_process_group(&mut child);
            // Reap so we don't leave a zombie.
            let _ = child.wait().await;
            return Err(ScadError::Timeout(timeout.as_secs_f64()));
        }
    };

    let stdout = String::from_utf8_lossy(&stdout_buf).into_owned();
    let stderr = String::from_utf8_lossy(&stderr_buf).into_owned();

    // ECHO/diagnostics land on stderr; parse both to be safe.
    let mut combined = String::with_capacity(stderr.len() + stdout.len());
    combined.push_str(&stderr);
    if !stdout.is_empty() {
        combined.push('\n');
        combined.push_str(&stdout);
    }
    let parsed = diagnostics::parse(&combined);

    Ok(RunOutput {
        success: status.success(),
        exit_code: status.code(),
        stdout,
        stderr,
        parsed,
    })
}

/// Kill the child's process group (Unix) or just the child (other platforms).
fn kill_process_group(child: &mut tokio::process::Child) {
    #[cfg(unix)]
    {
        if let Some(pid) = child.id() {
            // Negative pid targets the whole group (we set process_group(0)).
            unsafe {
                libc::killpg(pid as libc::pid_t, libc::SIGKILL);
            }
        }
    }
    let _ = child.start_kill();
}

/// Extract the version number from an `openscad --version` line.
fn parse_version(text: &str) -> Option<String> {
    for line in text.lines() {
        if let Some(idx) = line.find("version") {
            // Take the first whitespace-delimited token after "version" and
            // accept it only if it looks like a version number (starts with a
            // digit), so prose like "no version here" doesn't match.
            if let Some(tok) = line[idx + "version".len()..].split_whitespace().next() {
                if tok.starts_with(|c: char| c.is_ascii_digit()) {
                    return Some(tok.to_string());
                }
            }
        }
    }
    None
}

/// Candidate OpenSCAD library search directories, in priority order.
fn library_search_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    // OPENSCADPATH may contain several entries.
    if let Some(val) = std::env::var_os("OPENSCADPATH") {
        for entry in std::env::split_paths(&val) {
            if !entry.as_os_str().is_empty() {
                paths.push(entry);
            }
        }
    }

    // Per-user library directory.
    #[cfg(target_os = "macos")]
    if let Some(home) = std::env::var_os("HOME") {
        paths.push(PathBuf::from(home).join("Documents/OpenSCAD/libraries"));
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        if let Some(data) = std::env::var_os("XDG_DATA_HOME") {
            paths.push(PathBuf::from(data).join("OpenSCAD/libraries"));
        } else if let Some(home) = std::env::var_os("HOME") {
            paths.push(PathBuf::from(home).join(".local/share/OpenSCAD/libraries"));
        }
    }
    #[cfg(windows)]
    if let Some(docs) = std::env::var_os("USERPROFILE") {
        paths.push(PathBuf::from(docs).join("Documents/OpenSCAD/libraries"));
    }

    // System-wide install locations.
    paths.push(PathBuf::from("/usr/share/openscad/libraries"));
    paths.push(PathBuf::from("/usr/local/share/openscad/libraries"));

    paths
}

/// Detect notable libraries (BOSL2) among the search paths.
fn detect_libraries(paths: &[PathBuf]) -> Vec<String> {
    let mut found = Vec::new();
    for dir in paths {
        let candidate = dir.join("BOSL2");
        if candidate.is_dir() && !found.iter().any(|f| f == "BOSL2") {
            found.push("BOSL2".to_string());
        }
    }
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_version_from_stderr_banner() {
        assert_eq!(
            parse_version("OpenSCAD version 2021.01\n").as_deref(),
            Some("2021.01")
        );
        assert_eq!(
            parse_version("Some banner\nOpenSCAD version 2025.03.15").as_deref(),
            Some("2025.03.15")
        );
        assert_eq!(parse_version("no version here"), None);
    }

    #[test]
    fn library_search_paths_are_nonempty() {
        // Always includes the system-wide fallbacks.
        let paths = library_search_paths();
        assert!(paths.iter().any(|p| p.ends_with("openscad/libraries")));
    }
}
