// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// A flush-folding wall hook: a wall-mounted FRAME with a front pocket, and a
// PADDLE that nests flush in the pocket when not in use and swings out the bottom
// to hang things on. Styled with squared-oval (rounded-rectangle) outlines — its
// own geometry, not derived from any specific third-party model.
//
// Frame: the squared-oval outline lies in X-Y (X = width, Y = height up the wall);
// the wall is the X-Y plane at Z = 0 and +Z points out into the room.
//
// Pivot: a SEPARATE AXLE (a printed headed pin, or a 3 mm rod). The paddle has a
// through bore and drops into the pocket with clearance; the axle is then pushed
// through the frame's bores and the paddle's, joining them. This is what makes it
// actually assemblable — integral snap pins can't flex into a rigid pocket.
//
// Support-free: the paddle prints flat on its broad face; all the horizontal
// bores are teardropped (round where the axle bears, self-supporting ceilings);
// the axle prints standing on its head. Both shells print without supports.

use <demiourgos_support.scad>;

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle, axle]
// Preview only: 0 = folded flush, 90 = paddle straight out.
preview_deploy = 80;  // [0:5:95]

/* [Outline] */
w = 34;        // width  (X)
h = 68;        // height (Y)
depth = 13;    // depth from the wall (Z)
corner = 9;    // outline corner radius — bigger = rounder, smaller = squarer

/* [Frame] */
back_wall = 3;       // wall-side back thickness (backs the folded paddle)
side_wall = 6;       // pocket side-wall thickness
top_solid = 26;      // solid upper band (holds the screws), measured from the top

/* [Mounting screws] */
screw_d = 4.3;       // M4 clearance
screw_head_d = 8.0;  // countersink
screw_gap = 14;      // vertical spacing between the two screws

/* [Pivot — separate axle] */
axle_d = 3;          // axle diameter (printed pin, or a 3 mm rod / filament / paperclip)
axle_clear = 0.3;    // per-side clearance in the PADDLE bore (free rotation)
axle_fit = 0.05;     // per-side clearance in the FRAME bores (friction hold)
head_d = 6;          // axle head — won't pass through the frame bore
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
pivot_y = pocket_top - 6;                 // pivot just below the solid band
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = (pivot_y - (-h / 2)) - 3;    // reaches near the bottom edge when folded
hub_ext = axle_d / 2 + 3;                 // material above the pivot bore (the hub)

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

module axle_bore_frame() {
    // One through teardrop bore across the full width for the axle (apex +Z = up
    // when the frame prints, so the ceiling self-supports). Friction-fit; the
    // paddle, not the frame, rotates on the axle.
    translate([0, pivot_y, pivot_z]) rotate([0, 0, -90])
        teardrop_hole(d = axle_d + 2 * axle_fit, length = w + 2);
}

module frame() {
    difference() {
        frame_solid();
        pocket_cut();
        screw_cut(h / 2 - top_solid / 2 + screw_gap / 2);
        screw_cut(h / 2 - top_solid / 2 - screw_gap / 2);
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
            // Flat plate: tongue + pivot hub in one piece (pivot at the origin,
            // hub material extends +Y above it).
            translate([0, (hub_ext - paddle_len) / 2, 0])
                linear_extrude(paddle_t, center = true)
                    squared_oval(paddle_w, paddle_len + hub_ext, pocket_r - paddle_clear);
            // Finger lip near the free (bottom) end to flip it out.
            translate([0, -paddle_len + 7, paddle_t / 2])
                linear_extrude(lip)
                    squared_oval(paddle_w * 0.6, 5, 2);
            // Stop block above the pivot: butts the solid band to limit the swing.
            // A flat block — flat bottom/top, vertical faces — fully self-supporting.
            translate([0, hub_ext + 1.0, 0]) cube([paddle_w, 2.0, paddle_t], center = true);
        }
        // Axle bore: a through teardrop hole (apex +Z, self-supporting). The axle
        // bears on the round part, so the paddle rotates freely.
        rotate([0, 0, -90]) teardrop_hole(d = axle_d + 2 * axle_clear, length = paddle_w + 4);
    }
}

// Place the paddle at the pivot, rotated for the preview deploy angle.
module paddle_placed(deploy) {
    translate([0, pivot_y, pivot_z]) rotate([-deploy, 0, 0]) paddle_local();
}

// ===========================================================================
// AXLE
// ===========================================================================
// A headed pin. Prints standing on its head (flat disc on the bed, shaft up) so
// it is fully self-supporting. Push it through the assembled frame + paddle.
module axle() {
    shaft_len = w - 0.5;
    cylinder(d = head_d, h = head_h);
    translate([0, 0, head_h]) cylinder(d = axle_d, h = shaft_len);
    // Lead-in tip for easy insertion.
    translate([0, 0, head_h + shaft_len - 0.6]) cylinder(d1 = axle_d, d2 = axle_d - 1.2, h = 0.6);
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
    axle();
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
    // Axle through the pivot (preview), laid along X with the head on the left.
    color("DimGray") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z])
        rotate([0, 90, 0]) axle();
}
