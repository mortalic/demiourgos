//! Slicer integration for `print_check`: discover a PrusaSlicer-family CLI and
//! parse print-time / filament statistics out of the G-code it produces.
//!
//! The discovery and parsing here are pure and unit-tested; the actual slice is
//! run by the server tool. Slicing needs a slicer **and** a configuration
//! (printer/print/filament presets), so this is opt-in and degrades cleanly when
//! no slicer is installed.

use std::path::PathBuf;

use serde::Serialize;

/// PrusaSlicer-family CLI binaries to look for on `PATH`.
pub const SLICER_CANDIDATES: &[&str] = &[
    "prusa-slicer",
    "prusa-slicer-console",
    "PrusaSlicer",
    "superslicer",
    "SuperSlicer",
    "orca-slicer",
    "orcaslicer",
    "OrcaSlicer",
    "slic3r",
];

/// Locate a slicer binary: `DEMIOURGOS_SLICER` if set, else the first candidate
/// found on `PATH`.
pub fn discover_slicer() -> Option<PathBuf> {
    if let Some(v) = std::env::var_os("DEMIOURGOS_SLICER") {
        if !v.is_empty() {
            return Some(PathBuf::from(v));
        }
    }
    let path = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path) {
        for c in SLICER_CANDIDATES {
            let p = dir.join(c);
            if p.is_file() {
                return Some(p);
            }
        }
    }
    None
}

/// Print statistics parsed from sliced G-code.
#[derive(Debug, Clone, Default, PartialEq, Serialize)]
pub struct GcodeStats {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub print_time: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub print_time_seconds: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub filament_mm: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub filament_cm3: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub filament_g: Option<f64>,
}

impl GcodeStats {
    pub fn is_empty(&self) -> bool {
        self.print_time.is_none() && self.filament_mm.is_none() && self.filament_g.is_none()
    }
}

/// Extract the value after the first `=` on a line.
fn after_eq(line: &str) -> Option<&str> {
    line.split_once('=').map(|(_, v)| v.trim())
}

/// Parse a duration like `1d 2h 23m 45s` (any subset) into seconds.
fn parse_duration(s: &str) -> Option<u64> {
    let mut total = 0u64;
    let mut any = false;
    for tok in s.split_whitespace() {
        let (num, unit) = tok.split_at(tok.find(|c: char| c.is_alphabetic())?);
        let n: u64 = num.parse().ok()?;
        let mult = match unit {
            "d" => 86400,
            "h" => 3600,
            "m" => 60,
            "s" => 1,
            _ => return None,
        };
        total += n * mult;
        any = true;
    }
    any.then_some(total)
}

/// Parse PrusaSlicer/Slic3r-style footer comments for print stats.
pub fn parse_gcode_stats(gcode: &str) -> GcodeStats {
    let mut stats = GcodeStats::default();
    for line in gcode.lines() {
        let l = line.trim_start_matches(';').trim();
        let lower = l.to_ascii_lowercase();
        if lower.starts_with("estimated printing time") {
            if let Some(v) = after_eq(l) {
                stats.print_time = Some(v.to_string());
                stats.print_time_seconds = parse_duration(v);
            }
        } else if lower.starts_with("filament used [mm]") {
            stats.filament_mm = after_eq(l).and_then(|v| v.parse().ok());
        } else if lower.starts_with("filament used [cm3]") {
            stats.filament_cm3 = after_eq(l).and_then(|v| v.parse().ok());
        } else if lower.starts_with("filament used [g]")
            || lower.starts_with("total filament used [g]")
        {
            // Prefer the first non-zero reading we see.
            if stats.filament_g.is_none() {
                stats.filament_g = after_eq(l).and_then(|v| v.parse().ok());
            }
        }
    }
    stats
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_durations() {
        assert_eq!(parse_duration("45s"), Some(45));
        assert_eq!(parse_duration("23m 45s"), Some(23 * 60 + 45));
        assert_eq!(parse_duration("1h 23m 45s"), Some(3600 + 23 * 60 + 45));
        assert_eq!(parse_duration("1d 2h"), Some(86400 + 7200));
        assert_eq!(parse_duration("garbage"), None);
    }

    #[test]
    fn parses_prusaslicer_footer() {
        let gcode = "\
; G-code\nG1 X0 Y0\n\
; filament used [mm] = 1234.56\n\
; filament used [cm3] = 3.21\n\
; filament used [g] = 3.95\n\
; estimated printing time (normal mode) = 1h 23m 45s\n";
        let s = parse_gcode_stats(gcode);
        assert_eq!(s.filament_mm, Some(1234.56));
        assert_eq!(s.filament_cm3, Some(3.21));
        assert_eq!(s.filament_g, Some(3.95));
        assert_eq!(s.print_time.as_deref(), Some("1h 23m 45s"));
        assert_eq!(s.print_time_seconds, Some(3600 + 23 * 60 + 45));
        assert!(!s.is_empty());
    }

    #[test]
    fn empty_gcode_yields_empty_stats() {
        assert!(parse_gcode_stats("G1 X0\nG1 Y0\n").is_empty());
    }
}
