// fit-check helper: one positioned part of coffin_automaton at crank angle `al`
use <coffin_automaton.scad>
which = "torso";   // lid | torso | conrod | crank | handle | pins
al = 184;
if (which == "lid") pos_lid(al);
else if (which == "torso") pos_torso(al);
else if (which == "conrod") pos_conrod(al);
else if (which == "crank") pos_crank(al);
else if (which == "handle") pos_handle(al);
else if (which == "pins") pos_pins(al);
else if (which == "shaft") pos_shaft(al);
