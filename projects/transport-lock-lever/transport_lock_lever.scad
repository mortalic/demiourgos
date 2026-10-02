// Transport-lock lever — printable replacement for a stamped-steel U-channel lever.
// Side profile lives in XY (x: open/ear side -> web side, y: up the lever),
// channel width runs along Z. Print as modelled: one flange flat on the bed.

/* [Measured (hand sketch)] */
total_h  = 80;   // bottom edge to highest point
width    = 16;   // outside width of the channel
wall     = 2;    // flange + web thickness
tab_len  = 15;   // ear length, front edge to arm front edge
tab_h    = 30;   // ear height
pin_d    = 4;    // pivot pin diameter
pin_edge = 3;    // ear front edge to hole edge
pin_up   = 12;   // bottom edge to hole edge

/* [Estimated from photos] */
arm_depth = 9.5; // flange depth of the arm
lean      = 8.5; // arm lean toward the web side, deg from the ear edge
bend      = 32;  // grip lean toward the open side, deg from the ear edge
kink_h    = 55;  // height of the bend on the arm centreline
tip_r     = 3;   // grip tip corner radius

/* [Print / strength] */
pin_clear  = 0.3; // diametral clearance on the pin hole
solid_from = 34;  // arm is solid above this height (>= total_h keeps the full open channel)
step_r     = 1.5; // fillet in the ear/arm step corner
kink_r     = 8;   // fillet inside the bend
emboss     = true; // raised cartoon on the back face of the grip
relief     = 0.6;  // emboss height
template   = false; // true: 1.2 mm flat profile to hold against the original before the real print

$fn = 64;

u1 = [sin(lean), cos(lean)];
n1 = [cos(lean), -sin(lean)];
u2 = [-sin(bend), cos(bend)];
n2 = [cos(bend), sin(bend)];

F0  = [tab_len, tab_h];               // arm front edge at the step
C0  = F0 + n1 * arm_depth / 2;        // arm centreline at the step
s_k = (kink_h - C0.y) / cos(lean);
K   = C0 + u1 * s_k;                  // bend point
L2  = (total_h - tip_r - K.y - (arm_depth / 2 - tip_r) * sin(bend)) / cos(bend) + tip_r;
T   = K + u2 * L2;                    // grip tip centre
s_solid = (solid_from - tab_h) / cos(lean);

pin_c = [pin_edge + pin_d / 2, pin_up + pin_d / 2];

// region where (p - o) . n >= 0
module halfplane(o, n) {
    translate(o) rotate(atan2(n.y, n.x)) translate([0, -200]) square([400, 400]);
}

module arm_2d() {
    offset(r = -kink_r) offset(r = kink_r) {
        polygon([F0 - u1 * 60, F0 + u1 * s_k,
                 F0 + u1 * s_k + n1 * arm_depth, F0 - u1 * 60 + n1 * arm_depth]);
        translate(K) circle(d = arm_depth);
        hull() {
            translate(K) rotate(bend) translate([-arm_depth / 2, 0]) square([arm_depth, 1]);
            for (side = [-1, 1])
                translate(T - u2 * tip_r + n2 * side * (arm_depth / 2 - tip_r)) circle(r = tip_r);
        }
    }
}

module profile_2d() {
    intersection() {
        offset(r = -step_r) offset(r = step_r) {
            arm_2d();
            square([tab_len + 1, tab_h]);
        }
        halfplane([0, 0], [0, 1]);
    }
}

module channel_2d() {
    intersection() {
        offset(delta = 1) profile_2d();
        halfplane(F0 + n1 * (arm_depth - wall), -n1);  // keep the web
        halfplane(F0 + u1 * s_solid, -u1);             // keep the solid arm
    }
}

module lever() {
    difference() {
        linear_extrude(width) profile_2d();
        translate([0, 0, wall]) linear_extrude(width - 2 * wall) channel_2d();
        translate([pin_c.x, pin_c.y, -1]) cylinder(d = pin_d + pin_clear, h = width + 2);
    }
}

// cartoon, local 2D: x across the grip, y along it (toward the tip), 18 long
module cartoon_2d() {
    for (side = [-1, 1]) translate([side * 2.5, 2.8]) circle(r = 2.8);
    hull() {
        translate([0, 3]) circle(d = 4.4);
        translate([0, 13.5]) circle(d = 4.4);
    }
    translate([0, 15]) scale([1, 1.05]) circle(r = 2.9);
}

module grip_emboss() {
    o = K + n2 * (arm_depth / 2 - 0.5) + u2 * 6.5;
    multmatrix([[0, u2.x, n2.x, o.x],
                [0, u2.y, n2.y, o.y],
                [-1, 0,   0,    width / 2],
                [0, 0, 0, 1]])
        linear_extrude(relief + 0.5) cartoon_2d();
}

module template_plate() {
    linear_extrude(1.2) difference() {
        profile_2d();
        translate(pin_c) circle(d = pin_d + pin_clear);
    }
}

if (template) template_plate();
else {
    lever();
    if (emboss) grip_emboss();
}
