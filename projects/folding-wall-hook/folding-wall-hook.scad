// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// A flush-folding wall hook: a wall-mounted FRAME with a front pocket, and a
// PADDLE that nests flush in the pocket when not in use and swings out the bottom
// to hang things on. Styled with squared-oval (rounded-rectangle) outlines — its
// own geometry, not derived from any specific third-party model.
//
// Frame: the squared-oval outline lies in X-Y (X = width, Y = height up the wall);
// the wall is the X-Y plane at Z = 0 and +Z points out into the room. The paddle
// pivots on side pins about the X axis.

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle]
// Preview only: 0 = folded flush, 90 = paddle straight out.
preview_deploy = 80;  // [0:5:95]

/* [Outline] */
w = 34;        // width  (X)
h = 68;        // height (Y)
depth = 13;    // depth from the wall (Z)
corner = 9;    // outline corner radius — bigger = rounder, smaller = squarer

/* [Frame] */
back_wall = 3;       // wall-side back thickness (backs the folded paddle)
side_wall = 6;       // pocket side-wall thickness (must exceed the socket depth)
top_solid = 26;      // solid upper band (holds the screws), measured from the top

/* [Mounting screws] */
screw_d = 4.3;       // M4 clearance
screw_head_d = 8.0;  // countersink
screw_gap = 14;      // vertical spacing between the two screws

/* [Pivot] */
pin_d = 4;           // paddle trunnion pin
pin_len = 3.5;       // pin length into each side wall
pin_clear = 0.25;    // per-side pin/socket clearance (slip)

/* [Paddle] */
paddle_t = 6;        // paddle thickness
paddle_clear = 0.4;  // per-side gap between paddle and pocket
lip = 1.4;           // raised finger-lip to flip the paddle out

$fn = 96;

// ---- derived ----
pocket_top = h / 2 - top_solid;          // top of the pocket (Y)
pocket_w = w - 2 * side_wall;            // pocket width
pocket_r = max(2, corner - side_wall);   // pocket corner radius
pocket_front = depth;                     // pocket opens at the front face
pocket_back = back_wall;                  // pocket floor (paddle nests against it)
pivot_y = pocket_top - 6;                 // pivot just below the solid band
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = (pivot_y - (-h / 2)) - 3;    // reaches near the bottom edge when folded

// 2D squared-oval (rounded rectangle) centered at origin.
module squared_oval(width, height, r) {
    offset(r) offset(-r) square([width, height], center = true);
}

// ===========================================================================
// FRAME
// ===========================================================================
module frame_solid() {
    linear_extrude(depth) squared_oval(w, h, corner);
}

module pocket_cut() {
    // Front recess for the paddle. It extends below the frame bottom so the
    // lower edge is an open slot the paddle can swing out through, and up
    // through the front face (depth + 1) so the pocket is open at the front.
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

module pivot_sockets() {
    for (s = [-1, 1])
        translate([s * (pocket_w / 2 + 0.01), pivot_y, pivot_z])
            rotate([0, -s * 90, 0])
                cylinder(d = pin_d + 2 * pin_clear, h = pin_len + 0.4);
}

module frame() {
    difference() {
        frame_solid();
        pocket_cut();
        screw_cut(h / 2 - top_solid / 2 + screw_gap / 2);
        screw_cut(h / 2 - top_solid / 2 - screw_gap / 2);
        pivot_sockets();
    }
}

// ===========================================================================
// PADDLE
// ===========================================================================
// Local frame: pivot at origin; paddle hangs -Y; thickness in Z (front at +Z).
module paddle_local() {
    union() {
        difference() {
            union() {
                // Tongue body.
                translate([0, -paddle_len / 2, 0])
                    linear_extrude(paddle_t, center = true)
                        squared_oval(paddle_w, paddle_len, pocket_r - paddle_clear);
                // Finger lip near the free end (front side) to flip it out.
                translate([0, -paddle_len + 7, paddle_t / 2])
                    linear_extrude(lip)
                        squared_oval(paddle_w * 0.6, 5, 2);
            }
            // Hollow the back a touch so it seats flush (and saves plastic).
        }
        // Trunnion pins.
        for (s = [-1, 1])
            translate([s * paddle_w / 2, 0, 0]) rotate([0, s * 90, 0]) union() {
                cylinder(d = pin_d, h = pin_len);
                translate([0, 0, pin_len - 0.7]) cylinder(d1 = pin_d, d2 = pin_d - 1.2, h = 0.7);
            }
        // Stop shoulder above the pins: butts the solid band to stop the swing.
        translate([0, 2.5, 0]) rotate([0, 90, 0])
            cylinder(d = paddle_t, h = paddle_w, center = true);
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
    // Lay flat for printing: pivot axis on the bed, tongue in +Y.
    rotate([90, 0, 0]) paddle_local();
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
}
