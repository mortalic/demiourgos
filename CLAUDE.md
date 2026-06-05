# CLAUDE.md — Demiourgos

Project conventions for agentic coding sessions. Read this before changing code.

## What this is

Demiourgos is an **MCP server** (stdio, written in Rust with [`rmcp`]) that turns an
AI assistant into a capable OpenSCAD designer by closing the feedback loop: the
assistant writes SCAD, and Demiourgos gives it **eyes** (render), a **compiler**
(compile_check), and a **tape measure** (measure, fit_check). The differentiator
versus other OpenSCAD MCP servers is the measurement/analysis layer — not just
rendering and export.

## Workspace layout

```
crates/
  scad/    demiourgos-scad  — OpenSCAD CLI wrapper: discovery, timeouts, camera
                            math, diagnostic parsing, argument builders.
  mesh/    demiourgos-mesh  — STL parsing + geometry (bbox, volume, COM,
                            watertight), parry3d min-distance, and DFM analysis
                            (overhangs, wall thickness, footprint).
  tolerance/ demiourgos-tolerance — material/printer profiles, fit-class
                            clearances, calibration from outcomes, fit-test
                            coupon generation, and the on-disk store.
  server/  demiourgos       — the MCP binary: tool surface + workspace + rmcp glue.
examples/dovetail-bin/    — sample model used in docs and the golden test.
tests/golden/             — checked-in reference outputs for regression tests.
```

The server owns a **workspace directory** of `.scad` files (default `./workspace`,
override with `DEMIOURGOS_WORKSPACE`). Generated images/meshes go in
`<workspace>/artifacts/`. Tolerance profiles + the outcome log live in
`<workspace>/.demiourgos/` (override with `DEMIOURGOS_DATA`). Tools reference
models by **name**, never by passing full source on every call.

## Build / test / lint

```sh
cargo build                                   # build everything
cargo test                                    # unit tests (no OpenSCAD needed)
cargo test -- --include-ignored               # + integration tests (needs openscad)
cargo clippy --all-targets -- -D warnings     # lint gate (CI enforces this)
cargo fmt --all                               # format
cargo run -p demiourgos                         # run the server on stdio
```

Integration/golden tests that shell out to OpenSCAD are marked `#[ignore]`; CI
runs them with `--include-ignored` after `apt-get install openscad`.

### Manual MCP smoke test

Pipe newline-delimited JSON-RPC into the binary (stdout is the transport; logs
go to stderr):

```sh
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"x","version":"0"}}}' \
 '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
 | cargo run -q -p demiourgos
```

## Tool surface

| Tool            | Purpose |
|-----------------|---------|
| `health`        | Server + OpenSCAD versions, workspace path, BOSL2 presence. |
| `write_model`   | Create/overwrite a named `.scad` file. |
| `read_model` / `list_models` | Retrieve / enumerate models. |
| `compile_check` | Cheap inner-loop validation (`-o tmp.csg`); errors/warnings + ECHO. |
| `render`        | PNG of a named view, or a labeled contact sheet from `views[]`. |
| `view_3d`       | Offline self-contained Three.js HTML viewer of the exported mesh (orbit/zoom). Three.js is vendored under `crates/server/assets/three/` (MIT) and inlined via `include_str!`. |
| `param_sweep`   | Render a model across N values of one variable into a labeled grid. |
| `visual_diff`   | Render two variants from one view; highlight changed pixels (A \| B \| diff). |
| `measure`       | Export binary STL → bbox, volume, COM, triangle count, watertight. |
| `export`        | STL/3MF/OFF/AMF/DXF/SVG with `$fn` and binary/ASCII options. |
| `cross_section` | `projection(cut=true)` slice at axis+offset → 2D image. |
| `fit_check`     | Intersection volume + per-axis gap + min surface distance; optional profile-aware fit assessment. |
| `dfm_check`     | Overhang area/steepness, bed-contact footprint, min wall thickness, warnings. |
| `stress_check`  | First-order cantilever-beam strength estimate (not FEA); see `strength.rs`. |
| `print_check`   | Slice via a PrusaSlicer-family CLI; report time/filament; see `slicer.rs`. |
| `recommend_clearance` | Per-side clearance for slip/snug/press/snap (± std, confidence) on a printer+material. |
| `gen_fit_coupon` | Write a one-print fit-test coupon to calibrate a profile. |
| `suggest_coupon` | Active learning: write the next coupon centered on the estimate ± its uncertainty. |
| `record_outcome` | Log a coupon/caliper/fit outcome → recalibrate a profile (Bayesian). |
| `get_profile` / `list_profiles` / `set_profile` | Read/edit tolerance profiles. |
| `library_info`  | List OpenSCAD library paths/libraries; a named library's modules/functions. |

Tools return a human-readable text summary **and** a `structuredContent` JSON
payload; renders additionally return base64 PNG image content.

## Tolerance engine (the "learn from prints" half)

`demiourgos-tolerance` keeps a [`Profile`] per `(printer, material, nozzle)`:
per-fit-class **clearances** (per-side mm; `fit_check` measures this directly, so
a peg/hole pair is `hole = peg + 2 × clearance`) plus dimensional offsets, seeded
from `material_defaults` and refined by **outcomes**. The [`Store`] persists a
baseline registry (`profiles.json`) and an append-only outcome log
(`outcomes.ndjson`); the *effective* profile is `calibrate_from(baseline, log)` —
deterministic, replay-based, most-recent-feedback-wins per class. Manual edits via
`set_profile` are the baseline; outcomes adjust it.

The calibration loop: `gen_fit_coupon` → print → `record_outcome` (kind `coupon`,
`caliper`, or `fit`) → `recommend_clearance` / `fit_check` now return calibrated
values. To extend the learning model (e.g. Bayesian optimization), change
`calibrate_from` only — the data model and tools stay put.

DFM lives in `demiourgos-mesh` (`dfm_report` / `min_wall_thickness`); build
direction is **+Z**, overhang angle is measured from horizontal (0° = flat
ceiling, threshold default 45°).

## Conventions

- **stdout is sacred.** It is the MCP JSON-RPC transport. Never `println!` —
  all logging goes through `tracing` to **stderr** (`DEMIOURGOS_LOG` controls level).
- **Never panic on bad input.** OpenSCAD/mesh failures return structured,
  actionable errors. Usage errors (bad name, unknown view) → `invalid_params`;
  build failures (compile/export) → a result flagged `isError` whose payload
  carries the parsed diagnostics and stderr. Internal faults → `internal_error`.
- **Every OpenSCAD invocation has a timeout** (`config.rs`); on expiry the
  process group is killed. Defaults: render 60s, export 120s, check 30s.
- **Model names are sanitized** in `workspace.rs` (single path segment, no `..`),
  so a tool call cannot read/write outside the workspace.
- Keep argument construction **pure and unit-tested** in `scad/src/ops.rs`;
  the async wrappers just run the built argv.

## Camera conventions

`scad/src/camera.rs` owns all camera math. Named views map to OpenSCAD gimbal
rotations `(rot_x, rot_y, rot_z)`:

| view | rotation |
|------|----------|
| front | (0, 0, 0) |
| back | (0, 0, 180) |
| left | (0, 0, 90) |
| right | (0, 0, 270) |
| top | (90, 0, 0) |
| bottom | (270, 0, 0) |
| iso | (55, 0, 25) |

Renders pass `--camera=0,0,0,rx,ry,rz,500` together with `--viewall --autocenter`
so the object is always framed; the rotation provides orientation, viewall
provides distance. The `advanced_camera` passthrough bypasses this for power use
(and disables viewall/autocenter). Full renders pass `--render ""` — OpenSCAD's
`--render` option takes a value, so a bare flag is rejected by the parser.

## How to add a tool

1. Add an args struct in `server.rs` deriving `Deserialize + schemars::JsonSchema`
   with doc comments (they become the JSON-schema field descriptions). Use
   `#[serde(rename = "fn")]` for a `$fn` field (named `fn_n` in Rust).
2. Add an `async fn` inside the `#[tool_router] impl Demiourgos` block, annotated
   `#[tool(description = "…")]`, taking `Parameters(args): Parameters<YourArgs>`
   and returning `Result<CallToolResult, McpError>`.
3. Resolve/validate the model with `self.require_model(&name)`; build defines via
   `self.defines(&args.defines)`; run OpenSCAD through `self.scad()?`.
4. Return via the `result.rs` helpers (`json_result`, `json_error`,
   `image_result`).
5. Add unit tests for any new pure logic; if it needs OpenSCAD, gate behind
   `#[ignore]`.

The router and `list_tools`/`call_tool` are generated by the macros — no manual
registration.

## How golden tests work

`tests/golden/` holds reference JSON produced by running a tool against an
example. The `dovetail-bin.measure.json` golden is checked by
`crates/server/tests/golden.rs` (`#[ignore]`, needs OpenSCAD): it exports the
example to STL, measures it, and asserts bbox/volume/watertight/triangle-count.
If you intentionally change example geometry, re-run `measure` on it and update
the golden values.

## Roadmap (not yet implemented)

`param_sweep`, `print_check` (slicer integration), `visual_diff`, `library_info`.

[`rmcp`]: https://docs.rs/rmcp
