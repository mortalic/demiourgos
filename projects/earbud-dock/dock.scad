// earbud-dock — 4-case charging dock for Samsung Galaxy Buds cases
// ---------------------------------------------------------------------------
// Concept: a right-angle USB-C cable is routed UP through the base of each
// pocket; the connector pokes above the pocket floor and the case is lowered
// straight down onto it (port-face down). Cables exit the back of the dock.
//
// Each case is seated PORT-FACE DOWN so the connector mates from below:
//   Buds 3 / Buds 3 Pro : USB-C on the bottom face -> natural upright pill.
//   Buds 4 Pro / Live    : USB-C on the back face   -> case stands on its back
//                          edge so the port faces down onto the plug.
//
// Anti-lift: solid base + long anti-tip footprint + a fillable WEIGHT WELL
// (sand / steel shot / coins) closed by a press-fit cover.  Set part="cover"
// to print the lid.  See README.md for fill weights and case-spec sources.
// Units: millimetres.
// ---------------------------------------------------------------------------

/* [What to build] */
part = "dock";          // [dock, cover, all]

/* [Cases] */
// [label, footprint_X (along row), footprint_Y (front-back), stand_height]
// footprint = the case face that sits down (the one with the USB-C port).
cases = [
    ["Buds 3",     58.9, 24.4, 48.7],
    ["Buds 3 Pro", 58.9, 24.4, 48.7],
    ["Buds 4 Pro", 51.0, 28.3, 51.0],
    ["Live",       50.2, 27.8, 50.0],
];

/* [Fit] */
clear      = 0.6;   // per-side slip clearance around each case
lead_in    = 1.2;   // chamfer at the pocket mouth to guide the case in

/* [Walls & base] */
wall       = 2.0;   // thin divider walls between pockets
outer_wall = 2.5;   // outer perimeter wall
cradle_h   = 13;    // pocket wall height above the floor (how deep case sits)
slab_h     = 22;    // solid base below the floor (mass + routing + weight well)
corner_r   = 4;     // outer vertical corner radius
top_taper  = 1.2;   // top edge inset (subtle chamfer for a clean look)

/* [Cable routing] */
plug_w     = 13;    // connector clearance, across the row
plug_d     = 9;     // connector clearance, front-back
route_h    = 9;     // routing band height, measured down from the floor
shelf      = 2;     // solid shelf between routing band and weight well
elbow_w    = 16;    // right-angle housing cavity width
elbow_d    = 24;    // right-angle housing cavity depth (front-back)
chan_w     = 6;     // rear cable channel width (grips the cable for strain relief)
chan_h     = 6;     // rear cable channel height

/* [Weight well] */
weight_well = true;  // hollow the lower base for sand/shot ballast
well_x_margin = 16;  // solid base kept at each end (clears the foot recesses)
well_y_margin = 5;   // solid wall front/back of the well
ledge        = 1.5;  // seat the cover stops against
cover_th     = 2.4;  // press-fit cover thickness
cover_gap    = 0.25; // clearance around the cover (per side)

/* [Details] */
show_labels = true; // engrave case names on the front face
label_h     = 4.5;  // label text height
label_depth = 0.8;  // engraving depth
feet        = true; // recess pads for stick-on rubber feet
foot_d      = 11;
foot_inset  = 8;

/* [Hidden] */
$fn = 64;
eps = 0.01;
n   = len(cases);

// ---- derived layout -------------------------------------------------------
function fx(i) = cases[i][1];                 // case footprint X
function fy(i) = cases[i][2];                 // case footprint Y
function pw(i) = fx(i) + 2*clear;             // pocket inner width  (per case)
function pd(i) = fy(i) + 2*clear;             // pocket inner depth  (per case)
max_pd = max([for (i=[0:n-1]) pd(i)]);        // deepest pocket sets the body depth

function psum(i) = i <= 0 ? 0 : pw(i-1) + psum(i-1);
inner_span = psum(n) + wall*(n-1);
total_w    = inner_span + 2*outer_wall;
total_d    = max_pd + 2*outer_wall;
total_h    = slab_h + cradle_h;

// centre X of pocket i (whole dock centred on origin)
function px(i) = -inner_span/2 + psum(i) + wall*i + pw(i)/2;

// pockets are FRONT-aligned: front inner wall shared, depth varies toward back
front_inner = -total_d/2 + outer_wall;
function pcy(i) = front_inner + pd(i)/2;      // pocket & connector centre Y

// vertical bands inside the slab
route_lo = slab_h - route_h;             // bottom of the routing band
well_top = route_lo - shelf;             // top of the weight well (its ceiling)
well_w   = total_w - 2*well_x_margin;    // recess footprint, across the row
well_d   = total_d - 2*well_y_margin;    // recess footprint, front-back

// ---- 2D helpers -----------------------------------------------------------
module rrect(w, d, r) {
    r2 = min(r, w/2, d/2);
    offset(r = r2) square([w - 2*r2, d - 2*r2], center = true);
}

// ---- outer shell (rounded sides, gently tapered top) ----------------------
module shell() {
    hull() {
        linear_extrude(total_h - top_taper)
            rrect(total_w, total_d, corner_r);
        translate([0, 0, total_h - eps])
            linear_extrude(eps)
                rrect(total_w - 2*top_taper, total_d - 2*top_taper, corner_r);
    }
}

// ---- a single pocket void + cable routing for case i ----------------------
module pocket_void(i) {
    x = px(i);
    y = pcy(i);
    // main cavity the case drops into, with a lead-in chamfer at the mouth
    translate([x, y, slab_h])
        hull() {
            linear_extrude(eps) rrect(pw(i), pd(i), 2);
            translate([0, 0, cradle_h + eps])
                linear_extrude(eps)
                    rrect(pw(i) + 2*lead_in, pd(i) + 2*lead_in, 2);
        }

    // connector pass-through up into the pocket floor
    translate([x, y, route_lo])
        linear_extrude(route_h + eps)
            rrect(plug_w, plug_d, 2);

    // right-angle housing cavity in the routing band
    translate([x, y, route_lo])
        linear_extrude(route_h)
            rrect(elbow_w, elbow_d, 2);

    // cable channel out the back, within the routing band
    translate([x - chan_w/2, y, route_lo])
        cube([chan_w, total_d/2 - y + eps, chan_h]);
}

// ---- weight well (filled with ballast) + press-fit cover recess -----------
// Bottom (z 0..cover_th): recess the cover presses into.
// Above (z cover_th..well_top): narrower fill cavity; the step is the ledge
// the cover seats up against.
module well_void() {
    // cover recess, open at the bottom
    translate([0, 0, -eps])
        linear_extrude(cover_th + eps)
            rrect(well_w, well_d, corner_r);
    // fill cavity (inset by the ledge so the cover has a seat)
    translate([0, 0, cover_th])
        linear_extrude(well_top - cover_th)
            rrect(well_w - 2*ledge, well_d - 2*ledge, corner_r);
}

// ---- engraved labels on the front face ------------------------------------
module labels() {
    for (i = [0:n-1])
        translate([px(i), -total_d/2 + label_depth, slab_h + cradle_h/2])
            rotate([90, 0, 0])
                linear_extrude(label_depth + eps, center = true)
                    text(cases[i][0], size = label_h,
                         halign = "center", valign = "center",
                         font = "Liberation Sans:style=Bold");
}

// ---- rubber-foot recesses on the bottom corners ---------------------------
module foot_recesses() {
    fxp = total_w/2 - foot_inset;
    fyp = total_d/2 - foot_inset;
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx*fxp, sy*fyp, -eps])
            cylinder(h = 0.8 + eps, d = foot_d);
}

// ---- parts ----------------------------------------------------------------
module dock() {
    difference() {
        shell();
        for (i = [0:n-1]) pocket_void(i);
        if (weight_well) well_void();
        if (show_labels) labels();
        if (feet) foot_recesses();
    }
}

module cover() {
    // presses into the recess, stops against the ledge
    linear_extrude(cover_th - 0.2)
        rrect(well_w - 2*cover_gap, well_d - 2*cover_gap, corner_r);
}

if (part == "dock")  dock();
else if (part == "cover") cover();
else { dock(); translate([0, total_d + 10, 0]) cover(); }
