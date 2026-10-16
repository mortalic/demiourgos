# Low-poly ball python head — wall relief

**Status: pipeline done and verified, sculpt not there yet.** Read "Where this
stands" before printing anything.

## What it is

A faceted relief of a ball python head, front view, styled cute (enlarged eyes,
blunted snout, lifted mouth corner). Designed to hang flat on a wall.

Current default: **260 × 231 × 26 mm** (22 mm relief + 4 mm backer), 618 cm³,
two flush keyhole mounts in the back.

## How it's built

`gen_head.py` authors the head as a **single-valued height field** `z = f(x, y)`
over the silhouette and emits a native OpenSCAD `polyhedron()`.

Three decisions carry the whole thing:

1. **Height field, not free geometry.** If every `(x, y)` has exactly one `z`,
   then no facet can face downward, and the plaque prints back-flat on the bed
   with zero supports. This is enforced, not assumed — `build()` measures the
   downward-facing area of every facet and refuses to emit if any exists.

2. **`polyhedron()`, not an imported STL.** OpenSCAD 2021.01 cannot boolean
   imported meshes, so an STL would block the keyhole `difference()`.

3. **One closed shell, not a union.** Relief, silhouette wall and backer are a
   single manifold. The first attempt unioned a separate extruded plate onto the
   relief; the shared coincident face plus the zero-thickness knife edge at the
   silhouette made CGAL drop the relief entirely and silently emit only the
   plate. Building one shell removes both problems.

Two correctness passes run on every generate, and both caught real bugs:

- **Edge-manifold + orientation.** Regions are authored by hand and do not agree
  on winding. A BFS over face adjacency reorients everything consistently, then
  one global flip fixes the sign. It also asserts every edge is used exactly
  twice. Before this, the mesh was inconsistently wound, which is why the union
  silently dropped it.
- **Height-field assertion.** Caught 1764 mm² of genuinely downward-facing
  facets from two hand-triangulated regions that *overlapped in projection* —
  vertex `k1` sat inside the triangle next to it. Regions are now triangulated
  by ear clipping (`earclip()`), which cannot produce overlaps.

`dfm_check` independently confirms the result: *"No significant overhangs in
this orientation — should print support-free."* The 223 mm² it still reports is
the two keyhole pocket ceilings, which are short bridges over the bed and never
show.

## Where this stands

The machinery is correct and verified. **The sculpt is not good yet** — see
`renders/`. It currently reads as a faceted lump with two eye bumps, not as a
ball python. The silhouette and the feature placement are hand-guessed
coordinates, and blind coordinate-nudging is the wrong way to land anatomy.

Three rounds of tuning got the proportions roughly right (widened to ~1.3:1,
broadened the snout off its initial keel, sharpened the mouth crease) but it
needs a reference to go further. The productive next step is the tracing route
flagged at the outset: trace a head-on ball python photo to a vector outline,
use it to place the silhouette ring and the eye/nostril/mouth-corner positions,
and keep the existing generator underneath unchanged. Everything downstream —
manifold checks, height-field guarantee, keyholes, export — already works.

Specific things known to be weak:
- Silhouette is still too round; a ball python skull is a flatter-topped wedge.
- Eyes don't read. They need to be larger, set lower, and given a distinct rim.
- Chin is a flat fan — the two interior jaw points were dropped when regions
  moved to ear clipping, and should come back as a proper sub-region.
- No nostrils, no labial pits. Both are strong ball python cues.

## Files

- `gen_head.py` — the generator. Edit the `V` vertex table and `REGIONS`.
- `bp_head_data.scad` — generated; do not hand-edit.
- `ballpython_head.scad` — assembly: polyhedron + keyhole cuts.
- `ballpython_head.stl`, `renders/` — current state, for viewing.

Regenerate with:

    python3 projects/snake-wallart/gen_head.py workspace/bp_head_data.scad

## Print notes (once the sculpt is worth printing)

Back flat on the bed, no supports. 618 cm³ solid — at 15% infill expect roughly
150–200 g and a long print at this size; `scale` and `depth` in `gen_head.py`
take it down easily. Matte PLA or PETG; a raking wall light is what makes a
faceted relief work, so plan the hanging spot for side light.
