# Dracula Rises — crank automaton coffin

Entry for the Printables "Halloween 2026: Make It Move" flash contest
(deadline 2026-11-01 23:59 UTC). A coffin candy box with a hand crank on the
side: turn it and the vampire sits up and pushes the lid open, then lies back
down and the lid falls shut. Status: **v1 designed, unprinted.**

![open](img/assembly_open.png)

## Mechanism

Crank-rocker four-bar, all pin joints, nothing relies on friction:

| link | value |
|---|---|
| crank throw `r` | 6.5 mm |
| conrod `c` | 30 mm |
| rocker arm `a` (hip pivot to conrod pin) | 14 mm |
| ground `g` (crankshaft to hip pivot) | 30 mm, crank 14 mm below the hip |
| torso swing | 0° (flat) to 55° |
| worst transmission angle | 56° |

The rocker arm is a pair of cheeks hanging 28° behind straight-down from the
hip pivot, so the bottom of the symmetric ±28° swing is "lying flat". The lid is
hinged at the foot end; the top corner of the head lifts it to about 24°. Both
torso directions are driven; only the lid closes by gravity.

![cutaway](img/cutaway.png)
![sweep](img/crank_sweep.png)

## Parts and print orientation

Every part exports (`part=`) in its print orientation and passed `dfm_check`
support-free. All pins are 1.75 mm filament.

| part | prints | notes |
|---|---|---|
| `box` | floor down | hip bosses locate the torso in Y; crank bearing boss + outer pad; hinge knuckles with 45° roofs and ribs down the foot end |
| `lid` | top up | centre knuckle, notches for the box knuckles, raised crescent moon (`moon_phase` = crescent \| quarter, `moon_rot`, `moon_bite`) |
| `torso` | face down | rocker cheeks point up; engraved face is crisp against the bed |
| `conrod` | flat | 4.4 mm big end on the crank stub, 2.2 mm small end |
| `crank` | web down | shaft and crank-pin stub stand vertical; D-flat for the handle |
| `handle` | flat | press-fit D-bore |

Pins: hip 60 mm, fork 12 mm, lid 26 mm.

## Assembly

1. Drop the torso in the box (cheeks toward the crank side), push the hip pin
   through from either side wall.
2. Hook the conrod's big end over the crank-pin stub, then feed the crankshaft
   out through the bearing boss from inside the box. The conrod is trapped
   between the web and the boss face.
3. Pin the conrod's small end between the torso's cheeks (12 mm pin).
4. Press the handle onto the D-shaft outside.
5. Lid on, pin through the three knuckles.

## Clearances (checked with `fit_check` over the crank cycle)

| pair | gap |
|---|---|
| torso ↔ box | 0.5 mm per side |
| conrod ↔ cheeks | 0.3 mm per side |
| conrod ↔ crank stub | 0.2 mm radial |
| crankshaft ↔ bore | 0.2 mm radial |
| handle ↔ flared side wall | 0.5 mm at the knob |
| lid ↔ head top (at rest) | 3.4 mm |

`coffin_box.scad`, `coffin_part.scad` and `coffin_part2.scad` are wrappers so
`fit_check` can pit the box against one positioned part (`which`, `al`) or two
positioned parts against each other (`which` vs `which2`). `-D` overrides do not
reach a `use`d file, which is the whole trick.

## Todo before entry

- Sculpt: a real vampire (cape, collar, widow's peak, two-tone pale face), coffin
  lid bevel and plank lines, crank knob as a skull or bone.
- Print on the XL in two colours (black box/cape, bone face), tune the hip and
  crank fits from the first print and record them as a profile.
- Photos, a short video loop, assembly steps for the listing.
