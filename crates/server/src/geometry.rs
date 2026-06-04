//! Geometry helpers for the `cross_section` and `fit_check` tools: generating
//! wrapper SCAD that operates on exported STLs, and the matching mesh transform
//! math (so bounding boxes computed in Rust agree with what OpenSCAD renders).

use std::path::Path;
use std::str::FromStr;

use demiurge_mesh::{BoundingBox, Mesh};

/// A principal axis.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Axis {
    X,
    Y,
    Z,
}

impl FromStr for Axis {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "x" => Ok(Axis::X),
            "y" => Ok(Axis::Y),
            "z" => Ok(Axis::Z),
            other => Err(format!(
                "unknown axis '{other}' (expected 'x', 'y', or 'z')"
            )),
        }
    }
}

/// A rigid transform expressed the OpenSCAD way: `translate(t) rotate(r)`, i.e.
/// rotate first (Rz·Ry·Rx) then translate.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Transform {
    pub translation: [f64; 3],
    /// Rotation in degrees about X, Y, Z (applied in OpenSCAD's order).
    pub rotation: [f64; 3],
}

impl Transform {
    pub const IDENTITY: Transform = Transform {
        translation: [0.0, 0.0, 0.0],
        rotation: [0.0, 0.0, 0.0],
    };

    pub fn is_identity(&self) -> bool {
        self.translation == [0.0, 0.0, 0.0] && self.rotation == [0.0, 0.0, 0.0]
    }

    /// Apply the transform to a single point.
    pub fn apply(&self, p: [f64; 3]) -> [f64; 3] {
        let r = rotate_zyx(self.rotation, p);
        [
            r[0] + self.translation[0],
            r[1] + self.translation[1],
            r[2] + self.translation[2],
        ]
    }

    /// Return a copy of `mesh` with this transform applied to every vertex.
    pub fn apply_to_mesh(&self, mesh: &Mesh) -> Mesh {
        let vertices = mesh.vertices.iter().map(|&v| self.apply(v)).collect();
        Mesh::new(vertices, mesh.faces.clone())
    }
}

/// Rotate `p` by `[rx, ry, rz]` degrees in OpenSCAD's order: Rz·Ry·Rx.
fn rotate_zyx(deg: [f64; 3], p: [f64; 3]) -> [f64; 3] {
    let (rx, ry, rz) = (
        deg[0].to_radians(),
        deg[1].to_radians(),
        deg[2].to_radians(),
    );
    // Rx
    let (sx, cx) = rx.sin_cos();
    let p1 = [p[0], p[1] * cx - p[2] * sx, p[1] * sx + p[2] * cx];
    // Ry
    let (sy, cy) = ry.sin_cos();
    let p2 = [p1[0] * cy + p1[2] * sy, p1[1], -p1[0] * sy + p1[2] * cy];
    // Rz
    let (sz, cz) = rz.sin_cos();
    [p2[0] * cz - p2[1] * sz, p2[0] * sz + p2[1] * cz, p2[2]]
}

/// Escape a path for embedding in an OpenSCAD `import("…")` string literal.
fn scad_path(path: &Path) -> String {
    path.display()
        .to_string()
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
}

/// Generate a wrapper SCAD that slices `stl_path` at `axis = offset` and
/// projects the cut to 2D. The desired cut plane is mapped onto `z = 0` so
/// `projection(cut = true)` produces the section.
pub fn cross_section_scad(stl_path: &Path, axis: Axis, offset: f64) -> String {
    let import = format!("import(\"{}\");", scad_path(stl_path));
    let body = match axis {
        Axis::Z => format!("translate([0,0,{}]) {import}", -offset),
        Axis::X => format!("translate([0,0,{offset}]) rotate([0,90,0]) {import}"),
        Axis::Y => format!("translate([0,0,{}]) rotate([90,0,0]) {import}", -offset),
    };
    format!("// Demiurge cross_section wrapper\nprojection(cut = true)\n  {body}\n")
}

/// Generate a wrapper SCAD computing the intersection of two STLs, with an
/// optional transform applied to the second part.
pub fn fit_check_scad(a_stl: &Path, b_stl: &Path, transform: &Transform) -> String {
    let a = format!("import(\"{}\");", scad_path(a_stl));
    let b_import = format!("import(\"{}\");", scad_path(b_stl));
    let b = if transform.is_identity() {
        b_import
    } else {
        let t = transform.translation;
        let r = transform.rotation;
        format!(
            "translate([{},{},{}]) rotate([{},{},{}]) {b_import}",
            t[0], t[1], t[2], r[0], r[1], r[2]
        )
    };
    format!("// Demiurge fit_check wrapper\nintersection() {{\n  {a}\n  {b}\n}}\n")
}

/// Per-axis gap between two boxes: 0 when they overlap on that axis, otherwise
/// the positive separation distance.
pub fn axis_gaps(a: &BoundingBox, b: &BoundingBox) -> [f64; 3] {
    let mut gaps = [0.0; 3];
    for (k, gap) in gaps.iter_mut().enumerate() {
        let sep = (b.min[k] - a.max[k]).max(a.min[k] - b.max[k]);
        *gap = sep.max(0.0);
    }
    gaps
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: [f64; 3], b: [f64; 3]) {
        for k in 0..3 {
            assert!((a[k] - b[k]).abs() < 1e-9, "axis {k}: {} vs {}", a[k], b[k]);
        }
    }

    #[test]
    fn axis_parse() {
        assert_eq!("X".parse::<Axis>().unwrap(), Axis::X);
        assert!("w".parse::<Axis>().is_err());
    }

    #[test]
    fn identity_transform_is_noop() {
        approx(Transform::IDENTITY.apply([1.0, 2.0, 3.0]), [1.0, 2.0, 3.0]);
    }

    #[test]
    fn rotation_z_90_maps_x_to_y() {
        let t = Transform {
            translation: [0.0; 3],
            rotation: [0.0, 0.0, 90.0],
        };
        approx(t.apply([1.0, 0.0, 0.0]), [0.0, 1.0, 0.0]);
    }

    #[test]
    fn translation_then_applied_after_rotation() {
        let t = Transform {
            translation: [10.0, 0.0, 0.0],
            rotation: [0.0, 0.0, 90.0],
        };
        // (1,0,0) -> rotate -> (0,1,0) -> translate -> (10,1,0)
        approx(t.apply([1.0, 0.0, 0.0]), [10.0, 1.0, 0.0]);
    }

    #[test]
    fn cross_section_scad_picks_transform_per_axis() {
        let p = Path::new("/tmp/m.stl");
        assert!(cross_section_scad(p, Axis::Z, 5.0).contains("translate([0,0,-5])"));
        assert!(cross_section_scad(p, Axis::X, 5.0).contains("rotate([0,90,0])"));
        assert!(cross_section_scad(p, Axis::Y, 5.0).contains("rotate([90,0,0])"));
        assert!(cross_section_scad(p, Axis::Z, 5.0).contains("projection(cut = true)"));
    }

    #[test]
    fn fit_check_scad_includes_transform_when_present() {
        let a = Path::new("/tmp/a.stl");
        let b = Path::new("/tmp/b.stl");
        let s = fit_check_scad(
            a,
            b,
            &Transform {
                translation: [1.0, 2.0, 3.0],
                rotation: [0.0; 3],
            },
        );
        assert!(s.contains("intersection()"));
        assert!(s.contains("translate([1,2,3])"));
        let s2 = fit_check_scad(a, b, &Transform::IDENTITY);
        assert!(!s2.contains("translate"));
    }

    #[test]
    fn axis_gaps_zero_when_overlapping() {
        let a = BoundingBox {
            min: [0.0, 0.0, 0.0],
            max: [2.0, 2.0, 2.0],
            size: [2.0; 3],
        };
        let b = BoundingBox {
            min: [1.0, 5.0, 0.0],
            max: [3.0, 6.0, 2.0],
            size: [2.0, 1.0, 2.0],
        };
        // x overlaps -> 0; y separated by 3 (5-2); z overlaps -> 0
        approx(axis_gaps(&a, &b), [0.0, 3.0, 0.0]);
    }
}
