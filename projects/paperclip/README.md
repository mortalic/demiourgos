# Printable paperclip — 3 sizes

A gem-style paperclip designed as a **planar flexure**, not as scaled-down wire.

## Why it holds up

The usual printed paperclip fails because it's a round wire profile printed
standing up: the bend load pulls straight across the layer bonds, and it
delaminates on the second use.

This one is a flat extrusion printed **lying on the bed**. Every extrusion line
runs along the wire path, so bending is carried by the filament itself and layer
adhesion is never loaded in tension. The spring action is out-of-plane elastic
flexure — paper wedges between the outer and inner loop and twists them apart in
Z, exactly how a steel gem clip works. Nothing yields to make it grip.

Section is wide in-plane, thin in Z: stiff against splaying sideways, compliant
in the one direction it has to spring. Grip force goes as `width x thickness^3`
while strain only goes as `thickness`, and the flexure is long — so the sections
below buy real clamping force at a large margin to yield.

The crossover bend (the spring, and the peak-moment point) is locally swollen
18%, blended to zero at both ends so it doesn't close the gap to its neighbour.
Free tips taper, and every edge carries a 45 deg chamfer so paper leads in
instead of catching.

## Sizes

| | envelope L x W x T (mm) | wire w x t (mm) | volume | grip @1 mm open | 1% strain at |
|---|---|---|---|---|---|
| `s` | 38.8 x 13.8 x 1.8 | 2.6 x 1.8 | 0.58 cm3 | 0.45 N | 2.2 mm open |
| `m` | 55.7 x 17.8 x 2.4 | 3.4 x 2.4 | 1.44 cm3 | 0.44 N | 3.5 mm open |
| `l` | 78.8 x 23.0 x 3.0 | 4.4 x 3.0 | 3.43 cm3 | 0.37 N | 5.8 mm open |

Reference: a steel #1 gem clip is about 0.7 N at 1 mm. These land near 60% of
that, and don't reach 1% surface strain (roughly a third of PETG's yield) until
they are spread 2.2 / 3.5 / 5.8 mm — call it 20 / 35 / 55 sheets.

Grip numbers are a first-order cantilever model that ignores the torsional
compliance of the legs, so the real part is somewhat softer and less strained
than the table says. They are for comparing the three sizes, not absolutes.

## Print

Flat on the bed as modelled. **No supports.** The only thing `dfm_check` flags
is the 45.0 deg edge chamfer itself — zero flat overhang, nothing bridged.

- PETG, ASA or nylon. PLA prints fine but is brittle and creeps under a
  sustained clamp load; it will take a set.
- 4+ perimeters, 100% infill — at this section it's all perimeter anyway.
- 0.2 mm layers or finer. Slow the first layer; the chamfer means layer 1 is
  narrower than layer 2.

## Files

- `paperclip.scad` — the model. `-D sz="s"|"m"|"l"`.
- `paperclip_sizes.scad` — all three laid out on one plate.
- `paperclip_{s,m,l}.stl`, `paperclip_plate_all3.stl` — exported, watertight.

## Tuning

Everything lives in `pc_params(sz)`: `[length, wire width, thickness, gap]`.
Thickness is the strength knob — force is cubic in it, strain only linear — but
it is also how far the clip stands proud of the paper, which is the real limit.
Wire width buys force at *zero* strain cost; it just makes the clip wider.
