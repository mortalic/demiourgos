// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// A flush-folding wall hook: a wall-mounted FRAME with a front pocket, and a
// PADDLE that nests flush in the pocket when not in use and swings out to hang
// things on. Squared-oval (rounded-rectangle) outlines — its own geometry, not
// derived from any specific third-party model.
//
// Pivot + lock: the paddle rotates on a separate AXLE. A single revolute pivot
// can't hold a downward load on its own (the load torque always drives the
// paddle back toward folded — the same direction it must be free to fold), so a
// second drop-in LOCK PIN pins the paddle to the frame at the deploy angle for
// load. Pull the lock pin to fold flush. Both pins are separate parts (printed
// dowels, or 3–4 mm rod). See docs/support-free-design.md (Design for assembly).
//
// Support-free: the paddle prints flat on its broad face; every horizontal bore
// is teardropped (round where a pin bears, self-supporting ceiling); the pins
// print standing on their heads. All shells print without supports.

use <demiourgos_support.scad>;

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle, axle, lockpin]
// Preview only: 0 = folded flush, 90 = deployed (and locked).
preview_deploy = 90;  // [0:5:120]

/* [Outline] */
w = 34;        // width  (X)
h = 68;        // height (Y)
depth = 16;    // depth from the wall (Z) — deep enough that the lock hub clears
               // the pocket back wall when deployed
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

/* [Lock pin] */
lock_d = 3;          // lock-pin diameter (a 3 mm dowel / rod — same as the axle)
lock_r = 5;          // lock bore offset above the pivot (the load moment arm)
lock_angle = 90;     // deploy angle at which the lock bores align (held for load)
lock_clear = 0.1;    // per-side clearance in the PADDLE lock bore (snug, low slop)
lock_fit = 0.075;    // per-side clearance in the FRAME lock bores

/* [Pin heads] */
head_d = 6;
head_h = 1.6;

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
// Pivot dropped well below the band so the hub has room for BOTH the axle bore
// and the offset lock bore without poking the solid band when folded.
pivot_y = pocket_top - 9;
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = (pivot_y - (-h / 2)) - 3;    // reaches near the bottom edge when folded
// Hub reaches just above the lock bore (apex included). Kept short enough that the
// hub corner clears the pocket back wall as it swings to the deploy angle.
hub_ext = lock_r + (lock_d + 2 * lock_clear) / 2 + 0.6;

// 2D squared-oval (rounded rectangle) centered at origin.
module squared_oval(width, height, r) {
    offset(r) offset(-r) square([width, height], center = true);
}

// A headed dowel that prints standing on its head (flat disc on the bed, shaft
// up) — fully self-supporting. Used for both the axle and the lock pin.
module headed_pin(shaft_d, shaft_len, hd = head_d, hh = head_h) {
    cylinder(d = hd, h = hh);
    translate([0, 0, hh]) cylinder(d = shaft_d, h = shaft_len);
    translate([0, 0, hh + shaft_len - 0.6]) cylinder(d1 = shaft_d, d2 = shaft_d - 1.2, h = 0.6);
}

// ===========================================================================
// FRAME
// ===========================================================================
module frame_solid() {
    linear_extrude(depth) squared_oval(w, h, corner);
}

module pocket_cut() {
    // Front recess for the paddle, open at the bottom (a slot the paddle swings
    // through) and at the front face.
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

// Through teardrop bores across the full width (apex +Z = up when the frame
// prints, so the ceiling self-supports).
module axle_bore_frame() {
    translate([0, pivot_y, pivot_z]) rotate([0, 0, -90])
        teardrop_hole(d = axle_d + 2 * axle_fit, length = w + 2);
}

// Lock bores: positioned where the paddle's lock bore lands when deployed to
// `lock_angle`. Empty until you drop the lock pin in.
module lock_bore_frame() {
    p = lock_world(lock_angle);
    translate([0, p[0], p[1]]) rotate([0, 0, -90])
        teardrop_hole(d = lock_d + 2 * lock_fit, length = w + 2);
}

module frame() {
    difference() {
        frame_solid();
        pocket_cut();
        screw_cut(h / 2 - top_solid / 2 + screw_gap / 2);
        screw_cut(h / 2 - top_solid / 2 - screw_gap / 2);
        axle_bore_frame();
        lock_bore_frame();
    }
}

// World (Y, Z) of the paddle's lock bore (paddle-local (lock_r, 0)) at deploy `d`.
function lock_world(d) = [
    pivot_y + lock_r * cos(d),
    pivot_z - lock_r * sin(d),
];

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
            // Square off the hub top: the full-width lock bore would otherwise
            // breach the rounded top corners (zero wall). This keeps full height
            // across the whole width above the bore.
            translate([0, (lock_r - 1 + hub_ext) / 2, 0])
                linear_extrude(paddle_t, center = true)
                    square([paddle_w, hub_ext - lock_r + 1], center = true);
            // Finger lip near the free (bottom) end to flip it out.
            translate([0, -paddle_len + 7, paddle_t / 2])
                linear_extrude(lip)
                    squared_oval(paddle_w * 0.6, 5, 2);
        }
        // Axle bore at the pivot (teardrop, apex +Z, self-supporting).
        rotate([0, 0, -90]) teardrop_hole(d = axle_d + 2 * axle_clear, length = paddle_w + 4);
        // Lock bore, offset `lock_r` above the pivot (the load moment arm).
        translate([0, lock_r, 0])
            rotate([0, 0, -90]) teardrop_hole(d = lock_d + 2 * lock_clear, length = paddle_w + 4);
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
    // contact, and the teardrop bores self-support with +Z up.
    translate([0, 0, paddle_t / 2]) paddle_local();
} else if (part == "axle") {
    headed_pin(axle_d, w - 0.5);
} else if (part == "lockpin") {
    headed_pin(lock_d, w - 0.5);
} else if (part == "interference") {
    // Diagnostic: overlap of the deployed paddle and frame (sweep preview_deploy).
    intersection() { frame(); paddle_placed(preview_deploy); }
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
    // Axle through the pivot.
    color("DimGray") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z])
        rotate([0, 90, 0]) headed_pin(axle_d, w - 0.5);
    // Lock pin in place when deployed at the lock angle.
    if (preview_deploy == lock_angle)
        color("SteelBlue") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z - lock_r])
            rotate([0, 90, 0]) headed_pin(lock_d, w - 0.5);
}
