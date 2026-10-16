// ballpython_head.scad — low-poly faceted ball python head, wall relief.
//
// Geometry comes from projects/snake-wallart/gen_head.py as ONE closed
// polyhedron (relief + backer plate + silhouette wall). It is emitted as a
// native polyhedron() rather than an imported STL because OpenSCAD 2021.01
// cannot boolean imported meshes, and the keyholes below are a difference().
//
// The front surface is a single-valued height field, so no facet ever faces
// downward: this prints back-flat on the bed with ZERO supports.
//
// Re-generate after editing the vertex table:
//   python3 projects/snake-wallart/gen_head.py workspace/bp_head_data.scad

include <bp_head_data.scad>

keyhole  = true;   // cut two flush-mount keyhole slots in the back
kh_head  = 9.0;    // screw-head clearance dia
kh_slot  = 4.6;    // shank slot width
kh_drop  = 13.0;   // how far the slot runs up from the head
kh_roof  = 1.4;    // material left above the pocket
kh_x     = 0.42;   // keyhole x, as a fraction of half-width
kh_y     = 0.46;   // keyhole y, as a fraction of scale

$fn = 32;

// Cut from the BACK (z=0) upward. The pocket ceiling is a short bridge —
// trivial at this span, faces the bed, and never shows.
module keyhole_cut() {
  h = BP_BACKER - kh_roof;
  union() {
    cylinder(d = kh_head, h = h);
    translate([0, kh_drop / 2, h / 2]) cube([kh_slot, kh_drop, h], center = true);
    translate([0, kh_drop, 0]) cylinder(d = kh_slot, h = h);
  }
}

module ballpython_plaque() {
  difference() {
    polyhedron(points = BP_V, faces = BP_F, convexity = 12);
    if (keyhole)
      for (s = [-1, 1])
        translate([s * kh_x * BP_SCALE, kh_y * BP_SCALE, -0.01]) keyhole_cut();
  }
}

ballpython_plaque();

echo(overall_mm = [2 * BP_SCALE, 1.78 * BP_SCALE, BP_BACKER + BP_DEPTH],
     relief_mm = BP_DEPTH, backer_mm = BP_BACKER);
