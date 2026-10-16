#!/usr/bin/env python3
"""Generate a low-poly faceted relief of a ball python head (front view).

Emits an OpenSCAD file containing a native polyhedron() -- NOT an STL import,
because OpenSCAD 2021.01 cannot boolean imported meshes, and we need to union a
backer plate and subtract keyholes downstream.

The front surface is authored as a single-valued HEIGHT FIELD z = f(x, y) over
the head silhouette. That guarantees no facet ever faces downward, so the whole
plaque prints back-flat on the bed with zero supports.

Coordinates are normalised: x in [-1, 1] (half-width = 1), y roughly [-0.78, 1],
z in [0, 1] (0 = backer plane, 1 = frontmost point of the snout). Only the right
half (x >= 0) is authored; the left is mirrored programmatically so the facets
are guaranteed symmetric.
"""

import math

# --- vertex table: name -> (x, y, z) ---------------------------------------
# Styled "cute": eyes enlarged ~1.7x over anatomical, snout shortened and
# blunted, mouth corner lifted into a smile. Ball python cues kept: broad wedge
# skull, widest at the cheeks, blunt rostral, high-set mouth corner.

V = {
    # silhouette, z=0 (crown center -> clockwise -> chin center)
    "o0": (0.00,  1.00, 0.00),
    "o1": (0.36,  0.95, 0.00),
    "o2": (0.68,  0.80, 0.00),
    "o3": (0.92,  0.52, 0.00),
    "o4": (1.00,  0.16, 0.00),   # widest: cheek
    "o5": (0.94, -0.18, 0.00),
    "o6": (0.72, -0.48, 0.00),
    "o7": (0.38, -0.70, 0.00),
    "o8": (0.00, -0.78, 0.00),   # chin

    # ring 1: where the steep silhouette wall breaks into the face planes
    "r0": (0.00,  0.80, 0.56),
    "r1": (0.32,  0.74, 0.53),
    "r2": (0.60,  0.58, 0.48),   # doubles as eye rim, upper
    "r3": (0.78,  0.32, 0.40),   # doubles as eye rim, outer
    "r4": (0.82,  0.04, 0.36),   # doubles as eye rim, lower outer
    "r5": (0.78, -0.22, 0.34),   # mouth corner -- the "smile" tip
    "r6": (0.58, -0.46, 0.30),
    "r7": (0.30, -0.62, 0.28),
    "r8": (0.00, -0.66, 0.27),

    # eye rim, inner half (outer half is r2/r3/r4)
    "ei0": (0.50, -0.06, 0.46),
    "ei1": (0.22,  0.20, 0.54),
    "ei2": (0.26,  0.50, 0.56),

    # snout centre ridge
    "c1": (0.00,  0.46, 0.66),   # between the eyes
    "c2": (0.00,  0.10, 0.86),
    "c3": (0.00, -0.18, 0.92),   # frontmost point
    "c4": (0.00, -0.40, 0.86),   # rostral / mouth centre

    # snout flank
    "q1": (0.30,  0.04, 0.84),
    "q2": (0.46, -0.16, 0.88),

    # mouth line, running outward and UP from c4 to the corner at r5
    "m1": (0.37, -0.45, 0.80),
    "m2": (0.56, -0.32, 0.66),


}

# Ball python skulls are markedly wider than tall head-on. Authoring in a
# roughly square box keeps the layout readable; this squashes y on emit so the
# finished plaque lands near 1.3 : 1, which is what makes it read as a snake
# rather than a generic round animal face.
Y_SQUASH = 0.87

EYE_RIM = ["r2", "r3", "r4", "ei0", "ei1", "ei2"]   # clockwise in xy
EYE_MID_T, EYE_MID_Z = 0.45, 0.76                   # lerp toward centroid, z
EYE_TOP_T, EYE_TOP_Z = 0.78, 0.86                   # flat hex "pupil" facet

# --- regions on the right half --------------------------------------------
# Each region is an ordered boundary loop of vertex names, triangulated by ear
# clipping below. Hand-picking the triangles is what broke this the first time:
# two regions overlapped in projection, which silently destroys the height-field
# property and produces real downward-facing facets.

REGIONS = [
    ["r0", "r1", "r2", "ei2", "c1"],                    # crown, above the brow
    ["c1", "ei2", "ei1", "q1", "c2"],                   # snout, upper
    ["c2", "q1", "q2", "c3"],                           # snout, mid
    ["c3", "q2", "m1", "c4"],                           # snout, lower
    ["ei0", "r4", "r5"],                                # cheek under the eye
    ["q1", "ei1", "ei0", "r5", "m2", "m1", "q2"],       # upper lip band
    ["c4", "m1", "m2", "r5", "r6", "r7", "r8"],         # lower jaw and chin
]
# silhouette wall -> ring 1
REGIONS += [[f"o{i}", f"o{i+1}", f"r{i+1}", f"r{i}"] for i in range(8)]


def _area2(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def earclip(poly):
    """Triangulate a simple polygon [(x, y), ...]; returns CCW index triples."""
    n = len(poly)
    idxs = list(range(n))
    if sum(_area2((0.0, 0.0), poly[i], poly[(i + 1) % n]) for i in range(n)) < 0:
        idxs.reverse()
    tris = []
    while len(idxs) > 2:
        for k in range(len(idxs)):
            m = len(idxs)
            i0, i1, i2 = idxs[(k - 1) % m], idxs[k], idxs[(k + 1) % m]
            a, b, c = poly[i0], poly[i1], poly[i2]
            if _area2(a, b, c) <= 1e-12:           # reflex or degenerate
                continue
            if any(_area2(a, b, poly[j]) >= 0 and _area2(b, c, poly[j]) >= 0
                   and _area2(c, a, poly[j]) >= 0
                   for j in idxs if j not in (i0, i1, i2)):
                continue                           # another vertex is inside
            tris.append((i0, i1, i2))
            idxs.pop(k)
            break
        else:
            raise SystemExit("ear clipping stalled on %s -- region is not a "
                             "simple polygon" % (poly,))
    return tris


F = []
for loop in REGIONS:
    xy = [(V[n][0], V[n][1]) for n in loop]
    F += [[loop[i] for i in tri] for tri in earclip(xy)]

OUTLINE = [f"o{i}" for i in range(9)]


def build(scale=130.0, depth=22.0, backer=4.0):
    """Return (points, faces, outline_2d, volume) in millimetres.

    The backer plate is part of the SAME closed polyhedron rather than a
    separate solid unioned on. Unioning two solids that share a coincident
    planar face is exactly the case CGAL drops on the floor, and the relief
    silhouette would otherwise come to a zero-thickness knife edge. Building one
    manifold shell -- height field on top, vertical wall at the silhouette, flat
    back -- avoids both problems and leaves a clean `backer` mm edge.
    """
    pts, idx = [], {}

    def add(p):
        pts.append(p)
        return len(pts) - 1

    def vid(name, mirror=False):
        key = (name, mirror)
        if key in idx:
            return idx[key]
        x, y, z = V[name]
        if mirror:
            if abs(x) < 1e-9:                 # on the axis: shared, not doubled
                return vid(name, False)
            x = -x
        idx[key] = add((x * scale, y * scale * Y_SQUASH, z * depth + backer))
        return idx[key]

    # --- eye: three concentric hex rings, flat hexagonal top facet ---------
    rim = [V[n] for n in EYE_RIM]
    cx = sum(p[0] for p in rim) / 6.0
    cy = sum(p[1] for p in rim) / 6.0

    def eye_ring(t, z, mirror):
        out = []
        for (x, y, _) in rim:
            ex = x + (cx - x) * t
            ey = y + (cy - y) * t
            if mirror:
                ex = -ex
            out.append(add((ex * scale, ey * scale * Y_SQUASH,
                            z * depth + backer)))
        return out

    faces = []

    def emit(tri, mirror):
        f = [vid(n, mirror) for n in tri]
        faces.append(list(reversed(f)) if mirror else f)

    for mirror in (False, True):
        for tri in F:
            emit(tri, mirror)

        rim_i = [vid(n, mirror) for n in EYE_RIM]
        mid_i = eye_ring(EYE_MID_T, EYE_MID_Z, mirror)
        top_i = eye_ring(EYE_TOP_T, EYE_TOP_Z, mirror)
        for k in range(6):
            j = (k + 1) % 6
            for quad in ((rim_i[k], rim_i[j], mid_i[j], mid_i[k]),
                         (mid_i[k], mid_i[j], top_i[j], top_i[k])):
                a, b, c, d = quad
                tri1, tri2 = [a, b, c], [a, c, d]
                faces += [list(reversed(tri1)), list(reversed(tri2))] if mirror \
                    else [tri1, tri2]
        cap = list(reversed(top_i)) if mirror else top_i
        faces.append(cap)

    # --- silhouette wall: outline at z=backer down to the back at z=0 ------
    loop = [vid(n, False) for n in OUTLINE] + \
           [vid(f"o{i}", True) for i in range(7, 0, -1)]
    low = [add((pts[i][0], pts[i][1], 0.0)) for i in loop]
    n = len(loop)
    for k in range(n):
        j = (k + 1) % n
        faces += [[loop[k], loop[j], low[j]], [loop[k], low[j], low[k]]]

    # --- flat back, fanned from a hub -------------------------------------
    hub = add((0.0, 0.10 * scale * Y_SQUASH, 0.0))
    for k in range(n):
        faces.append([hub, low[k], low[(k + 1) % n]])

    # --- orient every face consistently, then fix the global sign --------
    # The regions above are hand-authored, so their windings do not agree with
    # each other. Walk the face-adjacency graph and flip as needed: two faces
    # sharing an edge are consistent exactly when they traverse that edge in
    # OPPOSITE directions. Then flip everything once if the result came out
    # inside-out. This also validates the mesh -- every edge must be used twice.
    edge_use = {}
    for fi, f in enumerate(faces):
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            edge_use.setdefault(frozenset((a, b)), []).append((fi, a, b))

    bad = {e: u for e, u in edge_use.items() if len(u) != 2}
    if bad:
        raise SystemExit("non-manifold: %d edges not shared by exactly 2 faces, "
                         "e.g. %s" % (len(bad), list(bad.items())[:3]))

    seen = {0}
    stack = [0]
    while stack:
        fi = stack.pop()
        f = faces[fi]
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]
            for (gj, ga, gb) in edge_use[frozenset((a, b))]:
                if gj in seen:
                    continue
                if (ga, gb) == (a, b):          # same direction -> inconsistent
                    faces[gj] = list(reversed(faces[gj]))
                seen.add(gj)
                stack.append(gj)
    if len(seen) != len(faces):
        raise SystemExit("mesh is not connected: %d/%d faces reached"
                         % (len(seen), len(faces)))

    vol = 0.0
    for f in faces:
        for k in range(1, len(f) - 1):
            a, b, c = pts[f[0]], pts[f[k]], pts[f[k + 1]]
            vol += (a[0] * (b[1] * c[2] - b[2] * c[1])
                    - a[1] * (b[0] * c[2] - b[2] * c[0])
                    + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    if vol > 0:                        # OpenSCAD wants CW seen from outside
        faces = [list(reversed(f)) for f in faces]

    # --- enforce the height-field guarantee -------------------------------
    # Everything above the back plane must face up or sideways, or the "prints
    # with zero supports" claim is simply false.
    bad_area = 0.0
    for f in faces:
        for k in range(1, len(f) - 1):
            a, b, c = pts[f[0]], pts[f[k]], pts[f[k + 1]]
            u = [b[i] - a[i] for i in range(3)]
            v = [c[i] - a[i] for i in range(3)]
            nrm = [u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2],
                   u[0]*v[1] - u[1]*v[0]]
            area2 = sum(x * x for x in nrm) ** 0.5
            if area2 < 1e-9:
                continue
            if -nrm[2] / area2 < -0.02 and min(a[2], b[2], c[2]) > 1e-6:
                bad_area += area2 / 2.0
    if bad_area > 1e-6:
        raise SystemExit("height field violated: %.1f mm^2 of downward-facing "
                         "facets above the back plane" % bad_area)

    outline2d = [(pts[i][0], pts[i][1]) for i in loop]
    return pts, faces, outline2d, abs(vol)


def emit_scad(path, scale=130.0, depth=22.0, backer=4.0):
    pts, faces, outline, vol = build(scale, depth, backer)
    fmt = lambda p: "[%.4f,%.4f,%.4f]" % p
    with open(path, "w") as fh:
        fh.write("// GENERATED by gen_head.py -- do not edit by hand.\n")
        fh.write("// Low-poly ball python head, front relief. Height field:\n")
        fh.write("// every facet faces up or sideways, so it prints support-free.\n")
        fh.write("BP_SCALE = %.3f;\nBP_DEPTH = %.3f;\nBP_BACKER = %.3f;\n"
                 % (scale, depth, backer))
        fh.write("BP_V = [\n  %s\n];\n" % ",\n  ".join(fmt(p) for p in pts))
        fh.write("BP_F = [\n  %s\n];\n"
                 % ",\n  ".join("[" + ",".join(str(i) for i in f) + "]"
                                for f in faces))
        fh.write("BP_OUTLINE = [\n  %s\n];\n"
                 % ",\n  ".join("[%.4f,%.4f]" % p for p in outline))
    return len(pts), len(faces), vol


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "bp_head_data.scad"
    n, f, vol = emit_scad(out)
    print("%s: %d verts, %d faces, shell volume %.1f mm^3" % (out, n, f, vol))
