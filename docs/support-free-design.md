# Designing for support-free FDM printing

A practical reference for designing parts that print with **no (or minimal)
support material** on FDM printers. Demiourgos uses these rules in three places:
they're summarized in the server's MCP instructions (so the assistant designs
with them), `dfm_check` turns detected overhangs into targeted advice from this
list, and `demiourgos_support.scad` provides ready-made self-supporting
primitives.

## The governing rule: 45° from vertical

A new layer is only stable if it overlaps enough of the layer below for
inter-layer adhesion to beat gravity. At a **45° overhang (measured from
vertical)** each layer still overlaps ~50% of the previous one — the practical
break-even. Steeper (closer to horizontal) and the overlap drops below 50%, so
the molten plastic sags, curls, or collapses.

- **Design rule:** keep down-facing surfaces **≤ 45° from vertical**. Steep walls
  are free; shallow ceilings are expensive.
- It's a guideline, not a law: good part cooling + PLA can reach ~60–65°, and
  some shops design to ~50°/70° on well-tuned machines. Treat **45°** as the safe
  default and anything past ~55° as "needs cooling or supports."

## The high-value design moves

These are the changes that remove supports, roughly in order of how often they
apply:

### 1. Chamfer undersides — never round them
A **45° chamfer is always self-supporting** and is the single most effective
change. Conversely, a **fillet/round on a *down-facing* edge is a trap**: at its
widest point it's a ~90° overhang and *will* need support. So:
- Replace a square overhang (a horizontal ledge) with a 45° chamfer underneath.
- Replace a **downward fillet** with a chamfer. (Top-facing fillets are fine —
  they only get easier layer by layer.)

### 2. Teardrop or hexagon horizontal holes
A round hole printed **horizontally** (axis parallel to the bed) has a 90°
overhang at its top. Reshape the top:
- **Teardrop** — add a 45° apex above the circle; the top is now self-supporting.
- **Hexagon / diamond** — flat-topped at ≤45° facets; easier to model, fits
  hex hardware.
- Most worthwhile for holes ≳ 6–10 mm. Keep holes ≥ ~2 mm or they close up.

### 3. Prefer flat bridges over sloped/curved ceilings
A **flat span between two anchors** (a bridge) prints unsupported because the
filament is pulled taut. Short bridges are reliable; long ones (cited up to
~50–100 mm with strong cooling) get risky. If a cavity must have a ceiling, make
it a **flat bridge**, not a dome or a slope below 45°.

### 4. Sacrificial bridge layer
For an enclosed horizontal hole or pocket, design a **1–2 layer-thick membrane**
that bridges the gap, then drill/pop it out after printing. Built-in support you
control, with no support-interface scarring on the real surfaces.

### 5. Orientation first (the cheapest fix)
Before changing geometry, change **which face touches the bed**. Reorient so the
large down-facing areas become vertical walls or top surfaces; print dome-topped
shapes flat-side-down. Demiourgos's `orientation_advisor` ranks the six
axis-aligned orientations by overhang area.

### 6. Staircase progression
Step each successive layer slightly wider than the one below so it's partially
supported — a series of small self-supporting steps instead of one big overhang.

### 7. Split and join
If an overhang is unavoidable in one piece, **split the part** at the overhang so
each half prints flat-face-down, then glue, bolt, or snap them together.

## Secondary rules

- **Minimum wall:** ≥ 2 extrusion widths (~0.8–0.9 mm at a 0.4 mm nozzle).
- **Base chamfer / elephant's foot:** a tiny chamfer (~first-layer + layer
  height, ≈ 0.3–0.5 mm) on bottom edges counters first-layer bulge.
- **Pins/trunnions** are horizontal cylinders → their underside is a 90°
  overhang. Give them a **teardrop cross-section** or a chamfered/conical lower
  half, or move the pivot pins to the mating part and **teardrop the sockets**.

## What this means for a part like the folding hook's paddle

The paddle needs support from two things, each with a fix above:
1. **Trunnion pins** (horizontal cylinders) → teardrop the pin cross-section or
   move the pins to the frame and teardrop the paddle's sockets (rule 2 / pins).
2. **Rounded edges on the down-facing face** → chamfer them, or reorient so the
   rounded profile is vertical (rules 1 / 5).

## Design for assembly — printed hinges and pivots

A part can be perfectly printable and still be **impossible to assemble**. Check
the assembly path before committing to a joint:

- **A snap-fit only works if something can flex.** Integral snap pins need a thin,
  cantilevered wall (a slot or a clip arm) to spring over the mating feature. Pins
  that snap into a **rigid pocket** (thick walls backed by solid material) won't
  go in — there's nothing to deflect. Rule of thumb: a snap arm should be a thin
  finger several times longer than the interference it has to clear, not a solid
  wall.
- **Rotating bearings must stay round.** You can't teardrop or chamfer the *bearing*
  surface of a pin/socket that turns — it would bind. Teardrop the **hole** (the
  round part bears, the apex is just self-supporting clearance above); keep the
  pin/axle round.
- **The default robust pivot is a separate axle.** For a rotating joint between two
  rigid printed parts, drop one part into the other with clearance, then push a
  **separate axle** through aligned (teardrop) bores — a printed headed pin, or a
  rod / filament / paperclip. It assembles every time, prints support-free (the
  axle stands on its head; the bores self-support), and sidesteps the snap-flex
  problem entirely.
- **Quick check:** for an integral-pin joint, compare *(how far the feature must
  deflect)* against *(how much the wall can actually flex)* and *(the lateral play
  available to angle parts in)*. If the deflection wins, switch to a separate axle
  or add a real flex slot.

This is why the folding-hook pivot uses a separate axle: its integral pins needed
~3 mm of wall deflection into a rigid 6 mm pocket with only ~0.8 mm of play — it
could never have gone together.

## Out of scope (but worth knowing)

- **Topology optimization with overhang constraints** generates self-supporting
  geometry by construction — powerful but not an OpenSCAD-server feature.
- **Non-planar / horizontal-overhang slicers** are an active area; they change
  *how* a part is sliced rather than its design.

## Sources

- The 45° rule and its physics —
  [Snapmaker](https://www.snapmaker.com/blog/45-degree-rule-3d-printing/),
  [Aleader](https://www.aleader-china.com/blog/45-degree-rule-3d-printing-design-guide/).
- Support-free design strategies (chamfers, orientation, splitting) —
  [3dx.info](https://3dx.info/mastering-overhangs-design-strategies-for-support-free-3d-printing/),
  [Wevolver](https://www.wevolver.com/article/3d-print-overhang).
- Engineering thresholds (overhang/bridge/wall numbers) —
  [Hydra Research design rules](https://www.hydraresearch3d.com/design-rules).
- Teardrop holes and bridging —
  [3D Printerly](https://3dprinterly.com/how-to-3d-print-holes-without-supports-is-it-possible/),
  [Zbotic](https://zbotic.in/3d-printing-overhangs-without-supports-bridging-tricks-that-actually-work/).
- Self-supporting topology optimization —
  [JCDE 2022](https://academic.oup.com/jcde/article/9/2/364/6537182),
  [Springer (overhang constraint)](https://link.springer.com/article/10.1007/s00158-018-2010-7).
