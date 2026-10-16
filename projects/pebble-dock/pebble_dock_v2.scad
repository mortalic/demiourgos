// Pebble Time 2 charging dock v2: weighted false-bottom drawer.
// Units mm. Frame = PRINT frame (original dock base-down, +Z up).
//
// In USE the dock stands on the back wall's outer face (print -X face), so the
// weight plate is added on -X. The body = plate() unioned (Python/manifold,
// build.py) with the original pebblechargingdock_v7 mesh, so the loop, facet,
// charger slot and watch-back recess are preserved exactly. Tray prints separately.
//
// Tray slides in along print +Z (open end at the top of the plate in print
// orientation = a side face in use). 6 weights: 2 along the slide axis x 3 across.

// ---- weights -------------------------------------------------------------
weight_a = 16;      // along the slide axis
weight_b = 19;      // across
weight_h = 4;       // thickness
w_clear  = 0.3;     // per-side drop-in clearance in the pockets

// ---- tray (local frame: X = slide axis, pull face at X=0; Y across; Z thickness)
tray_floor  = 1.6;
wall_outer  = 1.4;
wall_front  = 3.0;     // pull face wall, carries the fingernail groove
wall_inner  = 1.2;
pa = weight_a + 2*w_clear; pb = weight_b + 2*w_clear;
tray_x = 2*pa + wall_front + wall_outer + wall_inner;   // along slide axis
tray_y = 3*pb + 2*wall_outer + 2*wall_inner;            // across
tray_h = tray_floor + weight_h + 0.2;
slide_clear = 0.3;
detent_r = 0.6;

// ---- plate on the -X face --------------------------------------------------
orig_y = 67.78;                 // original wall spans y 0..67.78, z 0..40
skin   = 2.4;                   // material each side of the slot (X) and under it (Z)
plate_t  = tray_h + 2*slide_clear + 2*skin;      // X thickness of the plate
plate_y0 = -1;  plate_y1 = orig_y + 5;             // +Y end extended 4 mm for the front panel
slot_y   = tray_y + 2*slide_clear;
slot_y0  = (plate_y0 + plate_y1)/2 - slot_y/2;
slot_z0  = skin;
plate_z1 = slot_z0 + tray_x + slide_clear;       // slot is open at the top (print +Z)
plate_r  = 3;
overlap  = 0.5;                                  // bury the plate into the wall face
detent_x_local = tray_x - 6;                     // bumps near the inner end

// ---- front panel + personalization ----------------------------------------
// The front in use is the print +Y end (the watch screen faces +X+Y). The plate's
// end face continues upward (print +X) as a flat panel that carries the lettering.
panel_h   = 14;                 // how far the panel rises above the wall foot (print +X)
panel_y0  = 66;                 // panel starts here so it clears the band path (loop ends ~y 61)
personalization = "NAF";        // "" for none
text_size  = 12;
text_depth = 0.8;               // raised height (emboss) or cut depth (engrave)
text_style = "emboss";          // "emboss" | "engrave"
text_font  = "Liberation Sans:style=Bold";

module tray() {
    difference() {
        cube([tray_x, tray_y, tray_h]);
        for (i = [0:1], j = [0:2])
            translate([wall_front + i*(pa + wall_inner), wall_outer + j*(pb + wall_inner), tray_floor])
                cube([pa, pb, tray_h]);
        // fingernail groove across the pull face
        translate([0, -1, tray_h/2]) rotate([-90, 0, 0]) cylinder(r = 1.2, h = tray_y + 2, $fn = 24);
    }
    for (y = [0, tray_y])
        translate([detent_x_local, y, tray_h/2]) sphere(r = detent_r, $fn = 16);
}

// place the tray in the plate: local X -> print -Z (pull face up), Z -> print +X
module tray_in_plate(pull = 0) {
    translate([-plate_t + skin + slide_clear, slot_y0 + slide_clear, plate_z1 + pull])
        rotate([0, 90, 0]) tray();
}

module tray_slot() {
    sx = tray_h + 2*slide_clear;
    translate([-plate_t + skin, slot_y0, slot_z0]) cube([sx, slot_y, 100]);
    // detent dimples, exactly where the bumps land when the tray is home
    for (y = [slot_y0 + slide_clear, slot_y0 + slide_clear + tray_y])
        translate([-plate_t + skin + slide_clear + tray_h/2, y, plate_z1 - detent_x_local])
            sphere(r = detent_r + 0.15, $fn = 16);
}

module plate_profile() {   // 2D, drawn as (z, y): rounded top corners, flat print-bed edge at z = 0
    intersection() {
        offset(plate_r) offset(-plate_r) translate([-plate_r - 1, plate_y0]) square([plate_z1 + plate_r + 1, plate_y1 - plate_y0]);
        translate([0, plate_y0 - 1]) square([plate_z1 + 1, plate_y1 - plate_y0 + 2]);
    }
}

// lettering on the front face (y = plate_y1): text x -> print +Z, text y -> print +X
module lettering(h) {
    cx = (-plate_t + panel_h)/2;  cz = plate_z1/2;
    translate([cx, plate_y1, cz]) rotate([0, 0, -90]) rotate([0, -90, 0])
        linear_extrude(h) text(personalization, size = text_size, font = text_font, halign = "center", valign = "center");
}

module plate() {
    difference() {
        union() {
            // plate (x -plate_t..overlap) and panel (x 0..panel_h, y >= panel_y0) share one profile
            // rotate([0,-90,0]) maps 2D x -> Z, 2D y -> Y, extrude -> -X
            difference() {
                translate([panel_h, 0, 0]) rotate([0, -90, 0]) linear_extrude(plate_t + panel_h) plate_profile();
                translate([overlap, plate_y0 - 1, -1]) cube([panel_h + 1, panel_y0 - plate_y0 + 1, plate_z1 + 2]);
            }
            if (personalization != "" && text_style == "emboss") translate([0, -0.01, 0]) lettering(text_depth + 0.01);
        }
        tray_slot();
        if (personalization != "" && text_style == "engrave") translate([0, -text_depth, 0]) lettering(text_depth + 1);
    }
}

part = "both";   // "tray" | "plate" | "both"
if (part == "tray") tray();
else if (part == "plate") plate();
else { plate(); tray_in_plate(pull = 25); }
echo(personalization = personalization, tray_x = tray_x, tray_y = tray_y, tray_h = tray_h, plate_t = plate_t, plate_z1 = plate_z1, slot_y0 = slot_y0);
