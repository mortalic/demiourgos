//! Fit-test coupon generation.
//!
//! A coupon is a single small print that calibrates a printer/material in one
//! shot: a plate of through-holes stepped across a range of per-side clearances,
//! each embossed with its value, plus a separate reference peg. You print it
//! once, find the tightest hole the peg still satisfies for the fit you want,
//! and feed that clearance back via an `Outcome`. One print replaces a stack of
//! reprints.

/// Parameters for a fit-test coupon.
#[derive(Debug, Clone, PartialEq)]
pub struct CouponSpec {
    /// Nominal peg/pin diameter (mm). The reference peg is exactly this; each
    /// hole is `peg_diameter + 2 × clearance`.
    pub peg_diameter_mm: f64,
    /// Per-side clearances to test, in mm (one hole each).
    pub clearances_mm: Vec<f64>,
    /// Plate / hole depth (mm).
    pub plate_thickness_mm: f64,
}

impl Default for CouponSpec {
    fn default() -> Self {
        CouponSpec {
            peg_diameter_mm: 10.0,
            clearances_mm: clearance_steps(0.05, 0.40, 0.05),
            plate_thickness_mm: 4.0,
        }
    }
}

/// Build an inclusive list of clearance steps `[min, min+step, …, max]`.
/// Returns an empty vec for non-positive `step` or `max < min`.
pub fn clearance_steps(min: f64, max: f64, step: f64) -> Vec<f64> {
    let mut steps = Vec::new();
    if step <= 0.0 || max < min {
        return steps;
    }
    let n = ((max - min) / step).round() as i64;
    for i in 0..=n {
        steps.push(round3(min + step * i as f64));
    }
    steps
}

/// Generate OpenSCAD source for the coupon described by `spec`.
///
/// Returns the SCAD text. The hole at index `i` has per-side clearance
/// `spec.clearances_mm[i]`.
pub fn coupon_scad(spec: &CouponSpec) -> String {
    let peg_d = spec.peg_diameter_mm;
    let plate_t = spec.plate_thickness_mm;
    let max_c = spec.clearances_mm.iter().cloned().fold(0.0_f64, f64::max);

    // Pitch leaves room for the largest hole plus a label gutter.
    let pitch = (peg_d + 2.0 * max_c + 6.0).max(peg_d * 1.8);
    let n = spec.clearances_mm.len().max(1);
    let plate_w = pitch * n as f64;
    let plate_h = peg_d * 2.8;
    let label_size = (peg_d * 0.32).clamp(3.0, 6.0);

    let vec_lit = spec
        .clearances_mm
        .iter()
        .map(|c| format!("{c}"))
        .collect::<Vec<_>>()
        .join(", ");

    format!(
        "// Demiourgos fit-test coupon — generated.\n\
         // Print once. For each labeled hole, try the reference peg; the tightest\n\
         // hole that gives the fit you want is your calibrated per-side clearance.\n\
         peg_d      = {peg_d};\n\
         plate_t    = {plate_t};\n\
         clearances = [{vec_lit}];\n\
         pitch      = {pitch};\n\
         n          = len(clearances);\n\
         plate_w    = {plate_w};\n\
         plate_h    = {plate_h};\n\
         label_size = {label_size};\n\
         \n\
         module coupon_plate() {{\n\
         \x20   difference() {{\n\
         \x20       translate([-pitch/2, -plate_h/2, 0]) cube([plate_w, plate_h, plate_t]);\n\
         \x20       for (i = [0:n-1])\n\
         \x20           translate([i*pitch, plate_h*0.12, -1])\n\
         \x20               cylinder(h = plate_t + 2, d = peg_d + 2*clearances[i], $fn = 72);\n\
         \x20   }}\n\
         \x20   // Raised clearance labels.\n\
         \x20   for (i = [0:n-1])\n\
         \x20       translate([i*pitch, -plate_h*0.36, plate_t])\n\
         \x20           linear_extrude(0.6)\n\
         \x20               text(str(clearances[i]), size = label_size, halign = \"center\", valign = \"center\");\n\
         }}\n\
         \n\
         module reference_peg() {{\n\
         \x20   // Stands apart so it prints as its own body.\n\
         \x20   peg_h = plate_t + 8;\n\
         \x20   translate([plate_w/2 - pitch/2, plate_h, 0]) {{\n\
         \x20       cylinder(h = 1.5, d = peg_d + 6, $fn = 72);       // grip base\n\
         \x20       cylinder(h = peg_h, d = peg_d, $fn = 72);          // the gauge pin\n\
         \x20   }}\n\
         }}\n\
         \n\
         coupon_plate();\n\
         reference_peg();\n"
    )
}

fn round3(v: f64) -> f64 {
    (v * 1000.0).round() / 1000.0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn steps_are_inclusive_and_rounded() {
        let s = clearance_steps(0.05, 0.40, 0.05);
        assert_eq!(s.first(), Some(&0.05));
        assert_eq!(s.last(), Some(&0.40));
        assert_eq!(s.len(), 8);
    }

    #[test]
    fn bad_steps_are_empty() {
        assert!(clearance_steps(0.4, 0.1, 0.05).is_empty());
        assert!(clearance_steps(0.0, 1.0, 0.0).is_empty());
    }

    #[test]
    fn scad_contains_holes_peg_and_labels() {
        let scad = coupon_scad(&CouponSpec::default());
        assert!(scad.contains("clearances = [0.05"));
        assert!(scad.contains("reference_peg"));
        assert!(scad.contains("text(str(clearances[i])"));
        // Hole diameter formula present.
        assert!(scad.contains("peg_d + 2*clearances[i]"));
    }

    #[test]
    fn custom_spec_bakes_values() {
        let spec = CouponSpec {
            peg_diameter_mm: 6.0,
            clearances_mm: vec![0.1, 0.2, 0.3],
            plate_thickness_mm: 3.0,
        };
        let scad = coupon_scad(&spec);
        assert!(scad.contains("peg_d      = 6;"));
        assert!(scad.contains("clearances = [0.1, 0.2, 0.3];"));
    }
}
