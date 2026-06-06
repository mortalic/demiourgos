// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// A flush-folding wall hook: a wall-mounted FRAME with a front pocket, and a
// PADDLE that nests flush in the pocket when not in use and swings out to hang
// things on. Squared-oval (rounded-rectangle) outlines — its own geometry.
//
// Pivot + hold (fold-down, friction version): the paddle rotates on a separate
// AXLE with a snug, FRICTION fit so it holds wherever you set it (no fragile
// detent to shear). A solid STOPPER bar across the hub caps the deploy swing so
// it stops at a clean angle instead of flopping. NOTE: in this fold-down layout a
// downward pull is the same motion as folding, so the hold is friction only — it
// keeps light items but a firm tug folds it. (Fold-UP + a hard stopper is the way
// to truly lock a load; see docs/support-free-design.md.)
//
// Screws are hidden behind the folded paddle (in the pocket) and sit high, so the
// load hangs below them. Support-free: paddle prints flat; axle bore teardropped;
// axle prints on its head.

use <demiourgos_support.scad>;

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle, axle]
// Preview only: 0 = folded flush, 90 = deployed.
preview_deploy = 90;  // [0:5:120]

/* [Outline] */
w = 34;        // width  (X)
h = 50;        // height (Y) — smaller now the screws live in the pocket
depth = 15;    // depth from the wall (Z)
corner = 9;    // outline corner radius

/* [Frame] */
back_wall = 3;       // wall-side back thickness (also the screw-boss depth)
side_wall = 6;       // pocket side-wall thickness
top_solid = 6;       // small solid cap above the pocket (was a big screw band)

/* [Mounting screws — hidden in the pocket, behind the folded paddle] */
screw_d = 4.3;       // M4 clearance
screw_head_d = 8.0;  // countersink
screw_gap = 16;      // vertical spacing between the two screws
screw_drop = 5;      // how far below the pivot the upper screw sits

/* [Pivot axle] */
axle_d = 3;          // axle diameter (printed pin, or a 3 mm rod / filament / paperclip)
axle_clear = 0.1;    // per-side clearance in the PADDLE bore — SNUG for a friction hinge
axle_fit = 0.05;     // per-side clearance in the FRAME bores (the axle is fixed)
head_d = 6;
head_h = 1.6;
knurl_ribs = 10;     // longitudinal grip ribs on the shaft below the head
knurl_over = 0.2;    // how far each rib stands proud of the shaft (the press grip)

/* [Hub / stopper] */
hub_ext = 7;         // chunky pivot hub (the visible "stopper" block at the pivot
                     // end); kept within the paddle thickness so it prints flat

/* [Paddle] */
paddle_t = 6;        // paddle thickness
paddle_clear = 0.4;  // per-side gap between paddle and pocket
lip = 1.4;           // raised finger-lip to flip the paddle out

$fn = 96;

// ---- derived ----
pocket_top = h / 2 - top_solid;          // top of the pocket (Y)
pocket_w = w - 2 * side_wall;            // pocket width
pocket_r = max(2, corner - side_wall);   // pocket corner radius
pocket_back = back_wall;                  // pocket floor (paddle nests against it)
pivot_y = pocket_top - 8;                 // pivot dropped so the hub clears the cap
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = (pivot_y - (-h / 2)) - 2;    // reaches near the bottom edge when folded

// 2D squared-oval (rounded rectangle) centered at origin.
module squared_oval(width, height, r) {
    offset(r) offset(-r) square([width, height], center = true);
}

// A headed dowel that prints standing on its head (self-supporting). A band of
// longitudinal grip ribs just below the head presses into the frame bore so the
// pin seats and stays put (the ribs run vertical in the print — no support).
module headed_pin(shaft_d, shaft_len, hd = head_d, hh = head_h, knurl = false) {
    cylinder(d = hd, h = hh);
    translate([0, 0, hh]) cylinder(d = shaft_d, h = shaft_len);
    translate([0, 0, hh + shaft_len - 0.6]) cylinder(d1 = shaft_d, d2 = shaft_d - 1.2, h = 0.6);
    if (knurl) {
        band = min(side_wall - 1, shaft_len - 1);
        for (i = [0:knurl_ribs - 1])
            rotate([0, 0, i * 360 / knurl_ribs])
                translate([shaft_d / 2, 0, hh])
                    cylinder(d = 2 * knurl_over, h = band, $fn = 12);
    }
}

// ===========================================================================
// FRAME
// ===========================================================================
module frame_solid() {
    linear_extrude(depth) squared_oval(w, h, corner);
}

module pocket_cut() {
    cut_bottom = -h / 2 - 12;
    cut_h = pocket_top - cut_bottom;
    cut_cy = (pocket_top + cut_bottom) / 2;
    translate([0, cut_cy, pocket_back])
        linear_extrude(depth + 1)
            squared_oval(pocket_w, cut_h, pocket_r);
}

// Screw hole through the back wall, countersunk on the POCKET side so the head
// sits flush with the pocket floor — hidden behind the folded paddle. Drive it
// with the paddle deployed (swung out of the way).
module screw_cut(y) {
    translate([0, y, -1]) cylinder(d = screw_d, h = back_wall + 1.1);
    cs = (screw_head_d - screw_d) / 2;
    translate([0, y, back_wall - cs]) cylinder(d1 = screw_d, d2 = screw_head_d, h = cs + 0.2);
}

module axle_bore_frame() {
    translate([0, pivot_y, pivot_z]) rotate([0, 0, -90])
        teardrop_hole(d = axle_d + 2 * axle_fit, length = w + 2);
}

module frame() {
    difference() {
        frame_solid();
        pocket_cut();
        screw_cut(pivot_y - screw_drop);
        screw_cut(pivot_y - screw_drop - screw_gap);
        axle_bore_frame();
    }
}

// ===========================================================================
// PADDLE
// ===========================================================================
// Local frame: pivot at the origin; tongue hangs -Y; thickness in Z.
module paddle_local() {
    difference() {
        union() {
            // Flat plate: tongue + pivot hub in one piece (pivot at the origin).
            translate([0, (hub_ext - paddle_len) / 2, 0])
                linear_extrude(paddle_t, center = true)
                    squared_oval(paddle_w, paddle_len + hub_ext, pocket_r - paddle_clear);
            // Finger lip near the free (bottom) end to flip it out.
            translate([0, -paddle_len + 7, paddle_t / 2])
                linear_extrude(lip)
                    squared_oval(paddle_w * 0.6, 5, 2);
        }
        // Axle bore at the pivot (teardrop, apex +Z, self-supporting). Snug fit.
        rotate([0, 0, -90]) teardrop_hole(d = axle_d + 2 * axle_clear, length = paddle_w + 4);
    }
}

// Place the paddle at the pivot, rotated for the preview deploy angle.
module paddle_placed(deploy) {
    translate([0, pivot_y, pivot_z]) rotate([-deploy, 0, 0]) paddle_local();
}

// ===========================================================================
// SELECT
// ===========================================================================
if (part == "frame") {
    frame();
} else if (part == "paddle") {
    translate([0, 0, paddle_t / 2]) paddle_local();
} else if (part == "axle") {
    headed_pin(axle_d, w - 0.5, knurl = true);
} else if (part == "interference") {
    intersection() { frame(); paddle_placed(preview_deploy); }
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
    color("DimGray") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z])
        rotate([0, 90, 0]) headed_pin(axle_d, w - 0.5, knurl = true);
}
