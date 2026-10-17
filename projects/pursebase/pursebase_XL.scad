// pursebase_XL — 17" x 10" (431.8 x 254 mm) crochet / knit bag BASE PLATE.
// Two halves joined by a glued interlocking DOVETAIL seam, flush on both faces,
// so the finished base reads and handles as one piece.
//
// Why it is split at all: a 431.8 x 254 plate needs a 485 mm square bed even
// rotated 45 deg ((L+W)/sqrt(2) = 485). Rotating only helps parts narrower than
// ~149 mm; at 254 mm wide, axis-aligned is optimal and the one-piece max on a
// 360 mm bed is 360 x 254. There is no orientation that prints this in one part.
//
// Why the seam runs across X: the crochet supports the plate on all four edges,
// so the 254 mm span governs the bending. A seam on X is parallel to the
// dominant stress and only sees the weaker long-span component.
//
// How the joint carries load, now that there is no splice bar:
//   * At the seam plane the section is FULL 4 mm thickness across all 254 mm —
//     no thin lap leaves, so no local loss of section modulus.
//   * Tension across the seam transfers as SHEAR on the dovetail flanks
//     (~880 mm2 of angled face). At 8 kg of bag contents that is ~1.2 MPa
//     against 5-15 MPa for CA/epoxy on PLA.
//   * The dovetail flare means that even with the glue gone the halves cannot
//     be pulled apart in X or slid in Y. Only Z separation is glue-only, and
//     the seam sits at midspan where transverse shear is near zero.
//
// Tabs are concentrated in |y| < 105, which is where the bending moment peaks.
// Beyond that the seam is a plain glued butt line — correct, because the plate
// is edge-supported there and the moment falls to ~0 at y = +/-127.
//
// Assembly: the halves are exact 2D complements, so they mate by dropping one
// onto the other in Z (jigsaw-style), NOT by sliding together in the plane.
//   1. dry-fit first; the tabs should seat with hand pressure
//   2. thick CA or 5-min epoxy on the dovetail flanks — thin CA will grab
//      before the tabs are home
//   3. press flat on a known-flat surface, weight it, clamp across X
//   4. sand the seam after cure — wood PLA blends a sanded seam very well,
//      which is what makes the joint disappear
//
// PRINTING (wood PLA, hardened nozzle — wood fill is abrasive):
//   Two separate jobs; each half is 227.9 x 254 mm and two do not share a bed.
//   Brim on both — these are big flat parts and wood PLA is brittle if a corner
//   lifts. Print both halves the SAME face down so the two bed-finished faces
//   end up on the same side of the assembled base.
//
// Parts:  part = "A" | "B" | "assembled"

/* [Part] */
part = "assembled";     // [A, B, assembled]

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

/* [Seam — dovetail joint] */
seam_clear  = 0.20;     // per-side clearance (glue gap; wood PLA, uncalibrated)
tab_depth   = 12.0;     // how far each dovetail reaches across the seam
tab_w       = 24.0;     // target cell width along Y (actual is tab_span/ncells)
tab_span    = 210.0;    // dovetails live within |y| < tab_span/2, clear of the holes
dovetail_ang= 12.0;     // flank angle; 0 would be a straight finger joint
root_frac   = 0.62;     // tab root width as a fraction of the cell

/* [Seam — optional yarn lacing] */
seam_stitch  = false;   // extra holes so the seam can also be stitched with yarn
stitch_d     = 4.0;
stitch_x     = 16.0;    // the two stitch rows sit at x = +/- this (clear of tabs)
stitch_pitch = 16.0;
stitch_rows  = 6;       // holes per row per side of centre

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

stitch_ys = [ for (j = [0:stitch_rows-1])
                each [ (j + 0.5)*stitch_pitch, -(j + 0.5)*stitch_pitch ] ];
stitch_holes = seam_stitch
  ? [ for (y = stitch_ys) each [ [stitch_x, y], [-stitch_x, y] ] ] : [];

// ---- dovetail seam ----
// An odd cell count keeps the pattern symmetric about y = 0 and puts a tab, not
// a socket, on the centreline. Even cells carry A's tabs (pointing +x), odd
// cells carry B's tabs (pointing -x), so each half is both male and female and
// the joint locks in both directions along X.
ncells = 2*floor(tab_span/(2*tab_w)) + 1;
cw     = tab_span/ncells;
flare  = tab_depth * tan(dovetail_ang);
w_root = root_frac * cw;
w_tip  = w_root + 2*flare;      // tip wider than root == cannot pull out in X
function cell_y(k) = -tab_span/2 + (k + 0.5)*cw;

BIG = 1000;

module dovetail(yc, dir) {
  polygon([[0,             yc - w_root/2],
           [dir*tab_depth, yc - w_tip/2 ],
           [dir*tab_depth, yc + w_tip/2 ],
           [0,             yc + w_root/2]]);
}

// Half A: everything left of the seam, plus A's tabs, minus B's tabs.
// Half B is the exact complement, so the two mate by construction.
module seam_A_2d() {
  difference() {
    union() {
      translate([-BIG/2, 0]) square([BIG, BIG], center=true);
      for (k = [0:2:ncells-1]) dovetail(cell_y(k), +1);
    }
    for (k = [1:2:ncells-1]) dovetail(cell_y(k), -1);
  }
}

module seam_B_2d() {
  difference() { square([BIG, BIG], center=true); seam_A_2d(); }
}

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

// Shrinking BOTH halves by seam_clear/2 opens a uniform seam_clear glue gap on
// every mating face, including the angled flanks. delta (not r) keeps the
// dovetail corners sharp and preserves the flank angle.
module half(which) {
  intersection() {
    full_plate();
    linear_extrude(thickness + 2, center=true)
      offset(delta = -seam_clear/2)
        if (which == "A") seam_A_2d(); else seam_B_2d();
  }
}

// ---------------------------------------------------------------- assembly ---
if      (part == "A") half("A");
else if (part == "B") half("B");
else { half("A"); half("B"); }

// ------------------------------------------------------------------ report ---
half_x = plate_len/2 + tab_depth;
// flank area is what actually carries tension across the seam
flank_area = 2*ncells * (tab_depth/cos(dovetail_ang)) * thickness;
echo(str("half footprint = ", half_x, " x ", plate_wid, " mm  (two prints)"));
echo(str("dovetail flank glue area = ", round(flank_area), " mm2"));
echo(cells = ncells, tabs_on_A = ceil(ncells/2), tabs_on_B = floor(ncells/2),
     cell_w = cw, root_w = w_root, tip_w = w_tip, shoulder = cw - w_root,
     crochet_holes = len(perim_holes), stitch_holes = len(stitch_holes));
