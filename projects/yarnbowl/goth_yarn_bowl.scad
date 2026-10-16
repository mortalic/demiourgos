// Goth Yarn Bowl — "Nevermore edition" of yarn_bowl.scad.
// Same pot-bellied body, spiral yarn trap, and bayonet weighted base, but:
//   * back: large SKULL CAMEO — the halo around the face is recessed so the
//     skull stands proud (embossed without overhangs); the glaring eye sockets
//     and nasal cavity cut clean through, so the yarn colour glows through them
//   * front: the spiral trap keeps its curl; the dots become a crescent MOON
//     and diamond STARS (45-degree edges, print clean)
// Print the bowl rim-up in matte black. The cap from yarn_bowl.scad fits.
//
//   part = "bowl" | "cap" | "assembled" | "section"

/* [Which part] */
part = "bowl";        // [bowl, cap, assembled, section]

/* [Body profile] (radius mm at height z) */
H        = 100;
floor_z  = 8;
rim_lip  = 73.9;
belly_r  = 80;
neck_r   = 68.7;

/* [Yarn slot — coiled spiral trap] */
slot_azimuth = 0;
slot_mirror  = 0;
slot_cx      = -3;
slot_cz      = 56;
eye_r        = 4.0;
spiral_grow  = 0.00344;
spiral_sweep = 684;
spiral_phi0  = 90;
spiral_dir   = -1;
flame_w_max  = 6.5;
flame_w_min  = 4.5;

/* [Moon + stars] (u,v relative to motif center) */
moon_uv  = [34, 5];
moon_d   = 13;
moon_off = [3.2, 1.8];   // offset of the biting circle -> crescent
stars    = [ [26, -9, 3.6], [37, -5, 2.8], [31, 13, 2.4], [41, 10, 2.0] ];

/* [Skull cameo — back] */
skull_azimuth = 180;  // opposite the yarn slot
skull_cv      = 54;   // skull center height on the wall
engrave_d     = 1.5;  // cameo recess depth into the wall
halo_w        = 4;    // recessed halo band width around the skull

/* [Base] */
edge_chamfer = 1.0;

/* [Weighted base — bayonet bore] (identical to yarn_bowl.scad) */
weight_base = true;
bay_bore_d  = 16;
bay_clear   = 0.45;
bay_engage  = 6;
z_lip       = 2.0;
lug_t       = 2.0;
lug_arc     = 30;
entry_arc   = 38;
lock_travel = 70;
chan_extra  = 3.0;
n_lug       = 3;

/* [Weight cap] */
cap_foot_d  = 125;
cap_top_d   = 108;
cap_wall    = 3;
cap_floor   = 2.5;
cavity_h    = 5;
cavity_d    = 96;
lock_angle  = 60;

$fn = 140;

// ---- derived ----
post_d   = bay_bore_d - 2*bay_clear;
chan_rad = chan_extra + bay_clear;
lug_rad  = chan_extra - bay_clear;
z_seat   = cap_floor + cavity_h;

// ---- silhouettes (same as yarn_bowl.scad) ----
outer = [
  [0,0],[55-edge_chamfer,0],[55,edge_chamfer],[58,3],[65,9],[71,15],[76,21],
  [78.5,27],[79.9,33],[belly_r,39],[79.7,45],[78,51],[76,57],[73,63],[71,69],
  [69.4,75],[neck_r,81],[69.8,87],[72,93],[rim_lip,99],[rim_lip-1,H],[0,H]
];
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

// ---- spiral trap (unchanged) ----
function fR(a)   = eye_r*exp(spiral_grow*a);
function fang(a) = spiral_phi0 + spiral_dir*a;
function fP(a)   = [slot_cx + fR(a)*cos(fang(a)), slot_cz + fR(a)*sin(fang(a))];
function fw(a)   = flame_w_min + (flame_w_max-flame_w_min)*(a/spiral_sweep);

module flame_2d() {
  step = 6;
  for (a = [0 : step : spiral_sweep - step])
    hull() {
      translate(fP(a))      circle(d = fw(a),      $fn=20);
      translate(fP(a+step)) circle(d = fw(a+step), $fn=20);
    }
  hull() {
    translate(fP(spiral_sweep)) circle(d = fw(spiral_sweep), $fn=20);
    translate(fP(spiral_sweep) + [-2, 16]) circle(d = flame_w_max, $fn=20);
  }
}

// ---- moon + diamond stars ----
module moon_2d() {
  difference() {
    circle(d = moon_d, $fn=60);
    translate(moon_off) circle(d = moon_d, $fn=60);
  }
}
module star_2d(s) { rotate(45) square(s, center = true); }

module motif_2d() {
  mirror([slot_mirror,0,0]) flame_2d();
  translate([slot_cx + moon_uv[0], slot_cz + moon_uv[1]]) moon_2d();
  for (s = stars)
    translate([slot_cx + s[0], slot_cz + s[1]]) star_2d(s[2]);
}

module slot_cut() {
  rotate([0,0,slot_azimuth])
    translate([0, -40, 0])
      rotate([90,0,0])
        linear_extrude(height = 52)
          motif_2d();
}

// ---- skull cameo ----
// Cameo trick: instead of raising the skull (overhang ledges), recess the
// BACKGROUND halo around it so the face stands proud of the recessed band.
// Eyes + nasal cut clean through the wall; teeth are shallow engraving.

module skull_outline_2d() {
  hull() {
    translate([0, 8]) scale([1, 0.92]) circle(24, $fn=80);   // cranium
    for (sx = [-1, 1]) translate([sx*10, -16]) circle(8, $fn=40); // jaw
  }
}

// glaring socket: small inner corner, big outer sweep, slanted up-and-out
module eye_2d(sx) {
  hull() {
    translate([sx*5,    3.5]) circle(3.2, $fn=30);
    translate([sx*12.5, 6.5]) circle(5.8, $fn=40);
  }
}

module nasal_2d() {
  for (sx = [-1, 1]) translate([sx*1.6, -8.5]) circle(2.3, $fn=30);
  polygon([[-3.8, -8], [3.8, -8], [0, -0.5]]);   // pointed top: self-supporting
}

module teeth_2d() {
  translate([0, -14.5]) square([25, 1.8], center = true);      // gum line
  for (x = [-10, -5, 0, 5, 10])
    translate([x, -18.5]) square([1.7, 8], center = true);     // tooth gaps
}

// prism aimed through the wall at an azimuth (same technique as slot_cut)
module wall_prism(az) {
  rotate([0,0,az]) translate([0,-40,0]) rotate([90,0,0])
    linear_extrude(height = 52)
      translate([0, skull_cv])
        children();
}

// the outermost `d` mm of the body's outer surface, following the curve
module outer_skin(d) {
  difference() {
    rotate_extrude($fn=$fn) polygon(outer);
    rotate_extrude($fn=$fn) offset(r = -d) polygon(outer);
  }
}

module skull_cuts() {
  intersection() {                       // recessed halo -> embossed face
    wall_prism(skull_azimuth)
      difference() {
        offset(r = halo_w) skull_outline_2d();
        skull_outline_2d();
      }
    outer_skin(engrave_d);
  }
  intersection() {                       // engraved teeth
    wall_prism(skull_azimuth) teeth_2d();
    outer_skin(engrave_d);
  }
  wall_prism(skull_azimuth) {            // through-cuts: eyes + nasal
    eye_2d(-1);
    eye_2d(1);
    nasal_2d();
  }
}

// ---- bayonet FEMALE (unchanged) ----
module bay_female() {
  cylinder(d = bay_bore_d, h = bay_engage + 0.1);
  for (i = [0:n_lug-1])
    rotate([0,0, i*360/n_lug + entry_arc/2])
      translate([0,0,z_lip])
        rotate_extrude(angle = lock_travel)
          translate([bay_bore_d/2, 0]) square([chan_rad, bay_engage - z_lip + 0.1]);
  for (i = [0:n_lug-1])
    rotate([0,0, i*360/n_lug - entry_arc/2])
      rotate_extrude(angle = entry_arc)
        translate([bay_bore_d/2, 0]) square([chan_rad, bay_engage + 0.1]);
}

module bowl() {
  difference() {
    body();
    slot_cut();
    skull_cuts();
    if (weight_base) bay_female();
  }
}

// ---- weight cap (unchanged — the yarn_bowl.scad cap also fits) ----
module cap_local() {
  difference() {
    cylinder(d1 = cap_foot_d, d2 = cap_top_d, h = z_seat);
    translate([0,0,cap_floor]) cylinder(d = cavity_d, h = cavity_h + 0.1);
  }
  cylinder(d = post_d, h = z_seat + (bay_engage - bay_clear));
  for (i = [0:n_lug-1])
    rotate([0,0, i*360/n_lug])
      translate([0,0, z_seat + z_lip])
        rotate([0,0,-lug_arc/2])
          rotate_extrude(angle = lug_arc)
            translate([post_d/2 - 0.4, 0])
              square([bay_bore_d/2 + lug_rad - post_d/2 + 0.4, lug_t]);
}

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
