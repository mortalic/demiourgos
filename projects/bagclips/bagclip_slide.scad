// bagclip_slide — a C-channel you slide over the bag's folded top from the side.
// A detent bump in the channel grips the bag. RIGID, durable in PLA. The profile
// is extruded along Z (the slide length); prints flat, support-free.

clip_len = 30;     // length along the bag edge (Z) = slide length
gap      = 2.0;    // channel gap (folded bag thickness + light clearance)
jaw      = 3.0;    // jaw thickness
back     = 3.0;    // back-wall thickness
depth    = 17;     // how far the channel reaches in (X)
corner   = 1.0;    // outer rounding (keep < jaw/2 and < back/2 or the offset erodes the jaws)
bump     = 0.7;    // detent bump protrusion into the channel
n_bumps  = 2;

$fn = 32;

module frame2d() {
  offset(corner) offset(-corner)
    union() {
      translate([-depth,  gap/2])           square([depth, jaw]);        // top jaw
      translate([-depth, -gap/2 - jaw])      square([depth, jaw]);        // bottom jaw
      translate([-depth, -gap/2 - jaw])      square([back,  gap + 2*jaw]);// back wall
    }
}

module clip2d() {
  union() {
    frame2d();
    // grip detents on the top jaw, poking down into the channel
    for (i = [0 : n_bumps-1])
      translate([-depth + back + 3 + i * 6, gap/2]) circle(d = bump*2, $fn = 16);
  }
}

linear_extrude(clip_len) clip2d();
