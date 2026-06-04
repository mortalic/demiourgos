//! Fit classes — the qualitative kind of mating fit a designer wants between two
//! parts, and the clearance (per-side gap, in mm) each implies.

use std::fmt;
use std::str::FromStr;

use serde::{Deserialize, Serialize};

/// A qualitative mating fit between two parts.
///
/// Clearance throughout Demiourgos is the **per-side gap** between the two
/// nominal mating surfaces — the quantity `fit_check` measures as the minimum
/// surface distance. A round peg/hole pair therefore has
/// `hole_diameter = peg_diameter + 2 × clearance`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FitClass {
    /// Free-running: parts slide/rotate without resistance (drawers, lids).
    Slip,
    /// Locating fit: assembles by hand with light friction, no play.
    Snug,
    /// Interference fit: must be pressed together, held by friction (pins, bearings).
    Press,
    /// Snap fit: flexible engagement that clicks past a lip (clips, latches).
    Snap,
}

impl FitClass {
    /// All fit classes in a stable order.
    pub fn all() -> [FitClass; 4] {
        [
            FitClass::Slip,
            FitClass::Snug,
            FitClass::Press,
            FitClass::Snap,
        ]
    }

    /// Lowercase key used in serialization and profile maps.
    pub fn key(self) -> &'static str {
        match self {
            FitClass::Slip => "slip",
            FitClass::Snug => "snug",
            FitClass::Press => "press",
            FitClass::Snap => "snap",
        }
    }

    /// One-line description of the intended behavior.
    pub fn description(self) -> &'static str {
        match self {
            FitClass::Slip => "free-running: slides/rotates without resistance",
            FitClass::Snug => "locating: assembles by hand with light friction, no play",
            FitClass::Press => "interference: pressed together, held by friction",
            FitClass::Snap => "snap: flexible engagement that clicks past a lip",
        }
    }
}

impl fmt::Display for FitClass {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.key())
    }
}

impl FromStr for FitClass {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "slip" | "free" | "loose" | "clearance" => Ok(FitClass::Slip),
            "snug" | "locating" | "transition" => Ok(FitClass::Snug),
            "press" | "interference" | "friction" => Ok(FitClass::Press),
            "snap" | "snapfit" | "snap-fit" => Ok(FitClass::Snap),
            other => Err(format!(
                "unknown fit class '{other}' (expected slip, snug, press, or snap)"
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_aliases() {
        assert_eq!("loose".parse::<FitClass>().unwrap(), FitClass::Slip);
        assert_eq!("INTERFERENCE".parse::<FitClass>().unwrap(), FitClass::Press);
        assert!("welded".parse::<FitClass>().is_err());
    }

    #[test]
    fn keys_round_trip() {
        for c in FitClass::all() {
            assert_eq!(c.key().parse::<FitClass>().unwrap(), c);
        }
    }
}
