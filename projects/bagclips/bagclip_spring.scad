// bagclip_spring — a folded multi-leaf spring clip (copies the reference "fork"
// style). The bag's rolled top slides DOWN into the central channel; the nested
// thin leaves each flex a little, so it grips firmly yet survives in PLA because
// the strain is shared across many leaves (not one thick flexure).
//
// Flat part: the 2D profile is extruded along Z (the bite depth along the bag
// edge). Prints flat, support-free; the leaves flex in-plane (along the layers).

/* [Size] */
clip_h    = 52;    // height (Y)
clip_w    = 26;    // width  (X)
bite      = 12;    // Z depth (how much of the bag edge it grips)
corner    = 6;     // outer corner radius

/* [Spring] */
chan_w    = 3.2;   // central bag channel width (a touch under the folded bag)
chan_frac = 0.80;  // channel depth as a fraction of height
base      = 9;     // solid spring base at the bottom (the fold)
leaf_t    = 2.2;   // leaf (spring wall) thickness
relief_w  = 2.0;   // relief-slot width between leaves
relief_frac = 0.66;// relief-slot depth fraction
leaves    = 2;     // relief slots PER SIDE (more = softer, more nested look)

/* [Finger grip] */
serrated   = false; // scallop the outer edges for grip (the image-3 look)
serr_d     = 2.6;   // scallop diameter
serr_pitch = 4.2;   // scallop spacing

$fn = 48;

module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

// a rounded-bottom slot open at one end. top=true opens at the top (+Y),
// top=false opens at the bottom (-Y). Rounded closed end sits `depth` in.
module slot(x, w, depth, top) {
  yc = top ? clip_h/2 - depth : -clip_h/2 + depth;        // closed (rounded) end
  run = top ? depth + clip_h : -(depth + clip_h);
  translate([x, yc])
    union() {
      circle(d = w);
      translate([-w/2, min(0, run)]) square([w, abs(run)]);
    }
}

module clip2d() {
  d = clip_h * chan_frac;
  difference() {
    rrect(clip_w, clip_h, corner);
    slot(0, chan_w, d, true);                              // central bag mouth (opens top)
    // flanking slots alternate open-bottom / open-top -> one folded serpentine spring
    for (s = [-1, 1], k = [1 : leaves])
      slot(s * (chan_w/2 + k*(leaf_t + relief_w) - relief_w/2),
           relief_w, d, (k % 2) == 0);
    // optional scalloped finger grips down the outer edges
    if (serrated)
      for (s = [-1, 1], i = [0 : floor(clip_h / serr_pitch)])
        translate([s * clip_w/2, -clip_h/2 + corner + i*serr_pitch]) circle(d = serr_d);
  }
}

linear_extrude(bite) clip2d();
