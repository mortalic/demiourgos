// bagclip_serpentine — copied from Food_Clip_4.stl. Serrated jaws (right) held
// closed by a zig-zag "W" leaf spring (left). The jaw slot runs straight through
// into the open zig-zag, so squeezing the spring cantilevers the jaws open; the
// bag's folded top sits in the serrated jaws. Flat profile extruded along Z;
// prints flat, support-free.

/* [Size] */
jaw_tip   = 25;    // x of the jaw tips (right)
jaw_x     = 0;     // x where the jaws end and the spring begins
arm_t     = 2.8;   // arm thickness
bite      = 10;    // Z depth
jg        = 1.7;   // jaw half-gap (small -> grips)
amp       = 13;    // zig-zag amplitude
zz_l      = -22;   // left vertices of the zig-zag
zz_r      = -4;    // inner (right) vertices of the zig-zag

/* [Teeth] */
tooth_d = 0.35;
tooth_p = 1.8;

$fn = 40;

module ribbon(p, t) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=t); translate(p[i+1]) circle(d=t); }
}

// top jaw (right) -> sigma zig-zag spring (left) -> bottom jaw (right)
centerline = [
  [jaw_tip, jg], [jaw_x, jg],                 // top jaw
  [zz_l, amp], [zz_r, amp*0.4],               // zig-zag: top-left vertex, in
  [zz_l, 0],                                  //          mid-left vertex
  [zz_r, -amp*0.4], [zz_l, -amp],             //          in, bottom-left vertex
  [jaw_x, -jg], [jaw_tip, -jg],               // bottom jaw
];

module teeth(fy, dir) {
  for (x = [jaw_x + 2 : tooth_p : jaw_tip - 2])
    polygon([[x, fy - dir*0.5], [x + tooth_p/2, fy + dir*tooth_d], [x + tooth_p, fy - dir*0.5]]);
}

module clip2d() {
  union() {
    ribbon(centerline, arm_t);
    teeth( jg - arm_t/2, -1);   // top jaw inner (bottom) face
    teeth(-jg + arm_t/2, +1);   // bottom jaw inner (top) face
  }
}

linear_extrude(bite) clip2d();
