"""Build the v2 dock body: original v7 dock + weight plate on its back-wall face.

Frame = print frame (original base-down, axis-aligned: pebblechargingdock_v7_oriented.stl).
In use the dock stands on the print -X face; the plate with the tray slot is added there.

Needs: trimesh, manifold3d, numpy (uv pip install trimesh manifold3d numpy scipy shapely rtree)
Steps:
  openscad -D 'part="plate"' -o plate.stl pebble_dock_v2.scad
  openscad -D 'part="tray"'  -o pebble_dock_v2_tray.stl pebble_dock_v2.scad
  python build.py            # -> pebble_dock_v2_body.stl
"""
import trimesh
orig = trimesh.load("pebblechargingdock_v7_oriented.stl", force="mesh")
plate = trimesh.load("plate.stl", force="mesh")
body = trimesh.boolean.union([orig, plate], engine="manifold")
assert body.is_watertight and len(body.split(only_watertight=False)) == 1
body.export("pebble_dock_v2_body.stl")
print("ok", body.bounds, body.volume)
