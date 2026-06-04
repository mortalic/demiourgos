# Demiourgos

**An OpenSCAD MCP server that gives an AI assistant eyes, a compiler, and a tape
measure.**

Demiourgos is a [Model Context Protocol](https://modelcontextprotocol.io) server,
written in Rust, that turns an AI assistant into a capable OpenSCAD designer by
closing the feedback loop. The assistant writes SCAD code; Demiourgos renders it
(eyes), validates it (a compiler), and — the part most OpenSCAD MCP servers
lack — **measures and analyzes the resulting geometry** (a tape measure).

## Why it's different

Most OpenSCAD MCP servers stop at *render* and *export*. Demiourgos adds a
**measurement and fit-checking layer**:

- **`measure`** — exact bounding box, volume (mm³), center of mass, triangle
  count, and a watertight/manifold check, computed from the exported mesh.
- **`fit_check`** — the killer feature for interlocking parts (dovetails, pegs,
  press-fits): place one part relative to another, get the precise
  **intersection volume** (zero ⇒ no collision) plus each part's bounding box,
  the per-axis gap when disjoint, and the **true minimum surface distance**.
- **`cross_section`** — slice the model on any plane and render the 2D section to
  inspect internal geometry and wall thickness.

These let an assistant *reason about dimensions and clearances*, not just look at
pictures.

## Tool reference

| Tool | What it does |
|------|--------------|
| `health` | Server version, resolved OpenSCAD binary + version, workspace path, BOSL2 availability. |
| `write_model` | Create or overwrite a named `.scad` file in the workspace. |
| `read_model` | Return a model's source. |
| `list_models` | List workspace models. |
| `compile_check` | Fast validation (`-o tmp.csg`): success, errors/warnings with line numbers, and `ECHO` output. The cheap inner-loop tool. |
| `render` | PNG of a named view (`front`/`back`/`left`/`right`/`top`/`bottom`/`iso`), or a labeled **contact sheet** from a `views` array. Ortho or perspective, `$fn` and `-D` overrides, plus an `advanced_camera` passthrough. |
| `measure` | Export binary STL and report bounding box, volume, center of mass, triangle count, and watertightness. |
| `export` | Export to STL / 3MF / OFF / AMF / DXF / SVG with quality (`$fn`) and binary/ASCII STL options. |
| `cross_section` | `projection(cut=true)` at a given axis + offset → section image. |
| `fit_check` | Intersection volume, bounding boxes, per-axis gaps, and minimum surface distance between two parts (with an optional transform on the second). |

Every tool returns a human-readable summary **and** a structured JSON payload;
renders also return the PNG as inline image content so MCP clients can display it.

## Install

Requires [OpenSCAD](https://openscad.org) on your `PATH` (or set
`OPENSCAD_BINARY`) and a Rust toolchain.

```sh
cargo install --path crates/server
```

This installs the `demiourgos` binary.

## MCP client configuration

Demiourgos speaks MCP over **stdio**. Register it with your client (the repo also
ships a checked-in `.mcp.json`):

```json
{
  "mcpServers": {
    "demiourgos": {
      "command": "demiourgos",
      "args": [],
      "env": {}
    }
  }
}
```

### Configuration

| Env var | Default | Meaning |
|---------|---------|---------|
| `DEMIOURGOS_WORKSPACE` | `./workspace` | Directory of `.scad` models and `artifacts/`. |
| `OPENSCAD_BINARY` | `openscad` (on PATH) | Path to the OpenSCAD binary. |
| `DEMIOURGOS_RENDER_TIMEOUT` | `60` | Render timeout (seconds). |
| `DEMIOURGOS_EXPORT_TIMEOUT` | `120` | Export timeout (seconds). |
| `DEMIOURGOS_CHECK_TIMEOUT` | `30` | compile_check timeout (seconds). |
| `DEMIOURGOS_LOG` | `info` | `tracing` log filter (logs go to stderr). |

## Example

The `examples/dovetail-bin` model is a small parametric open-top tray with a
dovetail key. A typical assistant loop: `write_model` → `compile_check` (fast) →
`render` a contact sheet → `measure` to confirm dimensions → `fit_check` the bin
against a mating part.

## Security note

⚠️ **Rendering arbitrary SCAD is code execution by design.** OpenSCAD's
`import()` / `include` / `use` read files from disk, and SCAD can reference
external resources. Demiourgos runs the `openscad` binary on whatever source you
give it. Treat Demiourgos with the **same trust level as your own shell**: run it
locally, do not expose it as a remote/network service, and don't feed it
untrusted models. Demiourgos sanitizes *model file names* so tool calls stay inside
the workspace, but it cannot sandbox what OpenSCAD itself does once running.

## Roadmap

Planned but out of scope for the current pass:

- `param_sweep` — customizer preset grids / tolerance contact sheets.
- `print_check` — slicer integration (PrusaSlicer CLI), overhang/wall analysis.
- `visual_diff` — before/after render diffing.
- `library_info` — BOSL2 source discovery beyond the health check.

## License

Dual-licensed under either of [MIT](LICENSE-MIT) or
[Apache 2.0](LICENSE-APACHE) at your option.
