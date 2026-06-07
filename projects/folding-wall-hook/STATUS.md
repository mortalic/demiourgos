# Where we left off — folding wall hook

_Updated after the fold-up test print: added an **upward-tilt stop heel**
(`deploy_stop = 70`). Previous baseline was commit `6eb3b30`._

## Current design: FOLD-UP, peg rests TILTED UP on a paddle heel

The hook uses the **fold-up** layout (the one that can actually hold a load):

- Pivot is at the **bottom**; the paddle folds **UP** flush in the pocket and
  **covers the two mounting screws** (high in the pocket floor, countersunk).
- Deploys down and **rests at `deploy_stop` = 70° (≈20° above horizontal)** so
  hung items slide *toward* the wall instead of off the end. ← the fix from the
  test print, which deployed too flat / drooped.
- **Stop mechanism (heel on the paddle):** a heel on the paddle root, *in front of
  the pivot*, seats flat on the base ledge at `deploy_stop`. A downward load drives
  the heel *into* the solid base (compression, no shear); folding lifts it back
  off, so folding stays free. The heel is authored in the deployed frame and
  inverse-rotated into the paddle (`stop_heel_local`), so changing `deploy_stop`
  re-places it correctly — it's a one-line tune.
- Three parts: **frame, paddle, axle** (knurled 3 mm pin, or any 3 mm rod).

## State: WIP — reprint to verify the up-tilt stop

Verified in OpenSCAD via the `interference` volume sweep (`part="interference"`,
measure across `preview_deploy`):

- ✅ Folded (0°): **zero** paddle/frame overlap — folds fully in, heel protrudes
  ~0.5 mm past the front face (less than the 1.4 mm finger lip, so still flush-ok).
- ✅ Folding range 0–70°: flat ~6–9 mm³ light graze floor only (the pre-existing
  tongue-vs-base graze, ~0.05 mm).
- ✅ Past 70°: overlap climbs hard (8→14→22→29 mm³ at 71→75→80→85°), heel digging
  into solid base = the load stop at the up-tilt angle.
- ✅ `dfm_check` (paddle): steepest overhang 22.5°, "should print support-free."
- ⚠️ The 0.00 mm "wall" flag is the same cosmetic teardrop-apex/feather class the
  first successful print had.

## We were about to: REPRINT on the Prusa XL

STLs in [`stl/`](stl/) at `paddle_clear = 0.5`, `deploy_stop = 70`. **Watch for:**
1. Folds flush and covers both screws (heel nub ≤ finger lip, shouldn't catch).
2. Deployed peg **rests tilted up ~20°** and **holds a downward pull** — the heel
   bears on solid base.
3. Folds back **without binding** (is the mid-swing graze just friction?).

If the tilt is too shallow/steep, change **`deploy_stop`** (lower = more upward)
and re-export. To inspect the heel/base in OpenSCAD: `part="cutaway"` and sweep
`preview_deploy` (0 folded · 70 rest · 90 horizontal). `part="interference"` +
`measure` reads the actual stop engagement numerically.

## After the print

- If it holds tilted-up and folds cleanly → **done**: refresh README/PRINT-TEST,
  and `record_outcome` for Prusa XL / PLA so the tolerance engine learns the fit.
- If the swing binds → relieve the tongue front-bottom corner (the ~6 mm³ graze)
  with a small chamfer; the heel itself is the only intended hard contact.

## How we got here (short history)

snap-in pins (can't assemble into a rigid pocket) → **separate axle** → drop-in
**lock pin** (worked, but a loose part) → **compliant ball detent** (UX win, but
**sheared under finger load** on the first print) → **friction hinge** (robust but
can't lock a load in fold-down) → **FOLD-UP + ledge** (current — the only layout
where a hard stop holds a downward load *and* still folds). The kinematic reason
fold-down can't hold a load is recorded in
[`docs/support-free-design.md`](../../docs/support-free-design.md#design-for-assembly--printed-hinges-and-pivots).
