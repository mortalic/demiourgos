// little_skeleton — a small flat skeleton that lies in the coffin box.
//
// Print-in-place, one piece, no supports: shoulders and hips are captured
// vertical-axis hinges. The torso owns a fork (bottom plate, top plate and a
// pin between them); each limb owns a disc in the middle layer that turns on the
// pin. Gaps are 0.4 mm vertical and 0.4-0.5 mm radial: with 0.2 mm layers the
// limb disc and the top plate each print over two layers of air, the usual
// print-in-place trick. Break the joints free with a gentle twist.
//
// Frame: lying flat, X along the body (feet at x~2, skull top at x~93), Y across,
// Z up. Prints face up.

/* [Pose (print pose is the default)] */
arm_ang = 5;      // arms swung out from straight-down-the-body, degrees
leg_ang = 5;      // legs splayed out, degrees
part = "all";     // all | torso | arms | legs  (single groups, for fit checks)
sc = 1;           // size: scales the bones and layout; joint clearances, pins and thickness stay full size
                  // 0.88 fits the first crank coffin box between its bosses (feet 29 mm from the centre toward the foot end)

/* [Layers] */
T = 5.6;          // total thickness
plate = 1.4;      // fork plate thickness (bottom and top)
zgap = 0.4;       // vertical air gap each side of the limb disc
mid0 = plate + zgap;                // limb disc bottom
mid1 = T - plate - zgap;            // limb disc top

/* [Joints] */
pin_r = 1.5;
hole_r = 1.9;     // 0.4 radial running clearance
disc_r = 4;       // limb disc and fork plate radius
neck_r = 4.9;     // limb is full thickness beyond this radius from its pivot
void_r = 5.4;     // torso's middle layers are cleared within this radius

/* [Layout] */
shoulder = [69, 17] * sc;
hip = [30, 7] * sc;
skull_c = [83, 0]; skull_r = 10;

engrave_d = 0.6;
$fn = 48;

// ---------------- 2D shapes ----------------
module ribcage_2d() translate([57, 0]) scale([11, 13]) circle(r = 1);

module torso_body_2d() {
    scale(sc) torso_bones_2d();
    for (s = [-1, 1]) {                                                        // fork discs (full size)
        translate([shoulder.x, s * shoulder.y]) circle(r = disc_r);
        translate([hip.x, s * hip.y]) circle(r = disc_r);
    }
}
module torso_bones_2d() {
    polygon([[31.5, -9], [36, -11], [44, -9], [44, 9], [36, 11], [31.5, 9]]);   // pelvis (corners cut so the hip voids exit cleanly)
    translate([43.5, -2.5]) square([3, 5]);                                    // lumbar spine
    ribcage_2d();
    hull() for (s = [-1, 1]) translate([69, s * 17]) circle(r = 3.5);           // clavicle
    translate([71, -3]) square([5, 6]);                                        // neck
    translate(skull_c) circle(r = skull_r);                                    // skull
}
module torso_holes_2d() {
    for (s = [-1, 1]) translate(skull_c + [2, s * 3.6]) circle(r = 2.6);               // eye sockets
    translate(skull_c + [-2.2, 0]) polygon([[-1.4, -1.1], [-1.4, 1.1], [0.6, 0]]);     // nose (1 mm clear of eyes and teeth)
    intersection() {                                                                    // rib slots
        offset(delta = -2) ribcage_2d();
        for (s = [-1, 1], i = [0 : 3]) translate([64 - i * 4.3, s * 2]) rotate(s * 25)
            hull() { circle(r = 0.9); translate([0, s * 16]) circle(r = 0.9); }
    }
    for (s = [-1, 1]) translate([40, s * 5]) circle(r = 2);                            // pelvis openings
}
module torso_engrave_2d() {
    translate([47, -0.4]) square([18, 0.8]);                                           // sternum / spine
    translate(skull_c + [-6.5, -4.5]) square([0.6, 9]);                                 // jaw line
    for (k = [-2 : 2]) translate(skull_c + [-8, k * 1.8 - 0.3]) square([3, 0.6]);      // teeth
}

// limbs in their own frame: pivot at the origin, pointing down -X
module arm_2d() {
    hull() { circle(r = 2.1); translate([-13, 0]) circle(r = 1.6); }         // humerus
    translate([-13, 0]) circle(r = 2.3);                                      // elbow
    hull() { translate([-13, 0]) circle(r = 1.5); translate([-23, 0]) circle(r = 1.3); }   // forearm
    hull() { translate([-23, 0]) circle(r = 1.7); for (s = [-1, 1]) translate([-26, s * 2.3]) circle(r = 0.9); }   // palm
    for (k = [-1 : 1]) hull() { translate([-26, k * 2.3]) circle(r = 0.8); translate([-29.5, k * 2.5]) circle(r = 0.8); }   // fingers, rooted on the palm lobes
}
module leg_2d() {
    hull() { circle(r = 2.4); translate([-12, 0]) circle(r = 1.9); }         // femur
    translate([-12, 0]) circle(r = 2.6);                                      // knee
    hull() { translate([-12, 0]) circle(r = 1.8); translate([-23, 0]) circle(r = 1.6); }   // tibia
    hull() { translate([-23, 0]) circle(r = 2); for (s = [-1, 1]) translate([-27, s * 2.6]) circle(r = 0.9); }   // foot
    for (k = [-1 : 1]) hull() { translate([-27, k * 2.6]) circle(r = 0.9); translate([-28.8, k * 2.8]) circle(r = 0.9); }   // toes, rooted on the foot lobes
}

// ---------------- 3D ----------------
module limb(which) {
    // full-thickness bone beyond neck_r
    linear_extrude(T) difference() { scale(sc) if (which == "arm") arm_2d(); else leg_2d(); circle(r = neck_r); }
    // middle-layer disc + neck, turning on the torso's pin
    translate([0, 0, mid0]) linear_extrude(mid1 - mid0) difference() {
        union() {
            circle(r = disc_r);
            intersection() { scale(sc) if (which == "arm") arm_2d(); else leg_2d(); circle(r = neck_r + 1); }   // overlaps the full-thickness bone by 1 mm
        }
        circle(r = hole_r);
    }
}

module torso() {
    difference() {
        linear_extrude(T) torso_body_2d();
        // clear the middle layers (and their gaps) around every pivot
        for (s = [-1, 1], p = [shoulder, hip]) translate([p.x, s * p.y, plate]) cylinder(r = void_r, h = T - 2 * plate);
        translate([0, 0, -1]) linear_extrude(T + 2) scale(sc) torso_holes_2d();
        translate([0, 0, T - engrave_d]) linear_extrude(1) scale(sc) torso_engrave_2d();
    }
    for (s = [-1, 1], p = [shoulder, hip]) translate([p.x, s * p.y, 0]) cylinder(r = pin_r, h = T);   // pins
}

module arms_at(a) for (s = [-1, 1]) translate([shoulder.x, s * shoulder.y, 0]) rotate(-s * a) limb("arm");
module legs_at(a) for (s = [-1, 1]) translate([hip.x, s * hip.y, 0]) rotate(-s * a) limb("leg");
module arms() arms_at(arm_ang);
module legs() legs_at(leg_ang);

if (part == "all") { torso(); arms(); legs(); }
else if (part == "torso") torso();
else if (part == "arms") arms();
else if (part == "legs") legs();
