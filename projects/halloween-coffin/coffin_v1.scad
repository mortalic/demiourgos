// coffin_automaton — "Dracula Rises" crank automaton candy coffin.
//
// HOW IT WORKS: a hand crank on the side of the coffin turns a CRANKSHAFT inside
// the foot end. A CONROD links the crank pin to a short ROCKER ARM that hangs
// below the vampire's hip pivot (crank-rocker four-bar). One turn of the crank
// swings the torso from lying flat to sitting up ~55 degrees; the rising head
// lifts the LID (hinged at the foot end), which falls closed again on the way
// down. Both directions are positively driven, only the lid relies on gravity.
//
// Frame: X along the coffin (+X = head end), Y across (+Y = crank side),
// Z up. Origin = hip pivot in XY, box floor top at z = 0.
//
// Parts: box, lid, torso, conrod, crank(shaft), handle. Pins are 1.75 mm
// filament (hip 60 mm, fork 12 mm, lid 26 mm). Every part prints support-free
// in the orientation `part=` exports it.

use <demiourgos_support.scad>

/* [Output] */
part = "assembly";   // assembly | cutaway | box | lid | torso | conrod | crank | handle | plate
crank_angle = 184;   // crank position for the assembly view (184 = resting flat)
show_pins = true;    // draw the filament pins in the assembly

/* [Coffin outline] */
foot_x = -60; shoulder_x = 24; head_x = 60;
foot_hw = 17; sh_hw = 32; head_hw = 20;   // half-widths
wall = 2.4; floor_t = 2.4;
H_in = 32;           // interior height (rim at z = H_in)
lid_t = 3;
lid_lip = 1;         // lid overhangs the box by this much

/* [Lid moon] */
moon_phase = "crescent";  // crescent | quarter (half disc)
moon_bite = 0.3;          // crescent: offset of the shadow disc as a fraction of moon_d (bigger = thinner horns)
moon_d = 28;
moon_h = 2;               // relief height
moon_x = 30;              // centre along the coffin
moon_rot = 90;            // rotation of the moon on the lid, degrees CCW seen from above (0 = lit half toward the head)

/* [Mechanism] */
zh = 25;             // hip pivot height above the floor
a = 14;              // rocker arm length (hip pivot -> conrod pin)
arm_off = 28;        // arm angle behind straight-down at rest (sets the bottom of the swing)
g = 30;              // crankshaft is this far toward the foot end from the hip
zc = 11;             // crankshaft height
r = 6.5;             // crank throw
c = 30;              // conrod length between centres
crank_x = -g;

/* [Torso] */
t = 7;               // torso slab thickness
Lt = 55;             // hip pivot -> top of head
hip_hw = 18;         // torso half-width at the hip
sh_tw = 22;          // half-width at the shoulders
head_r = 10;

/* [Clearances] */
pin_d = 1.75;        // filament pins
pin_slip = 2.2;      // hole where the pin must turn
pin_grip = 1.9;      // hole where the pin should stay put
shaft_d = 5;  shaft_bore = 5.4;
stub_d = 4;   stub_bore = 4.4;
press_cl = 0.05;     // per side, handle on the D-shaft
side_play = 0.5;     // axial play per side for moving parts

/* [Crank side layout, along +Y] */
yb = 13.5;           // inner face of the crank bearing boss
conrod_t = 3.5;
web_t = 2.5;
y_web = yb - 4.5;    // web outer face (web occupies y_web-web_t .. y_web)
stub_len = yb - y_web - 0.3;
y_rod = (y_web + yb) / 2;      // conrod mid-plane
cheek_t = 3;
fork_gap = conrod_t + 2 * 0.3;
y_cheek_in = y_rod - fork_gap / 2;   // inner cheek outer face
y_cheek_out = y_rod + fork_gap / 2;  // outer cheek inner face
pad_y = 27.5;        // outer face of the crank pad on the box (handle must clear the flared wall)
hub_len = 6;
shaft_len = pad_y + side_play + hub_len + 0.5 - y_web;

$fn = 64;

// ---------- helpers ----------
module tilt(ang) rotate([0, -ang, 0]) children();          // +ang raises the +X end
function hw_at(x) = x < shoulder_x
    ? foot_hw + (sh_hw - foot_hw) * (x - foot_x) / (shoulder_x - foot_x)
    : sh_hw + (head_hw - sh_hw) * (x - shoulder_x) / (head_x - shoulder_x);

module coffin_2d(o = 0)
    offset(delta = o)
        polygon([[foot_x, -foot_hw], [shoulder_x, -sh_hw], [head_x, -head_hw],
                 [head_x, head_hw], [shoulder_x, sh_hw], [foot_x, foot_hw]]);

module moon_2d() {
    // offset in/out trims the crescent's horns so no feature is thinner than ~2 extrusion widths
    offset(r = 0.45) offset(delta = -0.45) difference() {
        circle(d = moon_d);
        if (moon_phase == "quarter") translate([-moon_d, -moon_d]) square([moon_d, 2 * moon_d]);   // dark half toward the feet
        else translate([-moon_d * moon_bite, 0]) circle(d = moon_d * 0.95);                        // crescent
    }
}
// pin hole along Y, teardrop apex +Z (print-up), centred at the origin
module ypin(d, len) teardrop_hole(d = d, length = len);
// outer knuckle profile along Y: round on top, 45-degree roof underneath
module knuckle(rad, len) {
    translate([0, len / 2, 0]) rotate([90, 0, 0]) linear_extrude(len)
        hull() { circle(r = rad); translate([0, -rad / sin(45)]) circle(r = 0.05, $fn = 8); }
}

// ---------- kinematics ----------
function crank_pin(al) = [crank_x + r * cos(al), zc + r * sin(al)];
function arm_pin(al) = let(
    cp = crank_pin(al), dx = cp[0], dz = cp[1] - zh, d = norm([dx, dz]),
    A = (a * a - c * c + d * d) / (2 * d), h = sqrt(max(a * a - A * A, 0)),
    mx = A * dx / d, mz = A * dz / d,
    s1 = [mx + h * dz / d, zh + mz - h * dx / d],
    s2 = [mx - h * dz / d, zh + mz + h * dx / d]) (s1[1] < s2[1]) ? s1 : s2;
function rocker(al) = let(P = arm_pin(al)) atan2(P[0], zh - P[1]);   // 0 = straight down
function torso_angle(al) = rocker(al) + arm_off;

lid_ax = foot_x - 2.5;            // lid hinge axis
lid_az = H_in + 3;
knuckle_r = 3;
// lid opening angle: the highest torso corner rests on the lid underside
function corner(tau, x, z) = [x * cos(tau) - z * sin(tau), zh + x * sin(tau) + z * cos(tau)];
function lid_for(pt) = let(v = [pt[0] - lid_ax, pt[1] - lid_az], rho = norm(v))
    atan2(v[1], v[0]) + asin(knuckle_r / rho);
function lid_angle(tau) = max(0, lid_for(corner(tau, Lt, t / 2)), lid_for(corner(tau, Lt, -t / 2)));

// ---------- BOX ----------
module box() {
    difference() {
        union() {
            difference() {
                translate([0, 0, -floor_t]) linear_extrude(H_in + floor_t) coffin_2d(0);
                linear_extrude(H_in + 1) coffin_2d(-wall);
            }
            // crank bearing boss (inside) + pad (outside)
            translate([crank_x - 7, yb, 0]) cube([14, hw_at(crank_x) - yb, zc + 6]);
            translate([crank_x - 8, hw_at(crank_x) - 2, -floor_t]) cube([16, pad_y - hw_at(crank_x) + 2, zc + 8 + floor_t]);
            // hip bosses: locate the torso in Y and carry the hip pin
            for (s = [-1, 1]) translate([-5, s > 0 ? hip_hw + side_play : -hw_at(0), 0])
                cube([10, hw_at(0) - hip_hw - side_play, zh + 5]);
            // lid hinge knuckles on the foot end
            for (s = [-1, 1]) hull() {
                translate([lid_ax, s * 9, lid_az]) knuckle(knuckle_r, 6);
                translate([foot_x - 2, s * 9 - 3, -floor_t]) cube([2.1, 6, H_in + floor_t]);   // rib down the outside of the foot end (no overhang)
            }
        }
        // crank bore (through boss, wall and pad)
        translate([crank_x, (yb + pad_y) / 2, zc]) ypin(shaft_bore, pad_y - yb + 4);
        // hip pin bore, straight through both sides
        translate([0, 0, zh]) ypin(pin_grip, 2 * hw_at(0) + 4);
        // lid pin bore
        translate([lid_ax, 0, lid_az]) ypin(pin_grip, 40);
    }
}

// ---------- LID ----------
module lid() {
    difference() {
        union() {
            translate([0, 0, H_in]) linear_extrude(lid_t) coffin_2d(lid_lip);
            hull() {   // centre knuckle, flush with the lid underside
                translate([lid_ax, 0, lid_az]) rotate([90, 0, 0]) cylinder(r = knuckle_r, h = 11, center = true);
                translate([foot_x + 1, -5.5, H_in]) cube([4, 11, lid_t]);
            }
            // raised moon on top
            translate([moon_x, 0, H_in + lid_t - 0.01]) linear_extrude(moon_h) rotate(moon_rot) moon_2d();
        }
        // notches for the box knuckles
        for (s = [-1, 1]) translate([lid_ax - 10, s * 9 - 3.5, H_in - 1]) cube([10 + knuckle_r + 0.5, 7, lid_t + 8]);
        translate([lid_ax, 0, lid_az]) ypin(pin_slip, 14);
    }
}

// ---------- TORSO (own frame: hip pivot at origin, head toward +X, face +Z) ----------
module torso_profile() {
    polygon([[0, -hip_hw], [12, -hip_hw], [34, -sh_tw], [40, -sh_tw], [40, sh_tw], [34, sh_tw], [12, hip_hw], [0, hip_hw]]);
    translate([Lt - head_r, 0]) circle(r = head_r);
    // widow's peak + collar
    polygon([[40, -sh_tw], [40, sh_tw], [48, 11], [48, -11]]);
}
module torso() {
    difference() {
        union() {
            linear_extrude(t, center = true) torso_profile();
            // rocker arm: two cheeks hanging behind the hip, offset arm_off toward the feet
            for (y0 = [y_cheek_in - cheek_t, y_cheek_out]) translate([0, y0, 0]) hull() {
                rotate([-90, 0, 0]) cylinder(r = 3.5, h = cheek_t);
                translate([-a * sin(arm_off), 0, -a * cos(arm_off)]) rotate([-90, 0, 0]) cylinder(r = 3.5, h = cheek_t);
            }
        }
        rotate([180, 0, 0]) ypin(pin_slip, 2 * hip_hw + 2);       // hip bore, apex toward the back (print up)
        translate([-a * sin(arm_off), y_rod, -a * cos(arm_off)]) rotate([180, 0, 0]) ypin(pin_grip, 2 * fork_gap + 2 * cheek_t);
        // face, engraved 1 mm (prints crisp face-down)
        translate([0, 0, t / 2 - 1]) linear_extrude(2) {
            for (s = [-1, 1]) translate([49, s * 4]) rotate(s * 20) square([4, 1.6], center = true);
            translate([44, 0]) square([1.2, 8], center = true);
            for (s = [-1, 1]) translate([42.5, s * 2.2]) polygon([[0, -0.7], [0, 0.7], [-2.5, 0]]);
        }
    }
}

// ---------- CONROD ----------
module conrod() {
    difference() {
        hull() for (x = [0, c]) translate([x, 0, 0]) cylinder(r = 3.5, h = conrod_t, center = true);
        cylinder(d = stub_bore, h = 10, center = true);
        translate([c, 0, 0]) cylinder(d = pin_slip, h = 10, center = true);
    }
}

// ---------- CRANKSHAFT (own frame: axis along +Y from the web face at y=0) ----------
module crank() {
    // web
    translate([0, -web_t, 0]) rotate([-90, 0, 0]) linear_extrude(web_t) hull() { circle(r = 3); translate([r, 0]) circle(r = 3); }
    // shaft with a D-flat on the outer end
    difference() {
        rotate([-90, 0, 0]) cylinder(d = shaft_d, h = shaft_len);
        translate([-5, shaft_len - 7.5, shaft_d / 2 - 0.8]) cube([10, 10, 5]);
    }
    // crank pin stub
    translate([r, 0, 0]) rotate([-90, 0, 0]) cylinder(d = stub_d, h = stub_len);
}

// ---------- HANDLE (own frame: hub axis Z, prints flat) ----------
module handle() {
    difference() {
        union() {
            cylinder(d = 12, h = hub_len);
            hull() { cylinder(d = 8, h = 4); translate([20, 0, 0]) cylinder(d = 8, h = 4); }
            translate([20, 0, 0]) cylinder(d = 7, h = 12);
        }
        translate([0, 0, -1]) difference() {
            cylinder(d = shaft_d + 2 * press_cl, h = 10);
            translate([-5, shaft_d / 2 - 0.8 + press_cl, 0]) cube([10, 10, 20]);
        }
    }
}

// ---------- ASSEMBLY ----------
// positioned parts at crank angle `al` (also used by coffin_part.scad for fit checks)
module pos_lid(al) translate([lid_ax, 0, lid_az]) tilt(lid_angle(torso_angle(al))) translate([-lid_ax, 0, -lid_az]) lid();
module pos_torso(al) translate([0, 0, zh]) tilt(torso_angle(al)) torso();
module pos_conrod(al) { cp = crank_pin(al); ap = arm_pin(al);
    translate([cp[0], y_rod, cp[1]]) tilt(atan2(ap[1] - cp[1], ap[0] - cp[0])) rotate([90, 0, 0]) conrod(); }
module pos_crank(al) translate([crank_x, y_web, zc]) tilt(al) crank();
module pos_handle(al) translate([crank_x, pad_y + side_play, zc]) rotate([-90, 0, 0]) rotate([0, 0, -al]) handle();
module pin(len) rotate([90, 0, 0]) cylinder(d = pin_d, h = len, center = true);
module pos_pins(al) { ap = arm_pin(al);
    translate([0, 0, zh]) pin(2 * hw_at(0) + 2);
    translate([ap[0], y_rod, ap[1]]) pin(12);
    translate([lid_ax, 0, lid_az]) pin(26); }
module assembly(al = crank_angle) {
    color("DimGray") box();
    color("DimGray") pos_lid(al);
    color("Gainsboro") pos_torso(al);
    color("DarkRed") pos_conrod(al);
    color("DarkRed") pos_crank(al);
    color("DarkRed") pos_handle(al);
    if (show_pins) color("Gold") pos_pins(al);
}

// ---------- OUTPUT ----------
if (part == "assembly") assembly();
else if (part == "cutaway") difference() { assembly(); translate([-200, -200, -50]) cube([400, 200 + 4, 200]); }
else if (part == "box") box();
else if (part == "lid") translate([0, 0, -H_in]) lid();
else if (part == "torso") translate([0, 0, t / 2]) rotate([180, 0, 0]) torso();      // face down, arm up
else if (part == "conrod") translate([0, 0, conrod_t / 2]) conrod();
else if (part == "crank") translate([0, 0, web_t]) rotate([90, 0, 0]) crank();       // web on the bed
else if (part == "handle") handle();
else if (part == "plate") {
    box();
    translate([0, 90, -H_in]) lid();
    translate([-40, -70, t / 2]) rotate([180, 0, 0]) torso();
    translate([30, -60, conrod_t / 2]) conrod();
    translate([70, -60, web_t]) rotate([90, 0, 0]) crank();
    translate([90, -40, 0]) handle();
}
