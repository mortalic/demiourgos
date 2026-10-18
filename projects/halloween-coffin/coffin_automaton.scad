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
// Parts: box, lid, torso (skeleton: skull, ribcage, pelvis), arm (x2, free
// shoulder pivots), legs (drop-in false floor over the mechanism), conrod,
// crank web, handle, pins (3 mm axles: hip, fork, lid, 2 shoulder; and the 5 mm
// crank shaft). Every part prints support-free in the orientation `part=`
// exports it.

use <demiourgos_support.scad>

/* [Output] */
part = "assembly";   // assembly | cutaway | box | lid | torso | arm | legs | conrod | crank | handle | pins | plate
crank_angle = 184;   // crank position for the assembly view (184 = resting flat)
show_pins = true;    // draw the axle pins in the assembly

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
zc = 12.5;           // crankshaft height
r = 6.5;             // crank throw
c = 30;              // conrod length between centres
crank_x = -g;

/* [Skeleton] */
t = 7;               // torso slab thickness
Lt = 55;             // hip pivot -> top of the skull
hip_hw = 15;         // torso half-width (pelvis, ribcage, clavicle all +-15)
skull_r = 8.5;
shld_x = 38;         // shoulder pivot (arm pins) along the torso
arm_t = 5;           // arm thickness
arm_len = 32;        // shoulder pivot -> fingertips
arm_hand_h = 2.6;    // half-width of the hand (lowest point when hanging)
rib_slots = 4;       // see-through slots per side
engrave = true;      // face/sternum/pelvis engravings (debug switch)
cheeks = true;       // rocker cheeks (debug switch)
ledge_top = 23.5;    // false floor (legs plate) rests on wall ledges at this height
ledge_d = 2.5;       // ledge depth into the cavity
plate_t = 3;         // false-floor thickness
leg_relief = 2;      // bone relief height on the false floor

/* [Clearances] */
pin_d = 3;           // printed axle pins
pin_head_d = 6; pin_head_t = 1.5;
pin_slip = 3.5;      // hole where the pin must turn
pin_grip = 3.25;     // hole where the pin should stay put (printed holes come out small)
cheek_r = 4.25;      // rocker cheek radius around the fork pin
rod_r = 3.7;         // conrod half-width (constant; 1.95 mm wall around the small-end hole)
shaft_d = 5;  shaft_bore = 5.4;   // crank shaft: a separate printed D-pin with a head
shaft_flat = 0.8;    // depth of the D-flat
shaft_head_d = 8; shaft_head_t = 1.5;
stub_d = 3;   stub_bore = 3.4;
press_cl = 0.05;     // per side, handle and web on the D-shaft
side_play = 0.5;     // axial play per side for moving parts

/* [Crank side layout, along +Y] */
// order from the wall inward: pad | wall | bearing boss | 0.5 | WEB | stub+CONROD | fork cheeks
// Nothing but the crank-pin stub sits in the conrod's plane, so the rod can swing across the
// shaft axis at crank 180 without hitting anything.
yb = 13.5;           // inner face of the crank bearing boss
conrod_t = 3.5;
web_t = 3.5;         // thick enough for the press fit on the shaft
y_web = yb - side_play;        // web OUTER face; web occupies y_web-web_t .. y_web
stub_len = conrod_t + 0.7;     // stub points -Y from the web's inner face
y_rod = y_web - web_t - 0.3 - conrod_t / 2;   // conrod mid-plane
cheek_t = 3;
fork_gap = conrod_t + 2 * 0.3;
y_cheek_in = y_rod - fork_gap / 2;   // inner cheek outer face
y_cheek_out = y_rod + fork_gap / 2;  // outer cheek inner face
pad_y = 27.5;        // outer face of the crank pad on the box (handle must clear the flared wall)
hub_len = 6;
y_hub = pad_y + side_play;                     // handle hub inner face
shaft_len = y_hub + hub_len - (y_web - web_t); // head on the hub's outer face, tip flush with the web's inner face

$fn = 64;

// ---------- helpers ----------
module tilt(ang) rotate([0, -ang, 0]) children();          // +ang raises the +X end
function hw_at(x) = x < shoulder_x
    ? foot_hw + (sh_hw - foot_hw) * (x - foot_x) / (shoulder_x - foot_x)
    : sh_hw + (head_hw - sh_hw) * (x - shoulder_x) / (head_x - shoulder_x);

wall_ang = atan2(sh_hw - foot_hw, shoulder_x - foot_x);          // side-wall angle in the foot section
ledge_len = (-8.5 - foot_x) / cos(wall_ang) - 1;                   // ledges stop short of the hip bosses
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

knuckle_r = 4;
lid_ax = foot_x - 2.5;            // lid hinge axis
lid_az = H_in + knuckle_r;   // knuckle underside flush with the lid underside
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
            // ledges for the false floor, along both side walls of the foot section (45-degree underside)
            for (s = [-1, 1]) mirror([0, s < 0 ? 1 : 0, 0]) translate([foot_x + wall * sin(wall_ang), foot_hw - wall * cos(wall_ang), 0])
                rotate(wall_ang) rotate([90, 0, 90]) linear_extrude(ledge_len)
                    polygon([[0.5, ledge_top - 3 - ledge_d], [0.5, ledge_top], [-ledge_d, ledge_top], [-ledge_d, ledge_top - 3], [0, ledge_top - 3 - ledge_d]]);
            // lid hinge knuckles on the foot end
            for (s = [-1, 1]) hull() {
                translate([lid_ax, s * 9, lid_az]) knuckle(knuckle_r, 6);
                translate([foot_x - 2, s * 9 - 3, -floor_t]) cube([2.1, 6, H_in + floor_t]);   // rib down the outside of the foot end (no overhang)
            }
        }
        // crank bore (through boss, wall and pad)
        translate([crank_x, (yb + pad_y) / 2, zc]) ypin(shaft_bore, pad_y - yb + 4);
        // hip pin bore, straight through both sides; head countersunk in the -Y wall
        translate([0, 0, zh]) ypin(pin_grip, 2 * hw_at(0) + 4);
        translate([0, -hw_at(0) - 1, zh]) rotate([-90, 0, 0]) cylinder(d = pin_head_d + 0.4, h = pin_head_t + 1);
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
        for (s = [-1, 1]) translate([lid_ax - 10, s > 0 ? 5.5 : -9 - 3.5 - pin_head_t - 0.5, H_in - 1])
            cube([10 + knuckle_r + 0.5, 7 + (s > 0 ? 0 : pin_head_t + 0.5), lid_t + 8]);
        translate([lid_ax, 0, lid_az]) ypin(pin_slip, 14);
    }
}

// ---------- TORSO (own frame: hip pivot at origin, head toward +X, face +Z) ----------
// skeleton silhouette: pelvis, lumbar spine, ribcage (oval with see-through rib slots), clavicle bar, neck, skull + jaw
module ribcage_2d() translate([26, 0]) scale([11, hip_hw]) circle(r = 1);
module torso_profile() {
    difference() {
        union() {
            hull() {   // pelvis; extends 3.5 behind the pivot so the hip bore is enclosed and exits through flat side faces
                for (s = [-1, 1]) translate([-t / 2 + 1, s * (hip_hw - 1)]) circle(r = 1);
                polygon([[0, -hip_hw], [8, -hip_hw], [14, -7], [14, 7], [8, hip_hw], [0, hip_hw]]);
            }
            translate([13, -3.5]) square([5, 7]);                                               // lumbar spine
            ribcage_2d();
            hull() for (s = [-1, 1], e = [-1, 1]) translate([shld_x + e * 2.5, s * (hip_hw - 1)]) circle(r = 1);   // clavicle bar, 7 wide, flat ends for the shoulder bore
            translate([Lt - skull_r, 0]) circle(r = skull_r);                                    // skull, sits on the clavicle bar
        }
        // rib slots: from the sternum outward and toward the feet, kept 2.2 mm inside the ribcage edge
        intersection() {
            offset(delta = -2.2) ribcage_2d();
            for (s = [-1, 1], i = [0 : rib_slots - 1]) translate([33 - i * 4.3, s * 2.5]) rotate(s * 25)
                hull() { circle(r = 0.9); translate([0, s * 16]) circle(r = 0.9); }
        }
    }
}
// engraved details on the face (1 mm deep, crisp against the bed)
module skeleton_engrave_2d() {
    for (s = [-1, 1]) translate([Lt - skull_r + 2.5, s * 3.3]) circle(r = 2.4);                 // eye sockets
    polygon([[Lt - skull_r - 1, -1.2], [Lt - skull_r - 1, 1.2], [Lt - skull_r + 1.3, 0]]);       // nose
    translate([shld_x + 3.5, -5]) square([0.6, 10]);                                           // mouth line
    for (k = [-2 : 2]) translate([shld_x + 2.3, k * 2 - 0.3]) square([3, 0.6]);                   // teeth
    for (s = [-1, 1]) translate([5.5, s * 7.5]) circle(r = 2.2);                                 // pelvis openings
    translate([17, -0.5]) square([18, 1]);                                                     // sternum
}
module torso() {
    difference() {
        union() {
            linear_extrude(t, center = true) torso_profile();
            // rocker arm: two cheeks hanging behind the hip, offset arm_off toward the feet
            if (cheeks) for (y0 = [y_cheek_in - cheek_t, y_cheek_out]) translate([0, y0, 0]) hull() {
                rotate([-90, 0, 0]) cylinder(r = t / 2 - 0.1, h = cheek_t);                 // just inside the slab faces (no tangent sliver)
                translate([-a * sin(arm_off), 0, -a * cos(arm_off)]) rotate([-90, 0, 0]) cylinder(r = cheek_r, h = cheek_t);
            }
        }
        rotate([180, 0, 0]) ypin(pin_slip, 2 * hip_hw + 2);       // hip bore, apex toward the back (print up)
        translate([-a * sin(arm_off), y_rod, -a * cos(arm_off)]) rotate([180, 0, 0]) ypin(pin_grip, 2 * fork_gap + 2 * cheek_t);
        translate([shld_x, 0, 0]) rotate([180, 0, 0]) ypin(pin_grip, 2 * hip_hw + 2);   // shoulder bore (arm pins grip here)
        if (engrave) translate([0, 0, t / 2 - 1]) linear_extrude(2) skeleton_engrave_2d();
    }
}

// ---------- ARM (own frame: flat, pivot bore at the origin, hangs toward -X; print 2, flip one) ----------
module arm_profile() {
    circle(r = 4.5);                                                                  // shoulder
    hull() { circle(r = 1.8); translate([-14, 0]) circle(r = 1.8); }                  // humerus
    translate([-14, 0]) circle(r = 2.6);                                              // elbow
    hull() { translate([-14, 0]) circle(r = 1.6); translate([-24, 0]) circle(r = 1.6); }   // forearm
    hull() { translate([-24, 0]) circle(r = 2); for (s = [-1, 1]) translate([-28.5, s * 3.2]) circle(r = 1.4); }   // palm
    for (k = [-1 : 1]) hull() { translate([-28.5, k * 2.4]) circle(r = 0.8); translate([-arm_len + 0.8, k * 2.6]) circle(r = 0.8); }   // fingers
}
module arm() {
    difference() {
        linear_extrude(arm_t) arm_profile();
        translate([0, 0, -1]) cylinder(d = pin_slip, h = arm_t + 2);
        translate([0, 0, arm_t - pin_head_t - 0.1]) cylinder(d = pin_head_d + 0.4, h = pin_head_t + 1);   // pin head countersunk (outboard face)
    }
}
// a free arm hangs vertically; when the hand would go through the floor it rests on the floor instead
function arm_phi(tau) = let(zs = zh + shld_x * sin(tau), zf = zs - arm_hand_h,
    psi = zf >= arm_len ? 90 : asin(max(-1, min(1, zf / arm_len)))) psi - tau;   // angle behind the along-body line, torso frame

// ---------- LEGS: false floor over the mechanism at the foot end, leg bones in relief ----------
module legs() {
    linear_extrude(plate_t) intersection() { coffin_2d(-wall - 0.3); translate([-100, -50]) square([100 - 8.5, 100]); }
    translate([0, 0, plate_t - 0.01]) linear_extrude(leg_relief) for (s = [-1, 1]) {
        hull() { translate([-10, s * 7]) circle(r = 2.4); translate([-30, s * 10]) circle(r = 2); }        // femur
        translate([-30, s * 10]) circle(r = 3);                                                             // knee
        hull() { translate([-30, s * 10]) circle(r = 1.8); translate([-48, s * 9]) circle(r = 1.6); }      // tibia
        hull() { translate([-31, s * 13.2]) circle(r = 0.9); translate([-47, s * 11.8]) circle(r = 0.9); } // fibula
        hull() { translate([-48, s * 9]) circle(r = 2.2); for (k = [-1, 1]) translate([-54, s * 9 + k * 2.6]) circle(r = 1.2); }   // foot
        for (k = [-1 : 1]) hull() { translate([-54, s * 9 + k * 2.4]) circle(r = 0.7); translate([-55.8, s * 9 + k * 2.5]) circle(r = 0.7); }   // toes (inside the plate edge at -57.3)
    }
    hull() for (s = [-1, 1]) translate([-8.5 - 2.5, s * 8]) cylinder(r = 2.5, h = plate_t + leg_relief - 0.01);   // sacrum lump at the hip end
}

// ---------- CONROD ----------
module conrod() {
    difference() {
        hull() for (x = [0, c]) translate([x, 0, 0]) cylinder(r = rod_r, h = conrod_t, center = true);
        cylinder(d = stub_bore, h = 10, center = true);
        translate([c, 0, 0]) cylinder(d = pin_slip, h = 10, center = true);
    }
}

// D-profile (2D) for the shaft: circle with a flat on the +X side
module d_profile(d, flat, grow = 0) difference() { circle(d = d + 2 * grow); translate([d / 2 - flat + grow, -d]) square([d, 2 * d]); }

// ---------- CRANK WEB (own frame: shaft axis Y, web occupies y in [0, web_t], stub points -Y) ----------
module crank() {
    difference() {
        rotate([-90, 0, 0]) linear_extrude(web_t) hull() { circle(r = 5); translate([r, 0]) circle(r = 3); }   // 2.45 mm wall around the press-fit bore
        translate([0, -1, 0]) rotate([-90, 0, 0]) linear_extrude(web_t + 2) d_profile(shaft_d, shaft_flat, press_cl);   // press fit on the D-shaft
    }
    translate([r, 0, 0]) rotate([90, 0, 0]) cylinder(d = stub_d, h = stub_len);   // crank-pin stub, -Y
}

// ---------- SHAFT (own frame: head on the bed at z<=0, D-shaft up +Z, flat on +X) ----------
module shaft() {
    translate([0, 0, -shaft_head_t]) cylinder(d = shaft_head_d, h = shaft_head_t);
    linear_extrude(shaft_len - 0.6) d_profile(shaft_d, shaft_flat);
    translate([0, 0, shaft_len - 0.6]) linear_extrude(0.6, scale = 0.76) d_profile(shaft_d, shaft_flat);   // D-shaped tip chamfer
}

// ---------- HANDLE (own frame: hub axis Z, prints flat) ----------
module handle() {
    difference() {
        union() {
            cylinder(d = 12, h = hub_len);
            hull() { cylinder(d = 8, h = 4); translate([20, 0, 0]) cylinder(d = 8, h = 4); }
            translate([20, 0, 0]) cylinder(d = 7, h = 12);
        }
        translate([0, 0, -1]) linear_extrude(10) d_profile(shaft_d, shaft_flat, press_cl);   // press fit on the D-shaft
    }
}

// ---------- ASSEMBLY ----------
// positioned parts at crank angle `al` (also used by coffin_part.scad for fit checks)
module pos_lid(al) translate([lid_ax, 0, lid_az]) tilt(lid_angle(torso_angle(al))) translate([-lid_ax, 0, -lid_az]) lid();
module pos_torso(al) translate([0, 0, zh]) tilt(torso_angle(al)) torso();
module pos_arms(al) { tau = torso_angle(al); phi = arm_phi(tau);
    translate([0, 0, zh]) tilt(tau) for (s = [-1, 1])
        translate([shld_x, s * (hip_hw + side_play), 0]) tilt(phi) rotate([-s * 90, 0, 0]) arm(); }   // counterbore outboard
module pos_legs() translate([0, 0, ledge_top]) legs();
module pos_conrod(al) { cp = crank_pin(al); ap = arm_pin(al);
    translate([cp[0], y_rod, cp[1]]) tilt(atan2(ap[1] - cp[1], ap[0] - cp[0])) rotate([90, 0, 0]) conrod(); }
module pos_crank(al) translate([crank_x, y_web - web_t, zc]) tilt(al) crank();
module pos_shaft(al) translate([crank_x, y_hub + hub_len, zc]) tilt(al) rotate([90, 0, 0]) shaft();   // head on the hub's outer face
module pos_handle(al) translate([crank_x, y_hub, zc]) rotate([-90, 0, 0]) rotate([0, 0, -al]) handle();
// ---------- PINS (own frame: head on the bed at z<=0, shaft up +Z) ----------
hip_pin_len = 2 * hw_at(0) - pin_head_t;                 // head sits in the counterbore, tip flush
fork_pin_len = 2 * cheek_t + fork_gap;
lid_pin_len = 24;
module pin_rod(len) {
    translate([0, 0, -pin_head_t]) cylinder(d = pin_head_d, h = pin_head_t);
    cylinder(d = pin_d, h = len - 0.4);
    translate([0, 0, len - 0.4]) cylinder(d1 = pin_d, d2 = pin_d - 0.8, h = 0.4);   // tip chamfer
}
arm_pin_len = arm_t - pin_head_t + 0.3 + 8;              // head countersunk in the arm, 8 mm grip in the torso
module pins() {
    for (i = [0 : 2]) translate([i * 10, 0, 0]) pin_rod([hip_pin_len, fork_pin_len, lid_pin_len][i]);
    translate([32, 0, 0]) shaft();
    for (i = [0, 1]) translate([44 + i * 10, 0, 0]) pin_rod(arm_pin_len);
}
module pos_pins(al) { ap = arm_pin(al);
    translate([0, -hw_at(0) + pin_head_t, zh]) rotate([-90, 0, 0]) pin_rod(hip_pin_len);          // head on -Y, countersunk
    translate([ap[0], y_cheek_out + cheek_t, ap[1]]) rotate([90, 0, 0]) pin_rod(fork_pin_len);   // head on +Y, outside the outer cheek
    translate([lid_ax, -12, lid_az]) rotate([-90, 0, 0]) pin_rod(lid_pin_len);                    // head on -Y, outside the box knuckle
    translate([0, 0, zh]) tilt(torso_angle(al)) for (s = [-1, 1])                                 // shoulder pins, heads in the arm counterbores
        translate([shld_x, s * (hip_hw + side_play + arm_t - pin_head_t), 0]) rotate([s * 90, 0, 0]) pin_rod(arm_pin_len); }
module assembly(al = crank_angle) {
    color("DimGray") box();
    color("DimGray") pos_lid(al);
    color("Gainsboro") pos_torso(al);
    color("Gainsboro") pos_arms(al);
    color("DimGray") pos_legs();
    color("DarkRed") pos_conrod(al);
    color("DarkRed") pos_crank(al);
    color("DarkRed") pos_handle(al);
    color("Gold") pos_shaft(al);
    if (show_pins) color("Gold") pos_pins(al);
}

// ---------- OUTPUT ----------
if (part == "assembly") assembly();
else if (part == "cutaway") difference() { assembly(); translate([-200, -200, -50]) cube([400, 200 + 4, 200]); }
else if (part == "box") box();
else if (part == "lid") translate([0, 0, -H_in]) lid();
else if (part == "torso") translate([0, 0, t / 2]) rotate([180, 0, 0]) torso();      // face down, cheeks up
else if (part == "arm") arm();                                                        // print two
else if (part == "legs") legs();
else if (part == "conrod") translate([0, 0, conrod_t / 2]) conrod();
else if (part == "crank") translate([0, 0, web_t]) rotate([-90, 0, 0]) crank();      // web on the bed, stub up
else if (part == "handle") handle();
else if (part == "pins") translate([0, 0, pin_head_t]) pins();                        // 3 axles + the crank shaft
else if (part == "plate") {
    box();
    translate([0, 90, -H_in]) lid();
    translate([-40, -70, t / 2]) rotate([180, 0, 0]) torso();
    for (i = [0, 1]) translate([120, -40 + i * 12, 0]) arm();
    translate([130, 80, 0]) legs();
    translate([30, -60, conrod_t / 2]) conrod();
    translate([70, -60, web_t]) rotate([-90, 0, 0]) crank();
    translate([90, -40, 0]) handle();
    translate([-60, -100, pin_head_t]) pins();
}
