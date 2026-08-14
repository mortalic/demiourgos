// pursebase_XL — 17" x 10" (431.8 x 254 mm) crochet / knit bag BASE PLATE,
// split into two halves so it fits a 360 mm bed, joined with a finger joint,
// a stitched-on underside splice bar, and yarn stitching through the seam.
//
// Why it is split: a 431.8 x 254 plate needs a 485 mm square bed even rotated
// 45 deg ((L+W)/sqrt(2) = 485). Rotating only helps parts narrower than ~149 mm;
// at 254 mm wide, axis-aligned is optimal and the one-piece max is 360 x 254.
//
// Why the seam runs this way: split across X puts the seam parallel to the
// dominant bending stress (the plate is edge-supported all round by the crochet,
// so the 254 mm span governs). The seam only sees the weaker long-span component.
//
// Load path at the seam, in order of importance:
//   1. splice bar on the UNDERSIDE  — the bottom fibre is in tension when the
//      loaded bag hangs, so the strap belongs on the bottom face
//   2. yarn stitched through both plate and bar — fibre in tension across the joint
//   3. CA glue on the finger joint  — assembly aid more than structure
//   4. finger joint itself          — alignment + shear along the seam
//
// PRINTING (wood PLA, hardened nozzle — wood fill is abrasive):
//   Each half is 223.9 x 254 mm; two halves side by side do NOT fit 360 mm.
//   Print half A + the bar together (263.9 x 254 fits), then half B. Brim on
//   both — these are big flat parts and wood PLA is brittle if a corner lifts.
//
// Parts:  part = "A" | "B" | "bar" | "assembled"

/* [Part] */
part = "assembled";     // [A, B, bar, assembled]

/* [Plate] */
plate_len   = 431.8;    // X, 17 in
plate_wid   = 254.0;    // Y, 10 in
thickness   = 4.0;      // 4 mm: stiffness goes as t^3, cheapest margin available
corner_frac = 0.12;     // outer corner radius as a fraction of the short side

/* [Crochet holes] */
hole_d      = 5.0;      // crochet hole diameter (hook + yarn)
edge_margin = 6.0;      // hole-center inset from the outline edge
hole_pitch  = 11.0;     // target spacing between holes along the perimeter
hole_chamfer= 0.8;      // 45deg chamfer at each hole face (so it can't saw yarn)
seam_offset = 10.0;     // x-distance from the seam to the nearest edge hole

/* [Seam — finger joint] */
seam_clear  = 0.20;     // per-side clearance in the joint (wood PLA, snug/glue fit)
tab_depth   = 8.0;      // how far the fingers reach across the seam
tab_w       = 22.0;     // finger width along Y
tab_span    = 200.0;    // fingers live within |y| < tab_span/2, clear of the edge holes

/* [Seam — splice bar] */
bar_w       = 40.0;     // X, wide enough to cover the fingers and both stitch rows
bar_len     = 224.0;    // Y
bar_t       = 3.0;      // doubles local section depth: 4 mm -> 7 mm, ~3x stiffer
bar_taper   = 1.0;      // side draft so it is not a snag on the bag underside

/* [Seam — stitch holes] */
stitch_d     = 4.0;     // yarn + hook
stitch_x     = 14.0;    // the two stitch rows sit at x = +/- this
stitch_pitch = 16.0;
stitch_rows  = 6;       // holes per row per side of centre (so 4 * this in total)

$fn = 48;

// ---------------------------------------------------------------- geometry ---
rc = min(plate_len, plate_wid) * corner_frac;   // outer corner radius

// inset rounded-rect path the crochet hole centers sit on
Lh = plate_len - 2*edge_margin;
Wh = plate_wid - 2*edge_margin;
rh = max(1, rc - edge_margin);
a  = Lh/2;  b = Wh/2;
h_run  = a - rh;            // half of a straight top/bottom run
sl_v   = 2*(b - rh);        // left/right straight run
sa     = (PI/2)*rh;         // quarter-arc length
L_side = 2*sa + sl_v;       // tangent point to tangent point, going round one end

// Straight (top/bottom) runs are laid out from the SEAM outward so no hole ever
// straddles the cut: the nearest hole centre is seam_offset away, and the run is
// re-pitched slightly to land exactly on the corner tangent point.
n_str = max(2, round((h_run - seam_offset)/hole_pitch) + 1);
p_str = (h_run - seam_offset)/(n_str - 1);
straight_xs = [ for (j = [0:n_str-1]) seam_offset + j*p_str ];

// The two ends get interior holes only — the tangent points already have one.
n_side = max(1, round(L_side/hole_pitch) - 1);
p_side = L_side/(n_side + 1);

// arc-length along the right-hand end, from (h_run, -b) round to (h_run, +b)
function side_point(t) =
    t < sa            ? let(an = -90 + 90*t/sa)
                        [ h_run + rh*cos(an), -(b-rh) + rh*sin(an) ]
  : t < sa + sl_v     ? [ a, -(b-rh) + (t - sa) ]
  :                     let(an = 90*(t - sa - sl_v)/sa)
                        [ h_run + rh*cos(an),  (b-rh) + rh*sin(an) ];

// every crochet hole centre, as [x, y]
perim_holes = concat(
    [ for (x = straight_xs) [ x, -b] ], [ for (x = straight_xs) [-x, -b] ],
    [ for (x = straight_xs) [ x,  b] ], [ for (x = straight_xs) [-x,  b] ],
    [ for (i = [1:n_side]) side_point(i*p_side) ],
    [ for (i = [1:n_side]) let(p = side_point(i*p_side)) [-p[0], p[1]] ]
);

// stitch hole centres — two rows flanking the seam, inside the bar footprint
stitch_ys = [ for (j = [0:stitch_rows-1])
                each [ (j + 0.5)*stitch_pitch, -(j + 0.5)*stitch_pitch ] ];
stitch_holes = [ for (y = stitch_ys) each [ [stitch_x, y], [-stitch_x, y] ] ];

// ------------------------------------------------------------------ modules ---
module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

// through hole + a 45deg chamfer at the top and bottom faces
module hole_cutter(d) {
  cylinder(d=d, h=thickness+2, center=true);
  translate([0, 0,  thickness/2 - hole_chamfer])
    cylinder(d1=d, d2=d + 2*hole_chamfer, h=hole_chamfer + 0.01);
  translate([0, 0, -thickness/2 - 0.01])
    cylinder(d1=d + 2*hole_chamfer, d2=d, h=hole_chamfer + 0.01);
}

// the un-split plate, centred on the origin, seam at x = 0
module full_plate() {
  difference() {
    linear_extrude(thickness, center=true) rrect(plate_len, plate_wid, rc);
    for (p = perim_holes)  translate([p[0], p[1], 0]) hole_cutter(hole_d);
    for (p = stitch_holes) translate([p[0], p[1], 0]) hole_cutter(stitch_d);
  }
}

// finger layout: odd cell count so the pattern is symmetric about y = 0.
// Even cells are half A's fingers, odd cells are half B's.
ncells = 2*floor(tab_span/(2*tab_w)) + 1;
function cell_y(k) = -(ncells - 1)/2*tab_w + k*tab_w;

BIG = 1000;

// everything belonging to half A, before clearance: x <= 0 plus A's fingers
module seam_A_2d() {
  union() {
    translate([-BIG/2, 0]) square([BIG, BIG], center=true);
    for (k = [0:2:ncells-1])
      translate([tab_depth/2, cell_y(k)]) square([tab_depth, tab_w], center=true);
  }
}

// half B is the exact complement, so B's sockets match A's fingers by construction
module seam_B_2d() {
  difference() { square([BIG, BIG], center=true); seam_A_2d(); }
}

// Shrinking BOTH sides by seam_clear/2 opens a uniform seam_clear gap on every
// joint face. delta (not r) keeps the finger corners square.
module half(which) {
  intersection() {
    full_plate();
    linear_extrude(thickness + 2, center=true)
      offset(delta = -seam_clear/2)
        if (which == "A") seam_A_2d(); else seam_B_2d();
  }
}

// underside butt strap. Printed flat, wide face down — that face is the glue
// face, and a bed-finished surface bonds better than a top surface.
module splice_bar() {
  difference() {
    hull() {
      linear_extrude(0.01) rrect(bar_w, bar_len, 5);
      translate([0, 0, bar_t - 0.01])
        linear_extrude(0.01) rrect(bar_w - 2*bar_taper, bar_len - 2*bar_taper, 4);
    }
    for (p = stitch_holes)
      translate([p[0], p[1], -1]) cylinder(d=stitch_d, h=bar_t + 2);
    // countersink the exposed face so the yarn crosses a chamfer, not an edge
    for (p = stitch_holes)
      translate([p[0], p[1], bar_t - hole_chamfer])
        cylinder(d1=stitch_d, d2=stitch_d + 2*hole_chamfer, h=hole_chamfer + 0.01);
  }
}

// ---------------------------------------------------------------- assembly ---
if (part == "A")           half("A");
else if (part == "B")      half("B");
else if (part == "bar")    splice_bar();
else {
  half("A");
  half("B");
  // bar hangs below the plate; flipped so its tapered face points away
  translate([0, 0, -thickness/2])
    mirror([0, 0, 1]) splice_bar();
}

// ------------------------------------------------------------------ report ---
half_x = plate_len/2 + tab_depth;
echo(str("half footprint  = ", half_x, " x ", plate_wid, " mm"));
echo(str("bar footprint   = ", bar_w, " x ", bar_len, " mm"));
echo(str("half + bar on X = ", half_x + bar_w, " mm (must be < bed)"));
// A carries all the tabs, B all the sockets — the seam is a square wave between
// x = 0 and x = tab_depth. Functionally identical to an interdigitated joint for
// shear and alignment, and it keeps B's outline simple.
echo(crochet_holes = len(perim_holes), stitch_holes = len(stitch_holes),
     tabs_on_A = ceil(ncells/2), sockets_in_B = ceil(ncells/2),
     straight_pitch = p_str, side_pitch = p_side);
