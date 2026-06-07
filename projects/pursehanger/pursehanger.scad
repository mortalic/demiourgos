// pursehanger — an over-the-table-edge bag hook (a candy-cane ribbon): a flat
// tongue rests on the tabletop, the ribbon drapes over the front edge, sweeps
// down the front, and curls up into a retaining hook for the bag straps.
//
// PRINT ORIENTATION (important, load-bearing part): the side profile is in XY
// and extruded along +Z by `rib_w`. A straight Z-extrusion is support-free, and
// the bag's downward load bends the hook IN-PLANE (along the layers), so it can't
// peel layers apart. Print standing as modeled — do NOT lay it on a broad face.

/* [Ribbon] */
rib_t = 5.0;     // ribbon thickness (bending strength)
rib_w = 28;      // width across (the Z extrusion = the part you grip)

/* [Geometry] */
reach   = 50;    // tongue length resting on the tabletop
edge_r  = 16;    // radius of the drape over the front edge
hang    = 70;    // how far it hangs down the front
hook_r  = 15;    // radius of the bottom bag-retaining hook
hook_sweep = 200; // bottom hook wrap angle (>180 curls the tip back in)

$fn = 64;

// arc as a list of [x,y] points
function arc(c, r, a0, a1, n) =
  [ for (i=[0:n]) [ c[0] + r*cos(a0 + (a1-a0)*i/n),
                    c[1] + r*sin(a0 + (a1-a0)*i/n) ] ];

// centerline of the ribbon (side profile, X = onto table, Y = up)
centerline = concat(
  [ [reach, 0], [0, 0] ],                              // tongue on the tabletop
  arc([0, -edge_r], edge_r, 90, 180, 16),             // drape over the front edge
  [ [-edge_r, -edge_r - hang] ],                      // shaft down the front
  arc([-edge_r - hook_r, -edge_r - hang], hook_r, 0, -hook_sweep, 28) // bottom hook
);

// thick the centerline into a rounded ribbon (constant thickness)
module ribbon2d(pts) {
  for (i = [0 : len(pts)-2])
    hull() {
      translate(pts[i])   circle(d = rib_t);
      translate(pts[i+1]) circle(d = rib_t);
    }
}

module pursehanger() {
  linear_extrude(height = rib_w) ribbon2d(centerline);
}

pursehanger();
