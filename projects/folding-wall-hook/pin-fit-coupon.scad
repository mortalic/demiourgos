// Demiourgos fit-test coupon — generated.
// Print once. For each labeled hole, try the reference peg; the tightest
// hole that gives the fit you want is your calibrated per-side clearance.
peg_d      = 5;
plate_t    = 4;
clearances = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4];
pitch      = 11.8;
n          = len(clearances);
plate_w    = 82.60000000000001;
plate_h    = 14;
label_size = 3;

module coupon_plate() {
    difference() {
        translate([-pitch/2, -plate_h/2, 0]) cube([plate_w, plate_h, plate_t]);
        for (i = [0:n-1])
            translate([i*pitch, plate_h*0.12, -1])
                cylinder(h = plate_t + 2, d = peg_d + 2*clearances[i], $fn = 72);
    }
    // Raised clearance labels.
    for (i = [0:n-1])
        translate([i*pitch, -plate_h*0.36, plate_t])
            linear_extrude(0.6)
                text(str(clearances[i]), size = label_size, halign = "center", valign = "center");
}

module reference_peg() {
    // Stands apart so it prints as its own body.
    peg_h = plate_t + 8;
    translate([plate_w/2 - pitch/2, plate_h, 0]) {
        cylinder(h = 1.5, d = peg_d + 6, $fn = 72);       // grip base
        cylinder(h = peg_h, d = peg_d, $fn = 72);          // the gauge pin
    }
}

coupon_plate();
reference_peg();
