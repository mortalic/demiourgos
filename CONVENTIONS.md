# OpenSCAD authoring conventions (read before editing any .scad)

You are writing **OpenSCAD input**. OpenSCAD is the compiler; you write programs
for it. Never modify this repo's Rust/server code to make a model.

## The #1 trap: 2D vs 3D. Read this or you WILL waste commits.

- `text()`, `circle()`, `square()`, `polygon()`, `projection()` produce **2D**.
- `linear_extrude()` and `rotate_extrude()` turn **2D → 3D**. They accept **only
  2D children**. A 3D child is **silently ignored** (warning, not error).
- `cube()`, `sphere()`, `cylinder()`, and anything already extruded are **3D**.
- **You cannot nest `linear_extrude` inside `linear_extrude`.** The inner one
  makes 3D; the outer one throws it away. This is the most common way text
  "disappears."

Wrong (text vanishes):
```scad
linear_extrude(bite)                 // outer = 2D operation
  linear_extrude(text_depth) text("hi");   // inner already made 3D -> IGNORED
```

Right — extrude each thing once, then combine as 3D with union/difference:
```scad
union() {
  linear_extrude(bite) clip2d();     // 2D profile -> 3D
  translate([0, 0, bite])            // sit on the top face
    linear_extrude(text_depth) text("hi");   // separate 2D -> 3D, unioned
}
```
Use `difference()` (text translated to `bite - text_depth`) to deboss instead of
emboss.

## You have NO EYES. Verify every change against the compiler.

After editing, run:
```sh
openscad -o /tmp/check.stl <file>.scad
```
Exit code 0 does **not** mean success. **Read stderr.** Treat these as FAILURES,
not warnings — fix and re-run before you commit:

- `Ignoring 3D child object for 2D operation` → your text/shape was dropped.
- `Mixing 2D and 3D objects is not supported` → same root cause.
- `WARNING: Object may not be a valid 2-manifold` → not watertight; won't print.

If you cannot confirm the feature is present, you did **not** succeed. Do not
claim you added something you cannot verify rendered.

## Housekeeping

- One attempt at a time. If you rewrite an approach, **delete the previous
  version** (dead modules like an unused `add_text()`) — don't leave both.
- Reuse the file's existing variables/params; don't invent parallel ones.
- Model new work on an existing example: `projects/bagclips/bagclip_tongs.scad`
  (mechanism) and `projects/bagclips/bagclip_brand.scad` (text-on-a-path).
