// bagclip_tongs — single-piece tongs/clothespin bag clip, copied from the
// reference bagclipstronger.stl / bag-clip-final.stl.
//
// HOW IT WORKS: the serrated JAWS (left) sit nearly CLOSED at rest and clamp the
// bag. The round LOOP (middle) is a compliant spring-pivot (a big radius keeps the
// strain low so it survives in PLA). The forked HANDLES (right) are levers — pinch
// them together and the jaws cantilever OPEN; release and the loop snaps them shut.
//
// Flat profile extruded along Z (bite depth). Prints flat, support-free; the loop
// flexes in-plane along the layers.

/* [Size] */
bite       = 10;    // Z depth (along the bag edge)
arm_t      = 2.6;   // arm/ribbon thickness

/* [Jaws] */
jaw_len    = 20;    // jaw length (left)
jaw_gap    = 1.0;   // gap between the closed jaw faces (small -> grips)
jaw_flat   = 5;     // x where the jaw stops being parallel and rises to the loop

/* [Spring loop] */
loop_r     = 5;     // loop radius (bigger = softer spring, lower strain)
loop_wall  = 2.0;   // loop wall thickness (the flexure)

/* [Handles] */
handle_len   = 17;  // handle length (right)
handle_spread= 7;   // half-distance between the handle tips (pinch leverage)

/* [Teeth] */
tooth_d = 0.35;     // tooth bite toward the other jaw
tooth_p = 1.8;      // tooth pitch

/* [Text] */
text_height = 1.5;  // height of the text extrusion
text_depth = 1.0;   // depth of the text (how far into the clip)

$fn = 48;

jc = (arm_t + jaw_gap) / 2;   // jaw centerline offset from the middle

function arc(c, r, a0, a1, n) =
  [ for (i=[0:n]) [ c[0]+r*cos(a0+(a1-a0)*i/n), c[1]+r*sin(a0+(a1-a0)*i/n) ] ];

module ribbon(p, t) {
  for (i = [0 : len(p)-2])
    hull() { translate(p[i]) circle(d=t); translate(p[i+1]) circle(d=t); }
}

// one arm: parallel jaw (left) -> up to the loop -> out to the handle (right)
function arm_pts(s) = [   // s = +1 top, -1 bottom
  [-jaw_len, s*jc], [-jaw_flat, s*jc], [0, s*loop_r], [handle_len, s*handle_spread]
];

// sawtooth on a jaw inner face at y=fy, biting toward dir. The base is sunk
// 0.5mm INTO the arm so the union is clean (no coincident edge -> watertight).
module teeth(fy, dir) {
  for (x = [-jaw_len + 2 : tooth_p : -jaw_flat])
    polygon([[x, fy - dir*0.5], [x + tooth_p/2, fy + dir*tooth_d], [x + tooth_p, fy - dir*0.5]]);
}

// Add text to the clip
module add_text() {
  // Create a 2D text shape and then extrude it properly
  translate([0, jc - arm_t/2, bite/2])
    linear_extrude(text_depth)
      text("imakethingsforu.com", size=text_height, halign="center", valign="center");
}

// Main clip module that creates the 2D profile
module clip2d() {
  union() {
    ribbon(arm_pts(+1), arm_t);
    ribbon(arm_pts(-1), arm_t);
    // spring = C-loop OPEN toward the jaws (right half only), so the jaw slot runs
    // into the loop and the arms can flex. A closed O would fuse the jaws solid.
    ribbon(arc([0, 0], loop_r, 90, -90, 28), loop_wall);
    teeth( jc - arm_t/2, -1);   // top jaw inner (bottom) face, teeth point down
    teeth(-jc + arm_t/2, +1);   // bottom jaw inner (top) face, teeth point up
  }
}

// Create the final 3D clip with text
module main_clip() {
  // First create the base clip
  clip2d();
  
  // Then add the text as a separate 3D element that's unioned with the clip
  // Position text on top of the jaw surface
  translate([0, jc - arm_t/2, bite/2])
    linear_extrude(text_depth)
      text("imakethingsforu.com", size=text_height, halign="center", valign="center");
}

// The final extrusion of the entire clip including text
linear_extrude(bite) main_clip();
