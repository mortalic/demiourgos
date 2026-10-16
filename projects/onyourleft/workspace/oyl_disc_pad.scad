// oyl_disc_pad.scad — disc pad with center stud (part04, exact recreation)
// Recovered from mesh: 18-sided polygon (original is faceted; raise $fn to smooth,
// but $fn=18 with these vertex radii reproduces the original mesh exactly).
// Local frame: axis = +Z, bottom face at z=0, axis at origin.

fn      = 18;       // 18 matches the original faceting
r_disc  = 14.7155;  // disc vertex radius
h_disc  = 2.4820;   // disc rim height
z_cone  = 4.9640;   // z where cone meets stud
r_stud  = 2.4718;   // stud vertex radius
h_total = 11.0380;  // total height

module disc_pad() {
    rotate_extrude($fn = fn)
        polygon([
            [0, 0],
            [r_disc, 0],
            [r_disc, h_disc],
            [r_stud, z_cone],
            [r_stud, h_total],
            [0, h_total]
        ]);
}

disc_pad();
