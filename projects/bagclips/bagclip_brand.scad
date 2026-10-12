// bagclip_brand.scad — maker's-mark helpers shared by the bag clips.
// `use <bagclip_brand.scad>` and pass everything as arguments.
//
// Width estimate: Liberation Sans Bold advance widths (metric-compatible with
// Arial Bold), per 1000 em. OpenSCAD text size 1 measures ~1.341 em of advance
// (calibrated against a rendered "imakethingsforu.com": 13.56 mm at size 10).

_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- ";
_adv   = [556,611,556,611,556,333,611,611,278,278,556,278,889,611,611,611,611,389,556,333,611,556,778,556,556,500,
          722,722,722,722,667,611,778,722,278,556,722,611,833,722,778,667,778,722,667,611,722,667,944,667,667,611,
          556,556,556,556,556,556,556,556,556,556, 278,333,278];

function _adv1(c) = let(i = search(c, _chars)) (len(i) == 0 || i[0] == undef) ? 600 : _adv[i[0]];
function _sum(v, i = 0) = i >= len(v) ? 0 : v[i] + _sum(v, i + 1);
function brand_w(t, s) = s * 1.341 * _sum([for (i = [0 : len(t) - 1]) _adv1(t[i])]) / 1000;
function sub(t, a, b) = b <= a ? "" : chr([for (i = [a : b - 1]) ord(t[i])]);

// largest size (capped at smax) at which `t` fits a flat canvas `can` mm long with 1 mm margins
function fit1(t, can, smax) = min(smax, (can - 2) / brand_w(t, 1));

// ---------------------------------------------------------------------------
// Engrave `txt` into a vertical face: f = face center (3D), n = outward unit normal
// in the xy plane. Reads left-to-right for a viewer standing outside the face,
// letters upright along +z.
module engrave(f, n, txt, size, depth, font) {
    u = cross(-n, [0, 0, 1]);
    multmatrix([[u[0], 0, -n[0], f[0] + n[0]*0.01],
                [u[1], 0, -n[1], f[1] + n[1]*0.01],
                [0,    1,  0,    f[2]],
                [0,    0,  0,    1]])
        linear_extrude(depth + 0.01)
            text(txt, size = size, font = font, halign = "center", valign = "center", $fn = 24);
}

// ---------------------------------------------------------------------------
// Text along a path: letters are placed one by one along the outer contour of a
// ribbon so the mark wraps around corners. `cl` is the ribbon centerline (2D
// polyline), `d` the half-thickness; the contour used is the side on the RIGHT of
// the direction of travel, which is also the reading direction.

function _tanv(p, i) = let(v = p[i + 1] - p[i]) v / norm(v);
// mitred offset of a polyline to the right of travel by d
function offset_right(p, d) = [for (i = [0 : len(p) - 1])
    let(t0 = _tanv(p, max(i - 1, 0)), t1 = _tanv(p, min(i, len(p) - 2)),
        n0 = [t0[1], -t0[0]], n1 = [t1[1], -t1[0]],
        nb = n0 + n1, m = nb / norm(nb), c = m * n0)
    p[i] + m * (d / c)];
function path_len(q, i = 0) = i >= len(q) - 1 ? 0 : norm(q[i + 1] - q[i]) + path_len(q, i + 1);
function vert_s(q, k) = k <= 0 ? 0 : norm(q[k] - q[k - 1]) + vert_s(q, k - 1);   // arc length at vertex k
// [point, unit tangent] at arc length s
function path_at(q, s, i = 0) = let(l = norm(q[i + 1] - q[i]))
    (s <= l || i >= len(q) - 2) ? let(t = (q[i + 1] - q[i]) / l) [q[i] + t * s, t] : path_at(q, s - l, i + 1);

// sequential letter layout: centers along the path; a letter that would overlap a
// dead zone [s0, s1] is pushed to the zone's end
function _adv_list(txt, size) = [for (i = [0 : len(txt) - 1]) brand_w(txt[i], size)];
function _skip(pos, w, dead, k = 0) = k >= len(dead) ? pos :
    let(z = dead[k]) (pos < z[1] && pos + w > z[0]) ? _skip(z[1], w, dead, 0) : _skip(pos, w, dead, k + 1);
function _layout(adv, dead, pos, i = 0) = i >= len(adv) ? [] :
    let(p = _skip(pos, adv[i], dead)) concat([p + adv[i] / 2], _layout(adv, dead, p + adv[i], i + 1));
function _dead_len(dead, i = 0) = i >= len(dead) ? 0 : dead[i][1] - dead[i][0] + _dead_len(dead, i + 1);
function _layout_end(txt, size, dead, margin) =
    let(adv = _adv_list(txt, size), cs = _layout(adv, dead, margin)) cs[len(cs) - 1] + adv[len(adv) - 1] / 2;

// text size that fills the contour (minus margins and dead zones), capped at smax
function path_text_size(cl, d, txt, dead, smax, margin = 0.5) =
    let(q = offset_right(cl, d), L = path_len(q),
        s1 = min(smax, (L - 2*margin - _dead_len(dead) - 1.5*len(dead)) / brand_w(txt, 1)),
        e1 = _layout_end(txt, s1, dead, margin))
    e1 <= L - margin ? s1 : s1 * (L - 2*margin) / (e1 - margin) * 0.99;

module engrave_path(cl, d, txt, size, depth, font, z, dead = [], margin = 0.5) {
    q   = offset_right(cl, d);
    adv = _adv_list(txt, size);
    cs  = _layout(adv, dead, margin);
    if (cs[len(cs) - 1] + adv[len(adv) - 1] / 2 > path_len(q) - margin + 0.05)
        echo(str("WARNING: mark \"", txt, "\" overruns its path by ",
                 cs[len(cs) - 1] + adv[len(adv) - 1] / 2 - (path_len(q) - margin), " mm"));
    for (i = [0 : len(txt) - 1])
        let(pt = path_at(q, cs[i]), p = pt[0], t = pt[1], n = [t[1], -t[0]])
            engrave([p[0], p[1], z], [n[0], n[1], 0], txt[i], size, depth, font);
}
