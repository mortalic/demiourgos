// fit-check helper: one group of little_skeleton, selected by `pa`, posed by arm_a / leg_a
use <little_skeleton.scad>
pa = "torso";
arm_a = 5; leg_a = 5;
if (pa == "torso") torso();
else if (pa == "arms") arms_at(arm_a);
else if (pa == "legs") legs_at(leg_a);
