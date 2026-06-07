// pursehanger — over-the-table-edge bag hook, modeled closely on the reference
// "comma/spiral" design. A long flat TONGUE rests on the tabletop; the body
// curls down and forward over the front edge in a big arc; the bottom HOOK curls
// back toward the table so the bag's weight sits near the edge line. That keeps
// the load close to the front-edge fulcrum, pressing the tongue DOWN onto the
// table (it grips) instead of levering it up and off.
//
// Tapered profile (thick through the loaded middle, thin at both tips), like the
// reference. PRINT as modeled: side profile extruded along +Z -> support-free,
// and the bag load bends it in-plane along the layers (no delamination).

/* [Profile] */
thk_mid = 9.0;    // ribbon thickness at the loaded middle
thk_tip = 3.6;    // thickness at the two tips (tongue tip, hook tip)
width   = 14;     // width across (Z)

/* [Geometry] */
reach   = 50;     // tongue length on the tabletop (counter-lever — keep it long)
r_body  = 26;     // radius of the main comma loop
hook_r  = 13;     // bottom bag-hook radius
hook_sweep = 205; // bottom hook wrap (>180 curls the tip back toward the table)

$fn = 64;

function arc(c, r, a0, a1, n) =
  [ for (i=[0:n]) [ c[0] + r*cos(a0 + (a1-a0)*i/n),
                    c[1] + r*sin(a0 + (a1-a0)*i/n) ] ];

// centerline (X = onto the table, Y = up; front edge corner at origin)
centerline = concat(
  [ [reach, 0] ],                                   // tongue (back end on the table)
  arc([0, -r_body], r_body, 90, 270, 44),          // over the edge + front-bulging body
  arc([hook_r, -2*r_body], hook_r, 180, 180 + hook_sweep, 26) // bottom hook, curling back
);

np = len(centerline);
// thick in the middle, thin at the tips
function thk_at(i) = thk_tip + (thk_mid - thk_tip) * sin(180 * i / (np - 1));

module ribbon() {
  for (i = [0 : np-2])
    hull() {
      translate(centerline[i])   circle(d = thk_at(i));
      translate(centerline[i+1]) circle(d = thk_at(i+1));
    }
}

module pursehanger() { linear_extrude(height = width) ribbon(); }

pursehanger();
