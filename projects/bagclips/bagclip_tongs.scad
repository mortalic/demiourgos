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

use <bagclip_brand.scad>

/* [Variant] */
variant = "large";        // std | large
L = (variant == "large");

/* [Size] */
bite       = L ? 15 : 10;    // Z depth (along the bag edge)
arm_t      = L ? 3.2 : 2.6;  // arm/ribbon thickness

/* [Jaws] */
jaw_len    = L ? 62 : 20;    // jaw length (left)
jaw_gap    = L ? 1.2 : 1.0;  // gap between the closed jaw faces (small -> grips)
jaw_flat   = L ? 5 : 3;      // x where the jaw stops being parallel and rises to the loop

/* [Spring loop] */
loop_r     = L ? 7 : 5;      // loop radius (bigger = softer spring, lower strain)
loop_wall  = L ? 2.4 : 2.0;  // loop wall thickness (the flexure)

/* [Handles] */
handle_len   = L ? 28 : 17;  // handle length (right)
handle_spread= L ? 11 : 7;   // half-distance between the handle tips (pinch leverage)

/* [Teeth] */
tooth_d = 0.35;     // tooth bite toward the other jaw
tooth_p = 1.8;      // tooth pitch

/* [Maker's mark] */
brand       = "imakethingsforu.com";
brand_font  = "Liberation Sans:style=Bold";
brand_depth = 0.4;           // engraving depth (single-colour print)
mmu_depth   = 0.9;           // letter thickness when exported as a separate part (two perimeters)
part        = "all";         // all | body | letters -- body/letters: two-part MMU export, the
                             // letters are a flush mmu_depth-thick solid for a second extruder
brand_min   = 3;             // if the whole mark fits the jaw at this size, keep it in one piece;
                             // otherwise flow it around jaw -> rise -> handle

$fn = 48;

jc = (arm_t + jaw_gap) / 2;   // jaw centerline offset from the middle

// ---- mark layout ----
// Large: the whole mark fits the jaw face in one piece. Otherwise it flows along the
// bottom arm's outer contour, jaw tip -> rise -> handle tip, wrapping the corners.
jaw_x0 = -jaw_len + arm_t/2 + 0.5;
jaw_x1 = -jaw_flat - 0.3;
jaw_can = jaw_x1 - jaw_x0;
mark_path = [[-jaw_len, -jc], [-jaw_flat, -jc], [0, -loop_r], [handle_len, -handle_spread]];
mark_dead = [];

smax        = bite * 0.45;
single_size = fit1(brand, jaw_can, smax);
single      = single_size >= brand_min;
brand_size  = single ? single_size : path_text_size(mark_path, arm_t/2, brand, mark_dead, smax);

echo(str(variant, ": ", jaw_len + handle_len, " x ", 2*max(handle_spread, loop_r) + arm_t, " x ", bite,
         " mm; mark ", brand_size, " mm ", single ? "on the jaw" : "flowing jaw -> rise -> handle",
         brand_size < brand_min ? "  (under 3 mm: use a 0.25 nozzle or expect rough letters)" : ""));

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

module prisms() {
  if (brand != "") {
    if (single)
      engrave([(jaw_x0 + jaw_x1)/2, -(jc + arm_t/2), bite/2], [0, -1, 0], brand, brand_size, mark_cut, brand_font, out = 2);
    else
      engrave_path(mark_path, arm_t/2, brand, brand_size, mark_cut, brand_font, bite/2, mark_dead, out = 2);
  }
}

// the mark as a solid: a mark_depth-thick skin of the outer face under the letters
mark_depth = part == "all" ? brand_depth : mmu_depth;
mark_cut   = arm_t - mark_depth - 0.3;   // how far the prisms reach in (stay off the inner face)
module mark() skin_mark(bite, mark_depth) { clip2d(); prisms(); }

if (part == "letters")
  mark();
else
  difference() {
    linear_extrude(bite) clip2d();
    mark();
  }
