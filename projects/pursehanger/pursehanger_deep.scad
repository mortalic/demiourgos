// pursehanger_deep — copied from Purse_Hanger.stl. A deep ~270 hook: a small lip
// at the top-left, a thin ribbon sweeping over the top and down the right, then
// flowing into a PARTIAL-oval (D-shaped) lobe at the bottom where the bag straps
// rest. The big open mouth on the left drops over the table edge.
//
// The ribbon runs well INTO the lobe so the two merge as one solid piece (no weak
// neck), and the lobe is only the bottom portion of an oval (flat top), like the
// reference. Side profile in XY, extruded along +Z -> support-free.

/* [Profile] */
rib_t = 7;     // thickness of the thin hook ribbon

/* [Lobe] — bottom portion of an ellipse */
lobe_cx = 50;  lobe_cy = 33;     // ellipse center
lobe_a  = 37;  lobe_b  = 31;     // ellipse semi-axes (x, y)
lobe_top = 52;                   // cut the oval flat here (partial oval)

/* [Build] */
width = 20;    // width across (Z)

$fn = 72;

// thin hook ribbon centerline, traced from the reference; the tail runs deep into
// the lobe so the union is one solid piece.
hook = [
  [13, 118], [11, 123], [18, 129], [45, 135], [68, 132],
  [85, 114], [91, 86], [88, 58], [80, 42], [60, 36], [45, 37]
];

module ribbon(p, t) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=t); translate(p[i+1]) circle(d=t); }
}

module lobe() {
  intersection() {
    translate([lobe_cx, lobe_cy]) scale([lobe_a, lobe_b]) circle(r = 1);  // ellipse
    translate([lobe_cx - lobe_a, lobe_cy - lobe_b])                       // keep y <= lobe_top
      square([2*lobe_a, lobe_top - (lobe_cy - lobe_b)]);
  }
}

module pursehanger_deep() {
  linear_extrude(width)
    union() { ribbon(hook, rib_t); lobe(); }
}

pursehanger_deep();
