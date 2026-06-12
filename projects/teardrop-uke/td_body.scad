include <td_dims.scad>
$fn = 120;

base_flat = 4;
brace_h   = 8;
brace_w   = 3.6;
brace_xs  = [-34, 0, 34];

module bridge() {
    base_h = saddle_str_z - body_depth - 4.5;   // base plate height (above soundboard)
    difference() {
        union() {
            translate([0, -1, 0]) linear_extrude(base_h)
                offset(r=3) square([bridge_w-6, bridge_len-6], center=true);
            linear_extrude(saddle_str_z - body_depth)            // saddle ridge -> string break height
                square([bridge_w-14, 2.4], center=true);
        }
        for (i = [0:n_strings-1])
            translate([(i-(n_strings-1)/2)*str_spacing, -bridge_len/2+5, -1])
                cylinder(h=base_h+2, d=2);
    }
}
module mortise() {
    tw = tenon_w + 2*joint_clear; td = tenon_d + 2*joint_clear;
    translate([-tw/2, body_len - tenon_len, body_depth/2 - td/2])
        cube([tw, tenon_len + 8, td]);
}
module feather2d(L = 150) {
    sh = 2.2;
    union() {
        polygon([[-sh/2,0],[sh/2,0],[0.4,L],[-0.4,L]]);
        for (i = [0:1:30]) {
            t = i/30; y = 7 + t*(L-14);
            bl = 24 * sin(180*t) * (1 - 0.30*t);
            for (s = [-1,1])
                translate([0,y]) rotate([0,0, 90 - s*40])
                    translate([0,-0.5]) square([max(bl,0.1), 1.0]);
        }
    }
}
module feather_engrave() {
    translate([6, 118, body_depth - 0.9 + 0.02])
        rotate([0,0, 32]) translate([0, -75]) linear_extrude(1.9) feather2d(150);
}
// gable cavity close: ridge near the soundboard so the down-facing slope is gentle (~32deg),
// the bulk of the close is a rising back floor (up-facing, no overhang). Soundhole stays clear.
module cavity_envelope() {
    yb = base_flat + wall_th;
    roof_y0 = 174;       // just above the soundhole top (~173)
    ridge_z = 46;        // ridge high (toward soundboard) -> gentle ceiling slope
    union() {
        translate([-200, yb, -1]) cube([400, roof_y0 - yb, body_depth + 2]);
        hull() {
            translate([-200, roof_y0, 0]) cube([400, 0.1, body_depth]);
            translate([-200, nb_start, ridge_z - 0.05]) cube([400, 0.1, 0.1]);
        }
    }
}
module cavity() {
    intersection() {
        translate([0, 0, wall_th]) linear_extrude(body_depth - 2*wall_th)
            offset(-wall_th) teardrop2d();
        cavity_envelope();
    }
}
module braces() {
    y0 = base_flat + wall_th + 2; y1 = 168;
    intersection() {
        for (bx = brace_xs)
            translate([bx - brace_w/2, y0, wall_th - 0.6])
                cube([brace_w, y1 - y0, brace_h + 0.6]);
        cavity();
    }
}
module body() {
    union() {
        difference() {
            union() {
                linear_extrude(body_depth) teardrop2d();
                translate([0, saddle_y, body_depth]) bridge();
            }
            cavity();
            translate([0, soundhole_y, body_depth - wall_th - 1])
                cylinder(h = wall_th + 2, d = soundhole_d);
            mortise();
            feather_engrave();
            translate([-200, -200, -10]) cube([400, 200 + base_flat, body_depth + 20]);
        }
        braces();
    }
}

rotate([90, 0, 0]) body();
