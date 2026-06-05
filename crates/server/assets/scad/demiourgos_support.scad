// demiourgos_support.scad — self-supporting primitives for support-free FDM.
//
// Demiourgos installs this into every workspace. Use it from a model with:
//     use <demiourgos_support.scad>;
//
// Build direction is +Z. These helpers make horizontal holes and pins
// self-supporting (a ≤45° apex at the top) so they print without supports.
// See docs/support-free-design.md for the design rules behind them.

// 2D teardrop profile: a circle of diameter `d` with a self-supporting apex
// pointing +Y. `ang` is the apex half-angle from vertical (45° = the standard
// self-supporting limit). Tangent sides, so no kink.
module teardrop_2d(d = 5, ang = 45, fn = 64) {
    r = d / 2;
    hull() {
        circle(r = r, $fn = fn);
        translate([0, r / sin(ang), 0]) circle(r = 0.05, $fn = 8);
    }
}

// A teardrop prism for a self-supporting HORIZONTAL HOLE. The apex points +Z
// (up), the axis runs along Y, and it is centered on the origin and `length`
// long. Subtract it from a wall to make a hole that needs no support:
//     difference() { wall(); translate([x, y, z]) teardrop_hole(d=6, length=20); }
module teardrop_hole(d = 5, length = 10, ang = 45, fn = 64) {
    translate([0, length / 2, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                teardrop_2d(d, ang, fn);
}

// A flat-topped HEXAGONAL hole (across-flats = `d`). The flat top is a short
// bridge and the upper facets sit at 30° from vertical, so it self-supports and
// fits hex hardware. Apex/flat at +Z, axis along Y, centered, `length` long.
module hex_hole(d = 6, length = 10) {
    translate([0, length / 2, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                circle(d = d / cos(30), $fn = 6);
}

// A horizontal PIN / trunnion with a teardrop cross-section so its underside is
// self-supporting. Extends +Y from the origin by `length`, apex +Z. Use in place
// of a plain `cylinder` for sideways pins:
//     translate([x, y, z]) support_pin(d=4, length=4);
module support_pin(d = 4, length = 4, ang = 45, fn = 64) {
    translate([0, length, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                teardrop_2d(d, ang, fn);
}

// A 45° CHAMFER prism to place under a horizontal ledge so the overhang becomes
// self-supporting. `w` wide (X), `length` long (Y), rising `h` in Z at 45°.
// Position its top edge at the ledge underside and subtract/union as needed.
module chamfer_45(w = 10, length = 10, h = 5) {
    // Right-triangle cross-section in X-Z (45°), extruded along Y.
    translate([0, length, 0])
        rotate([90, 0, 0])
            linear_extrude(height = length)
                polygon([[-w / 2, 0], [w / 2, 0], [w / 2, h]]);
}
