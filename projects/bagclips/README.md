# Bag clips

Three single-piece, flat-printed bag clips, each a parametric copy of a
reference STL in `reference/` with the real mechanism (not just the outline):

| model | mechanism | std | large | xl | xxl |
|---|---|---|---|---|---|
| `bagclip_tongs` | serrated jaws closed at rest, open C spring loop, pinch handles | 37 x 17 x 10 | 93 x 25 x 15 | | |
| `bagclip_hairpin` | top loop spring, long interleaved-tooth jaws, splayed feet | 27 x 71 x 10 | 37 x 117 x 15 | 37 x 161 x 15 | 37 x 205 x 15 |
| `bagclip_serpentine` | zig-zag leaf spring feeding serrated jaws | 50 x 29 x 10 | 91 x 39 x 15 | | |

Each `.scad` has a `variant` switch (`"std"` or `"large"`, default large).
`stl/` holds every size. Large = longer jaws (more bag), 15 mm bite, thicker
arms and spring.

The hairpin is the favourite, so it also comes in `"xl"` and `"xxl"`: same
bite as large, only the jaw is longer (56 / 100 / 144 mm).

### Hairpin v2 (grip)

The first print held a bag only loosely. Two causes, both fixed in v2:

- The jaws were parallel with 0.7 mm of clear gap, so a 0.2 mm bag slid in
  without deflecting the legs at all. Now the two rows of teeth (0.7 mm tall,
  2.5 mm pitch) sit half a pitch apart and overlap by 0.3 mm, leaving a
  0.35 mm zig-zag channel. The bag has to bend around every tooth, and the
  hold multiplies through each bend like a rope on a capstan. Slide the clip
  onto a folded bag edge from the side.
- The legs were too soft on the long sizes (stiffness goes with thickness^3
  over length^3). Arms are 4.5 mm on large and 5 mm on xl / xxl (std stays
  3 mm); the loop is the same thickness, radius 9 mm. Even at 5 mm the loop
  sees well under 1 % strain when the feet are opened 10 mm, so PLA is fine.
  Slice with 5 or more perimeters so the arms are solid wall.

## Maker's mark

Every clip carries the full `imakethingsforu.com` recessed 0.4 mm into its
broad outer face (Liberation Sans Bold; helpers in `bagclip_brand.scad`).
The mark is cut as a uniform-thickness skin under the letter prisms, so a
letter that wraps a corner keeps the same depth on both sides of the bend.
The size is computed from the flat faces available:

- large: one piece on the jaw face, ~3.9 mm; hairpin xl / xxl 6.75 mm.
- std: the jaw alone is too short, so the letters are laid out one by one
  along the clip's outer contour and wrap around the corners: tongs jaw ->
  rise -> handle (2.75 mm), hairpin leg -> jaw -> foot (4.5 mm), serpentine
  outer spring arm -> jaw (2.9 mm, with a gap where the spring arm's rounded
  end steps onto the jaw arm). Under 3 mm a 0.4 nozzle will struggle; use a
  0.25 nozzle or expect rough letters.

Set `brand = ""` to remove it.

## Two-colour (MMU) letters

Painting the recess floor in the slicer gives stringy, half-filled letters:
the 0.4 mm recess is thinner than one extrusion width. For a multi-material
print use `mmu/*_mmu.3mf` instead. Each is one object with two parts: the
body on extruder 1 and the letters on extruder 2, a flush 0.9 mm (two
perimeter) solid that replaces the recess. Open it in PrusaSlicer, assign
filaments, slice. Suggested settings: 0.1 mm layers on the std clips,
external perimeter width 0.4, Arachne with minimum perimeter width 50 %.

The parts come from the same `.scad` files: `part = "body"` and
`part = "letters"` (default `"all"` is the engraved single-colour clip).
`make_mmu.py` regenerates all eight 3MFs from OpenSCAD.

Print flat as modeled, no supports. The springs flex in-plane along the
layers, so PLA is fine; PETG is more forgiving.
