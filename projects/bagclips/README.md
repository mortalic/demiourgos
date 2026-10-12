# Bag clips

Three single-piece, flat-printed bag clips, each a parametric copy of a
reference STL in `reference/` with the real mechanism (not just the outline):

| model | mechanism | std | large | xl | xxl |
|---|---|---|---|---|---|
| `bagclip_tongs` | serrated jaws closed at rest, open C spring loop, pinch handles | 37 x 17 x 10 | 93 x 25 x 15 | | |
| `bagclip_hairpin` | top loop spring, long serrated V jaws, splayed feet | 27 x 71 x 10 | 35 x 115 x 15 | 35 x 159 x 15 | 35 x 203 x 15 |
| `bagclip_serpentine` | zig-zag leaf spring feeding serrated jaws | 50 x 29 x 10 | 91 x 39 x 15 | | |

Each `.scad` has a `variant` switch (`"std"` or `"large"`, default large).
`stl/` holds every size. Large = longer jaws (more bag), 15 mm bite, thicker
arms and spring.

The hairpin is the favourite, so it also comes in `"xl"` and `"xxl"`: same
bite and arm thickness as large, only the jaw is longer (56 / 100 / 144 mm).
Longer legs are a softer spring, so the xxl grips a thin bag more gently than
the large; bump `arm_t` if it feels loose.

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
