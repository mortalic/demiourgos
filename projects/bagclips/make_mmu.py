#!/usr/bin/env python3
"""Build two-colour PrusaSlicer projects for the bag clips.

For every model/variant this exports the clip twice from OpenSCAD (part=body and
part=letters, see the .scad files) and packs both meshes into one 3MF as a single
object with two parts: the body on extruder 1 and the flush maker's-mark letters
on extruder 2. Open the 3MF in PrusaSlicer, pick your filaments, slice.

    python3 make_mmu.py            # all clips -> mmu/*.3mf
    python3 make_mmu.py hairpin xl # one
"""
import struct, subprocess, sys, tempfile, zipfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / "mmu"
VARIANTS = {"tongs": ["std", "large"], "hairpin": ["std", "large", "xl", "xxl"], "serpentine": ["std", "large"]}
BED = (150.0, 150.0)   # where the clip lands on the plate


def export(model, variant, part, out):
    cmd = ["openscad", "-q", "--export-format", "binstl", "-o", str(out),
           "-D", f'variant="{variant}"', "-D", f'part="{part}"', str(HERE / f"bagclip_{model}.scad")]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def read_stl(path):
    data = path.read_bytes()
    n = struct.unpack_from("<I", data, 80)[0]
    tri = np.frombuffer(data, dtype=np.dtype([("n", "<3f4"), ("v", "<9f4"), ("a", "<u2")]), count=n, offset=84)
    v = tri["v"].reshape(-1, 3).astype(np.float64)
    key = np.round(v, 4)
    uniq, idx = np.unique(key, axis=0, return_inverse=True)
    return uniq, idx.reshape(-1, 3)


def xml_mesh(parts):
    """parts: list of (name, verts, faces). Returns (vertices xml, triangles xml, [(first,last)])."""
    vx, tx, ranges, voff, toff = [], [], [], 0, 0
    for _, verts, faces in parts:
        for p in verts:
            vx.append(f'   <vertex x="{p[0]:.4f}" y="{p[1]:.4f}" z="{p[2]:.4f}"/>')
        for f in faces + voff:
            tx.append(f'   <triangle v1="{f[0]}" v2="{f[1]}" v3="{f[2]}"/>')
        ranges.append((toff, toff + len(faces) - 1))
        voff += len(verts); toff += len(faces)
    return "\n".join(vx), "\n".join(tx), ranges


def write_3mf(path, name, parts):
    vx, tx, ranges = xml_mesh(parts)
    allv = np.vstack([p[1] for p in parts])
    cx, cy = (allv[:, 0].min() + allv[:, 0].max()) / 2, (allv[:, 1].min() + allv[:, 1].max()) / 2
    model = f'''<?xml version="1.0" encoding="UTF-8"?>
<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:slic3rpe="http://schemas.slic3r.org/3mf/2017/06">
 <metadata name="slic3rpe:Version3mf">1</metadata>
 <metadata name="Title">{name}</metadata>
 <metadata name="Application">make_mmu.py</metadata>
 <resources>
  <object id="1" type="model">
   <mesh>
    <vertices>
{vx}
    </vertices>
    <triangles>
{tx}
    </triangles>
   </mesh>
  </object>
 </resources>
 <build>
  <item objectid="1" transform="1 0 0 0 1 0 0 0 1 {BED[0]-cx:.4f} {BED[1]-cy:.4f} 0" printable="1"/>
 </build>
</model>
'''
    vols = "".join(f'''  <volume firstid="{a}" lastid="{b}">
   <metadata type="volume" key="name" value="{pname}"/>
   <metadata type="volume" key="volume_type" value="ModelPart"/>
   <metadata type="volume" key="extruder" value="{i + 1}"/>
  </volume>
''' for i, ((pname, _, _), (a, b)) in enumerate(zip(parts, ranges)))
    config = f'''<?xml version="1.0" encoding="UTF-8"?>
<config>
 <object id="1" instances_count="1">
  <metadata type="object" key="name" value="{name}"/>
{vols} </object>
</config>
'''
    types = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>
'''
    rels = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>
'''
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", types)
        z.writestr("_rels/.rels", rels)
        z.writestr("3D/3dmodel.model", model)
        z.writestr("Metadata/Slic3r_PE_model.config", config)


def build(model, variant):
    name = f"bagclip_{model}" + ("" if variant == "std" else f"_{variant}")
    with tempfile.TemporaryDirectory() as td:
        parts = []
        for part in ("body", "letters"):
            stl = Path(td) / f"{part}.stl"
            export(model, variant, part, stl)
            verts, faces = read_stl(stl)
            parts.append((part, verts, faces))
    OUT.mkdir(exist_ok=True)
    out = OUT / f"{name}_mmu.3mf"
    write_3mf(out, name, parts)
    print(f"{out.name}: body {len(parts[0][2])} tris, letters {len(parts[1][2])} tris")


if __name__ == "__main__":
    if len(sys.argv) == 3:
        build(sys.argv[1], sys.argv[2])
    else:
        for m, vs in VARIANTS.items():
            for v in vs:
                build(m, v)
