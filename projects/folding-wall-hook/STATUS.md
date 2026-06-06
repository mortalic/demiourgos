# Where we left off — folding wall hook

_Last updated at commit `6eb3b30` (fold-up version, `paddle_clear = 0.5`)._

## Current design: FOLD-UP with a ledge load-stop

The hook now uses the **fold-up** layout (the one that can actually hold a load):

- Pivot is at the **bottom**; the paddle folds **UP** flush in the pocket and
  **covers the two mounting screws** (which sit high in the pocket floor,
  countersunk, hidden).
- Deploys **down to a horizontal peg**.
- A hanging **load pushes the tongue down onto a solid frame ledge** below the
  pivot — a hard stop (no flex to shear). **Folding lifts it back off the ledge**,
  so folding stays free. This is the realized form of the user's "stopper edge"
  idea (a raised underside edge would break the flat print; the ledge does the
  same job).
- Three parts: **frame, paddle, axle** (knurled 3 mm pin, or any 3 mm rod).

## State: WIP — printable to TEST, not yet polished

- ✅ Folds flush, hides the screws (verified by render).
- ✅ Deploys to a horizontal peg; ledge engages past 90° (verified by the
  `interference` sweep).
- ⚠️ **Mid-swing grazing** ~6 mm³ (~0.05 mm) in the rotation plane (tongue profile
  vs pocket front/back) — NOT the side gap (bumping `paddle_clear` didn't change
  it). Likely just slight friction; a print will tell.
- ⚠️ `dfm_check` flags (0.00 mm "wall", a near-flat frame facet) are the cosmetic
  teardrop-apex / feather class — the same kind the **first successful print** had.

## We were about to: TEST-PRINT on the Prusa XL

STLs in [`stl/`](stl/) at `paddle_clear = 0.5`. **Watch for:**
1. Folds flush and covers both screws.
2. Deployed peg **holds a downward pull** onto the ledge (the whole point of the
   flip — the detents sheared here on the previous version).
3. Folds back **without binding** (is the mid-swing rub just friction?).

To inspect the hidden base in OpenSCAD: set `part = "cutaway"` and sweep
`preview_deploy` (0 folded · 90 horizontal · 105 drooped onto the ledge). Also
`folding-wall-hook-viewer.html` (offline WebGL) and `renders/cutaway-deployed-*`.

## After the print

- If it holds and folds cleanly → **done**: refresh README/PRINT-TEST for fold-up,
  and `record_outcome` for Prusa XL / PLA so the tolerance engine learns the fit.
- If the swing binds → diagnose the rotation-plane grazing (tongue corner vs
  pocket front/back; likely a small chamfer or pocket-edge relief).

## How we got here (short history)

snap-in pins (can't assemble into a rigid pocket) → **separate axle** → drop-in
**lock pin** (worked, but a loose part) → **compliant ball detent** (UX win, but
**sheared under finger load** on the first print) → **friction hinge** (robust but
can't lock a load in fold-down) → **FOLD-UP + ledge** (current — the only layout
where a hard stop holds a downward load *and* still folds). The kinematic reason
fold-down can't hold a load is recorded in
[`docs/support-free-design.md`](../../docs/support-free-design.md#design-for-assembly--printed-hinges-and-pivots).
