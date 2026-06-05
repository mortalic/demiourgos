# Slicing notes — Prusa XL (PrusaSlicer) and Troodon 300 (OrcaSlicer 2.3.0)

These notes apply to **any model Demiourgos generates**. The STLs it exports are
already **pre-oriented to print support-free** (see
[support-free-design.md](support-free-design.md)) and assume a **dimensionally
calibrated** printer (the tolerance engine's clearances are only as good as your
flow/size calibration). What follows is the short list of slicer settings that
most affect whether a print *succeeds* — and where to find them in each slicer.

> TL;DR: get the **first layer**, **flow/dimensional accuracy**, and **cooling**
> right; leave **supports off**; bump **walls/infill** for load-bearing parts.

---

## The settings that decide success (both slicers)

### 1. First layer & bed adhesion — the #1 cause of failure
- **First layer height** 0.2–0.25 mm (≥ the nozzle's first-layer default). Thicker
  first layers stick better.
- **Z-offset / live-Z**: dial it in per machine. A first layer that's too high
  won't stick; too low and it clogs/warps. (The Prusa XL's loadcell probe makes
  this very repeatable; the Troodon needs a good manual/abl first layer.)
- **Brim** for tall/narrow or small-footprint parts (a 3–5 mm brim). Our parts are
  oriented for a large footprint, so a brim is usually optional.
- **Bed temp**: PLA 60 °C, PETG 70–80 °C, ABS/ASA 100–110 °C. Clean the sheet
  (IPA); use glue stick for PETG on smooth PEI to avoid over-adhesion.

### 2. Dimensional accuracy & fit — makes snap-fits actually fit
This is what the tolerance engine depends on. If parts come out tight/loose:
- **Flow rate / extrusion multiplier**: calibrate it (see per-slicer below).
  Over-extrusion shrinks holes and tightens fits.
- **XY size / horizontal expansion compensation**: a small negative value
  (−0.05 to −0.15 mm) shrinks outer walls if the printer prints "fat." Holes go
  the other way. Prefer fixing flow first, then this.
- **Elephant's foot compensation** 0.1–0.2 mm: trims first-layer bulge so the
  base isn't oversized (which throws off fits and flatness).
- Re-run a Demiourgos `gen_fit_coupon` → `record_outcome` after changing any of
  these; the learned clearance is per *calibrated* machine.

### 3. Part cooling — overhangs, small layers, bridges
- **Fan**: PLA 100%; PETG ~40–60% (more for overhangs, less for layer adhesion);
  ABS/ASA low (0–20%, enclosure). Good cooling is what lets the small round pin
  undersides and any short bridge print cleanly.
- **Minimum layer time / slow down for short layers**: keep on, so small features
  (pins, the finger lip) get time to cool.

### 4. Supports — off by default
- Our models are designed support-free, so **set supports to None**.
- If a slicer auto-flags a trivial overhang (e.g. the 4 mm trunnion pin
  undersides), it's negligible — print without support; cooling handles it.
- If you ever *do* need support on a custom overhang, use **support-on-build-plate
  only** and a 0.2 mm interface gap.

### 5. Walls & infill — strength for load-bearing parts
Hooks/brackets/arms carry bending load, which the **walls** (perimeters) resist
far more than infill:
- **Perimeters/walls**: 3–4 (the load-bearing default; 2 is fine for cosmetic).
- **Infill**: 20–30% for general parts; 40%+ or 4–5 walls for anything weight-bearing.
- **Top/bottom layers**: 4–5 so flat faces seal.
- Print load-bearing parts so the **load is across layers as little as possible**
  (Demiourgos `orientation_advisor` + `stress_check` help here — Z/layer-adhesion
  is the weak axis).

### 6. Seams & wall order (cosmetic + small strength)
- **Seam position**: "Rear" or "Aligned" hides the seam; "Random" spreads it.
- **External perimeters first** can improve dimensional accuracy of outer walls.

---

## Prusa XL (2 toolhead) — PrusaSlicer

The XL is very forgiving (loadcell first-layer probe, input shaper and pressure
advance auto-tuned by the printer), so first layers are reliable out of the box.

- **Start from the Prusa XL system presets** (Printer = *Original Prusa XL*,
  the *0.4 mm nozzle* variant) and the material preset for your filament — these
  carry correct temps, cooling, and the XL's machine limits. Don't hand-roll a
  printer profile.
- **First Layer Calibration** on the printer itself; trust the loadcell probe.
- **Print Settings ▸ Advanced**: *XY size compensation* and *Elephant foot
  compensation* live here if you need to tune fit.
- **Print Settings ▸ Layers and perimeters**: set perimeters and *Detect bridging
  perimeters* (on) for clean bridges; *Ensure vertical shell thickness* (on).
- **Supports**: *Support material* off for our parts.
- **Two toolheads**: a single-color part uses **one tool** — just assign the model
  to the loaded extruder; nothing special. For multi-color/multi-material, assign
  each part/extruder and enable a purge/wipe tower; expect more filament and time.
- Quick flow check: print a single-wall calibration cube (Vase mode, 0.45 mm
  wall) and measure; adjust the filament's *Extrusion multiplier* to hit the wall
  width.

## Troodon 300 — OrcaSlicer 2.3.0

The Troodon is not a turnkey machine like the XL, so **calibrate it once** in
Orca — this matters more here than on the Prusa.

- **Printer**: add the Troodon as a custom printer, bed **300 × 300**, height
  **400 mm** (adjust to your Z), 0.4 mm nozzle. Match the firmware flavor
  (Marlin → *Linear Advance*; Klipper → *Pressure Advance*).
- **OrcaSlicer Calibration menu** (do these in order, once per filament):
  1. **Flow Rate** (Pass 1 then Pass 2) — the biggest lever on fit/quality.
  2. **Pressure Advance / Flow Dynamics** — sharpens corners and hole roundness.
  3. **Temperature tower** — pick the temp with best layer adhesion + surface.
  4. **Max Volumetric Speed** — caps speed so the hotend keeps up.
  5. **Tolerance test** — confirms your snap-fit clearances on *this* machine.
- **Quality ▸ Precision**:
  - *Precise wall* (on) and the **Arachne** wall generator improve dimensional
    accuracy of thin/variable walls.
  - *Elephant foot compensation* 0.1–0.2 mm; *XY hole/contour compensation* only
    if flow calibration didn't fix fit.
  - *Slow down for overhangs* (on); optionally *Make overhang printable* for the
    odd steep face (it nudges overhang geometry, not your model).
- **Support**: *Don't generate support* for our parts; if needed, *On build plate
  only* + *Don't support bridges* (on) so short bridges print unsupported.
- **Strength**: walls 3–4, top/bottom 4–5, infill 20–40% per the table above.
- Bed adhesion: a smooth/textured PEI; brim for small parts; first layer dialed in
  with your ABL/Z-offset (no loadcell here, so verify the first layer visually).

---

## Per-print checklist

1. Right **printer + filament preset** loaded (XL system preset / Troodon
   calibrated profile).
2. **Supports: None** (our STLs are pre-oriented support-free).
3. **Walls/infill** matched to the part (load-bearing → 4 walls / ≥ 40%).
4. **Cooling** set for the material.
5. First **slice**, then run Demiourgos **`print_check`** for the time/filament
   estimate and a sanity check.
6. For functional fits, confirm the clearance with a **`gen_fit_coupon`** print and
   **`record_outcome`** before committing to the full part.
