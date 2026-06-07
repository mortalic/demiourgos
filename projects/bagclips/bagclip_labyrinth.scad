// bagclip_labyrinth — thread the bag's folded top down through a comb of
// alternating teeth; the forced weave grips by friction. RIGID (no flex), so
// it's durable in PLA. Prints flat, support-free (profile extruded along Z).

clip_w    = 12;    // width along the bag edge (Z)
body_x    = 26;    // overall X
body_h    = 40;    // overall Y (height)
corner    = 3;     // outer corner radius
wall      = 3;     // solid wall around the channel
channel_w = 10;    // straight channel width
overlap   = 2.2;   // how far each tooth reaches PAST center (forces the weave)
tooth_h   = 3.0;   // tooth thickness (Y)
tooth_r   = 1.2;   // tooth tip rounding
n_teeth   = 5;     // number of alternating teeth

$fn = 32;

module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

module tooth(y, from_left) {
  // a rounded bar reaching from one channel wall to `overlap` past center
  x0 = from_left ? -channel_w/2 - 0.1 : -overlap;
  x1 = from_left ?  overlap          :  channel_w/2 + 0.1;
  translate([(x0+x1)/2, y])
    rrect(x1 - x0, tooth_h, tooth_r);
}

module clip2d() {
  union() {
    difference() {
      rrect(body_x, body_h, corner);
      // open-top channel (extends past the top edge so the bag can enter)
      translate([0, wall/2])
        rrect(channel_w, body_h - wall + 2, corner - 1);
    }
    // alternating teeth poke into the channel
    for (i = [0 : n_teeth-1])
      tooth(-body_h/2 + wall + (i+1) * (body_h - 2*wall) / (n_teeth+1),
            (i % 2) == 0);
  }
}

linear_extrude(clip_w) clip2d();
