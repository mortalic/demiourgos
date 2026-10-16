# Pebble Time 2 charging dock v2 — weighted false-bottom drawer

A remix of **"Pebble Time 2 / Pebble 2 Duo - Charging Stand"** by **snrkl**,
<https://www.printables.com/model/1784934-pebble-time-2-pebble-2-duo-charging-stand>
(published 2026-07-19, GNU General Public License v3.0).

The original stand is light enough that pulling the watch off lifts it. This
remix adds a weight plate to the face the dock stands on, with a sliding tray
that holds six small steel weights behind a false bottom. The band loop, the
facet, the charger slot and the watch-back recess of the original are untouched.

## Files

| file | what |
|---|---|
| `pebblechargingdock_v7_oriented.stl` | snrkl's original dock, re-oriented base-down and axis-aligned (unmodified geometry) |
| `pebble_dock_v2.scad` | the weight plate (`part="plate"`) and the drawer tray (`part="tray"`) |
| `build.py` | unions the plate onto the original mesh with trimesh/manifold → `pebble_dock_v2_body.stl` |
| `pebble_dock_v2_body.stl` / `.3mf` | the remixed body, print as-is |
| `pebble_dock_v2_tray.stl` / `.3mf` | the drawer, prints separately |

Weights: 6 × 16 × 19 × 4 mm (2 along the slide, 3 across), 0.3 mm pocket
clearance. The tray slides in along print +Z with a 0.3 mm clearance and a
0.6 mm detent; the pull face carries a fingernail groove.

## Rebuild

```sh
openscad -D 'part="plate"' -o plate.stl pebble_dock_v2.scad
openscad -D 'part="tray"'  -o pebble_dock_v2_tray.stl pebble_dock_v2.scad
python build.py            # needs trimesh, manifold3d, numpy
```

## License

Everything in this directory is licensed under the **GNU General Public License
v3.0** (see `LICENSE`), as required by the share-alike terms of the original.
This differs from the rest of the repository, which is MIT OR Apache-2.0.
