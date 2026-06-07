// bagclip_pinch — traced from smallest_bag_clip.stl. A flattened S-fold spring:
// two serrated prongs at the top pinch the bag, joined through a middle bar and a
// bottom U that act as the spring. Squeeze the prongs apart, insert the bag's
// folded top, release — the serrations bite and the fold holds it.
//
// Flat profile extruded along Z (bite depth). Prints flat, support-free; the fold
// flexes in-plane along the layers (low strain per fold -> survives in PLA).

/* [Size] */
clip_h  = 35;     // height (Y)
gap_x   = 4.3;    // prong centerline offset from middle (sets overall width)
rib     = 2.6;    // ribbon thickness
bite    = 10;     // Z depth (along the bag edge)
mid_top = 18;     // height where the middle bar joins across to the right prong

/* [Teeth] */
tooth_d   = 0.7;  // how far teeth bite inward
tooth_p   = 2.2;  // tooth pitch
tooth_lo  = 20;   // teeth start height
tooth_hi  = 33;   // teeth end height

$fn = 40;

// folded S centerline (left prong down, bottom U, middle bar up, bridge, right prong up)
pts = [
  [-gap_x, clip_h],   [-gap_x, 2.6],   [-gap_x+1.4, 1.0],
  [0, 1.4],           [0, mid_top],    [gap_x, mid_top],   [gap_x, clip_h],
];

module ribbon(p) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=rib); translate(p[i+1]) circle(d=rib); }
}

// sawtooth on a vertical inner face at x=fx, biting in direction `dir`
module teeth(fx, dir) {
  for (y = [tooth_lo : tooth_p : tooth_hi])
    polygon([[fx, y], [fx + dir*tooth_d, y + tooth_p/2], [fx, y + tooth_p]]);
}

module clip2d() {
  union() {
    ribbon(pts);
    teeth(-gap_x + rib/2, +1);   // left prong inner face
    teeth( gap_x - rib/2, -1);   // right prong inner face
  }
}

linear_extrude(bite) clip2d();
