# Pixel 9a rugged TPU case with credit-card recess

Own OpenSCAD design. Cutout positions were measured from Heimwerkerdad's
CC BY-SA 4.0 "Google Pixel 9a rugged case" (Printables 1358846); no geometry
from it is reused.

## The difference

A 0.9 mm deep pocket in the inner back face, sized for an ISO ID-1 card
(85.6 x 54 mm) with 0.3 mm clearance per side and a 14 mm fingernail notch
at its lower edge. The phone sits on top of the card and holds it. The back
is 2.4 mm thick so 1.5 mm of floor remains under the card.

Caveat: a card with a chip or magstripe between the phone and a Qi pad will
block wireless charging and may get its stripe degraded over time. Use a
dumb card (hotel key, transit, ID) or accept cable-only charging.

## Print

Modeled in print orientation: back face on the bed, opening up. Support-free
(the screen lip and camera chamfers are 45 deg; the port ceilings are
1.85 mm bridges). Previous case printed fine on the Troodon 300 in generic
TPU at 240 C, 0.12 mm layers, 3 walls, 15% gyroid.

## Key parameters (top of the .scad)

| param | value | note |
|---|---|---|
| `stretch` | 0.4 | cavity undersize for TPU grip, same as the reference |
| `back` | 2.4 | back thickness incl. recess floor |
| `card_depth` | 0.9 | 0.76 nominal card; embossed cards ~0.84 |
| `card_y` | -12 | recess center, toward the USB end, 13 mm clear of the camera pill |
| `mic_x` | -17.95 | bottom mic opening position is estimated, not measured |

Outer 76.6 x 158 x 13.3 mm (reference was 12.0 tall; +0.9 back, +0.4 rim).
