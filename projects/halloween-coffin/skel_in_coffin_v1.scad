// preview: the little skeleton at 88% lying in the FIRST crank coffin box (bosses, no crank parts)
// include (not use) so `sc` can be overridden; part = "none" silences the included output
include <little_skeleton.scad>
use <coffin_v1.scad>
sc = 0.88;
part = "none";
color("DimGray") box();
color("Ivory") translate([-27, 0, 0.2]) { torso(); arms_at(5); legs_at(5); }
