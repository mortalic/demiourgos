//! Mesh-to-mesh proximity queries, backed by `parry3d-f64`.
//!
//! Used by `fit_check` to report the true minimum distance between two parts
//! when they are disjoint — a tighter, geometry-aware measure than comparing
//! axis-aligned bounding boxes.

use parry3d_f64::na::{Isometry3, Point3, Vector3};
use parry3d_f64::query::{self, Ray, RayCast};
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

/// Estimate the minimum wall thickness of a (closed) mesh by ray sampling.
///
/// For up to `max_samples` triangles, fire a ray from just inside the surface
/// along the inward normal and measure the distance to the opposite wall; the
/// minimum across samples approximates the thinnest wall. Returns `None` for an
/// empty mesh or if no sample produced a finite thickness. Wrapped in
/// `catch_unwind` for robustness against pathological meshes.
pub fn min_wall_thickness(mesh: &Mesh, max_samples: usize) -> Option<f64> {
    std::panic::catch_unwind(|| {
        let tri = to_trimesh(mesh)?;
        let n_faces = mesh.faces.len();
        if n_faces == 0 {
            return None;
        }
        let stride = (n_faces / max_samples.max(1)).max(1);
        // Step in just off the surface so the ray doesn't immediately hit its
        // own originating triangle.
        let eps = 1e-3;
        let max_toi = 1.0e6;

        let mut min_thickness: Option<f64> = None;
        for f in mesh.faces.iter().step_by(stride) {
            let a = mesh.vertices[f[0]];
            let b = mesh.vertices[f[1]];
            let c = mesh.vertices[f[2]];
            let Some(normal) = winding_normal(a, b, c) else {
                continue;
            };
            let centroid = [
                (a[0] + b[0] + c[0]) / 3.0,
                (a[1] + b[1] + c[1]) / 3.0,
                (a[2] + b[2] + c[2]) / 3.0,
            ];
            // Inward direction is the negative outward normal.
            let dir = Vector3::new(-normal[0], -normal[1], -normal[2]);
            let origin = Point3::new(
                centroid[0] + dir.x * eps,
                centroid[1] + dir.y * eps,
                centroid[2] + dir.z * eps,
            );
            let ray = Ray::new(origin, dir);
            if let Some(toi) = tri.cast_local_ray(&ray, max_toi, false) {
                let thickness = toi + eps;
                if thickness > 1e-4 {
                    min_thickness = Some(match min_thickness {
                        Some(m) => m.min(thickness),
                        None => thickness,
                    });
                }
            }
        }
        min_thickness
    })
    .ok()
    .flatten()
}

/// Outward unit normal from triangle winding, or `None` if degenerate.
fn winding_normal(a: [f64; 3], b: [f64; 3], c: [f64; 3]) -> Option<[f64; 3]> {
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
