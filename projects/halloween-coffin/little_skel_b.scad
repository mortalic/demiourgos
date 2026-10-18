// fit-check helper: one group of little_skeleton, selected by `pb`, posed by arm_b / leg_b
use <little_skeleton.scad>
pb = "torso";
arm_b = 5; leg_b = 5;
if (pb == "torso") torso();
else if (pb == "arms") arms_at(arm_b);
else if (pb == "legs") legs_at(leg_b);
