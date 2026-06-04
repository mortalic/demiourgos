// dovetail-bin — a small parametric open-top tray with a dovetail mounting key.
//
// Used by Demiurge's docs and integration tests. The outer envelope is a clean
// `width × depth × height` box so its bounding box is easy to assert; the
// dovetail key is carved as a slot so it does not change the outer dimensions.

// --- Parameters --------------------------------------------------------------
width  = 40;   // X
depth  = 30;   // Y
height = 20;   // Z
wall   = 2;    // wall / floor thickness

dovetail_width  = 10;  // wide edge of the dovetail slot
dovetail_throat = 6;   // narrow edge of the dovetail slot
dovetail_depth  = 4;   // how deep the slot cuts into the back wall

// --- Helpers -----------------------------------------------------------------
module dovetail_slot() {
    // A trapezoidal prism (the classic dovetail cross-section), oriented to cut
    // into the +Y back wall and extruded vertically.
    translate([0, 0, wall])
        linear_extrude(height = height)
            polygon(points = [
                [-dovetail_width / 2,  0],
                [ dovetail_width / 2,  0],
                [ dovetail_throat / 2, dovetail_depth],
                [-dovetail_throat / 2, dovetail_depth],
            ]);
}

// --- Model -------------------------------------------------------------------
module dovetail_bin() {
    difference() {
        // Outer solid.
        cube([width, depth, height]);

        // Open-top cavity.
        translate([wall, wall, wall])
            cube([width - 2 * wall, depth - 2 * wall, height]);

        // Dovetail slot cut into the back wall (at y = depth).
        translate([width / 2, depth - dovetail_depth, 0])
            dovetail_slot();
    }
}

dovetail_bin();
