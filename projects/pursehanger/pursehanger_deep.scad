// pursehanger_deep — copied from Purse_Hanger.stl. A deep ~270 hook: a small lip
// at the top-left, a thin ribbon sweeping over the top and down the right side,
// ending in a SOLID rounded lobe at the bottom where the bag straps rest. The big
// open mouth on the left drops over the table edge.
//
// Side profile in XY, extruded along +Z (width) -> support-free; load bends it
// in-plane along the layers. A second hanger style next to the simpler one in
// pursehanger.scad.

/* [Profile] */
rib_t = 7;     // thickness of the thin hook ribbon
width = 20;    // width across (Z)

/* [Lobe] */
lobe_w = 76;   // bottom lobe width
lobe_h = 54;   // bottom lobe height
lobe_cx = 50;  // lobe center x
lobe_r = 26;   // lobe corner rounding (big -> rounded bottom)

$fn = 64;

// thin hook ribbon centerline (X right, Y up), traced from the reference
hook = [
  [16, 116], [13, 121], [20, 128], [45, 134], [68, 131],
  [84, 114], [90, 88], [88, 62], [83, 49]
];

module ribbon(p, t) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=t); translate(p[i+1]) circle(d=t); }
}

module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

module pursehanger_deep() {
  linear_extrude(width)
    union() {
      ribbon(hook, rib_t);
      translate([lobe_cx, lobe_h/2]) rrect(lobe_w, lobe_h, lobe_r);  // solid bottom lobe
    }
}

pursehanger_deep();
