//! Material/printer **profiles**: the calibrated dimensional behavior of one
//! `(printer, material, nozzle)` combination, plus its recommended per-fit-class
//! clearances. Profiles start from literature-based defaults and are refined by
//! [`crate::calibrate`] as real-world outcomes accumulate.

use serde::{Deserialize, Serialize};

use crate::fit::FitClass;

/// Recommended per-side clearance (mm) for each fit class.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Clearances {
    pub slip: f64,
    pub snug: f64,
    pub press: f64,
    pub snap: f64,
}

impl Clearances {
    /// All four classes set to the same value.
    pub fn uniform(v: f64) -> Clearances {
        Clearances {
            slip: v,
            snug: v,
            press: v,
            snap: v,
        }
    }

    pub fn get(&self, class: FitClass) -> f64 {
        match class {
            FitClass::Slip => self.slip,
            FitClass::Snug => self.snug,
            FitClass::Press => self.press,
            FitClass::Snap => self.snap,
        }
    }

    pub fn set(&mut self, class: FitClass, value: f64) {
        match class {
            FitClass::Slip => self.slip = value,
            FitClass::Snug => self.snug = value,
            FitClass::Press => self.press = value,
            FitClass::Snap => self.snap = value,
        }
    }
}

/// Prior (uncalibrated) standard deviation on a per-side clearance, in mm —
/// how unsure the literature default is before any real-world data.
pub const PRIOR_STD_MM: f64 = 0.12;

/// Default per-class standard deviations (the prior), used by serde when an
/// older `profiles.json` predates the field.
fn prior_std_clearances() -> Clearances {
    Clearances::uniform(PRIOR_STD_MM)
}

/// Where a profile's numbers came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ProfileSource {
    /// Seeded from material/literature defaults; not yet calibrated.
    Default,
    /// Refined from at least one recorded real-world outcome.
    Calibrated,
}

/// The calibrated dimensional behavior of one printer + material + nozzle.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Profile {
    pub printer: String,
    pub material: String,
    pub nozzle_mm: f64,

    /// Signed XY dimensional error (printed − nominal), in mm. Positive means
    /// the printer makes outer dimensions larger than designed.
    pub xy_offset_mm: f64,
    /// Signed hole-diameter error (printed − nominal), in mm. Usually negative:
    /// holes print undersized.
    pub hole_offset_mm: f64,
    /// First-layer bulge ("elephant's foot"), in mm, as a positive widening.
    pub elephant_foot_mm: f64,

    /// Recommended per-side clearances by fit class (posterior mean).
    pub clearances_mm: Clearances,
    /// Posterior standard deviation of each clearance (confidence — smaller is
    /// more certain). Shrinks as outcomes accumulate.
    #[serde(default = "prior_std_clearances")]
    pub clearance_std_mm: Clearances,

    /// How many recorded outcomes informed this profile.
    pub samples: u32,
    pub source: ProfileSource,
}

impl Profile {
    /// Stable identifier `printer/material/nozzle`.
    pub fn id(printer: &str, material: &str, nozzle_mm: f64) -> String {
        format!(
            "{}/{}/{}",
            slug(printer),
            slug(material),
            trim_num(nozzle_mm)
        )
    }

    /// This profile's id.
    pub fn key(&self) -> String {
        Profile::id(&self.printer, &self.material, self.nozzle_mm)
    }

    /// Build a fresh, uncalibrated profile seeded from material defaults.
    pub fn default_for(printer: &str, material: &str, nozzle_mm: f64) -> Profile {
        let d = material_defaults(material);
        Profile {
            printer: printer.to_string(),
            material: material.to_string(),
            nozzle_mm,
            xy_offset_mm: d.xy_offset_mm,
            hole_offset_mm: d.hole_offset_mm,
            elephant_foot_mm: d.elephant_foot_mm,
            clearances_mm: d.clearances,
            clearance_std_mm: prior_std_clearances(),
            samples: 0,
            source: ProfileSource::Default,
        }
    }

    /// Recommended per-side clearance for a fit class (posterior mean).
    pub fn clearance(&self, class: FitClass) -> f64 {
        self.clearances_mm.get(class)
    }

    /// Posterior standard deviation (uncertainty) of a class's clearance.
    pub fn clearance_std(&self, class: FitClass) -> f64 {
        self.clearance_std_mm.get(class)
    }
}

/// Material-level default behavior, before any calibration.
pub struct MaterialDefaults {
    pub clearances: Clearances,
    pub xy_offset_mm: f64,
    pub hole_offset_mm: f64,
    pub elephant_foot_mm: f64,
}

/// Literature-informed starting points per material. Unknown materials fall back
/// to PLA-like values. These are deliberately conservative seeds — the whole
/// point is to refine them per printer from measured outcomes.
pub fn material_defaults(material: &str) -> MaterialDefaults {
    let m = material.trim().to_ascii_uppercase();
    // (slip, snug, press, snap) per-side mm, then offsets.
    let (slip, snug, press, snap, xy, hole, foot) = match m.as_str() {
        "PLA" => (0.20, 0.10, 0.00, 0.15, 0.00, -0.10, 0.15),
        "PETG" => (0.25, 0.13, 0.00, 0.18, 0.05, -0.12, 0.20),
        "ABS" | "ASA" => (0.28, 0.15, 0.02, 0.20, 0.00, -0.10, 0.20),
        "TPU" | "TPE" => (0.30, 0.18, 0.05, 0.25, 0.05, -0.15, 0.20),
        "NYLON" | "PA" | "PA12" | "PA6" => (0.30, 0.16, 0.03, 0.22, 0.05, -0.15, 0.20),
        // Unknown → PLA-ish defaults.
        _ => (0.20, 0.10, 0.00, 0.15, 0.00, -0.10, 0.15),
    };
    MaterialDefaults {
        clearances: Clearances {
            slip,
            snug,
            press,
            snap,
        },
        xy_offset_mm: xy,
        hole_offset_mm: hole,
        elephant_foot_mm: foot,
    }
}

/// Lowercase, filesystem-safe slug for ids.
fn slug(s: &str) -> String {
    s.trim()
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '.' || c == '-' {
                c.to_ascii_lowercase()
            } else {
                '_'
            }
        })
        .collect()
}

/// Format a float compactly for ids (e.g. `0.4`).
fn trim_num(v: f64) -> String {
    format!("{v}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn id_is_stable_and_slugged() {
        assert_eq!(Profile::id("Ender 3", "PETG", 0.4), "ender_3/petg/0.4");
    }

    #[test]
    fn default_profile_is_uncalibrated() {
        let p = Profile::default_for("ender3", "PLA", 0.4);
        assert_eq!(p.source, ProfileSource::Default);
        assert_eq!(p.samples, 0);
        assert_eq!(p.clearance(FitClass::Slip), 0.20);
        assert_eq!(p.clearance(FitClass::Press), 0.00);
    }

    #[test]
    fn unknown_material_falls_back() {
        let p = Profile::default_for("ender3", "Wood-fill", 0.4);
        // PLA-like fallback
        assert_eq!(p.clearance(FitClass::Snug), 0.10);
    }

    #[test]
    fn petg_is_looser_than_pla() {
        let pla = Profile::default_for("p", "PLA", 0.4);
        let petg = Profile::default_for("p", "PETG", 0.4);
        assert!(petg.clearance(FitClass::Slip) > pla.clearance(FitClass::Slip));
    }
}
