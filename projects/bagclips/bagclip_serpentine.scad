// bagclip_serpentine — copied from Food_Clip_4.stl. Serrated jaws (right) held
// closed by a zig-zag "W" leaf spring (left). The jaw slot runs straight through
// into the open zig-zag, so squeezing the spring cantilevers the jaws open; the
// bag's folded top sits in the serrated jaws. Flat profile extruded along Z;
// prints flat, support-free.

use <bagclip_brand.scad>

/* [Variant] */
variant = "large";        // std | large
L = (variant == "large");

/* [Size] */
jaw_tip   = L ? 58 : 25;    // x of the jaw tips (right)
jaw_x     = 0;              // x where the jaws end and the spring begins
arm_t     = L ? 3.2 : 2.8;  // arm thickness
bite      = L ? 15 : 10;    // Z depth
jg        = L ? 2.0 : 1.7;  // jaw half-gap (small -> grips)
amp       = L ? 18 : 13;    // zig-zag amplitude
zz_l      = L ? -30 : -22;  // left vertices of the zig-zag
zz_r      = L ? -6 : -4;    // inner (right) vertices of the zig-zag

/* [Teeth] */
tooth_d = 0.35;
tooth_p = 1.8;

/* [Maker's mark] */
brand       = "imakethingsforu.com";
brand_font  = "Liberation Sans:style=Bold";
brand_depth = 0.4;           // engraving depth (single-colour print)
mmu_depth   = 0.9;           // letter thickness when exported as a separate part (two perimeters)
part        = "all";         // all | body | letters -- body/letters: two-part MMU export, the
                             // letters are a flush mmu_depth-thick solid for a second extruder
brand_min   = 3;             // if the whole mark fits the jaw at this size, keep it in one piece;
                             // otherwise flow it along spring arm -> jaw

$fn = 40;

// ---- mark layout ----
// Large: the whole mark fits the jaw face in one piece. Otherwise it flows along the
// bottom outer contour: the lowest zig-zag segment, then the jaw. Where that segment's
// rounded end steps up onto the arm that joins the jaw, the surface is not a clean
// face, so that stretch is a dead zone and the letters resume on the jaw.
jaw_x0 = jaw_x + 0.5;
jaw_x1 = jaw_tip - arm_t/2 - 0.5;
jaw_can = jaw_x1 - jaw_x0;
mark_path = [[zz_l, -amp], [zz_r, -amp*0.4], [jaw_x, -jg], [jaw_tip, -jg]];
mark_q    = offset_right(mark_path, arm_t/2);
mark_dead = [[vert_s(mark_q, 1) - 0.8, vert_s(mark_q, 2) + 0.3]];

smax        = bite * 0.45;
single_size = fit1(brand, jaw_can, smax);
single      = single_size >= brand_min;
brand_size  = single ? single_size : path_text_size(mark_path, arm_t/2, brand, mark_dead, smax);

echo(str(variant, ": ", jaw_tip - zz_l + arm_t, " x ", 2*amp + arm_t, " x ", bite,
         " mm; mark ", brand_size, " mm ", single ? "on the jaw" : "flowing spring arm -> jaw",
         brand_size < brand_min ? "  (under 3 mm: use a 0.25 nozzle or expect rough letters)" : ""));

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

module prisms() {
  if (brand != "") {
    if (single)
      engrave([(jaw_x0 + jaw_x1)/2, -(jg + arm_t/2), bite/2], [0, -1, 0], brand, brand_size, mark_cut, brand_font, out = 2);
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
