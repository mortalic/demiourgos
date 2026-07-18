// td_dims.scad — shared geometry for the teardrop uke
scale_len   = 330.7;
saddle_y    = 64;   // bridge 16 lower (nearer the tail), like the reference; nut/frets follow
nut_y       = saddle_y + scale_len;
num_frets   = 12;
function fret_y(n) = nut_y - scale_len*(1 - pow(2, -n/12));

// ---- body ----
body_len    = 232;
bout_w      = 168;
neck_w      = 54;
body_depth  = 60;
belly       = 0.62;
wall_th     = 2.6;
soundhole_y = 150;   // kept where it was
soundhole_d = 46;
nb_start    = 192;

// ---- bridge ----
bridge_w    = 58;
bridge_len  = 22;
n_strings   = 4;
str_spacing = 12;

// ---- neck/body joint ----
tenon_w     = 22;
tenon_d     = 26;
tenon_len   = 28;
joint_clear = 0.2;

// ---- neck ----
nut_w       = 35.6;
fb12_w      = 44;
fb_th       = 5;
fret_h      = 0.9;
fret_w      = 1.7;
head_len    = 72;
head_w      = 56;
head_th     = 15;   // face-to-back at the tuner holes. At 9 the pegs stood too
                    // proud of the face and held the strings high off the frets;
                    // reference head is 15.6 where ours printed 11.6 → +4 (Jul 10);
                    // strings still rode high at the posts on that print → +2 more
                    // (Jul 18). Added on the BACK only — the plate extrudes downward
                    // from the face/pivot plane, so face and nut geometry are unchanged.
tuner_sleeve_od = 8;    // measured OD of the metal tuner bushing (calipers)
tuner_d     = tuner_sleeve_od + 0.3;   // snug (0.1/side) + 0.1 hole-undersize comp; a press
                                       // fit split a printed headstock — glue if loose
tuner_y0    = 19;   // nut-side tuner posts, local head y (0 = nut pivot)
tuner_pitch = 33.6; // post-to-post spacing along the head, per side. Test-fit
                     // history: 28 collided; 36.6 overshot the head edge (top
                     // plate screw off the end); Jul 9: down 4 / in 2; Jul 10
                     // final nudge: bottom pair down 1 (top pair y stays 52.6),
                     // top pair in 1 more
tuner_stagger = 3;   // tip-side pair inboard shift (see above)
nut_str_spacing = 9;    // string pitch at the nut (fans out to str_spacing=12 at the bridge)
nut_slot_w  = 1.4;      // nut string-slot width (nylon uke strings run 0.6-0.9)
nut_wall    = 1.6;      // nut material left above the slot floor
neck_end_y  = nut_y + head_len;

// ---- string / action geometry ----
fb_top      = body_depth + 6;                 // fretboard top plane (66)
fb_bot      = fb_top - fb_th;                  // 61
fret_top    = fb_top + fret_h;                 // fret crowns (66.9)
action_nut  = 0.5;
action_12   = 2.5;
nut_str_z    = fret_top + action_nut;          // 67.4
saddle_str_z = fret_top + 2*action_12 - action_nut;   // 71.4

// headstock: back-angled like the reference uke, so the strings break DOWN
// over the nut to the tuner posts. Pivots at the nut. head_angle is eyeballed
// ~13 deg off the reference STL (typical ukes 12-17); set it from the measured
// physical reference. (The volute on the back of the kink was removed — it
// blocked the mounting hardware of the nut-side pair of tuner pegs.)
head_angle  = 13;                               // headstock back-tilt (deg)

module teardrop2d() {
    rb = bout_w/2; rt = neck_w/2; rm = rb*0.92; ym = body_len*0.42;
    hull() {
        translate([0, rb])            circle(rb);
        translate([0, ym])            circle(rm*belly + rb*(1-belly));
        translate([0, body_len - rt]) circle(rt);
    }
}
