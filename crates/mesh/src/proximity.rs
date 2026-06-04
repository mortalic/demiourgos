//! Mesh-to-mesh proximity queries, backed by `parry3d-f64`.
//!
//! Used by `fit_check` to report the true minimum distance between two parts
//! when they are disjoint — a tighter, geometry-aware measure than comparing
//! axis-aligned bounding boxes.

use parry3d_f64::na::{Isometry3, Point3};
use parry3d_f64::query;
use parry3d_f64::shape::TriMesh;

use crate::Mesh;

/// Convert a [`Mesh`] into a parry [`TriMesh`]. Returns `None` for an empty
/// mesh (parry cannot build a BVH without triangles).
fn to_trimesh(mesh: &Mesh) -> Option<TriMesh> {
    if mesh.faces.is_empty() || mesh.vertices.is_empty() {
        return None;
    }
    let vertices: Vec<Point3<f64>> = mesh
        .vertices
        .iter()
        .map(|v| Point3::new(v[0], v[1], v[2]))
        .collect();
    let indices: Vec<[u32; 3]> = mesh
        .faces
        .iter()
        .map(|f| [f[0] as u32, f[1] as u32, f[2] as u32])
        .collect();
    Some(TriMesh::new(vertices, indices))
}

/// Minimum distance between two meshes (0.0 if they touch or overlap), in the
/// meshes' units. Returns `None` if either mesh is empty or the query is
/// unsupported. Wrapped in `catch_unwind` so a pathological mesh can never take
/// down a tool call.
pub fn min_distance(a: &Mesh, b: &Mesh) -> Option<f64> {
    std::panic::catch_unwind(|| {
        let ta = to_trimesh(a)?;
        let tb = to_trimesh(b)?;
        let id = Isometry3::identity();
        query::distance(&id, &ta, &id, &tb).ok()
    })
    .ok()
    .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cube(offset: [f64; 3]) -> Mesh {
        let v = vec![
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [1.0, 1.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [1.0, 0.0, 1.0],
            [1.0, 1.0, 1.0],
            [0.0, 1.0, 1.0],
        ]
        .into_iter()
        .map(|p: [f64; 3]| [p[0] + offset[0], p[1] + offset[1], p[2] + offset[2]])
        .collect();
        let f = vec![
            [0, 2, 1],
            [0, 3, 2],
            [4, 5, 6],
            [4, 6, 7],
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
    fn separated_cubes_report_gap() {
        // Cube at origin, cube shifted +3 in x: faces at x=1 and x=3 -> gap 2.
        let d = min_distance(&cube([0.0, 0.0, 0.0]), &cube([3.0, 0.0, 0.0]));
        assert!(d.is_some(), "distance query unsupported");
        assert!((d.unwrap() - 2.0).abs() < 1e-6, "got {:?}", d);
    }

    #[test]
    fn overlapping_cubes_report_zero() {
        let d = min_distance(&cube([0.0, 0.0, 0.0]), &cube([0.5, 0.0, 0.0]));
        assert!(d.is_some());
        assert!(d.unwrap() < 1e-9, "got {:?}", d);
    }

    #[test]
    fn empty_mesh_yields_none() {
        assert!(min_distance(&Mesh::default(), &cube([0.0, 0.0, 0.0])).is_none());
    }
}
