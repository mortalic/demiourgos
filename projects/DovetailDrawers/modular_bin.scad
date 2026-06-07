/* ============================================================
   MODULAR INTERLOCKING DRAWER BIN
   ------------------------------------------------------------
   One bin that links to identical copies of itself via dovetail
   connectors: a MALE rib on the +X (right) and +Y (back) faces,
   a FEMALE groove on the -X (left) and -Y (front) faces.

   Two copies join by sliding one DOWN into the other from the
   top. Once seated they cannot be pulled apart sideways, only
   lifted back out -- so they stay put in a drawer but you can
   still remove one when you want it.

   Print several, lay them in a grid, slide together. For a
   clean outer border, turn OFF the connectors that face the
   open edge (see toggles) and print a few "edge" / "corner"
   variants.

   Units: millimeters.  Render F6, export STL F7.
   ============================================================ */

/* ---------- [ MODULE SIZE ] ---------- */
unit_width  = 80;   // X  (left-to-right)
unit_depth  = 80;   // Y  (front-to-back)
unit_height = 50;   // Z

/* ---------- [ STRUCTURE ] ---------- */
wall            = 2.0;
floor_thickness = 1.6;
pocket_radius   = 2;   // inside corner rounding of the bin cavity

/* ---------- [ DOVETAIL CONNECTOR ] ---------- */
dt_neck   = 7;    // width at the narrow neck
dt_flare  = 2;    // extra half-width at the wide head (the locking bit)
dt_depth  = 4;    // how far the dovetail protrudes / grooves in
clearance = 0.20; // boss/rail sizing gap (leave this — your drawer rail is tuned to it)
slot_clearance = 0.55; // dovetail SLOT looseness per side. 0.45 printed too tight
                       // (joints wouldn't seat), 0.60 fit (a touch loose); trying
                       // 0.55. Raise if rails won't seat, lower if rattly.

/* ---------- [ WHICH CONNECTORS ARE PRESENT ] ----------
   A full interior tile has all four. For edge pieces, switch off
   the side(s) that face the open border so you get a clean wall. */
tab_right  = true;  // male  on +X  (right)
tab_back   = true;  // male  on +Y  (back)
slot_left  = true;  // female on -X  (left)
slot_front = true;  // female on -Y  (front)

/* ---------- [ WALL-MOUNT KEYHOLE ] ----------
   Cut a keyhole hanger into the closed floor (which becomes the BACK
   when the cabinet stands on end). Circle at the bottom to drop over
   the screw head, narrow slot above so you slide the bin DOWN to lock. */
mount_keyhole   = true;
screw_head_dia  = 8.0;    // big hole — clears the screw head
screw_shank_dia = 4.0;    // slot width — clears the shank, traps the head
keyhole_travel  = 8.0;    // slide-down distance

$fn = 48;

/* set false when this file is INCLUDED by an assembly preview */
render_single = true;

/* ============================================================
   --- geometry below ---
   ============================================================ */

boss_back = 1.6;  // material left behind a groove so it can't break through

module rrect2d(w, d, r){
  if (r <= 0) square([w, d]);
  else translate([r, r]) offset(r=r) square([w-2*r, d-2*r]);
}

// Dovetail cross-section: narrow neck at x=0, wide head at x=depth.
module dovetail_profile(neck, flare, depth, grow=0){
  pts = [[0,-neck/2],[depth,-(neck/2+flare)],[depth,(neck/2+flare)],[0,neck/2]];
  if (grow > 0) offset(delta=grow) polygon(pts);
  else polygon(pts);
}

module hollow_box(){
  difference(){
    cube([unit_width, unit_depth, unit_height]);
    translate([wall, wall, floor_thickness])
      linear_extrude(height = unit_height)   // cuts through the open top
        rrect2d(unit_width - 2*wall, unit_depth - 2*wall, pocket_radius);
  }
}

/* ---- male ribs ---- */
module male_x(){    // protrudes +X, centered on the depth
  translate([unit_width, unit_depth/2, 0])
    linear_extrude(height = unit_height)
      dovetail_profile(dt_neck, dt_flare, dt_depth);
}
module male_y(){    // protrudes +Y, centered on the width
  translate([unit_width/2, unit_depth, 0])
    rotate([0,0,90])
      linear_extrude(height = unit_height)
        dovetail_profile(dt_neck, dt_flare, dt_depth);
}

/* ---- female grooves (cut) ---- */
module female_x(){
  translate([0, unit_depth/2, -1])
    linear_extrude(height = unit_height + 2)
      dovetail_profile(dt_neck, dt_flare, dt_depth, grow=slot_clearance);
}
module female_y(){
  translate([unit_width/2, 0, -1])
    rotate([0,0,90])
      linear_extrude(height = unit_height + 2)
        dovetail_profile(dt_neck, dt_flare, dt_depth, grow=slot_clearance);
}

/* ---- backing bosses so grooves don't open into the bin ---- */
module boss_x(){
  bw = dt_neck + 2*dt_flare + 2*wall + 2*clearance;
  translate([0, unit_depth/2 - bw/2, 0])
    cube([dt_depth + boss_back, bw, unit_height]);
}
module boss_y(){
  bw = dt_neck + 2*dt_flare + 2*wall + 2*clearance;
  translate([unit_width/2 - bw/2, 0, 0])
    cube([bw, dt_depth + boss_back, unit_height]);
}

// keyhole hanger cut through the floor; sits centered, in the upper third
module keyhole_cut(){
  cx = unit_width/2;
  cy = unit_depth - 10 - keyhole_travel;   // screw rests ~10mm from the top edge
  translate([cx, cy, -1])
    linear_extrude(height = floor_thickness + 2){
      circle(d = screw_head_dia);                                          // drop-over hole
      translate([-screw_shank_dia/2, 0]) square([screw_shank_dia, keyhole_travel]); // slot up
      translate([0, keyhole_travel]) circle(d = screw_shank_dia);          // rounded slot top
    }
}

module bin(){
  difference(){
    union(){
      hollow_box();
      if (tab_right)  male_x();
      if (tab_back)   male_y();
      if (slot_left)  boss_x();
      if (slot_front) boss_y();
    }
    if (slot_left)  female_x();
    if (slot_front) female_y();
    if (mount_keyhole) keyhole_cut();
  }
}

if (render_single) bin();
