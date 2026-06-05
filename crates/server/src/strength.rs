//! First-order mechanical strength estimation for FDM parts.
//!
//! This is a **closed-form cantilever-beam estimate**, not a finite-element
//! analysis. For the dominant failure mode of hooks, brackets, and arms — a load
//! bending a roughly prismatic section — beam theory gives a fast, useful
//! ballpark. The maximum bending stress in a rectangular cantilever of width `b`,
//! height `h`, and length `L` under a tip load `P` is
//!
//! ```text
//! σ = 6·P·L / (b·h²)
//! ```
//!
//! so the load at which the effective material strength is reached is
//! `P_max = σ_eff·b·h² / (6·L)`. The effective strength applies an FDM knockdown
//! for print orientation (layer adhesion is much weaker than in-plane) and for
//! infill. True strength also depends on geometry stress concentrations, fillets,
//! and toolpaths — for anything safety-critical, run real FEA or a physical test.

use serde::Serialize;

const GRAVITY: f64 = 9.81;

/// Print orientation relative to the bending load.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Orientation {
    /// Layers lie in the bending plane (lying flat) — strongest.
    Flat,
    /// Printed on edge — slightly weaker.
    OnEdge,
    /// Load pulls across the layer lines (upright) — weakest (layer adhesion).
    Upright,
}

impl std::str::FromStr for Orientation {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "flat" | "lying" => Ok(Orientation::Flat),
            "on_edge" | "edge" | "on-edge" => Ok(Orientation::OnEdge),
            "upright" | "vertical" | "standing" | "across_layers" => Ok(Orientation::Upright),
            other => Err(format!(
                "unknown orientation '{other}' (expected flat, on_edge, or upright)"
            )),
        }
    }
}

/// Material flexural properties used by the estimate.
struct MatProps {
    /// In-plane flexural strength (MPa).
    flexural_mpa: f64,
    /// Inter-layer (Z) strength as a fraction of in-plane.
    z_factor: f64,
}

/// Literature-ballpark flexural properties. Unknown materials fall back to PLA.
fn material_props(material: &str) -> MatProps {
    match material.trim().to_ascii_uppercase().as_str() {
        "PLA" => MatProps {
            flexural_mpa: 55.0,
            z_factor: 0.50,
        },
        "PETG" => MatProps {
            flexural_mpa: 50.0,
            z_factor: 0.65,
        },
        "ABS" | "ASA" => MatProps {
            flexural_mpa: 42.0,
            z_factor: 0.45,
        },
        "NYLON" | "PA" | "PA12" | "PA6" => MatProps {
            flexural_mpa: 50.0,
            z_factor: 0.60,
        },
        "TPU" | "TPE" => MatProps {
            flexural_mpa: 12.0,
            z_factor: 0.70,
        },
        _ => MatProps {
            flexural_mpa: 50.0,
            z_factor: 0.50,
        },
    }
}

/// Inputs for a cantilever strength estimate.
#[derive(Debug, Clone)]
pub struct BeamSpec {
    /// Cross-section width `b` (mm) — the dimension across the bending axis.
    pub width_mm: f64,
    /// Cross-section height `h` (mm) — the dimension in the bending direction.
    pub height_mm: f64,
    /// Cantilever length `L` (mm) from the support to the load.
    pub length_mm: f64,
    pub material: String,
    pub orientation: Orientation,
    /// Infill fraction (0.0–1.0).
    pub infill_fraction: f64,
    /// Applied tip load (N), if checking a specific load.
    pub load_n: Option<f64>,
}

/// The strength estimate.
#[derive(Debug, Clone, Serialize)]
pub struct StrengthReport {
    pub effective_strength_mpa: f64,
    pub section_modulus_mm3: f64,
    /// Maximum tip load before the effective strength is reached.
    pub max_load_n: f64,
    pub max_load_kg: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub applied_load_n: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bending_stress_mpa: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub safety_factor: Option<f64>,
    pub notes: Vec<String>,
}

/// Estimate the bending strength of a rectangular cantilever.
pub fn estimate(spec: &BeamSpec) -> Result<StrengthReport, String> {
    if spec.width_mm <= 0.0 || spec.height_mm <= 0.0 || spec.length_mm <= 0.0 {
        return Err("width, height, and length must be positive".to_string());
    }
    let infill = spec.infill_fraction.clamp(0.0, 1.0);
    let props = material_props(&spec.material);

    let orient_factor = match spec.orientation {
        Orientation::Flat => 1.0,
        Orientation::OnEdge => 0.85,
        Orientation::Upright => props.z_factor,
    };
    // Walls carry most bending load, so infill matters but isn't linear.
    let infill_factor = 0.40 + 0.60 * infill;
    let effective = props.flexural_mpa * orient_factor * infill_factor;

    // Section modulus S = b·h²/6 (mm³); max moment M = σ·S; P_max = M / L.
    let s = spec.width_mm * spec.height_mm * spec.height_mm / 6.0;
    let max_moment = effective * s; // N·mm  (MPa·mm³ = N·mm)
    let max_load_n = max_moment / spec.length_mm;

    let mut notes = vec![
        "First-order cantilever beam estimate — not FEA. Assumes a prismatic \
         rectangular section, a tip point load, and no stress concentrations."
            .to_string(),
    ];
    if matches!(spec.orientation, Orientation::Upright) {
        notes.push(
            "Upright orientation loads across layer lines; layer adhesion governs and \
             real strength is highly print-dependent."
                .to_string(),
        );
    }

    let (applied_load_n, bending_stress_mpa, safety_factor) = match spec.load_n {
        Some(p) if p > 0.0 => {
            let stress =
                6.0 * p * spec.length_mm / (spec.width_mm * spec.height_mm * spec.height_mm);
            let sf = effective / stress;
            if sf < 1.5 {
                notes.push(format!(
                    "Safety factor {sf:.1} is low; consider a thicker section, shorter reach, \
                     or a stronger orientation/material."
                ));
            }
            (Some(p), Some(round2(stress)), Some(round2(sf)))
        }
        _ => (None, None, None),
    };

    Ok(StrengthReport {
        effective_strength_mpa: round2(effective),
        section_modulus_mm3: round2(s),
        max_load_n: round2(max_load_n),
        max_load_kg: round2(max_load_n / GRAVITY),
        applied_load_n,
        bending_stress_mpa,
        safety_factor,
        notes,
    })
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec() -> BeamSpec {
        BeamSpec {
            width_mm: 20.0,
            height_mm: 6.0,
            length_mm: 40.0,
            material: "PLA".into(),
            orientation: Orientation::Flat,
            infill_fraction: 1.0,
            load_n: None,
        }
    }

    #[test]
    fn max_load_matches_beam_formula() {
        // σ_eff = 55 MPa (flat, 100% infill). S = 20*36/6 = 120 mm³.
        // M = 55*120 = 6600 N·mm; P = 6600/40 = 165 N.
        let r = estimate(&spec()).unwrap();
        assert!((r.section_modulus_mm3 - 120.0).abs() < 1e-6);
        assert!((r.max_load_n - 165.0).abs() < 0.1, "got {}", r.max_load_n);
    }

    #[test]
    fn upright_is_weaker_than_flat() {
        let mut up = spec();
        up.orientation = Orientation::Upright;
        assert!(estimate(&up).unwrap().max_load_n < estimate(&spec()).unwrap().max_load_n);
    }

    #[test]
    fn lower_infill_reduces_strength() {
        let mut low = spec();
        low.infill_fraction = 0.2;
        assert!(estimate(&low).unwrap().max_load_n < estimate(&spec()).unwrap().max_load_n);
    }

    #[test]
    fn applied_load_reports_safety_factor() {
        let mut s = spec();
        s.load_n = Some(82.5); // half of max -> SF ~2
        let r = estimate(&s).unwrap();
        assert!((r.safety_factor.unwrap() - 2.0).abs() < 0.05);
    }

    #[test]
    fn taller_section_is_much_stronger() {
        // Doubling height should ~4x the strength (h² term).
        let mut tall = spec();
        tall.height_mm = 12.0;
        let ratio = estimate(&tall).unwrap().max_load_n / estimate(&spec()).unwrap().max_load_n;
        assert!((ratio - 4.0).abs() < 0.01);
    }

    #[test]
    fn rejects_bad_dims() {
        let mut bad = spec();
        bad.height_mm = 0.0;
        assert!(estimate(&bad).is_err());
    }
}
