// bp_coiled_wire — ball python, head in profile on a raised neck over a coiled
// body, drawn as contour-line wire art.
//
// Flat cut-through plate: constant thickness, prints back-flat with zero
// supports, hangs as a silhouette.
//
// STYLE — from the supplied Snake_-_Had.stl: the form is described by flowing
// PARALLEL CONTOUR LINES of near-constant width with generous open space
// between them. The body lines here are GENERATED, not hand-placed: a centreline
// plus a half-width profile, offset along the normal. That is what produces true
// parallel flow through a curve, and it is why the reference reads as one
// continuous ribbon rather than a bundle of separate strokes.
//
// COMPOSITION — a head alone in profile is a blob; snakes have no ears, brow or
// muzzle to break the outline. What makes both references read is the neck
// CONSTRICTION and the body behind it. So the head tapers rearward into a neck
// narrower than the skull, and the body coils below.
//
// ANATOMY — from the supplied photos: chunky head ~1.6:1 long-to-deep, blunt
// near-vertical rostral, large eye set forward and high, mouth running well past
// the eye, and the labial PITS as a row of slots along the front of the lip.
//
// CONNECTIVITY: on a cut-through plate a stroke touching nothing falls out. The
// body contours converge at the tail taper and merge into the head at the neck;
// head chains meet the outline or the eye ring.

/* [Size] */
piece_w   = 300;   // finished width (mm), X
thick     = 4;     // plate thickness (mm), Z

/* [Line weights] */
r_out     = 2.6;   // outline / body edge stroke radius
r_line    = 1.9;   // interior contour radius
r_fine    = 1.5;   // pit rungs

/* [Eye] */
eye_x     = 46;
eye_y     = 30;
eye_ro    = 16.0;
eye_ri    = 9.5;
eye_squash= 0.90;

/* [Hanging] */
hang_boss = 9.0;
hang_hole = 2.6;

/* [Quality] */
seg       = 18;
$fn       = 14;

// ---------------------------------------------------------------- primitives

function lerp(a, b, t) = a + (b - a) * t;

function bez(p0, p1, p2, p3, t) =
      pow(1 - t, 3)           * p0
    + 3 * pow(1 - t, 2) * t   * p1
    + 3 * (1 - t) * pow(t, 2) * p2
    + pow(t, 3)               * p3;

// derivative — needed for the normal when offsetting the body centreline
function dbez(p0, p1, p2, p3, t) =
      3 * pow(1 - t, 2)   * (p1 - p0)
    + 6 * (1 - t) * t     * (p2 - p1)
    + 3 * pow(t, 2)       * (p3 - p2);

function bezpts(p0, p1, p2, p3, n = seg, skip = false) =
    [for (i = [skip ? 1 : 0 : n]) bez(p0, p1, p2, p3, i / n)];

function bpts(s, n = seg, skip = false) = bezpts(s[0], s[1], s[2], s[3], n, skip);
function bpt(s, t)  = bez(s[0], s[1], s[2], s[3], t);
function dseg(s, t) = dbez(s[0], s[1], s[2], s[3], t);

function unit(v) = v / max(norm(v), 0.0001);
function perp(v) = [-v[1], v[0]];

module vstroke(pts, r0, r1) {
    n = len(pts) - 1;
    for (i = [0 : n - 1])
        hull() {
            translate(pts[i])     circle(r = lerp(r0, r1, i / n));
            translate(pts[i + 1]) circle(r = lerp(r0, r1, (i + 1) / n));
        }
}

module chain(ch, r) { for (s = ch) vstroke(bpts(s), r, r); }

// ---------------------------------------------------------------- body ribbon
// Centreline: out of the neck, right and down, around the bottom, back left,
// then an inner coil returning right and tapering to the tail. Laid out so no
// coil overlaps another.

BODY = [
    [[160,   8], [185,   6], [208,   2], [225,  -5]],
    [[225,  -5], [243, -25], [252, -48], [250, -70]],
    [[250, -70], [248, -98], [228, -116], [200, -118]],
    [[200, -118], [172, -121], [140, -126], [110, -125]],
    [[110, -125], [ 80, -126], [ 58, -120], [ 52, -105]],
    [[ 52, -105], [ 42,  -95], [ 46,  -84], [ 58,  -80]],
    [[ 58,  -80], [ 78,  -74], [100,  -73], [120,  -76]],
    [[120,  -76], [140,  -78], [158,  -85], [170,  -92]],
];

// half-width along the body, as (global t, half-width) — the neck is markedly
// narrower than the skull, which is the constriction that makes it read.
HW = [[0, 27], [0.12, 27], [0.35, 25], [0.6, 22], [0.85, 13], [1.0, 3]];

function hwi(g, i = 0) =
    i >= len(HW) - 1 ? HW[len(HW) - 1][1]
  : g <= HW[i + 1][0]
      ? lerp(HW[i][1], HW[i + 1][1],
             (g - HW[i][0]) / (HW[i + 1][0] - HW[i][0]))
      : hwi(g, i + 1);

// One offset contour at `frac` of the half-width, across the whole body.
function ribbon(frac, gmax = 1.0) = [
    for (i = [0 : len(BODY) - 1], j = [0 : seg])
        let (t = j / seg, g = (i + t) / len(BODY))
        if (g <= gmax)
            let (p = bpt(BODY[i], t),
                 n = perp(unit(dseg(BODY[i], t))))
            p + n * frac * hwi(g)
];

module body() {
    vstroke(ribbon( 1.0), r_out,  r_out);
    vstroke(ribbon(-1.0), r_out,  r_out);
    vstroke(ribbon( 0.5, 0.86), r_line, r_line);
    vstroke(ribbon(-0.5, 0.86), r_line, r_line);
    vstroke(ribbon( 0.0, 0.80), r_line, r_line);
}

// ---------------------------------------------------------------- head
// Closed loop. The rear tapers into the neck and is swallowed by the body, so
// the skull reads as wider than the neck behind it.

OUT = [
    [[158, -19], [159, -28], [156, -36], [148, -42]],  // 0 continues body inner edge
    [[148, -42], [134, -46], [118, -47], [102, -47]],  // 1 rictus / jaw
    [[102, -47], [ 84, -47], [ 64, -46], [ 46, -43]],  // 2 jaw bottom — flat
    [[ 46, -43], [ 32, -40], [ 22, -36], [ 16, -28]],  // 3 chin
    [[ 16, -28], [ 10, -22], [  6, -14], [  5,  -6]],  // 4 rostral underside
    [[  5,  -6], [  3,  12], [  4,  28], [ 10,  38]],  // 5 rostral — blunt face
    [[ 10,  38], [ 18,  48], [ 30,  53], [ 44,  54]],  // 6 snout top, rising fast
    [[ 44,  54], [ 68,  57], [ 94,  58], [112,  56]],  // 7 crown — flat
    [[112,  56], [126,  52], [136,  45], [148,  38]],  // 8 back of skull
    [[148,  38], [152,  36], [157,  35], [162,  35]],  // 9 continues body outer edge
];

function outline_pts() = concat(
    bpts(OUT[0]), [for (k = [1 : 9]) each bpts(OUT[k], seg, true)]
);

module head_outline() { vstroke(outline_pts(), r_out, r_out); }

// Brow: rises off the rostral, crests over the eye, sweeps back into the neck.
BROW = [
    [[  8,   6], [ 16,  30], [ 28,  42], [ 46,  43]],   // lands ON the eye ring
    [[ 46,  43], [ 66,  47], [ 88,  46], [110,  44]],
    [[110,  44], [130,  42], [148,  34], [161,  21]],   // continues the +0.5 contour
];

// Cheek: starts on the eye ring, follows the jaw back into the neck.
CHEEK = [
    [[ 57,  24], [ 78,  16], [ 98,  11], [120,   6]],
    [[120,   6], [136,   5], [150,   6], [160,   8]],   // continues the centre contour
];

// Lower jaw contour.
JAW = [
    [[ 20, -24], [ 44, -34], [ 74, -38], [106, -39]],
    [[106, -39], [122, -39], [138, -39], [152, -39]],   // dies at the rictus
];

// Rear margin of the mandible — carries the -0.5 body contour into the head now
// that the jaw contour no longer reaches it.
THROAT = [
    [[140, -40], [146, -28], [152, -16], [159,  -5]],
];

// ---------------------------------------------------------------- lips

LIP_TOP = [[  6,  14], [ 58,   4], [114, -10], [150, -30]];
MOUTH   = [[  6,  -4], [ 54, -12], [110, -26], [154, -40]];
PIT_T   = [0.06, 0.13, 0.20, 0.27, 0.34];

module lips() {
    chain([LIP_TOP], r_line);
    chain([MOUTH], r_line);
    for (t = PIT_T)
        vstroke([bpt(LIP_TOP, t), bpt(MOUTH, t)], r_fine, r_fine);
}

module eye() {
    translate([eye_x, eye_y]) scale([1, eye_squash]) difference() {
        circle(r = eye_ro, $fn = 48);
        circle(r = eye_ri, $fn = 48);
    }
}

// ---------------------------------------------------------------- hanging
// Placed after measuring the centre of mass — see README.

HANG = [[132.4, 47.2]];   // solved: directly above the centre of mass

module hang_bosses() { for (h = HANG) translate(h) circle(r = hang_boss, $fn = 28); }
module hang_holes()  { for (h = HANG) translate(h) circle(r = hang_hole, $fn = 24); }

// ---------------------------------------------------------------- assembly

module art2d() {
    difference() {
        union() {
            body();
            head_outline();
            hang_bosses();
            chain(BROW,  r_line);
            chain(CHEEK, r_line);
            chain(JAW,   r_line);
            chain(THROAT, r_line);
            lips();
            eye();
        }
        hang_holes();
    }
}

s = piece_w / (275 + 2 * r_out);

scale(s) translate([-140, 35]) linear_extrude(height = thick / s) art2d();
