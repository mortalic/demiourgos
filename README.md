# Demiourgos

**An OpenSCAD MCP server that gives an AI assistant eyes, a compiler, a tape
measure — and a memory of what actually prints.**

Demiourgos is a [Model Context Protocol](https://modelcontextprotocol.io) server,
written in Rust, that turns an AI assistant into a capable OpenSCAD designer by
closing the feedback loop. The assistant writes SCAD; Demiourgos renders it
(eyes), validates it (a compiler), **measures and analyzes the resulting
geometry** (a tape measure), and **learns your printer's real tolerances** so you
stop reprinting to dial in fits.

## Why it's different

Most OpenSCAD MCP servers stop at *render* and *export*. Demiourgos adds the
layers that let an assistant reason about a part instead of just looking at it:

- **Measurement** — exact bounding box, volume, center of mass, watertightness.
- **Fit checking** — intersection volume and true minimum surface distance
  between mating parts (dovetails, pegs, press-fits).
- **Design-for-manufacturing** — overhang/wall/footprint pre-flight before you
  print, and a first-order strength estimate.
- **A learning tolerance engine** — calibrate a printer + material once and reuse
  the right clearances forever (Bayesian, with active-learning coupon
  suggestions).
- **An offline interactive 3D viewer** — spin the real mesh in a browser.

## Tool reference

All tools return a human-readable summary **and** a structured JSON payload;
renders/viewers also return an image or a file path. Models are referenced by
**name**, never by re-sending source.

### Workspace & models
| Tool | What it does |
|------|--------------|
| `health` | Server + OpenSCAD versions, workspace path, BOSL2 availability, timeouts. |
| `write_model` | Create/overwrite a named `.scad` file. |
| `read_model` / `list_models` | Retrieve / enumerate models. |

### Validate, render & visualize
| Tool | What it does |
|------|--------------|
| `compile_check` | Fast validation (`-o tmp.csg`): errors/warnings with line numbers + `ECHO`. The cheap inner-loop tool. |
| `render` | PNG of a named view (`front`/`back`/`left`/`right`/`top`/`bottom`/`iso`), or a labeled **contact sheet** from a `views` array. Ortho/perspective, `$fn` and `-D` overrides, `advanced_camera` passthrough. |
| `view_3d` | Build a **fully offline** interactive 3D viewer (Three.js inlined) — orbit/zoom/pan the real mesh in a browser. See [below](#interactive-3d-viewer-webgl). |
| `cross_section` | `projection(cut=true)` at an axis + offset → 2D section image (internal geometry, wall thickness). |
| `param_sweep` | Render a model across N values of one variable into a labeled grid (customizer preset grid / tolerance contact sheet). |
| `visual_diff` | Render two variants from the same view, highlight changed pixels in red, report the changed fraction (A \| B \| diff). |

### Measure & analyze
| Tool | What it does |
|------|--------------|
| `measure` | Export binary STL → bounding box, volume (mm³), center of mass, triangle count, watertightness. |
| `fit_check` | Intersection volume, bounding boxes, per-axis gaps, and minimum surface distance between two parts (optional transform on the second); optional tolerance-profile assessment. |
| `dfm_check` | Unsupported overhang area + steepest overhang, bed-contact footprint, estimated minimum wall thickness, and actionable warnings. |
| `stress_check` | First-order **cantilever-beam** strength estimate (not FEA): max tip load before yield, plus stress + safety factor for a given load, with material + orientation + infill knockdowns. |
| `print_check` | Slice via a PrusaSlicer-family CLI and report estimated **print time** and **filament** (length/volume/weight). Needs a slicer + config; degrades cleanly when absent. |

### Export
| Tool | What it does |
|------|--------------|
| `export` | STL / 3MF / OFF / AMF / DXF / SVG with `$fn` and binary/ASCII STL options. |

### Tolerance engine (learn once, reuse forever)
| Tool | What it does |
|------|--------------|
| `recommend_clearance` | Per-side clearance (mm) for a fit class (slip/snug/press/snap), with **± std and a confidence level**, from the calibrated profile. |
| `gen_fit_coupon` | Generate a one-print fit-test coupon (stepped holes + reference peg). |
| `suggest_coupon` | **Active learning**: write the *next* coupon, centered on the current estimate and widened by its uncertainty, to converge the calibration. |
| `record_outcome` | Record a real result (coupon best-fit, caliper reading, or assembly verdict `loose`/`good`/`tight`/`jam`) → recalibrate. |
| `get_profile` / `list_profiles` / `set_profile` | Read / edit material-printer tolerance profiles. |

### Libraries
| Tool | What it does |
|------|--------------|
| `library_info` | List OpenSCAD library search paths and installed libraries; for a named library (e.g. BOSL2), its modules/functions with an optional filter. |

## Interactive 3D viewer (WebGL)

`view_3d` writes a single **self-contained HTML file** to the workspace's
`artifacts/` directory with the model's mesh **and Three.js itself inlined** — so
it works with **no internet connection**.

1. Call `view_3d` with a model `name` (optionally a hex `color`). It returns the
   HTML path, e.g. `…/artifacts/<model>.view.html`.
2. Open that file in any browser:
   ```sh
   xdg-open  /path/to/workspace/artifacts/<model>.view.html   # Linux
   open      /path/to/workspace/artifacts/<model>.view.html   # macOS
   start     \path\to\workspace\artifacts\<model>.view.html   # Windows
   ```
   In Claude Code you can run it inline by typing `! xdg-open <path>`.
3. Controls: **drag** = orbit, **scroll** = zoom, **right-drag** = pan, **R** =
   reset. The overlay shows the bounding box, triangle count, and watertightness.

Z-up CAD orientation, a build-plate grid, and XYZ axes are included. For a quick
*still* image instead, use `render` (it returns the PNG inline).

## The tolerance engine — learn once, reuse forever

The differentiator isn't measuring the *digital* model; it's remembering what
happens when it meets a *physical* printer.

Each `(printer, material, nozzle)` has a **profile**: per-fit-class clearances
(slip/snug/press/snap) plus dimensional offsets. Each clearance is modeled as a
Normal posterior — a **mean** (the recommendation) and a **standard deviation**
(confidence) — seeded from material defaults and refined by recorded **outcomes**
via a conjugate Bayesian update that *fuses* repeated measurements instead of
letting the last one win. Profiles + an append-only outcome log persist under
`<workspace>/.demiourgos/` (git-friendly JSON + NDJSON).

The loop that cuts down reprints:

1. **`suggest_coupon`** (or `gen_fit_coupon`) writes a single test print — a plate
   of holes stepped across a clearance range, plus a reference peg.
2. Print it once; find the tightest hole that gives the fit you want.
3. **`record_outcome`** logs that clearance; the profile recalibrates and its
   uncertainty shrinks.
4. **`recommend_clearance`** (and profile-aware **`fit_check`**) now return the
   value that works on *your* printer — for every future design. Call
   `suggest_coupon` again and it proposes a tighter confirming sweep, or says the
   fit is already well calibrated.

Ideal for standardized geometry like **Gridfinity**: calibrate a material once,
and every bin afterward uses the learned clearance instead of a guess.
`record_outcome` also accepts caliper readings (dimensional offsets) and
qualitative assembly verdicts.

## Quickstart

```text
write_model           → compile_check (fast inner loop)
render / view_3d      → see it (still image or interactive)
measure / dfm_check   → check dimensions & manufacturability
fit_check             → verify clearances against mating parts
stress_check          → sanity-check load-bearing features
export / print_check  → produce the mesh; estimate time & filament
```

To dial in a real printer: `suggest_coupon` → print → `record_outcome` → repeat;
then `recommend_clearance` feeds the right gaps back into your designs.

## Install

Requires [OpenSCAD](https://openscad.org) on `PATH` (or set `OPENSCAD_BINARY`) and
a Rust toolchain. Optional: a PrusaSlicer-family CLI for `print_check`.

```sh
cargo install --path crates/server   # installs the `demiourgos` binary
demiourgos --version
```

## MCP client configuration

Demiourgos speaks MCP over **stdio**. Register it with your client (the repo ships
a checked-in `.mcp.json`):

```json
{
  "mcpServers": {
    "demiourgos": { "command": "demiourgos", "args": [], "env": {} }
  }
}
```

### Configuration (environment variables)

| Env var | Default | Meaning |
|---------|---------|---------|
| `DEMIOURGOS_WORKSPACE` | `./workspace` | Directory of `.scad` models + `artifacts/`. |
| `DEMIOURGOS_DATA` | `<workspace>/.demiourgos` | Tolerance store (profiles + outcome log). |
| `OPENSCAD_BINARY` | `openscad` (on PATH) | Path to the OpenSCAD binary. |
| `DEMIOURGOS_SLICER` | auto-discovered on PATH | Path to a PrusaSlicer-family CLI for `print_check`. |
| `DEMIOURGOS_RENDER_TIMEOUT` | `60` | Render timeout (seconds). |
| `DEMIOURGOS_EXPORT_TIMEOUT` | `120` | Export / slice timeout (seconds). |
| `DEMIOURGOS_CHECK_TIMEOUT` | `30` | compile_check timeout (seconds). |
| `DEMIOURGOS_LOG` | `info` | `tracing` log filter (logs go to **stderr**; stdout is the MCP transport). |

## Examples & projects

- `examples/dovetail-bin` — a small parametric tray used in docs and the golden
  test.
- `projects/folding-wall-hook` — a worked project: an original squared-oval
  flush-folding wall hook designed and validated entirely with Demiourgos
  (renders, STLs, an offline `view_3d` viewer, and a fit-test coupon).

## Notes & caveats

- **`stress_check` is a first-order estimate, not FEA.** It models a prismatic
  rectangular cantilever with a tip load and applies FDM knockdowns; use it to
  *size* hooks/brackets, not to certify safety-critical parts.
- **`print_check` needs a slicer config.** Slicing requires printer/print/filament
  presets — pass a `.ini` via the `config` argument (or have a configured slicer
  on PATH). Without a slicer it reports `available: false`.

## Security note

⚠️ **Rendering arbitrary SCAD is code execution by design.** OpenSCAD's
`import()` / `include` / `use` read files from disk. Demiourgos runs the
`openscad` binary (and, for `print_check`, a slicer) on whatever you give it.
Treat Demiourgos with the **same trust level as your own shell**: run it locally,
do not expose it as a remote/network service, and don't feed it untrusted models.
Model file names are sanitized so tool calls stay inside the workspace, but
Demiourgos cannot sandbox what OpenSCAD itself does once running.

## Roadmap

The initial roadmap (Bayesian calibration, `stress_check`, `param_sweep`,
`print_check`, `visual_diff`, `library_info`) is **implemented**. Possible future
work:

- Real FEA strength analysis (e.g. CalculiX/FEniCS) for safety-critical parts.
- Hierarchical cross-material/printer priors in the tolerance model.
- Multi-color assembled `view_3d` and turntable export.
- Slicer auto-config presets so `print_check` works with zero setup.

## License

Dual-licensed under either of [MIT](LICENSE-MIT) or
[Apache 2.0](LICENSE-APACHE) at your option.
