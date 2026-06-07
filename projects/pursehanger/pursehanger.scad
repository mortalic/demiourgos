// pursehanger — over-the-table-edge bag hook, traced from the reference
// bag_hanger.stl (a compact, mostly-straight hook). A flat TONGUE rests on the
// tabletop; it drapes over the front edge and runs down the front; the bottom
// HOOK curls back UNDER the tongue so the bag's weight sits behind the front-edge
// fulcrum and clamps the tongue down (this is what makes it grip).
//
// Side profile in XY, extruded along +Z (width) -> support-free; the load bends
// it in-plane along the layers.

/* [Profile] */
rib_t = 5;        // ribbon thickness
width = 15;       // width across (Z)

/* [Shape] — traced from bag_hanger.stl (~60 x 96 x 15 mm) */
// centerline points (X = toward the front edge / drape side, Y = up)
pts = [
  [-24,  29],     // tongue back tip (rests on table, slight up-tick)
  [ 33,  28],     // front-edge corner (turn down here)
  [ 31, -10],     // drape down the front...
  [ 28, -52],     // ...slightly curved
  [ 18, -64],     // bottom
  [ -2, -66],     // bottom valley (bag handle sits here)
  [-17, -63],     // up into the retaining hook
  [-21, -54],     // hook tip
];

$fn = 48;

module ribbon(p) {
  for (i = [0 : len(p)-2])
    hull() {
      translate(p[i])   circle(d = rib_t);
      translate(p[i+1]) circle(d = rib_t);
    }
}

module pursehanger() { linear_extrude(width) ribbon(pts); }

pursehanger();
