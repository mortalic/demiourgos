// bagclip_hairpin — copied from Bag_Clip_1.1.stl. A vertical hairpin clip: a top
// LOOP spring (open DOWNWARD toward the jaws so the legs can flex), two legs, and
// serrated V JAWS at the bottom that sit nearly closed and grip the bag. The
// splayed feet are the lead-in / finger grip — push the bag into the V (or pinch
// the feet) and the legs flex about the top loop; release and it clamps.
//
// Flat profile extruded along Z; prints flat, support-free; legs flex in-plane.

/* [Size] */
clip_h   = 68;    // height (Y)
foot_w   = 12;    // half-width at the splayed feet (bottom)
arm_t    = 3.0;   // leg thickness
bite     = 10;    // Z depth

/* [Loop spring] */
r_loop   = 6;     // top loop bend radius (legs sit at +/- r_loop up top)

/* [Jaws] */
jaw_lo   = 18;    // jaw bottom (Y)
jaw_len  = 18;    // parallel serrated jaw length
jg       = 2.0;   // jaw centerline offset from middle (small -> grips)
tooth_d  = 0.35;  // tooth bite
tooth_p  = 1.8;   // tooth pitch

$fn = 48;

function arc(c, r, a0, a1, n) =
  [ for (i=[0:n]) [ c[0]+r*cos(a0+(a1-a0)*i/n), c[1]+r*sin(a0+(a1-a0)*i/n) ] ];

module ribbon(p, t) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=t); translate(p[i+1]) circle(d=t); }
}

// folded-ribbon centerline: foot -> jaw -> leg -> loop -> leg -> jaw -> foot
centerline = concat(
  [ [-foot_w, 0], [-jg, jaw_lo], [-jg, jaw_lo+jaw_len], [-r_loop, clip_h - r_loop] ],
  arc([0, clip_h - r_loop], r_loop, 180, 0, 22),
  [ [r_loop, clip_h - r_loop], [jg, jaw_lo+jaw_len], [jg, jaw_lo], [foot_w, 0] ]
);

// vertical sawtooth on a jaw inner face at x=fx, biting toward dir
module teeth(fx, dir) {
  for (y = [jaw_lo : tooth_p : jaw_lo + jaw_len])
    polygon([[fx - dir*0.5, y], [fx + dir*tooth_d, y + tooth_p/2], [fx - dir*0.5, y + tooth_p]]);
}

module clip2d() {
  union() {
    ribbon(centerline, arm_t);
    teeth(-jg + arm_t/2, +1);   // left jaw inner face, teeth point right
    teeth( jg - arm_t/2, -1);   // right jaw inner face, teeth point left
  }
}

linear_extrude(bite) clip2d();
