//! Design-for-manufacturing (DFM) analysis for FDM printing.
//!
//! These are the *cheap, geometric* checks that catch most reprints — overhangs
//! that need support, the bed-contact footprint, and an estimate of the thinnest
//! wall — computed directly from the mesh. They are not a physics simulation;
//! they are the fast pre-flight a human would eyeball, made automatic.
//!
//! Build direction is assumed to be **+Z** (the usual FDM convention).

use serde::Serialize;

use crate::Mesh;

/// Default overhang threshold: surfaces inclined less than this from horizontal
/// generally need support on FDM.
pub const DEFAULT_OVERHANG_THRESHOLD_DEG: f64 = 45.0;

/// Result of a DFM pre-flight.
#[derive(Debug, Clone, Serialize)]
pub struct DfmReport {
    /// Build height (bounding-box Z size), mm.
    pub build_height_mm: f64,
    pub overhang_threshold_deg: f64,
    /// Total downward-facing surface area steeper than the threshold (needs support), mm².
    pub overhang_area_mm2: f64,
    /// Total surface area, mm².
    pub total_area_mm2: f64,
    /// Fraction of surface area that is unsupported overhang.
    pub overhang_fraction: f64,
    /// Steepest overhang present: the smallest surface-from-horizontal angle among
    /// downward faces (0° = flat ceiling, worst). `None` if there are no downward faces.
    pub steepest_overhang_deg: Option<f64>,
    /// Area in contact with the bed (downward faces at the lowest Z), mm².
    pub bed_contact_area_mm2: f64,
    /// Estimated minimum wall thickness from ray sampling, mm. `None` if it could
    /// not be estimated.
    pub min_wall_mm: Option<f64>,
    /// Human-readable warnings worth surfacing to the designer.
    pub warnings: Vec<String>,
}

/// Geometric (winding-based) unit normal of a triangle, or `None` if degenerate.
fn triangle_normal(a: [f64; 3], b: [f64; 3], c: [f64; 3]) -> Option<[f64; 3]> {
    let u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
    let v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    let n = [
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
    ];
    let len = (n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt();
    if len < 1e-12 {
        None
    } else {
        Some([n[0] / len, n[1] / len, n[2] / len])
    }
}

fn triangle_area(a: [f64; 3], b: [f64; 3], c: [f64; 3]) -> f64 {
    let u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
    let v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    let n = [
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
    ];
    0.5 * (n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt()
}

impl Mesh {
    /// Run a DFM pre-flight with the default overhang threshold.
    pub fn dfm_report(&self) -> DfmReport {
        self.dfm_report_with(DEFAULT_OVERHANG_THRESHOLD_DEG)
    }

    /// Run a DFM pre-flight with a custom overhang threshold (degrees from horizontal).
    pub fn dfm_report_with(&self, overhang_threshold_deg: f64) -> DfmReport {
        let z_min = self
            .vertices
            .iter()
            .map(|v| v[2])
            .fold(f64::INFINITY, f64::min);
        let build_height_mm = self.bounding_box().map(|b| b.size[2]).unwrap_or(0.0);

        // Bed-contact band: faces whose centroid sits within this of the lowest Z.
        let bed_eps = (build_height_mm * 0.01).clamp(0.05, 0.5);

        let mut total_area = 0.0;
        let mut overhang_area = 0.0;
        let mut bed_contact_area = 0.0;
        let mut steepest: Option<f64> = None;

        for f in &self.faces {
            let a = self.vertices[f[0]];
            let b = self.vertices[f[1]];
            let c = self.vertices[f[2]];
            let area = triangle_area(a, b, c);
            if area <= 0.0 {
                continue;
            }
            total_area += area;

            let Some(n) = triangle_normal(a, b, c) else {
                continue;
            };

            // Downward-facing exterior surface.
            if n[2] < -1e-6 {
                // Surface angle from horizontal via acos(-n.z): a flat ceiling
                // (n.z = -1) gives 0°, a vertical wall (n.z → 0) gives 90°.
                let overhang_angle = (-n[2]).clamp(0.0, 1.0).acos().to_degrees();

                steepest = Some(match steepest {
                    Some(s) => s.min(overhang_angle),
                    None => overhang_angle,
                });

                if overhang_angle < overhang_threshold_deg {
                    overhang_area += area;
                }

                // Bed contact: downward face near the lowest Z.
                let cz = (a[2] + b[2] + c[2]) / 3.0;
                if (cz - z_min).abs() <= bed_eps {
                    bed_contact_area += area;
                }
            }
        }

        let overhang_fraction = if total_area > 0.0 {
            overhang_area / total_area
        } else {
            0.0
        };

        let min_wall_mm = crate::proximity::min_wall_thickness(self, 1500);

        let mut warnings = Vec::new();
        if overhang_fraction > 0.02 {
            warnings.push(format!(
                "{:.0}% of the surface is unsupported overhang (steeper than {:.0}° from horizontal); supports likely needed",
                overhang_fraction * 100.0,
                overhang_threshold_deg
            ));
        }
        if let Some(s) = steepest {
            if s < 20.0 {
                warnings.push(format!(
                    "near-horizontal overhang present (~{s:.0}° from horizontal); expect sag or supports"
                ));
            }
        }
        if bed_contact_area < 1.0 {
            warnings.push(
                "very small bed-contact footprint; the part may need a brim/raft for adhesion"
                    .to_string(),
            );
        }
        if let Some(w) = min_wall_mm {
            if w < 0.8 {
                warnings.push(format!(
                    "thinnest wall ~{w:.2} mm is below ~2 nozzle widths; it may be weak or unprintable"
                ));
            }
        }

        DfmReport {
            build_height_mm,
            overhang_threshold_deg,
            overhang_area_mm2: overhang_area,
            total_area_mm2: total_area,
            overhang_fraction,
            steepest_overhang_deg: steepest,
            bed_contact_area_mm2: bed_contact_area,
            min_wall_mm,
            warnings,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A box [0,w]×[0,d]×[0,h]; with a clean axis-aligned box there are no
    /// overhangs (all faces vertical or horizontal-up except the flat bottom).
    fn box_mesh(w: f64, d: f64, h: f64) -> Mesh {
        let v = vec![
            [0.0, 0.0, 0.0],
            [w, 0.0, 0.0],
            [w, d, 0.0],
            [0.0, d, 0.0],
            [0.0, 0.0, h],
            [w, 0.0, h],
            [w, d, h],
            [0.0, d, h],
        ];
        let f = vec![
            [0, 2, 1],
            [0, 3, 2], // bottom (normal -Z)
            [4, 5, 6],
            [4, 6, 7], // top (normal +Z)
            [0, 1, 5],
            [0, 5, 4],
            [2, 3, 7],
            [2, 7, 6],
            [1, 2, 6],
            [1, 6, 5],
            [0, 4, 7],
            [0, 7, 3],
        ];
        Mesh::new(v, f)
    }

    #[test]
    fn box_has_no_overhangs_but_has_bed_contact() {
        let r = box_mesh(10.0, 10.0, 10.0).dfm_report();
        // The only downward face is the flat bottom (0° from horizontal) — but it
        // sits on the bed, so it is bed contact, and 0° < 45° counts as overhang
        // area too. Important: it IS flagged as the steepest overhang.
        assert_eq!(r.steepest_overhang_deg, Some(0.0));
        assert!(r.bed_contact_area_mm2 >= 99.0); // ~100 mm^2 bottom
        assert!(r.build_height_mm == 10.0);
    }

    #[test]
    fn vertical_walls_are_not_overhangs() {
        // A tall thin box: walls vertical, bottom on bed. The side walls must not
        // count as overhang.
        let r = box_mesh(20.0, 20.0, 40.0).dfm_report();
        // Overhang area should be just the bottom face (which is bed contact),
        // not the 4 tall walls.
        assert!(r.overhang_area_mm2 < r.total_area_mm2 * 0.2);
    }

    #[test]
    fn min_wall_estimates_box_thickness() {
        // A 4mm-thick slab: min wall (smallest dimension) should be ~4mm.
        let w = crate::proximity::min_wall_thickness(&box_mesh(40.0, 40.0, 4.0), 500);
        assert!(w.is_some());
        let w = w.unwrap();
        assert!((w - 4.0).abs() < 0.5, "got {w}");
    }
}
