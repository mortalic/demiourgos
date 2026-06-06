// Squared-Oval Folding Wall Hook — an ORIGINAL parametric design by this project.
//
// FOLD-UP layout: the PADDLE folds UP flush in the pocket (covering the high,
// hidden mounting screws) and deploys DOWN to a horizontal peg. A raised STOPPER
// EDGE on the paddle root catches the frame at horizontal — a hanging load pushes
// the paddle *into* the edge (a solid stop, no flex to shear), while folding is
// free because you lift it back UP, the opposite way. The screws sit high, so the
// load hangs below them and pulls down on them.
//
// Pivot is a separate AXLE (drop the paddle in, push the pin through). Support-
// free: paddle prints flat (the edge and lip point up, off the bed); axle bore is
// teardropped; axle prints on its head.

use <demiourgos_support.scad>;

/* [Which part] */
part = "assembled";   // [assembled, frame, paddle, axle]
// Preview only: 0 = folded UP (flush), 90 = deployed horizontal.
preview_deploy = 90;  // [0:5:110]

/* [Outline] */
w = 34;        // width  (X)
h = 48;        // height (Y)
depth = 15;    // depth from the wall (Z)
corner = 9;    // outline corner radius

/* [Frame] */
back_wall = 3;       // wall-side back thickness
side_wall = 6;       // pocket side-wall thickness
top_solid = 5;       // small cap above the pocket

/* [Mounting screws — high in the pocket, hidden behind the folded-up paddle] */
screw_d = 4.3;       // M4 clearance
screw_head_d = 8.0;  // countersink
screw_gap = 13;      // vertical spacing
screw_top = 4;       // first screw this far below the pocket top

/* [Pivot axle] */
axle_d = 3;          // axle diameter (printed pin, or a 3 mm rod / filament)
axle_clear = 0.3;    // per-side clearance in the PADDLE bore (free rotation)
axle_fit = 0.05;     // per-side clearance in the FRAME bores
head_d = 6;
head_h = 1.6;
knurl_ribs = 10;
knurl_over = 0.2;

/* [Stopper edge] */
edge_h = 2.5;        // how far the edge stands proud of the paddle face
edge_run = 4.0;      // chamfer run along the tongue (angled so it prints flat)

/* [Paddle] */
paddle_t = 6;        // paddle thickness
paddle_clear = 0.5;  // per-side gap between paddle and pocket (more swing room)
lip = 1.4;           // raised finger-lip to flip the paddle out

$fn = 96;

// ---- derived ----
pocket_top = h / 2 - top_solid;          // top of the pocket (Y)
pocket_w = w - 2 * side_wall;            // pocket width
pocket_r = max(2, corner - side_wall);   // pocket corner radius
pocket_back = back_wall;
pivot_y = -h / 2 + 8;                     // pivot near the BOTTOM
pivot_z = depth - paddle_t / 2 - paddle_clear; // pivot centered in the paddle
hub_below = paddle_t / 2;                 // paddle reaches down to the deployed underside
ledge_y = pivot_y - paddle_t / 2 - 0.6;   // top of the solid stopper ledge below the pivot

paddle_w = pocket_w - 2 * paddle_clear;
paddle_len = pocket_top - pivot_y - 2;    // tongue reaches up near the pocket top

// 2D squared-oval (rounded rectangle) centered at origin.
module squared_oval(width, height, r) {
    offset(r) offset(-r) square([width, height], center = true);
}

// A headed dowel that prints standing on its head (self-supporting); grip knurl.
module headed_pin(shaft_d, shaft_len, hd = head_d, hh = head_h, knurl = false) {
    cylinder(d = hd, h = hh);
    translate([0, 0, hh]) cylinder(d = shaft_d, h = shaft_len);
    translate([0, 0, hh + shaft_len - 0.6]) cylinder(d1 = shaft_d, d2 = shaft_d - 1.2, h = 0.6);
    if (knurl) {
        band = min(side_wall - 1, shaft_len - 1);
        for (i = [0:knurl_ribs - 1])
            rotate([0, 0, i * 360 / knurl_ribs])
                translate([shaft_d / 2, 0, hh]) cylinder(d = 2 * knurl_over, h = band, $fn = 12);
    }
}

// ===========================================================================
// FRAME
// ===========================================================================
module frame_solid() {
    linear_extrude(depth) squared_oval(w, h, corner);
}

// Front pocket ABOVE the pivot (holds the folded-up tongue). Solid frame BELOW
// the pivot is the stopper ledge the deployed paddle's edge catches.
module pocket_cut() {
    cut_top = pocket_top;
    cut_bottom = ledge_y;   // pocket floor at the ledge top; solid frame below it
    cut_h = cut_top - cut_bottom;
    cut_cy = (cut_top + cut_bottom) / 2;
    translate([0, cut_cy, pocket_back])
        linear_extrude(depth + 1)
            squared_oval(pocket_w, cut_h, pocket_r);
}

// Screws high in the pocket, countersunk on the POCKET side so the heads sit
// flush in the pocket floor — hidden behind the folded-up paddle.
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
        screw_cut(pocket_top - screw_top);
        screw_cut(pocket_top - screw_top - screw_gap);
        axle_bore_frame();
    }
}

// ===========================================================================
// PADDLE
// ===========================================================================
// Local frame: pivot at the origin; tongue extends +Y (UP when folded); +Z front.
module paddle_local() {
    difference() {
        union() {
            // Tongue + a little hub below the pivot (for bore material).
            translate([0, (paddle_len - hub_below) / 2, 0])
                linear_extrude(paddle_t, center = true)
                    squared_oval(paddle_w, paddle_len + hub_below, pocket_r - paddle_clear);
            // Finger lip near the free (+Y, top) end to flip it out.
            translate([0, paddle_len - 7, paddle_t / 2])
                linear_extrude(lip)
                    squared_oval(paddle_w * 0.6, 5, 2);
        }
        // Axle bore at the pivot (teardrop, apex +Z, self-supporting).
        rotate([0, 0, -90]) teardrop_hole(d = axle_d + 2 * axle_clear, length = paddle_w + 4);
    }
}

// Place the paddle at the pivot. deploy 0 = folded up (+Y), 90 = horizontal (+Z).
module paddle_placed(deploy) {
    translate([0, pivot_y, pivot_z]) rotate([deploy, 0, 0]) paddle_local();
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
} else if (part == "cutaway") {
    // Half-section through the middle so the pivot, the paddle base, and the
    // solid stopper ledge below it are visible.
    difference() {
        union() {
            frame();
            color("Coral") paddle_placed(preview_deploy);
        }
        translate([w / 2, 0, depth / 2]) cube([w, 2 * h, 2 * depth + 4], center = true);
    }
} else {
    frame();
    color("Coral") paddle_placed(preview_deploy);
    color("DimGray") translate([-w / 2 - head_h + 0.5, pivot_y, pivot_z])
        rotate([0, 90, 0]) headed_pin(axle_d, w - 0.5, knurl = true);
}
