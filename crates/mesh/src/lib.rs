//! `demiourgos-mesh` — STL parsing and geometric analysis.
//!
//! This is the "tape measure" half of Demiourgos. Given a triangle mesh (loaded
//! from an STL that OpenSCAD exported) it computes the quantities a designer
//! actually wants to check: bounding box, solid volume, center of mass,
//! triangle count, and whether the surface is watertight (a closed 2-manifold).
//!
//! Volume and center of mass use the divergence-theorem / signed-tetrahedron
//! method, which is exact for any closed triangle mesh regardless of convexity.

use std::io::{Read, Seek};
use std::path::Path;

use serde::Serialize;

pub mod proximity;
pub use proximity::min_distance;

/// Errors from loading or analyzing a mesh.
#[derive(Debug, thiserror::Error)]
pub enum MeshError {
    #[error("failed to read STL: {0}")]
    Read(#[source] std::io::Error),

    #[error("STL is structurally invalid: {0}")]
    Invalid(String),

    #[error("mesh is empty (no triangles)")]
    Empty,
}

/// An indexed triangle mesh in double precision.
#[derive(Debug, Clone, Default)]
pub struct Mesh {
    /// Deduplicated vertex positions.
    pub vertices: Vec<[f64; 3]>,
    /// Triangles as triples of indices into [`Mesh::vertices`].
    pub faces: Vec<[usize; 3]>,
}

/// Axis-aligned bounding box.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct BoundingBox {
    pub min: [f64; 3],
    pub max: [f64; 3],
    /// `max - min` per axis.
    pub size: [f64; 3],
}

/// The full analysis report for a mesh.
#[derive(Debug, Clone, Serialize)]
pub struct Analysis {
    pub bounding_box: BoundingBox,
    /// Solid volume in the mesh's units cubed (mm³ for OpenSCAD output).
    pub volume: f64,
    pub center_of_mass: [f64; 3],
    pub triangle_count: usize,
    /// Number of distinct vertices.
    pub vertex_count: usize,
    /// True when every edge is shared by exactly two triangles (closed 2-manifold).
    pub watertight: bool,
}

impl Mesh {
    /// Load and analyze in one step from a file path.
    pub fn from_stl_path(path: impl AsRef<Path>) -> Result<Mesh, MeshError> {
        let file = std::fs::File::open(path).map_err(MeshError::Read)?;
        let mut reader = std::io::BufReader::new(file);
        Mesh::from_stl_reader(&mut reader)
    }

    /// Load from any seekable reader (binary or ASCII STL — `stl_io` autodetects).
    pub fn from_stl_reader<R: Read + Seek>(reader: &mut R) -> Result<Mesh, MeshError> {
        let indexed = stl_io::read_stl(reader).map_err(MeshError::Read)?;
        indexed
            .validate()
            .map_err(|e| MeshError::Invalid(e.to_string()))?;

        let vertices = indexed
            .vertices
            .iter()
            .map(|v| [v[0] as f64, v[1] as f64, v[2] as f64])
            .collect();
        let faces = indexed
            .faces
            .iter()
            .map(|f| [f.vertices[0], f.vertices[1], f.vertices[2]])
            .collect();

        Ok(Mesh { vertices, faces })
    }

    /// Construct directly from vertices and faces (used by tests).
    pub fn new(vertices: Vec<[f64; 3]>, faces: Vec<[usize; 3]>) -> Mesh {
        Mesh { vertices, faces }
    }

    pub fn triangle_count(&self) -> usize {
        self.faces.len()
    }

    pub fn is_empty(&self) -> bool {
        self.faces.is_empty()
    }

    /// Axis-aligned bounding box, or `None` for an empty mesh.
    pub fn bounding_box(&self) -> Option<BoundingBox> {
        let mut iter = self.vertices.iter();
        let first = iter.next()?;
        let mut min = *first;
        let mut max = *first;
        for v in iter {
            for a in 0..3 {
                if v[a] < min[a] {
                    min[a] = v[a];
                }
                if v[a] > max[a] {
                    max[a] = v[a];
                }
            }
        }
        Some(BoundingBox {
            min,
            max,
            size: [max[0] - min[0], max[1] - min[1], max[2] - min[2]],
        })
    }

    /// Signed volume contributions; returns `(total_signed_volume, weighted_centroid_sum)`.
    fn volume_moments(&self) -> (f64, [f64; 3]) {
        let mut total = 0.0;
        let mut moment = [0.0f64; 3];
        for f in &self.faces {
            let a = self.vertices[f[0]];
            let b = self.vertices[f[1]];
            let c = self.vertices[f[2]];
            // Signed volume of the tetrahedron (origin, a, b, c).
            let v = dot(a, cross(b, c)) / 6.0;
            total += v;
            // Centroid of that tetra is (a+b+c+origin)/4.
            for k in 0..3 {
                moment[k] += v * (a[k] + b[k] + c[k]) / 4.0;
            }
        }
        (total, moment)
    }

    /// Solid volume (always non-negative).
    pub fn volume(&self) -> f64 {
        self.volume_moments().0.abs()
    }

    /// Center of mass assuming uniform density. Falls back to the vertex
    /// average for degenerate (near-zero-volume) meshes.
    pub fn center_of_mass(&self) -> Option<[f64; 3]> {
        if self.vertices.is_empty() {
            return None;
        }
        let (total, moment) = self.volume_moments();
        if total.abs() < 1e-12 {
            // Degenerate solid — average the vertices instead.
            let n = self.vertices.len() as f64;
            let mut sum = [0.0; 3];
            for v in &self.vertices {
                for k in 0..3 {
                    sum[k] += v[k];
                }
            }
            return Some([sum[0] / n, sum[1] / n, sum[2] / n]);
        }
        Some([moment[0] / total, moment[1] / total, moment[2] / total])
    }

    /// True when the mesh is a closed 2-manifold: every undirected edge is
    /// shared by exactly two triangles.
    pub fn is_watertight(&self) -> bool {
        if self.faces.is_empty() {
            return false;
        }
        use std::collections::HashMap;
        let mut edges: HashMap<(usize, usize), u32> = HashMap::new();
        for f in &self.faces {
            for &(i, j) in &[(f[0], f[1]), (f[1], f[2]), (f[2], f[0])] {
                let key = if i < j { (i, j) } else { (j, i) };
                *edges.entry(key).or_insert(0) += 1;
            }
        }
        edges.values().all(|&count| count == 2)
    }

    /// Compute the full analysis report. Returns [`MeshError::Empty`] for a mesh
    /// with no triangles.
    pub fn analyze(&self) -> Result<Analysis, MeshError> {
        let bounding_box = self.bounding_box().ok_or(MeshError::Empty)?;
        if self.faces.is_empty() {
            return Err(MeshError::Empty);
        }
        Ok(Analysis {
            bounding_box,
            volume: self.volume(),
            center_of_mass: self.center_of_mass().ok_or(MeshError::Empty)?,
            triangle_count: self.triangle_count(),
            vertex_count: self.vertices.len(),
            watertight: self.is_watertight(),
        })
    }
}

fn cross(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}

fn dot(a: [f64; 3], b: [f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A unit cube [0,1]^3 as 12 triangles with outward winding.
    fn unit_cube() -> Mesh {
        let v = vec![
            [0.0, 0.0, 0.0], // 0
            [1.0, 0.0, 0.0], // 1
            [1.0, 1.0, 0.0], // 2
            [0.0, 1.0, 0.0], // 3
            [0.0, 0.0, 1.0], // 4
            [1.0, 0.0, 1.0], // 5
            [1.0, 1.0, 1.0], // 6
            [0.0, 1.0, 1.0], // 7
        ];
        // Outward-facing (CCW seen from outside) triangles.
        let f = vec![
            [0, 2, 1],
            [0, 3, 2], // bottom (z=0), normal -z
            [4, 5, 6],
            [4, 6, 7], // top (z=1), normal +z
            [0, 1, 5],
            [0, 5, 4], // front (y=0), normal -y
            [2, 3, 7],
            [2, 7, 6], // back (y=1), normal +y
            [1, 2, 6],
            [1, 6, 5], // right (x=1), normal +x
            [0, 4, 7],
            [0, 7, 3], // left (x=0), normal -x
        ];
        Mesh::new(v, f)
    }

    #[test]
    fn unit_cube_bounding_box() {
        let bb = unit_cube().bounding_box().unwrap();
        assert_eq!(bb.min, [0.0, 0.0, 0.0]);
        assert_eq!(bb.max, [1.0, 1.0, 1.0]);
        assert_eq!(bb.size, [1.0, 1.0, 1.0]);
    }

    #[test]
    fn unit_cube_volume_is_one() {
        assert!((unit_cube().volume() - 1.0).abs() < 1e-9);
    }

    #[test]
    fn unit_cube_center_of_mass_is_centroid() {
        let com = unit_cube().center_of_mass().unwrap();
        for (k, &c) in com.iter().enumerate() {
            assert!((c - 0.5).abs() < 1e-9, "axis {k}: {c}");
        }
    }

    #[test]
    fn unit_cube_is_watertight() {
        assert!(unit_cube().is_watertight());
    }

    #[test]
    fn open_mesh_is_not_watertight() {
        // The cube minus its top: edges around the opening are used once.
        let mut m = unit_cube();
        m.faces.truncate(10);
        assert!(!m.is_watertight());
    }

    #[test]
    fn scaled_cube_volume_scales_cubically() {
        let mut m = unit_cube();
        for v in &mut m.vertices {
            for c in v.iter_mut() {
                *c *= 2.0;
            }
        }
        assert!((m.volume() - 8.0).abs() < 1e-9);
        let bb = m.bounding_box().unwrap();
        assert_eq!(bb.size, [2.0, 2.0, 2.0]);
    }

    #[test]
    fn analyze_reports_everything() {
        let a = unit_cube().analyze().unwrap();
        assert_eq!(a.triangle_count, 12);
        assert_eq!(a.vertex_count, 8);
        assert!(a.watertight);
        assert!((a.volume - 1.0).abs() < 1e-9);
    }

    #[test]
    fn empty_mesh_analyze_errors() {
        assert!(matches!(Mesh::default().analyze(), Err(MeshError::Empty)));
    }
}
