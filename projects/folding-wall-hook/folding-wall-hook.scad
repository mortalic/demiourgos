// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// A flush-folding wall hook: a wall-mounted FRAME with a front pocket, and a
// PADDLE that nests flush in the pocket when not in use and swings out to hang
// things on. Squared-oval (rounded-rectangle) outlines — its own geometry, not
// derived from any specific third-party model.
//
// Pivot + detent: the paddle rotates on a separate AXLE. A single revolute pivot
// can't hold a downward load on its own (the load torque drives the paddle back
// toward folded — the same direction it must be free to fold), so the deployed
// angle is held by a COMPLIANT BALL DETENT: two thin flexible fingers on the hub
// carry a small ball each that snaps into a dimple in the pocket wall at the
// deploy angle. No loose parts — you just flip it out until it clicks, and push
// to fold. (The snap force is print-tuned; see PRINT-TEST.md.)
//
// Support-free: the paddle prints flat on its broad face; the axle bore is
// teardropped (round bearing, self-supporting ceiling); the axle prints standing
// on its head. See docs/support-free-design.md.

use <demiourgos_support.scad>;

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle, axle]
// Preview only: 0 = folded flush, 90 = deployed (detent angle).
preview_deploy = 90;  // [0:5:120]

/* [Outline] */
w = 34;        // width  (X)
h = 68;        // height (Y)
depth = 15;    // depth from the wall (Z) — deep enough the detent hub clears the
               // pocket back wall as it swings
corner = 9;    // outline corner radius — bigger = rounder, smaller = squarer

/* [Frame] */
back_wall = 3;       // wall-side back thickness (backs the folded paddle)
side_wall = 6;       // pocket side-wall thickness
top_solid = 26;      // solid upper band (holds the screws), measured from the top

/* [Mounting screws] */
screw_d = 4.3;       // M4 clearance
screw_head_d = 8.0;  // countersink
screw_gap = 14;      // vertical spacing between the two screws

/* [Pivot axle] */
axle_d = 3;          // axle diameter (printed pin, or a 3 mm rod / filament / paperclip)
axle_clear = 0.3;    // per-side clearance in the PADDLE bore (free rotation)
axle_fit = 0.05;     // per-side clearance in the FRAME bores (friction hold)
head_d = 6;
head_h = 1.6;
knurl_ribs = 10;     // longitudinal grip ribs on the shaft below the head
knurl_over = 0.2;    // how far each rib stands proud of the shaft (the press grip)

/* [Detent] */
detent_angle = 90;   // deploy angle the detent holds (horizontal peg)
nub_ly = 4.5;        // ball offset above the pivot (the detent's moment arm) —
                     // kept low enough the squared hub clears the pocket's top corners
nub_r = 1.2;         // detent ball radius
nub_press = 0.3;     // how far the relaxed ball passes the pocket wall (the squeeze) —
                     // bigger = firmer click and more holding, stiffer swing
finger_w = 1.3;      // flexible finger thickness (X) — thinner = lighter snap
slot_w = 1.4;        // slot that frees each finger
finger_base = 2.6;   // ly where the slot/finger starts (above the axle bore)

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
pivot_y = pocket_top - 8;                 // pivot dropped so the hub clears the band
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = (pivot_y - (-h / 2)) - 3;    // reaches near the bottom edge when folded
hub_ext = nub_ly + nub_r + 0.3;           // hub reaches just above the detent ball

// World (Y, Z) of a paddle-local point (ly, 0) at deploy angle `d`.
function arc(ly, d) = [pivot_y + ly * cos(d), pivot_z - ly * sin(d)];

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

module screw_cut(y) {
    translate([0, y, -1]) cylinder(d = screw_d, h = depth + 2);
    cs = (screw_head_d - screw_d) / 2;
    translate([0, y, depth - cs + 0.01]) cylinder(d1 = screw_d, d2 = screw_head_d, h = cs + 0.5);
}

module axle_bore_frame() {
    translate([0, pivot_y, pivot_z]) rotate([0, 0, -90])
        teardrop_hole(d = axle_d + 2 * axle_fit, length = w + 2);
}

// Detent dimples: a ball-seat in each pocket side wall where the hub ball lands
// at the deploy angle.
module detent_dimples() {
    p = arc(nub_ly, detent_angle);
    for (s = [-1, 1])
        translate([s * (pocket_w / 2), p[0], p[1]]) sphere(r = nub_r + 0.1);
}

module frame() {
    difference() {
        frame_solid();
        pocket_cut();
        screw_cut(h / 2 - top_solid / 2 + screw_gap / 2);
        screw_cut(h / 2 - top_solid / 2 - screw_gap / 2);
        axle_bore_frame();
        detent_dimples();
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
            // Square off the hub top so the detent fingers/balls have full-width
            // material (the rounded oval corners would otherwise undercut them).
            translate([0, (finger_base - 0.5 + hub_ext) / 2, 0])
                linear_extrude(paddle_t, center = true)
                    square([paddle_w, hub_ext - finger_base + 0.5], center = true);
            // Finger lip near the free (bottom) end to flip it out.
            translate([0, -paddle_len + 7, paddle_t / 2])
                linear_extrude(lip)
                    squared_oval(paddle_w * 0.6, 5, 2);
            // Detent balls on the outer face of each flexible finger. The ball
            // TIP sits `nub_press` past the pocket wall (the squeeze), so the
            // finger rides flexed and relaxes into the dimple at the detent angle.
            for (s = [-1, 1])
                translate([s * (pocket_w / 2 + nub_press - nub_r), nub_ly, 0])
                    sphere(r = nub_r);
        }
        // Axle bore at the pivot (teardrop, apex +Z, self-supporting).
        rotate([0, 0, -90]) teardrop_hole(d = axle_d + 2 * axle_clear, length = paddle_w + 4);
        // Slots that free the two flexible detent fingers: each finger is the
        // outer `finger_w` strip, cantilevered from `finger_base` up past its ball.
        for (s = [-1, 1])
            translate([s * (paddle_w / 2 - finger_w - slot_w / 2),
                       (finger_base + hub_ext + 0.5) / 2, 0])
                cube([slot_w, (hub_ext + 0.5) - finger_base, paddle_t + 1], center = true);
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
    // Print flat on the broad face: rounded edges become vertical walls, big bed
    // contact, and the teardrop bore self-supports with +Z up.
    translate([0, 0, paddle_t / 2]) paddle_local();
} else if (part == "axle") {
    headed_pin(axle_d, w - 0.5, knurl = true);
} else if (part == "interference") {
    // Diagnostic: overlap of the deployed paddle and frame (sweep preview_deploy).
    // The detent shows as a small overlap (the ball squeeze) that dips at the
    // detent angle (ball seated in the dimple).
    intersection() { frame(); paddle_placed(preview_deploy); }
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
    color("DimGray") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z])
        rotate([0, 90, 0]) headed_pin(axle_d, w - 0.5, knurl = true);
}
