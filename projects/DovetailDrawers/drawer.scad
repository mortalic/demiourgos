/* ============================================================
   DRAWER FOR THE MODULAR BIN
   ------------------------------------------------------------
   Stand a modular bin on one of its groove faces (the faces with
   NO dovetail sticking out) so the open mouth points forward.
   This drawer slides into that mouth.

   Frame used here = the in-use orientation:
     X = width      Y = slide depth (front at +Y)     Z = up
   So this is also the print orientation: open side up, flat on
   the bed, no supports.

   The bin's interior backing-bosses become guides: the one that
   lands on the floor is a center ridge -> this drawer has a
   matching groove that rides it like a rail. The side one is
   simply cleared.

   MODE = 0  ->  drawer only (export this to print)
   MODE = 1  ->  exploded assembly with the carcass (preview)

   IMPORTANT: the values below must match the bin you printed.
   ============================================================ */

include <modular_bin.scad>     // pulls in unit_width, wall, dt_*, etc.
render_single = false;         // (after include) stop the bin from self-rendering here

/* ---------- [ FIT / CLEARANCE ] ----------
   slide_clear is the SIDE/TOP gap (drawer body vs cavity). Keep it >= ~1.0:
   the floor groove is the guide rail, so the sides should stay a touch loose
   or they fight the rail. Lower a hair to reduce rattle, not to zero. */
slide_clear  = 1.10;   // was 1.40 — pulled in a hair to cut rattle
back_gap     = 0.50;   // gap at the very back
faceplate_th = 2.6;    // front plate thickness
stop_lip     = 1.0;    // how far the face overlaps the opening rim (acts as a stop)

/* ---------- [ DRAWER BUILD ] ---------- */
draw_wall  = 1.8;
draw_floor = 8.5;      // floor thickness. Raised from 6.5 to give the rail groove
                       // room for 45° chamfered shoulders (shorter bridge) + a
                       // thicker cap. Lower it toward 6.5 for a faster/lighter
                       // floor at the cost of a longer, messier rail bridge.

/* ---------- [ FINGER PULL ] ----------
   An apex-UP V notch (point at the top, wide flat base at the bottom). The wide
   edge sits on solid faceplate below it, so there's no top bridge — only the
   45deg+ sides, which self-support. Keep pull_h >= pull_w/2 for >=45deg sides. */
pull_w    = 36;        // width across the wide (bottom) edge of the V
pull_h    = 20;        // V height (base up to the apex); taller = steeper sides
pull_r    = 3;         // corner rounding

$fn = 48;

/* ============================================================
   --- geometry ---
   ============================================================ */

// cavity (cavity-local frame): X=width, Y=depth, Z=height
cav_w = unit_width  - 2*wall;          // 76 by default
cav_h = unit_depth  - 2*wall;          // 76
cav_d = unit_height - floor_thickness; // 48.4

// how far a backing boss stands proud into the cavity, and how wide
boss_pro = (dt_depth + boss_back) - wall;
boss_w   = dt_neck + 2*dt_flare + 2*wall + 2*clearance;

floor_boss_cx = cav_w/2;   // floor ridge runs down the centre

// drawer body extents
bx0 = slide_clear;
bx1 = cav_w - boss_pro - 0.8;   // inset on +X to clear the side boss
bz0 = 0;                        // rests on the floor
bz1 = cav_h - slide_clear;      // top clearance
by0 = back_gap;
by1 = cav_d;                    // front plane (faceplate sits here)

body_w = bx1 - bx0;
body_h = bz1 - bz0;
body_d = by1 - by0;

module drawer_body(){
  translate([bx0, by0, bz0])
    difference(){
      cube([body_w, body_d, body_h]);
      // hollow: leaves floor + back + two sides; open top and open front
      translate([draw_wall, draw_wall, draw_floor])
        cube([body_w - 2*draw_wall, body_d - draw_wall + 1, body_h]);
    }
}

module faceplate(){
  fw = cav_w + 2*stop_lip;     // lip on both sides
  fh = cav_h + stop_lip;       // lip on top only; bottom edge sits flush with the floor
  translate([cav_w/2 - fw/2, by1 - 0.6, 0])   // bottom at z = 0 -> flat on the bed, no supports
    cube([fw, faceplate_th + 0.6, fh]);
}

// groove on the underside that receives the bin's floor boss (guide rail).
// Pentagon section: full width up past the rail top, then 45deg shoulders to a
// shorter top flat -> the unsupported bridge is only the top flat, not the full
// groove, and it prints with anchored sloped lead-ins. Side clearance stays
// generous (that face sags) so a little bridge droop never binds the rail.
floor_cap = 1.5;                       // solid cap left above the groove ceiling
module floor_groove(){
  gw    = boss_w + 4;                   // width at the rail (keep generous)
  gd    = draw_floor - floor_cap;       // ceiling height
  roof0 = boss_pro + 0.5;              // start the 45deg shoulders just above the rail top
  chamf = max(0.1, gd - roof0);        // shoulder run/rise (45deg)
  half  = gw / 2;
  pts = [[-half, -1], [half, -1],
         [half, roof0], [half - chamf, gd],
         [-(half - chamf), gd], [-half, roof0]];
  translate([floor_boss_cx, by1 + 1, 0])
    rotate([90, 0, 0])                  // profile X->width, Y->+Z height; extrude -> -Y length
      linear_extrude(height = by1 + 2)
        polygon(pts);
}

// finger pull through the upper part of the faceplate: an apex-UP V notch (point
// at the top, wide flat base at the bottom). The wide edge rests on solid
// faceplate, so nothing bridges except the self-supporting 45deg+ sides.
module finger_pull(){
  cz   = cav_h * 0.76;                                           // raised a bit
  half = pull_w / 2;
  pts = [[-half, -pull_h/2], [half, -pull_h/2], [0, pull_h/2]];  // apex up (^)
  translate([cav_w/2, by1 + faceplate_th + 1, cz])
    rotate([90, 0, 0])
      linear_extrude(height = faceplate_th + 3)
        offset(r = pull_r) offset(delta = -pull_r) polygon(pts);
}

module drawer(){
  difference(){
    union(){ drawer_body(); faceplate(); }
    floor_groove();
    finger_pull();
  }
}

// place the bin into the same (in-use) frame as the drawer
module carcass_in_use(){
  multmatrix([[-1,0,0, unit_width - wall],
              [ 0,0,1, -floor_thickness],
              [ 0,1,0, -wall],
              [ 0,0,0, 1]])
    bin();
}

/* ---------- [ MAKER'S MARK ] ---------- */
brand_text  = "imakethingsforu.com";
brand_size  = 5;     // cap height (mm)
brand_depth = 0.8;   // engrave depth
brand_z     = 10;    // height of the text, up from the bottom of the face

module brand_label(){
  translate([cav_w/2, by1 + faceplate_th + 0.01, brand_z])
    rotate([90, 0, 0])
      mirror([1, 0, 0])                          // reads correctly from the front
        linear_extrude(height = brand_depth + 0.01)
          text(brand_text, size = brand_size, halign = "center", valign = "center",
               font = "Liberation Sans:style=Bold");
}

module drawer_labeled(){
  difference(){ drawer(); brand_label(); }
}

MODE = 0;
if (MODE == 0){
  drawer_labeled();
} else {
  color("#6f8fb0") carcass_in_use();
  color("#d98a3d") translate([0, 38, 0]) drawer_labeled();   // pulled out the front
}
