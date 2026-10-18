// fit-check helper: the coffin box's walls and floor with no mechanism
module coffin_2d(o = 0) offset(delta = o) polygon([[-60, -17], [24, -32], [60, -20], [60, 20], [24, 32], [-60, 17]]);
difference() { translate([0, 0, -2.4]) linear_extrude(34.4) coffin_2d(0); linear_extrude(33) coffin_2d(-2.4); }
