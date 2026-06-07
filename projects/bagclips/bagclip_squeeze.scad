// bagclip_squeeze — a single-piece C-clamp. Push the bag's folded top into the
// tapered mouth; the two sprung arms spread and the inner teeth grip, the curved
// back acts as the spring. COMPLIANT — flexes every use, so print in PETG/TPU for
// fatigue life; PLA works but can crack at the throat over time.
// Prints flat, support-free (profile extruded along Z).

clip_w   = 12;     // width along the bag edge (Z)
body_x   = 22;     // overall X
body_h   = 30;     // overall Y
corner   = 4;      // outer corner radius
mouth_top= 5.5;    // mouth opening width at the top (easy start)
mouth_bot= 1.2;    // mouth width at the throat (grip)
mouth_d  = 20;     // mouth depth (down from the top)
throat_d = 6;      // stress-relief circle at the bottom of the mouth
n_teeth  = 3;      // grip teeth per arm
tooth    = 0.8;    // tooth protrusion

$fn = 48;

module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

module clip2d() {
  difference() {
    rrect(body_x, body_h, corner);
    // tapered mouth (wide at top, narrow at the throat)
    polygon([[-mouth_top/2,  body_h/2 + 1],
             [ mouth_top/2,  body_h/2 + 1],
             [ mouth_bot/2,  body_h/2 - mouth_d],
             [-mouth_bot/2,  body_h/2 - mouth_d]]);
    // throat stress-relief circle (keeps the spring from cracking)
    translate([0, body_h/2 - mouth_d]) circle(d = throat_d);
    // grip teeth: notch the inner faces so a few ridges bite the bag
    for (i = [0 : n_teeth-1]) {
      y = body_h/2 - 4 - i * (mouth_d - 6) / n_teeth;
      w = mouth_bot + (mouth_top - mouth_bot) * (body_h/2 - y) / mouth_d;
      for (s = [-1, 1])
        translate([s * (w/2 + tooth/2), y]) circle(d = tooth*2, $fn = 12);
    }
  }
}

linear_extrude(clip_w) clip2d();
