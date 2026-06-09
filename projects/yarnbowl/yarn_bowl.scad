// Yarn Bowl — parametric recreation of projects/yarnbowl/yarn_bowl.stl, with an
// optional WEIGHTED screw-on base (bayonet twist-lock).
//
// A pot-bellied round bowl (~160 dia x 100 tall) with a spiral "flame" yarn slot
// that curls from a central eye out to a rim notch, plus three graduated dots.
// The base has a small central bayonet BORE; a separate CAP (a wider foot that
// holds stick-on wheel-weights) twists a quarter-turn to lock on — no glue.
// Both parts print flat, support-free.
//
//   part = "bowl"       the bowl (export this, base down)
//   part = "cap"        the weight cap (export this, foot down = print orientation)
//   part = "assembled"  bowl + cap locked together (preview)
//   part = "section"    assembled, cut in half to see the bayonet

/* [Which part] */
part = "bowl";        // [bowl, cap, assembled, section]

/* [Body profile] (radius mm at height z) */
H        = 100;   // total height
floor_z  = 8;     // interior floor height (also the base thickness; >= bay roof)
rim_lip  = 73.9;  // outer radius at the rim
belly_r  = 80;    // max outer radius (belly)
neck_r   = 68.7;  // min outer radius (waist below the rim)

/* [Yarn slot — coiled spiral trap] */
// A narrow spiral that enters at the rim and coils ~1.9 turns into a tight,
// upward-ending inner curl. The extra wrap + the narrow channel keep the working
// yarn from lifting out (a 1-turn swoosh lets it slip — crochet-expert feedback).
slot_azimuth = 0;     // rotate the motif around the bowl (deg); 0 = faces -Y
slot_mirror  = 0;     // 1 = mirror the spiral handedness
slot_cx      = -3;    // spiral center, arc offset
slot_cz      = 56;    // spiral center height
eye_r        = 4.0;   // inner radius (the trap)
spiral_grow  = 0.00344;// log-spiral growth per degree (outer turn reaches the rim)
spiral_sweep = 684;   // ~1.9 turns of wrap
spiral_phi0  = 90;    // start angle (inner terminus points up = the trap)
spiral_dir   = -1;    // -1 clockwise, +1 counter-clockwise
flame_w_max  = 6.5;   // channel width at the rim entry
flame_w_min  = 4.5;   // channel width at the inner curl (yarn-width, snug)
hook_up      = 6;     // upward hook at the inner terminus (the trap)

/* [Decorative dots] [u, v] relative to motif center, [d]iameter (right crook) */
dots = [ [33, 8, 6.0], [38, 0, 4.5], [32, -8, 3.4] ];

/* [Base] */
edge_chamfer = 1.0; // 45 deg chamfer at the bottom outer edge (eases first layer)

/* [Weighted base — bayonet bore] */
weight_base = true;  // cut the bayonet bore into the base
bay_bore_d  = 16;    // bore diameter (the cap's post fits this)
bay_clear   = 0.45;  // per-side clearance (post/bore + lugs/channel) — tune to printer
bay_engage  = 6;     // bore depth / post insertion (needs floor_z - bay_engage >= 2 roof)
z_lip       = 2.0;   // retaining-lip height (narrow bore 0..z_lip)
lug_t       = 2.0;   // lug axial thickness
lug_arc     = 30;    // lug angular width (deg)
entry_arc   = 38;    // insertion-slot width (deg)
lock_travel = 70;    // lock channel arc beyond the entry (deg)
chan_extra  = 3.0;   // lug radial protrusion past the bore wall
n_lug       = 3;

/* [Weight cap] */
cap_foot_d  = 125;   // wider foot at the table
cap_top_d   = 108;   // seats against the bowl base (matches base dia)
cap_wall    = 3;     // outer/seat wall
cap_floor   = 2.5;   // cap floor thickness
cavity_h    = 5;     // weight layer depth (~150 g of 1/4 oz stick-on segments)
cavity_d    = 96;    // weight tray diameter (leaves a 6 mm seat ring)
lock_angle  = 60;    // preview twist (insert at 0, locked here)

$fn = 140;

// ---- derived ----
post_d   = bay_bore_d - 2*bay_clear;
chan_rad = chan_extra + bay_clear;          // channel radial cut past the bore wall
lug_rad  = chan_extra - bay_clear;          // lug protrusion (fits channel w/ clearance)
z_seat   = cap_floor + cavity_h;            // cap local height to the seat plane

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

// ---- coiled spiral trap, authored in (u = arc, v = height) ----
function fR(a)   = eye_r*exp(spiral_grow*a);
function fang(a) = spiral_phi0 + spiral_dir*a;
function fP(a)   = [slot_cx + fR(a)*cos(fang(a)), slot_cz + fR(a)*sin(fang(a))];
// narrow channel: yarn-width at the inner curl, a touch wider at the rim entry
function fw(a)   = flame_w_min + (flame_w_max-flame_w_min)*(a/spiral_sweep);

// short upward hook past the inner terminus that curls over — the working yarn
// seats under it and can't lift out ("ends with an upward motion").
function hookP(t) = fP(0) + [ -hook_up*0.7*(1-cos(t*90))/1, hook_up*sin(t*90) ];

module flame_2d() {
  step = 6;
  for (a = [0 : step : spiral_sweep - step])
    hull() {
      translate(fP(a))      circle(d = fw(a),      $fn=20);
      translate(fP(a+step)) circle(d = fw(a+step), $fn=20);
    }
  // rim lead-in: extend the outer end up through the rim (the entry)
  hull() {
    translate(fP(spiral_sweep)) circle(d = fw(spiral_sweep), $fn=20);
    translate(fP(spiral_sweep) + [-2, 16]) circle(d = flame_w_max, $fn=20);
  }
  // inner upward hook (the trap)
  for (t = [0:0.2:0.8])
    hull() {
      translate(hookP(t))     circle(d = flame_w_min, $fn=20);
      translate(hookP(t+0.2)) circle(d = flame_w_min, $fn=20);
    }
}

module motif_2d() {
  mirror([slot_mirror,0,0]) flame_2d();
  for (d = dots)
    translate([slot_cx + d[0], slot_cz + d[1]]) circle(d = d[2], $fn=40);
}

module slot_cut() {
  rotate([0,0,slot_azimuth])
    translate([0, -40, 0])
      rotate([90,0,0])
        linear_extrude(height = 52)
          motif_2d();
}

// ---- bayonet FEMALE: cut into the base bottom (z0 up) ----
module bay_female() {
  cylinder(d = bay_bore_d, h = bay_engage + 0.1);                 // narrow bore
  for (i = [0:n_lug-1])                                           // upper lug channels
    rotate([0,0, i*360/n_lug + entry_arc/2])
      translate([0,0,z_lip])
        rotate_extrude(angle = lock_travel)
          translate([bay_bore_d/2, 0]) square([chan_rad, bay_engage - z_lip + 0.1]);
  for (i = [0:n_lug-1])                                           // full-depth entry slots
    rotate([0,0, i*360/n_lug - entry_arc/2])
      rotate_extrude(angle = entry_arc)
        translate([bay_bore_d/2, 0]) square([chan_rad, bay_engage + 0.1]);
}

module bowl() {
  difference() {
    body();
    slot_cut();
    if (weight_base) bay_female();
  }
}

// ---- weight cap (local frame: foot bottom on z=0 = print orientation) ----
module cap_local() {
  difference() {
    cylinder(d1 = cap_foot_d, d2 = cap_top_d, h = z_seat);   // flared foot shell
    translate([0,0,cap_floor]) cylinder(d = cavity_d, h = cavity_h + 0.1);  // weight tray
  }
  cylinder(d = post_d, h = z_seat + (bay_engage - bay_clear)); // central post (re-fills tray center, goes into bore)
  for (i = [0:n_lug-1])                                        // lugs near the post top
    rotate([0,0, i*360/n_lug])
      translate([0,0, z_seat + z_lip])
        rotate([0,0,-lug_arc/2])
          rotate_extrude(angle = lug_arc)
            translate([post_d/2 - 0.4, 0])
              square([bay_bore_d/2 + lug_rad - post_d/2 + 0.4, lug_t]);
}

// cap placed in the bowl's assembled frame (seat at z0), twisted to the lock angle
module cap_assembled() {
  rotate([0,0,lock_angle]) translate([0,0,-z_seat]) cap_local();
}

if (part == "cap") {
  cap_local();
} else if (part == "assembled") {
  bowl();
  color("Coral") cap_assembled();
} else if (part == "section") {
  difference() {
    union() { bowl(); color("Coral") cap_assembled(); }
    translate([belly_r, 0, H/2]) cube([2*belly_r, 4*belly_r, 2*H+30], center = true);
  }
} else {
  bowl();
}
