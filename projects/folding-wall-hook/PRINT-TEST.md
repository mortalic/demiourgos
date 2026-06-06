# Print-test note — verify the axle fit and the hinge friction

The pivot clearances and the **hinge friction** are calibrated-printer
assumptions, **not yet verified on a print**. Run this short test before trusting
them, and feed the result back into Demiourgos so the next design uses the real
numbers.

## The fits being checked

| Fit | Bore | Per-side clearance | Target feel |
|-----|------|--------------------|-------------|
| Axle in **frame** | `axle_d + 2*axle_fit` = **3.10 mm** | 0.05 mm | **friction** — presses in, doesn't back out on its own |
| Axle in **paddle** | `axle_d + 2*axle_clear` = **3.20 mm** | 0.10 mm | **snug — this is the hinge friction**; the paddle stays where set |
| Paddle in **pocket** | — | 0.40 mm | slides in, no slop that rattles |

Axle shaft = **3.0 mm**.

**The hinge friction is the unverified part.** The deployed paddle is held only by
how snugly it grips the axle, which depends on the print. Deploy it to horizontal
and check it **stays put under a light hang**, and that you can **fold it by hand**
without it being floppy or seized. Tune with:

| Symptom | Fix |
|---------|-----|
| Paddle is floppy / droops on its own | **decrease** `axle_clear` (tighter bore) |
| Too stiff to fold, or binds | **increase** `axle_clear` |
| Won't hold the weight you need | this layout is friction-limited — for a real load lock, flip to fold-up + a hard stopper |

PETG is a bit slicker/tougher than PLA for a friction bore.

## Procedure

1. **Coupon first (cheap).** Print `pin-fit-coupon.scad` (8 holes, 0.05–0.40 mm,
   3 mm peg) and a short 3 mm test peg — or just use a printed `axle`. Find the
   tightest hole the axle **slips** into and the tightest it **presses** into.
   - The *press* hole → your `axle_fit` (frame).
   - The *slip* hole → your `axle_clear` (paddle).
2. **Print the parts.** `frame`, `paddle`, `axle` (orientations are built in).
3. **Assemble and feel it:**
   - Push the axle through frame → paddle → frame. It should need a light press
     and **stay** (not slide back out when you let go or hang a load).
   - The paddle should **swing freely** end to end with no catch, and **no axial
     rattle**.
   - Folded, the paddle should sit flush; the finger-lip should let you flip it out.

## Pass / fail and what to change

| Symptom | Fix (in `folding-wall-hook.scad`) |
|---------|-----------------------------------|
| Axle falls out / spins in the frame | **decrease** `axle_fit` (tighter frame bore) |
| Axle won't start into the frame, or splits a wall | **increase** `axle_fit` |
| Paddle binds / stiff to swing | **increase** `axle_clear` |
| Paddle wobbles on the axle | **decrease** `axle_clear` |
| Paddle rattles side-to-side in the pocket | **decrease** `paddle_clear` |

Change in steps of **0.05 mm** and re-print only the affected part.

## Record the result (so the engine learns)

After you've found the fit you like, record it so every future design on this
printer/material reuses it instead of guessing:

```
record_outcome  printer=prusaxl  material=pla  fit_class=snug \
                measured_clearance_mm=<the press value you found>  verdict=good
```

Use `fit_class=slip` and the slip value for the rotating paddle bore. Then
`recommend_clearance` will return your calibrated numbers, and you can update
`axle_fit` / `axle_clear` / `paddle_clear` to match.

> Status: **awaiting first print.** Fill in once tested:
>
> - axle_fit (frame, press): `____ mm`  ·  axle_clear (paddle, slip): `____ mm`  ·  paddle_clear: `____ mm`
> - detent: nub_press `____ mm`  ·  finger_w `____ mm`  ·  feel (click/hold): `____`
> - printer / material: `____` / `____`  ·  date: `____`
