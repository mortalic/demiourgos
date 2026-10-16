// fit-check helper #2: a second positioned part of coffin_automaton (variable `which2`)
use <coffin_automaton.scad>
which2 = "conrod";   // lid | torso | conrod | crank | handle | pins
al = 184;
if (which2 == "lid") pos_lid(al);
else if (which2 == "torso") pos_torso(al);
else if (which2 == "conrod") pos_conrod(al);
else if (which2 == "crank") pos_crank(al);
else if (which2 == "handle") pos_handle(al);
else if (which2 == "pins") pos_pins(al);
