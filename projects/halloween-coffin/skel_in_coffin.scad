// preview: the little skeleton lying in a plain coffin shell (no mechanism)
// (the coffin outline is copied here: coffin_automaton.scad also has a torso() module)
use <little_skeleton.scad>
dx = -42;
module coffin_2d(o = 0) offset(delta = o) polygon([[-60, -17], [24, -32], [60, -20], [60, 20], [24, 32], [-60, 17]]);
module shell() difference() { translate([0, 0, -2.4]) linear_extrude(34.4) coffin_2d(0); linear_extrude(33) coffin_2d(-2.4); }
part = "both";   // both | shell | skel
if (part != "skel") color("DimGray") shell();
if (part != "shell") color("Ivory") translate([dx, 0, 0.2]) { torso(); arms_at(5); legs_at(5); }
