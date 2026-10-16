// oyl_mount_tab.scad — slotted mounting tab with bent foot (part03, exact recreation)
// Sheet-metal-style part: a plan footprint (rounded corners, slanted foot tip,
// slot) bent along its length. Built as the intersection of two extrusions:
//   1. the plan footprint (minus slot) extruded vertically, and
//   2. the bend profile (a mid-width cross-section) extruded across the width.
// Exact because the side walls are vertical and the bend is uniform across X.
// Local frame: origin at bbox min; width 40.0 along X, length along Y, bend in Z.

width = 40.0004;

// plan footprint, projected from the mesh
outline = [
    [0.0000, 121.2547], [0.4113, 123.3196], [0.9668, 124.6630], [2.1372, 126.4133],
    [3.5869, 127.8634], [5.3374, 129.0333], [6.6807, 129.5894], [8.7453, 130.0005],
    [31.2541, 130.0005], [33.3186, 129.5894], [34.6630, 129.0333], [36.4135, 127.8634],
    [37.8632, 126.4133], [39.0326, 124.6630], [39.5891, 123.3196], [40.0004, 121.2547],
    [40.0004, 0.0000], [0.0000, 4.3799]
];

// slot hole
slot = [
    [22.0279, 79.8555], [23.8674, 80.6170], [24.6347, 81.3854], [25.3969, 83.2245],
    [25.3969, 111.4683], [24.6347, 113.3074], [23.8674, 114.0753], [22.0279, 114.8373],
    [18.7664, 114.8373], [16.9268, 114.0753], [16.1585, 113.3074], [15.3974, 111.4683],
    [15.3974, 83.2245], [16.1585, 81.3854], [16.9268, 80.6170], [18.7664, 79.8555]
];

// bend profile in (Y,Z), sectioned at mid-width
bend_profile = [
    [126.2850, 3.3322], [131.0000, 3.3322], [131.0000, 6.0807], [36.7940, 6.0807],
    [35.3455, 5.9635], [34.4176, 5.8125], [33.0073, 5.4645], [26.7241, 3.3646],
    [25.3134, 3.0166], [24.3854, 2.8656], [22.9375, 2.7484], [-1.0000, 2.7484],
    [-1.0000, 0.0000], [22.9375, 0.0000], [24.3854, 0.1172], [25.3134, 0.2682],
    [26.7241, 0.6161], [33.0073, 2.7161], [34.4176, 3.0641], [35.3455, 3.2150],
    [36.7940, 3.3322], [125.0757, 3.3322]
];

module mount_tab() {
    intersection() {
        translate([0, 0, -1])
            linear_extrude(height = 6.081 + 2)
                difference() {
                    polygon(outline);
                    polygon(slot);
                }
        translate([-0.5, 0, 0])
            rotate([90, 0, 90])
                linear_extrude(height = width + 1)
                    polygon(bend_profile);
    }
}

mount_tab();
