include <td_dims.scad>
$fn = 64;

fb_y0   = 196;
heel_y0 = 232;     // heel front = body neck-end face
heel_y1 = 270;     // heel back (blends into shaft)
neck_d  = 16;

function fbw(y) = nut_w + (fb12_w + 2 - nut_w) * (nut_y - y) / (nut_y - fb_y0);

module fretboard() {
    hull() {
        translate([0, fb_y0, fb_bot]) linear_extrude(fb_th) square([fbw(fb_y0), 0.1], center=true);
        translate([0, nut_y,  fb_bot]) linear_extrude(fb_th) square([nut_w, 0.1], center=true);
    }
}
module frets() {
    for (n = [1:num_frets]) {
        y = fret_y(n);
        translate([0, y, fb_top]) linear_extrude(fret_h) square([fbw(y) - 2, fret_w], center=true);
    }
    // nut: top sits at the string height (low action over the 1st fret)
    translate([0, nut_y, fb_top]) linear_extrude(nut_str_z - fb_top) square([nut_w, 3], center=true);
}
module shaft() {
    intersection() {
        hull() {
            translate([0, heel_y1, fb_bot]) scale([fbw(heel_y1)/2, 1, neck_d])   rotate([-90,0,0]) cylinder(h=0.01, r=1);
            translate([0, nut_y,   fb_bot]) scale([nut_w/2+1,     1, neck_d-2]) rotate([-90,0,0]) cylinder(h=0.01, r=1);
        }
        translate([-100, 0, fb_bot - 200]) cube([200, 1000, 200]);
    }
}
// rounded "Spanish" heel: smooth hull from the shaft down to a rounded toe at the body
module heel() {
    hull() {
        translate([0, heel_y1, fb_bot - neck_d/2]) scale([fbw(heel_y1)/2, 5, neck_d/2]) sphere(r=1);
        translate([0, heel_y0 + 3, 28])            scale([fbw(heel_y0)/2 - 1, 7, 14])   sphere(r=1);
    }
    // tenon (precise box for the joint) protruding -Y into the body mortise
    translate([0, (201 + heel_y0)/2, body_depth/2])
        cube([tenon_w, heel_y0 - 201 + 2, tenon_d], center=true);
}
module headstock() {
    difference() {
        hull() {
            translate([0, nut_y - 10, fb_bot]) linear_extrude(head_th) square([nut_w, 0.1], center=true);
            translate([0, neck_end_y, fb_bot]) linear_extrude(head_th) square([head_w, 0.1], center=true);
        }
        for (sx = [-1, 1], sy = [0, 1])
            translate([sx*head_w*0.22, nut_y + 20 + sy*28, fb_bot - 1])
                cylinder(h = head_th + 2, d = tuner_d);
    }
}
module neck() {
    union() { fretboard(); frets(); shaft(); heel(); headstock(); }
}

rotate([90, 0, 0]) neck();
