// td_dims.scad — shared geometry for the teardrop uke
scale_len   = 330.7;
saddle_y    = 80;
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
head_th     = 9;
tuner_d     = 7;
neck_end_y  = nut_y + head_len;

// ---- string / action geometry ----
fb_top      = body_depth + 6;                 // fretboard top plane (66)
fb_bot      = fb_top - fb_th;                  // 61
fret_top    = fb_top + fret_h;                 // fret crowns (66.9)
action_nut  = 0.5;
action_12   = 2.5;
nut_str_z    = fret_top + action_nut;          // 67.4
saddle_str_z = fret_top + 2*action_12 - action_nut;   // 71.4

module teardrop2d() {
    rb = bout_w/2; rt = neck_w/2; rm = rb*0.92; ym = body_len*0.42;
    hull() {
        translate([0, rb])            circle(rb);
        translate([0, ym])            circle(rm*belly + rb*(1-belly));
        translate([0, body_len - rt]) circle(rt);
    }
}
