include <td_dims.scad>
$fn = 120;

base_flat = 4;
brace_h   = 8;
brace_w   = 3.6;
brace_xs  = [-34, 0, 34];

module tube(p1, p2, d) {
    hull() { translate(p1) sphere(d=d); translate(p2) sphere(d=d); }
}

// Bridge copied from the reference uke: TWO separate pieces on the soundboard.
//  - Saddle: a blade with flat top at crest, VERTICAL neck face (string breaks
//    over its neck-side top edge at saddle_y, edge rounded by an r=0.8 rod),
//    and a 45-deg wedge down the tail side (print-down is -y, ref used 38).
//  - Tie ledge: a block 1.7 lower, separated by a strip of bare soundboard;
//    flat top (no holes), vertical neck wall, 45-deg tail ramp. Per string a
//    straight ~7-deg tunnel runs from a hole in the neck wall (the set you see
//    from above, in the gap) out a hole low on the tail ramp (the underside
//    set) - knot sits on the ramp, string wraps the ledge corner then breaks
//    over the saddle.
module bridge() {
    crest = saddle_str_z - body_depth + 0.2;  // 11.6 local: sunk 0.2 into the board
    sc    = crest + saddle_wall;   // saddle top: saddle_wall above the string line, so
                                   // the slots cut back down to it (was shared with
                                   // the nut; the nut peaks went up 0.25 on Jul 23
                                   // and the saddle stayed put)
    sd    = 3.2;                   // saddle top depth
    gap   = 1.5;                   // bare soundboard between the two pieces
    lt    = crest - 1.7;           // tie ledge height
    ld    = 9.5;                   // ledge top depth
    wally = -(sd + crest + gap);   // ledge neck wall      (~ -16.3)
    rampy = wally - ld;            // ramp crest           (~ -25.8)
    footy = rampy - lt - 0.6;      // ramp foot, 0.6 below the base plane
    difference() {
        intersection() {
            union() {
                rotate([90,0,90]) translate([0,0,-35]) linear_extrude(70) {
                    // tail ramp foot stays at the old-45-deg point so the 1.5
                    // gap to the ledge survives the raised top; the ramp is now
                    // ~48 deg from horizontal — steeper than 45, still support-free
                    polygon([[0,-0.6],[0,sc],[-sd,sc],[-sd-crest-0.6,-0.6]]);
                    polygon([[wally,-0.6],[wally,lt],[rampy,lt],[footy,-0.6]]);
                }
                translate([35,-0.05,sc-0.75]) rotate([0,-90,0]) cylinder(h=70, r=0.8);
            }
            translate([0,0,-1]) linear_extrude(sc+2) offset(r=2)
                translate([0,(footy-0.3+0.9)/2]) square([48, 0.9-(footy-0.3)-4], center=true);
        }
        for (i = [0:n_strings-1]) {
            sx = (i-(n_strings-1)/2)*str_spacing;
            B = [sx, wally, 5.2];            // mouth on the neck wall (top set)
            A = [sx, footy+3.6, 3.0];        // mouth on the 45-deg ramp (under set)
            u = (A-B)/norm(A-B);
            tube(B - u*2, A + u*2, 1.8);
            // string guide channel (like the nut slots): notch the neck wall +
            // top corner, 0.9 deep (= tunnel radius, so the floor meets the
            // mouth), so the wrap stays aligned with its tunnel
            translate([sx - nut_slot_w/2, wally - 0.9, 5.0])
                cube([nut_slot_w, 3, lt + 2 - 5.0]);
            // saddle string channel (like the nut slots): the floor crowns at
            // the neck face (y=0 = saddle_y) at exactly the string line z=crest,
            // ramping 3 deg down toward the tail, so the string still bears on
            // the scale-length point at saddle_str_z and the slot only locates
            // it sideways. Behind the flat top the string lifts off onto the
            // 48-deg ramp corner on its way down to the tie-ledge tunnel.
            translate([sx, 0, crest]) rotate([3, 0, 0])
                translate([-nut_slot_w/2, -6, 0]) cube([nut_slot_w, 7.5, 6]);
        }
    }
}
module mortise() {
    tw = tenon_w + 2*joint_clear; td = tenon_d + 2*joint_clear;
    // pocket reaches the tenon's front face: that face is the neck's print-bed
    // plane at y=200 (see fb_y0 in td_neck.scad), 32 proud of the heel — NOT
    // tenon_len deep. A tenon_len-deep pocket bottomed out 4 early and held
    // the heel 4 off the body face.
    translate([-tw/2, 200 - joint_clear, body_depth/2 - td/2])
        cube([tw, body_len - 200 + joint_clear + 8, td]);
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
module cavity_envelope() {
    yb = base_flat + wall_th;
    roof_y0 = 174;
    ridge_z = 46;
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
                translate([0, saddle_y, body_depth - 0.2]) bridge();
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