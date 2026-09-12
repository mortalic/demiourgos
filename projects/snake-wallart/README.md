# Ball python wall art

Two independent attempts at a ball python for the wall. The **wire piece is
done and printable**; the relief is parked.

| | file | status |
|---|---|---|
| Coiled wire line-art | `bp_coiled_wire.scad` | **done** — 297 × 225 × 4 mm, one connected piece, support-free |
| Low-poly head relief | `ballpython_head.scad` + `gen_head.py` | parked — machinery correct, sculpt never landed |

---

## 1. Coiled wire line-art (current)

A flat cut-through plate in the style of `reference/Snake_-_Had.stl`: the form is
described by flowing **parallel contour lines** of near-constant width with
generous open space between them. Head in profile on a raised neck, body coiling
below.

**297 × 225 × 4 mm**, 73.5 cm³, watertight, prints back-flat with **zero
overhangs** and an 18,400 mm² bed footprint. Minimum wall 3.2 mm.

### How it's built

The body lines are **generated, not hand-placed**. A centreline (`BODY`, eight
bezier segments) plus a half-width profile (`HW`) are offset along the normal:

```scad
function ribbon(frac, gmax = 1.0) = [ ... p + n * frac * hwi(g) ... ];
```

That is what produces true parallel flow through a curve. Hand-placed strokes
drift out of parallel on the bends and look wrong; this does not. `gmax` lets the
interior contours stop short of the tail so it tapers to a point instead of
filling in as a solid wedge.

Three things carry the piece:

1. **The head outline is an OPEN chain, not a closed loop.** A closed loop needs
   a rear closure, and since the body is contour lines rather than a filled
   shape, that closure stays visible and caps off the back of the skull. The
   curve instead runs from the body's inner edge forward along the jaw, around
   the blunt rostral, back over the crown, and lands on the body's outer edge.

2. **Every head line continues a body contour from its exact start point.** The
   body contours begin at `x = 160` with blunt caps; anything that merely ended
   *near* one left a visible stub floating in the open space between contours.
   The junction positions were solved numerically, not guessed:

   ```
   frac +1.0  head top line  -> (162.2,  34.9)
   frac +0.5  BROW           -> (161.1,  21.5)
   frac  0.0  CHEEK          -> (160.0,   8.0)
   frac -0.5  THROAT         -> (158.9,  -5.5)
   frac -1.0  head jaw line  -> (157.8, -18.9)
   ```

3. **Connectivity is verified, not assumed.** On a cut-through plate any stroke
   touching nothing falls out of the piece. See below.

### Connectivity — check this after every edit

The first export had **two** connected components: `{eye ring → cheek → centre
body contour}` was an island of 1876 triangles that would have dropped straight
out. The brow was passing 1.7 mm above the eye instead of landing on it.

Nothing in the render shows this. Check it explicitly:

```sh
openscad -o /tmp/bp.stl --export-format binstl projects/snake-wallart/bp_coiled_wire.scad
# then union-find over triangles sharing a welded vertex; must report 1 component
```

Watertight is **not** the same test — a floating island is perfectly watertight.

### Anatomy notes (from `reference/`)

- Head is **1.45:1 long-to-deep**. A ball python is not a colubrid; anything
  longer reads as a fish. This was the single most persistent error.
- The skull is a **brick with a rounded end** — flat crown, flat jaw, near-vertical
  rostral face. Letting the crown and jaw taper to a front point gives a teardrop,
  which reads as a dolphin.
- Eye is large (≈1/5 of head length), set forward and high, with the brow
  resting directly on it.
- **Labial pits** are the signature and the reason this reads as a ball python
  rather than a generic snake — the row of slots along the front of the upper
  lip, bright orange in the photos. Drawn as rungs between the two lip rails,
  front only (`PIT_T`).

### Hanging

**One hole**, at design `(132.4, 47.2)` → final x = −8.14 mm, against a centre of
mass at x = −8.52 mm. It hangs level off a single nail.

Two holes would be better for anti-rotation but there is no pair of points at
equal height either side of the balance point — the coil puts the mass well right
of the crown, and the crown is the only high ground. Rebalancing the composition
is the only way to get a second hanger.

### Print notes

Back flat on the bed, no supports. 73.5 cm³ — at 15 % infill expect roughly
60–80 g. A raking wall light is what makes line art work, so plan the hanging
spot for side light. `piece_w` scales the whole thing; 297 mm fits the 360 mm bed
with room to spare.

---

## 2. Low-poly head relief (parked)

`gen_head.py` authors the head as a single-valued height field `z = f(x, y)` over
the silhouette and emits a native OpenSCAD `polyhedron()`. Three decisions carry
it: height field (so no facet can face downward and it prints back-flat),
`polyhedron()` rather than an imported STL (OpenSCAD 2021.01 cannot boolean
imported meshes, so an STL would block the keyhole `difference()`), and one
closed shell rather than a union (a shared coincident face plus a zero-thickness
knife edge made CGAL silently drop the relief).

Two correctness passes run on every generate and both caught real bugs: a BFS
reorientation that also asserts every edge is used exactly twice, and a
height-field assertion that caught 1764 mm² of downward-facing facets from two
hand-triangulated regions overlapping in projection.

**The machinery is correct; the sculpt is not.** It reads as a faceted lump with
two eye bumps. It was built before the reference photos existed, on hand-guessed
coordinates — which is exactly why it stalled. The photos in `reference/` are now
what it always needed, if it's ever worth resuming.

Regenerate with:

    python3 projects/snake-wallart/gen_head.py workspace/bp_head_data.scad

---

## Reference

`reference/` holds the source material (gitignored — third-party, keep local):

- two head-on ball python photos — skull proportions, eye placement, labial pits
- a three-quarter coiled leucistic — head profile and the coiled pose
- `Snake_-_Had.stl` — the contour-line style target
