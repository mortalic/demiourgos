include <td_dims.scad>
$fn = 64;

fb_y0   = 200.05;  // fretboard tip (hull square is 0.1 thick, centered) flush
                   // with the tenon front face at y=200, so the upright print
                   // puts both on the bed (no supports)
heel_y0 = 232;     // heel front = body neck-end face
heel_y1 = 270;     // heel back (blends into shaft)
neck_d  = 16;

function fbw(y) = nut_w + (fb12_w + 2 - nut_w) * (nut_y - y) / (nut_y - fb_y0);

module fretboard() {
    hull() {
        translate([0, fb_y0, fb_bot]) linear_extrude(fb_th) square([fbw(fb_y0), 0.1], center=true);
        translate([0, nut_y,  fb_bot]) linear_extrude(fb_th) square([nut_w, 0.1], center=true);
    }
}
module frets() {
    for (n = [1:num_frets]) {
        y = fret_y(n);
        translate([0, y, fb_top]) linear_extrude(fret_h) square([fbw(y) - 2, fret_w], center=true);
    }
    // nut: raised block with one slot per string. Each slot floor crowns at
    // nut_y (shallow ramp toward the saddle, head_angle ramp toward the tuners)
    // so the string bears exactly on the scale-length point at nut_str_z.
    nut_h = nut_str_z + nut_wall - fb_top;   // peak height above the fretboard
    difference() {
        union() {
            translate([0, nut_y, fb_top])
                linear_extrude(nut_h) square([nut_w, 3], center=true);
            // 45-deg chamfer under the saddle-side face: printed upright that
            // face points straight down (90-deg overhang) — it drooped and
            // dragged strands across the slot mouths. Slots cut through it.
            // Rises the full nut_h so raising the peaks leaves no bare shelf.
            translate([0, nut_y, fb_top]) rotate([90, 0, 90]) translate([0, 0, -nut_w/2])
                linear_extrude(nut_w) polygon([[-1.5, 0], [-1.5 - nut_h, 0], [-1.5, nut_h]]);
        }
        // the two cuts tilt AWAY from each other above the crown pivot, so
        // each must extend past the pivot or an uncut wedge is left standing
        // across the slot (0.35 mm thick at the top — it printed, and blocked
        // the channels)
        for (i = [0 : n_strings-1])
            translate([(i - (n_strings-1)/2) * nut_str_spacing, nut_y, nut_str_z]) {
                rotate([3, 0, 0])           translate([-nut_slot_w/2, -5.5, 0]) cube([nut_slot_w, 7.5, 5]);
                rotate([-head_angle, 0, 0]) translate([-nut_slot_w/2, -2,   0]) cube([nut_slot_w, 5,   5]);
            }
    }
}
module shaft() {
    intersection() {
        hull() {
            translate([0, heel_y1, fb_bot]) scale([fbw(heel_y1)/2, 1, neck_d])   rotate([-90,0,0]) cylinder(h=0.01, r=1);
            translate([0, nut_y,   fb_bot]) scale([nut_w/2+1,     1, neck_d-2]) rotate([-90,0,0]) cylinder(h=0.01, r=1);
        }
        translate([-100, 0, fb_bot - 200]) cube([200, 1000, 200]);
    }
}
// rounded "Spanish" heel: smooth hull from the shaft down to a toe cap that
// flares off the tenon's end face at >=45 deg, so the upright print needs no
// supports under it. (The old spherical toe wrapped the body's curved end —
// its underside was a ~30 deg print-down dome that needed organic supports,
// and it interfered ~0.5 with the body at the mortise lip.) The slab is the
// tenon cross-section on the body-face plane y=232; the cap is narrowed and
// pushed back until the 45 deg tangents from the slab edges clear its equator
// (x: 241-232 = 9 rise vs 18-11 = 7 reach; chin: 47 deg to the shaft blend).
// The heel now butts the body only on that flat band at the y=232 apex line.
module heel() {
    hull() {
        translate([0, heel_y1, fb_bot - neck_d/2]) scale([fbw(heel_y1)/2, 5, neck_d/2]) sphere(r=1);
        translate([-tenon_w/2, heel_y0, body_depth/2 - tenon_d/2]) cube([tenon_w, 0.1, tenon_d]);
        translate([0, heel_y0 + 9, 30])            scale([18, 7, 12])                   sphere(r=1);
    }
    // tenon (precise box for the joint) protruding -Y into the body mortise
    translate([0, (201 + heel_y0)/2, body_depth/2])
        cube([tenon_w, heel_y0 - 201 + 2, tenon_d], center=true);
}
// Back-angled headstock (like the reference uke): the head plate pivots at the
// nut and tilts back by head_angle, so the strings break DOWN over the nut to
// the tuner posts. Tuner holes are drilled perpendicular to the angled face.
module headstock() {
    translate([0, nut_y, fb_top])          // pivot at the nut, on the fretboard plane
    rotate([-head_angle, 0, 0])            // tilt the head back/down
    difference() {
        // plate: top face on the pivot plane (local z=0), thickness downward,
        // starts 6mm before the nut so it welds into the fretboard.
        hull() {
            translate([0, -6,       -head_th]) linear_extrude(head_th) square([nut_w,  0.1], center=true);
            translate([0, head_len, -head_th]) linear_extrude(head_th) square([head_w, 0.1], center=true);
        }
        for (sx = [-1, 1], sy = [0, 1])
            translate([sx*(head_w*0.22 - sy*tuner_stagger), tuner_y0 + sy*tuner_pitch, -head_th - 1])
                cylinder(h = head_th + 2, d = tuner_d);
    }
}
// (the volute that blended the kink on the back of the head was removed: it
// sat exactly where the nut-side pair of tuner pegs mount and blocked them)
module neck() {
    union() { fretboard(); frets(); shaft(); heel(); headstock(); }
}

rotate([90, 0, 0]) neck();
