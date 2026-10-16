// paperclip.scad — printable gem-style paperclip in three sizes
//
// WHY THIS ONE DOESN'T SNAP
//
//   * The whole clip is a PLANAR extrusion printed flat on the bed. Every
//     extrusion line runs along the wire path, so bending load is carried by
//     the filament itself and never by layer adhesion. This is the single
//     biggest difference from a scaled-down round-wire clip printed upright.
//
//   * The spring action is out-of-plane ELASTIC flexure: paper wedges between
//     the outer loop and the inner loop and twists them apart in Z, exactly how
//     a steel gem clip works. Nothing has to yield to make it grip.
//
//   * The section is WIDE in plane and THIN in Z — stiff against splaying
//     sideways, compliant in the one direction it must spring.
//
//   * Grip force scales as width x thickness^3 but strain only as thickness,
//     and the flexure is long, so the sections below buy real clamping force
//     (~0.45 N per mm of opening, about 60% of a steel gem clip) while peak
//     surface strain stays under 0.5% — roughly a 6x margin to PETG yield.
//
//   * Every reversal is a generous radius, the crossover bend (the spring, and
//     the highest-moment point) is locally swollen, the free tips taper, and
//     all edges are chamfered so paper leads in instead of catching.
//
// PRINT: flat on the bed as modelled. No supports. 4+ perimeters / 100% infill
// (it is all perimeter anyway). PETG, ASA or nylon. PLA works but is brittle
// and creeps under sustained clamp load — PETG is the pick.

sz = "m";                 // "s" | "m" | "l"
seg = 18;                 // segments per 180 deg bend
$fn = 24;

paperclip_clip(sz);

// ---------------------------------------------------------------------------

// [ overall length, wire width, thickness (Z), gap between adjacent wires ]
function pc_params(sz) =
    sz == "s" ? [36, 2.6, 1.8, 0.9]
  : sz == "l" ? [74, 4.4, 3.0, 1.4]
  :             [52, 3.4, 2.4, 1.1];

// boost > 0 swells the wire through the middle of a bend and blends back to the
// nominal width at both ends — extra meat exactly where the moment peaks, and
// none where it would close up the gap to the neighbouring wire.
function pc_arc(cx, cy, r, a0, a1, rr, n, boost = 0) =
  [ for (i = [0 : n])
      let (u = i / n, t = a0 + (a1 - a0) * u)
      [cx + r * cos(t), cy + r * sin(t), rr * (1 + boost * sin(180 * u))] ];

// wire centreline as [x, y, half-width]
function pc_path(sz, n = 18, xb = 0.18) =
  let (
    P   = pc_params(sz),
    L   = P[0], w = P[1], gap = P[3],
    b   = 0.8 * w,            // inner-loop half width (== its bend radius)
    a   = b + w + gap,        // outer-loop half width
    xn  = (a + b) / 2,        // crossover bend: centre x, radius, centre y
    Rn  = (a + b) / 2,
    yn  = (b - a) / 2,
    Lc  = L - a,              // centre x of the outer far U
    Lic = 0.78 * L - b,       // centre x of the inner far U
    rw  = w / 2,
    rt  = 0.78 * rw,          // tapered free-tip half width
    tl  = min(6, 0.22 * L),   // taper run-out
    xt1 = 0,                  // outer free tip, +y leg
    xt2 = xn + 1.5 * w        // inner free tip, -y leg
  )
  concat(
    [[xt1, a, rt], [xt1 + tl, a, rw]],              // outer tip + taper, +y leg
    pc_arc(Lc,  0,  a,  90,  -90, rw, n),           // outer far U   -> (Lc, -a)
    pc_arc(xn,  yn, Rn, -90, -270, rw, n, xb),      // crossover     -> (xn,  b)
    pc_arc(Lic, 0,  b,  90,  -90, rw, n),           // inner far U   -> (Lic,-b)
    [[xt2 + tl, -b, rw], [xt2, -b, rt]]             // taper + inner tip
  );

// the swept cross-section: a disc with 45 deg chamfers top and bottom
module pc_node(r, th, ch) {
  hull() {
    cylinder(r = r,      h = th - 2 * ch, center = true);
    cylinder(r = r - ch, h = th,          center = true);
  }
}

module paperclip_clip(sz = "m", n = 18) {
  th = pc_params(sz)[2];
  ch = min(0.6, th / 4);            // chamfer: paper lead-in, no sharp edge
  p  = pc_path(sz, n);
  for (i = [0 : len(p) - 2])
    hull() {
      translate([p[i][0],     p[i][1],     th / 2]) pc_node(p[i][2],     th, ch);
      translate([p[i + 1][0], p[i + 1][1], th / 2]) pc_node(p[i + 1][2], th, ch);
    }
}

// --- first-order spring numbers -------------------------------------------
// Cantilever model, deliberately conservative: it ignores the torsional
// compliance of the legs, so the real part is softer and less strained.
PP  = pc_params(sz);
E   = 1700;                                  // MPa, printed PETG along extrusion
Le  = 0.78 * PP[0] - (2.6 * PP[1] + PP[3]) / 2;   // effective flexure length
Iz  = PP[1] * PP[2] * PP[2] * PP[2] / 12;    // mm^4, out-of-plane 2nd moment
Fmm = 3 * E * Iz / (Le * Le * Le);           // N per mm of opening
emm = 3 * PP[2] / (2 * Le * Le);             // surface strain per mm of opening

echo(size = sz, wire_w_t = [PP[1], PP[2]],
     envelope_mm = [PP[0] + PP[1] / 2 + 0.09 * PP[1],
                    2 * (1.8 * PP[1] + PP[3]) + PP[1], PP[2]]);
echo(grip_N_per_mm_open = Fmm, strain_pct_per_mm_open = 100 * emm,
     mm_open_at_1pct_strain = 0.01 / emm);
