// bagclip_hairpin (v2) — copied from Bag_Clip_1.1.stl. A vertical hairpin clip: a top
// LOOP spring (open DOWNWARD toward the jaws so the legs can flex), two legs, and
// serrated V JAWS at the bottom that sit nearly closed and grip the bag. The
// splayed feet are the lead-in / finger grip — push the bag into the V (or pinch
// the feet) and the legs flex about the top loop; release and it clamps.
//
// Flat profile extruded along Z; prints flat, support-free; legs flex in-plane.

use <bagclip_brand.scad>

/* [Variant] */
variant = "large";        // std | large | xl | xxl
sz = variant == "std" ? 0 : variant == "large" ? 1 : variant == "xl" ? 2 : 3;
function pk(v) = v[sz];   // pick per variant: [std, large, xl, xxl]

/* [Size] */
// xl / xxl only grow in Y (longer jaws); bite matches large. The three big sizes
// have thicker arms (v2): grip stiffness goes with thickness^3 / length^3, and
// the loop takes well under 1% strain even at 5 mm, so the loop is the same
// thickness as the legs rather than a thin hinge.
clip_h   = pk([68, 112, 156, 200]);  // height (Y)
foot_w   = pk([12, 16, 16, 16]);     // half-width at the splayed feet (bottom)
arm_t    = pk([3.0, 4.5, 5.0, 5.0]); // leg / loop thickness
bite     = pk([10, 15, 15, 15]);     // Z depth

/* [Loop spring] */
r_loop   = pk([6, 9, 9, 9]);         // top loop bend radius (legs sit at +/- r_loop up top)

/* [Jaws] */
// v2: the jaws sit closed with the two rows of teeth interleaved, so a bag has to
// follow a zig-zag path between them (the hold multiplies through every bend like
// a rope on a capstan). The v1 jaws were parallel with a 0.7 mm clear gap, which a
// 0.2 mm bag passed without deflecting the legs at all.
jaw_lo   = pk([18, 22, 22, 22]);     // jaw bottom (Y)
jaw_len  = pk([18, 56, 100, 144]);   // serrated jaw length
tooth_d  = 0.7;   // tooth height off the jaw face
tooth_p  = 2.5;   // tooth pitch
tooth_ov = 0.3;   // how far the two rows' tips pass each other
jaw_gap  = 2*tooth_d - tooth_ov;             // jaw inner faces apart (1.1)
jg       = arm_t/2 + jaw_gap/2;              // jaw centerline offset from the middle
// nearest approach of a tooth tip to the opposing flank (the channel the bag threads)
tooth_clr = (jaw_gap/2 - tooth_ov/2) * (tooth_p/2) / norm([jaw_gap/2 + tooth_ov/2, tooth_p/2]);

/* [Maker's mark] */
brand       = "imakethingsforu.com";
brand_font  = "Liberation Sans:style=Bold";
brand_depth = 0.4;           // engraving depth (single-colour print)
mmu_depth   = 0.9;           // letter thickness when exported as a separate part (two perimeters)
part        = "all";         // all | body | letters -- body/letters: two-part MMU export, the
                             // letters are a flush mmu_depth-thick solid for a second extruder
brand_min   = 3;             // if the whole mark fits the jaw at this size, keep it in one piece;
                             // otherwise flow it down leg -> jaw -> foot

$fn = 48;

// ---- mark layout ----
// Large and up: the whole mark fits the jaw face in one piece. Otherwise it flows down the
// left side's outer contour, loop junction -> leg -> jaw -> foot tip, reading
// top-to-bottom for a viewer facing the -x side.
jaw_y1 = jaw_lo + jaw_len - 1.0;
jaw_y0 = jaw_lo + 1.0;
jaw_can = jaw_y1 - jaw_y0;
mark_path = [[-r_loop, clip_h - r_loop], [-jg, jaw_lo + jaw_len], [-jg, jaw_lo], [-foot_w, 0]];
mark_dead = [];

smax        = bite * 0.45;
single_size = fit1(brand, jaw_can, smax);
single      = single_size >= brand_min;
brand_size  = single ? single_size : path_text_size(mark_path, arm_t/2, brand, mark_dead, smax);

echo(str(variant, ": ", 2*foot_w + arm_t, " x ", clip_h + arm_t, " x ", bite,
         " mm; tooth channel ", tooth_clr, " mm; mark ", brand_size, " mm ", single ? "on the jaw" : "flowing leg -> jaw -> foot",
         brand_size < brand_min ? "  (under 3 mm: use a 0.25 nozzle or expect rough letters)" : ""));

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

// vertical sawtooth on a jaw inner face at x=fx, biting toward dir, first tooth at y0
module teeth(fx, dir, y0) {
  for (y = [y0 : tooth_p : jaw_lo + jaw_len - tooth_p])
    polygon([[fx - dir*0.5, y], [fx + dir*tooth_d, y + tooth_p/2], [fx - dir*0.5, y + tooth_p]]);
}

module clip2d() {
  union() {
    ribbon(centerline, arm_t);
    teeth(-jg + arm_t/2, +1, jaw_lo);               // left jaw inner face, teeth point right
    teeth( jg - arm_t/2, -1, jaw_lo + tooth_p/2);   // right row, half a pitch up: interleaved
  }
}

module prisms() {
  if (brand != "") {
    if (single)
      engrave([-(jg + arm_t/2), (jaw_y0 + jaw_y1)/2, bite/2], [-1, 0, 0], brand, brand_size, mark_cut, brand_font, out = 2);
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
