# Print-test note — verify the axle fit

The pivot clearances are **calibrated-printer assumptions, not yet verified on a
print**. Run this short test before trusting them, and feed the result back into
Demiourgos so the next design uses the real numbers.

## The fits being checked

| Fit | Bore | Per-side clearance | Target feel |
|-----|------|--------------------|-------------|
| Axle in **frame** | `axle_d + 2*axle_fit` = **3.10 mm** | 0.05 mm | **friction** — presses in, doesn't back out on its own |
| Axle in **paddle** | `axle_d + 2*axle_clear` = **3.60 mm** | 0.30 mm | **free rotation** — paddle swings with no bind |
| Lock pin in **paddle** | `lock_d + 2*lock_clear` = **3.20 mm** | 0.10 mm | **snug** — drops in, minimal slop under load |
| Lock pin in **frame** | `lock_d + 2*lock_fit` = **3.15 mm** | 0.075 mm | snug, holds the deployed angle |
| Paddle in **pocket** | — | 0.40 mm | slides in, no slop that rattles |

Both pins are **3.0 mm** shafts (the axle and lock pin are interchangeable).

**Also check the lock engagement:** with the paddle deployed to horizontal, the
paddle and frame lock bores should line up so the lock pin drops straight through
all three (frame → paddle hub → frame). If they're offset, nudge `lock_angle` or
`lock_r`. Loaded, the paddle should not rotate — the lock pin takes it in shear.

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

> Status: **awaiting first print.** Fill in the measured values here once tested:
>
> - axle_fit (frame, press): `____ mm`  ·  axle_clear (paddle, slip): `____ mm`  ·  paddle_clear: `____ mm`
> - printer / material: `____` / `____`  ·  date: `____`
