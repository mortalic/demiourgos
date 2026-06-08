// Yarn Bowl — parametric recreation of projects/yarnbowl/yarn_bowl.stl.
// A pot-bellied round bowl (~160 dia x 100 tall) with a spiral "flame" yarn slot
// that curls from a central eye out to a rim notch, plus three graduated
// decorative dots in the crook. Prints flat on its base, support-free.

/* [Body profile] (radius mm at height z) */
H        = 100;   // total height
floor_z  = 6;     // interior floor height (floor thickness)
rim_lip  = 73.9;  // outer radius at the rim
belly_r  = 80;    // max outer radius (belly)
neck_r   = 68.7;  // min outer radius (waist below the rim)

/* [Yarn slot — spiral flame] */
slot_azimuth = 0;     // rotate the motif around the bowl (deg); 0 = faces -Y
slot_mirror  = 0;     // 1 = mirror the flame handedness (0 = lobe to upper-left)
slot_cx      = -3;    // motif center, arc offset
slot_cz      = 60;    // motif center height
eye_r        = 4.0;   // spiral eye (curl) radius
spiral_grow  = 0.0064;// log-spiral growth per degree (crest reaches the rim)
spiral_sweep = 360;   // one clean turn: eye -> crest at the rim
spiral_phi0  = 90;    // start angle of the eye (deg)
spiral_dir   = -1;    // -1 clockwise, +1 counter-clockwise
flame_w_max  = 20;    // width at the rounded crest (breaks the rim)
flame_w_min  = 2.2;   // width at the eye

/* [Decorative dots] [u, v] relative to motif center, [d]iameter (right crook) */
dots = [ [19, 8, 7.0], [27, 1, 5.0], [21, -8, 3.8] ];

/* [Base] */
// A recessed foot prints unsupported only if it can bridge; a ~90 mm flat ceiling
// can't, so the base is left flat (the recess is only ever seen from underneath).
edge_chamfer = 1.0; // 45 deg chamfer at the bottom outer edge (eases first layer)

$fn = 140;

// ---- outer silhouette (r, z), traced from the reference (flat base + chamfer) ----
outer = [
  [0,0],[55-edge_chamfer,0],[55,edge_chamfer],[58,3],[65,9],[71,15],[76,21],
  [78.5,27],[79.9,33],[belly_r,39],[79.7,45],[78,51],[76,57],[73,63],[71,69],
  [69.4,75],[neck_r,81],[69.8,87],[72,93],[rim_lip,99],[rim_lip-1,H],[0,H]
];

// ---- interior cavity silhouette (rounded bowl, open top) ----
inner = [
  [0,floor_z],[44,floor_z],[58,15],[65,21],[70,27],[73,33],[74.9,39],[73.8,45],
  [71.5,51],[70,57],[66.5,63],[64.5,69],[63.6,75],[63.5,81],[63.9,87],[65.5,93],
  [67.8,H],[0,H]
];

module body() {
  difference() {
    rotate_extrude($fn=$fn) polygon(outer);
    rotate_extrude($fn=$fn) polygon(inner);
  }
}

// ---- spiral flame, authored in (u = arc, v = height) ----
function fR(a)   = eye_r*exp(spiral_grow*a);
function fang(a) = spiral_phi0 + spiral_dir*a;
function fx(a)   = slot_cx + fR(a)*cos(fang(a));
function fy(a)   = slot_cz + fR(a)*sin(fang(a));
// width grows from a thin eye to the fat rounded crest at the rim (a wave/koru)
function fw(a)   = flame_w_min + (flame_w_max-flame_w_min)*pow(a/spiral_sweep, 0.85);

module flame_2d() {
  step = 5;
  for (a = [0 : step : spiral_sweep])
    hull() {
      translate([fx(a),      fy(a)])      circle(d = max(0.4,fw(a)),      $fn=20);
      translate([fx(a+step), fy(a+step)]) circle(d = max(0.4,fw(a+step)), $fn=20);
    }
}

module motif_2d() {
  // mirror only the flame; dots stay in the right-hand crook
  mirror([slot_mirror,0,0]) flame_2d();
  for (d = dots)
    translate([slot_cx + d[0], slot_cz + d[1]]) circle(d = d[2], $fn=40);
}

// Cut the motif radially through the wall at the slot azimuth (plate spans
// Y in [-92,-40], extruding outward through the -Y wall).
module slot_cut() {
  rotate([0,0,slot_azimuth])
    translate([0, -40, 0])
      rotate([90,0,0])
        linear_extrude(height = 52)
          motif_2d();
}

difference() {
  body();
  slot_cut();
}
