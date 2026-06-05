// Folding Wall Hook — parametric, three-part snap-fit recreation of the concept
// by VC Design (https://www.printables.com/model/1616074-folding-wall-hook).
// Independent clean-room reimplementation of the mechanism (no original
// geometry copied).
//
// Three parts, no fasteners for the joints:
//   BASE  — wall plate (countersunk M4 holes) + a vertical post with a snap head.
//   BODY  — a collet collar that snaps onto the post and ROTATES about it
//           (vertical axis), carrying a clevis for the hook.
//   HOOK  — an arm whose trunnion pins snap into the body's clevis and TILT
//           (horizontal axis): folds flat up, swings down to a load-bearing stop.
//
// Frame: wall is the X-Z plane at Y = 0; +Y points into the room, +Z is up.

/* [Which part] */
part = "assembled";    // [assembled, base, body, hook]
/* [Preview only] */
preview_deploy = 90;   // [0:5:120]  hook tilt: 0 folded up, 90 deployed
preview_swing = 25;    // [-90:5:90] body swivel about the post

/* [Base plate] */
plate_w = 40;
plate_h = 72;
plate_t = 5;
corner_r = 4;

/* [Mounting screws] */
screw_d = 4.3;
screw_head_d = 8.4;
screw_inset = 12;

/* [Swivel post] */
post_d = 9;           // shaft diameter
post_y = 16;          // post axis distance from the wall
post_base_z = 16;     // bottom of the post
gusset_h = 14;        // bracket height tying the post to the plate (collar rests on it)
head_extra = 1.6;     // head radius beyond the shaft (snap retention)
head_h = 3;
shaft_clear = 0.4;    // collar-lip bore clearance (rotational slip fit)
chamber_clear = 0.6;  // head-chamber clearance
lip_h = 3;            // retaining-lip height at the collar bottom
collar_h = 18;        // collar height
collar_wall = 2.6;

/* [Hook hinge in the body] */
arm_w = 16;           // hook arm width
joint_clear = 0.3;    // per-side gap between arm and ears
ear_w = 6;            // ear thickness (X)
pin_d = 5;
pin_len = 4;
pin_clear = 0.25;     // per-side pin/socket clearance (slip)
pivot_fwd = 15;       // pivot axis forward of the post axis (+Y, body frame)
pivot_up = 1;         // pivot height above collar mid (Z, body frame)

/* [Hook arm] */
arm_len = 34;
arm_t = 7;
tip_h = 15;

$fn = 64;

// ---- derived ----
ear_gap = arm_w + 2 * joint_clear;
boss_d = pin_d + 7;
socket_d = pin_d + 2 * pin_clear;
head_d = post_d + 2 * head_extra;
lip_bore = post_d + shaft_clear;            // narrow retaining lip rides on the shaft
chamber_bore = head_d + chamber_clear;      // wide chamber captures the head
collar_od = chamber_bore + 2 * collar_wall;
collar_base_z = post_base_z + gusset_h;     // collar rests on the gusset top
head_z = collar_base_z + lip_h + 1;         // head sits just above the lip
shaft_top_z = head_z;                       // shaft runs up to the head

// ===========================================================================
// BASE: plate + screws + post
// ===========================================================================
module rounded_plate() {
    hull() for (x = [corner_r - plate_w / 2, plate_w / 2 - corner_r])
        for (z = [corner_r, plate_h - corner_r])
            translate([x, 0, z]) rotate([-90, 0, 0]) cylinder(r = corner_r, h = plate_t);
}

module screw_cut(z) {
    translate([0, -1, z]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = plate_t + 2);
    cs = (screw_head_d - screw_d) / 2;
    translate([0, plate_t - cs + 0.01, z]) rotate([-90, 0, 0])
        cylinder(d1 = screw_d, d2 = screw_head_d, h = cs + 0.5);
}

module post() {
    translate([0, post_y, 0]) {
        // Vertical shaft up to the head.
        translate([0, 0, post_base_z]) cylinder(d = post_d, h = shaft_top_z - post_base_z);
        // Snap head: a chamfered disc the collar lip clicks over. The lower
        // chamfer is a lead-in; the upper chamfer avoids a degenerate apex.
        translate([0, 0, head_z]) {
            translate([0, 0, -1]) cylinder(d1 = post_d, d2 = head_d, h = 1); // lead-in
            cylinder(d = head_d, h = head_h);
            translate([0, 0, head_h]) cylinder(d1 = head_d, d2 = post_d * 0.6, h = 1.2);
        }
    }
    // Gusset tying the post base to the plate (a filled wedge for strength).
    hull() {
        translate([-post_d / 2, plate_t - 0.1, post_base_z]) cube([post_d, 0.1, gusset_h]);
        translate([0, post_y, post_base_z]) cylinder(d = post_d, h = gusset_h);
    }
}

module base() {
    difference() {
        union() {
            rounded_plate();
            post();
        }
        screw_cut(screw_inset);
        screw_cut(plate_h - screw_inset);
    }
}

// ===========================================================================
// BODY: rotating collar + clevis
// ===========================================================================
// Modeled in a local frame with the post axis on Z at the origin and the collar
// running z = 0 .. collar_h. The clevis projects +Y. Placed onto the post by the
// assembly.
module clevis_ear(side) {
    inner_x = side * (ear_gap / 2);
    lo = min(inner_x, inner_x + side * ear_w);
    pz = collar_h / 2 + pivot_up;
    difference() {
        hull() {
            // Root embedded into the collar wall for a solid join.
            translate([lo, collar_od / 2 - 3, pz - 9]) cube([ear_w, 3.5, 18]);
            translate([lo, pivot_fwd, pz]) rotate([0, 90, 0]) cylinder(d = boss_d, h = ear_w);
        }
        translate([inner_x - side * 0.01, pivot_fwd, pz]) rotate([0, side * 90, 0])
            cylinder(d = socket_d, h = pin_len + 0.6);
    }
}

module body_local() {
    difference() {
        union() {
            // Collar tube.
            cylinder(d = collar_od, h = collar_h);
            // Clevis ears on the +Y face.
            clevis_ear(1);
            clevis_ear(-1);
        }
        // Head chamber (wide) above the lip — the head rotates freely here.
        translate([0, 0, lip_h]) cylinder(d = chamber_bore, h = collar_h);
        // Retaining lip (narrow) at the bottom, riding on the shaft.
        translate([0, 0, -0.5]) cylinder(d = lip_bore, h = lip_h + 0.5);
        // Lead-in chamfer at the bottom mouth so the lip starts onto the head.
        translate([0, 0, -0.01]) cylinder(d1 = lip_bore + 1.4, d2 = lip_bore, h = 1.4);
        // Collet slots through the lip so it can flex over the snap head.
        for (a = [0:120:359])
            rotate([0, 0, a]) translate([-0.9, 0, -0.5]) cube([1.8, collar_od, lip_h + 4]);
    }
}

// ===========================================================================
// HOOK ARM (tilts in the body clevis)
// ===========================================================================
// Distance the heel reaches back from the pivot to butt the collar front.
heel_back = pivot_fwd - collar_od / 2 - 0.2;

module arm_bar(d) {
    rotate([0, 90, 0]) cylinder(d = d, h = arm_w, center = true);
}

module hook_local() {
    union() {
        arm_bar(boss_d - 1); // pivot hub
        // Main arm out to the end.
        hull() {
            arm_bar(arm_t);
            translate([0, arm_len, 0]) arm_bar(arm_t);
        }
        // Up-turned retaining tip at the very end, curling slightly back.
        hull() {
            translate([0, arm_len, 0]) arm_bar(arm_t);
            translate([0, arm_len - 2, tip_h]) arm_bar(arm_t);
        }
        // Heel: a shoulder that butts the collar front to stop at horizontal
        // under downward load (the arm still folds freely upward).
        hull() {
            arm_bar(arm_t);
            translate([0, -heel_back, -arm_t / 2 + 0.5]) arm_bar(arm_t * 0.8);
        }
        // Trunnion pins with a snap lead-in chamfer.
        for (s = [-1, 1])
            translate([s * arm_w / 2, 0, 0]) rotate([0, s * 90, 0]) union() {
                cylinder(d = pin_d, h = pin_len);
                translate([0, 0, pin_len - 0.8]) cylinder(d1 = pin_d, d2 = pin_d - 1.4, h = 0.8);
            }
    }
}

// ===========================================================================
// ASSEMBLY / PART SELECT
// ===========================================================================
module body_placed(swing) {
    translate([0, post_y, collar_base_z]) rotate([0, 0, swing]) children();
}

// In the body local frame, the pivot is at (0, pivot_fwd, collar_h/2 + pivot_up).
module hook_in_body(deploy) {
    translate([0, pivot_fwd, collar_h / 2 + pivot_up]) rotate([90 - deploy, 0, 0]) hook_local();
}

if (part == "base") {
    rotate([90, 0, 0]) base();          // print plate-down, post up
} else if (part == "body") {
    body_local();                        // print collar-axis vertical
} else if (part == "hook") {
    rotate([-90, 0, 0]) hook_local();    // print flat on its back
} else {
    base();
    body_placed(preview_swing) {
        color("SteelBlue") body_local();
        color("Orange") hook_in_body(preview_deploy);
    }
}
