// pursebase — parametric crochet / knit bag BASE PLATE with a perimeter ring of
// holes you crochet the bag body up through. Modeled after common PU-leather
// bases. Three stock sizes (cm): S 18x7, M 23x7.5, L 28x10.
//
// Prints flat on the bed, support-free (it's a perforated plate). Large flat
// part -> use a brim and good adhesion to avoid warping, especially size L.

/* [Size] */
size = "M";        // [S, M, L, custom]

/* [Custom size — used only when size = custom] */
cust_len = 230;    // length X (mm)
cust_wid = 75;     // width  Y (mm)

/* [Plate] */
thickness   = 3.0;     // plate thickness (stiffness)
corner_frac = 0.20;    // outer corner radius as a fraction of width

/* [Holes] */
hole_d      = 5.0;     // crochet hole diameter (hook + yarn)
edge_margin = 6.0;     // hole-center inset from the outline edge
hole_pitch  = 11.0;    // target spacing between holes along the perimeter
hole_chamfer= 0.8;     // 45deg chamfer at each hole face (so it can't saw yarn)

$fn = 48;

// ---- size table (length X, width Y in mm) ----
plate_len = size=="S" ? 180 : size=="M" ? 230 : size=="L" ? 280 : cust_len;
plate_wid = size=="S" ?  70 : size=="M" ?  75 : size=="L" ? 100 : cust_wid;
rc = min(plate_len, plate_wid) * corner_frac;   // outer corner radius

// ---- inset rounded-rect path the hole centers sit on ----
Lh = plate_len - 2*edge_margin;
Wh = plate_wid - 2*edge_margin;
rh = max(1, rc - edge_margin);
a  = Lh/2;  b = Wh/2;
sl_h = 2*(a - rh);     // top/bottom straight run
sl_v = 2*(b - rh);     // left/right straight run
sa   = (PI/2)*rh;      // quarter-arc length
perim = 2*sl_h + 2*sl_v + 4*sa;
nholes = max(8, round(perim / hole_pitch));

// cumulative segment boundaries around the path
c1=sl_h; c2=c1+sa; c3=c2+sl_v; c4=c3+sa; c5=c4+sl_h; c6=c5+sa; c7=c6+sl_v;

// arc-length s -> [x,y] on the inset rounded-rect (centered at origin), CCW
function prr_point(s) =
  s < c1 ? [ -(a-rh) + s, -b ] :
  s < c2 ? let(t=s-c1, an=-90 + (t/sa)*90) [ (a-rh)+rh*cos(an), -(b-rh)+rh*sin(an) ] :
  s < c3 ? let(t=s-c2) [ a, -(b-rh)+t ] :
  s < c4 ? let(t=s-c3, an=  0 + (t/sa)*90) [ (a-rh)+rh*cos(an),  (b-rh)+rh*sin(an) ] :
  s < c5 ? let(t=s-c4) [ (a-rh)-t, b ] :
  s < c6 ? let(t=s-c5, an= 90 + (t/sa)*90) [ -(a-rh)+rh*cos(an), (b-rh)+rh*sin(an) ] :
  s < c7 ? let(t=s-c6) [ -a, (b-rh)-t ] :
           let(t=s-c7, an=180 + (t/sa)*90) [ -(a-rh)+rh*cos(an), -(b-rh)+rh*sin(an) ];

module rrect(w, d, r) { offset(r) offset(-r) square([w, d], center=true); }

// through hole + a 45deg chamfer at the top and bottom faces
module hole_cutter() {
  cylinder(d=hole_d, h=thickness+2, center=true);
  translate([0,0, thickness/2 - hole_chamfer])
    cylinder(d1=hole_d, d2=hole_d+2*hole_chamfer, h=hole_chamfer+0.01);
  translate([0,0,-thickness/2 - 0.01])
    cylinder(d1=hole_d+2*hole_chamfer, d2=hole_d, h=hole_chamfer+0.01);
}

module pursebase() {
  difference() {
    linear_extrude(thickness, center=true) rrect(plate_len, plate_wid, rc);
    for (i = [0:nholes-1])
      let(p = prr_point(i*perim/nholes))
        translate([p[0], p[1], 0]) hole_cutter();
  }
}

echo(size=size, plate_len=plate_len, plate_wid=plate_wid, holes=nholes, pitch=perim/nholes);
pursebase();
