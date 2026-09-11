// paperclip_sizes.scad — all three sizes laid out for a print plate / preview.
use <paperclip.scad>;

pitch = 30;   // y spacing between clips

module one(s) { paperclip_clip(s); }

translate([0,  pitch, 0]) one("l");
translate([0,  0,     0]) one("m");
translate([0, -pitch, 0]) one("s");
