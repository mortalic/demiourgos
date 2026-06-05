//! Interactive 3D viewer generation.
//!
//! Demiourgos renders static PNGs via OpenSCAD; this produces a self-contained
//! HTML page that shows the actual exported mesh in an orbit-controlled WebGL
//! viewer (Three.js). The STL **and** Three.js itself are inlined, so the page
//! works fully offline — open it in any browser with no network access.
//!
//! Three.js and its addons are vendored under `assets/three/` and embedded via
//! `include_str!`. They are exposed to the page's ES modules through an import
//! map whose entries are `data:` URLs, so the addons' own `import … from 'three'`
//! resolves to the inlined library without touching the network.

use base64::Engine;

/// Vendored three.js r160 (MIT). See `assets/three/NOTICE.md`.
const THREE_SRC: &str = include_str!("../assets/three/three.module.min.js");
const ORBIT_SRC: &str = include_str!("../assets/three/OrbitControls.js");
const STLLOADER_SRC: &str = include_str!("../assets/three/STLLoader.js");

fn b64(s: &str) -> String {
    base64::engine::general_purpose::STANDARD.encode(s.as_bytes())
}

/// Build a standalone, offline HTML viewer for a binary STL (base64-encoded).
///
/// `title` and `meta` are shown in an overlay; `model_stl_base64` is the embedded
/// model; `theme_hex` is the model surface color (6 hex digits, no `#`).
pub fn viewer_html(title: &str, meta: &str, model_stl_base64: &str, theme_hex: &str) -> String {
    TEMPLATE
        .replace("__THREE_B64__", &b64(THREE_SRC))
        .replace("__ORBIT_B64__", &b64(ORBIT_SRC))
        .replace("__STLLOADER_B64__", &b64(STLLOADER_SRC))
        .replace("__MODEL_B64__", model_stl_base64)
        .replace("__THEME__", theme_hex)
        .replace("__TITLE__", &escape_html(title))
        .replace("__META__", &escape_html(meta))
}

fn escape_html(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

const TEMPLATE: &str = r##"<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>__TITLE__ — Demiourgos viewer</title>
<style>
  :root { color-scheme: dark; }
  html, body { margin: 0; height: 100%; overflow: hidden; background: #1b1d23; }
  #app { position: fixed; inset: 0; }
  #info {
    position: fixed; top: 10px; left: 10px; z-index: 10;
    font: 13px/1.45 system-ui, sans-serif; color: #e7e7ea;
    background: rgba(0,0,0,.45); padding: 8px 11px; border-radius: 6px;
    backdrop-filter: blur(3px); pointer-events: none; max-width: 60ch;
  }
  #info b { font-size: 14px; }
  #info .meta { color: #aab; }
  #hint { position: fixed; bottom: 10px; left: 10px; z-index: 10;
    font: 12px system-ui, sans-serif; color: #889; }
  #err { position: fixed; inset: 0; display: none; place-items: center;
    color: #f88; font: 14px system-ui; text-align: center; padding: 2rem; }
</style>
</head>
<body>
<div id="app"></div>
<div id="info"><b>__TITLE__</b><br><span class="meta">__META__</span></div>
<div id="hint">drag to orbit · scroll to zoom · right-drag to pan · R to reset · fully offline</div>
<div id="err">Failed to initialize the 3D viewer — see the browser console.</div>

<script type="importmap">
{ "imports": {
  "three": "data:text/javascript;base64,__THREE_B64__",
  "three/addons/controls/OrbitControls.js": "data:text/javascript;base64,__ORBIT_B64__",
  "three/addons/loaders/STLLoader.js": "data:text/javascript;base64,__STLLOADER_B64__"
} }
</script>

<script type="module">
  import * as THREE from 'three';
  import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
  import { STLLoader } from 'three/addons/loaders/STLLoader.js';

  try {
    const MODEL_B64 = "__MODEL_B64__";
    const bin = atob(MODEL_B64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const geo = new STLLoader().parse(bytes.buffer);
    geo.computeVertexNormals();
    geo.computeBoundingBox();
    const bb = geo.boundingBox;
    const size = new THREE.Vector3(); bb.getSize(size);
    const center = new THREE.Vector3(); bb.getCenter(center);
    geo.translate(-center.x, -center.y, -center.z);
    const radius = size.length() / 2 || 50;

    const app = document.getElementById('app');
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);
    app.appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1b1d23);

    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, radius / 100, radius * 100);
    const start = radius * 2.6;
    camera.position.set(start, -start * 0.9, start * 0.7);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;

    // OpenSCAD/CAD convention is Z-up.
    THREE.Object3D.DEFAULT_UP.set(0, 0, 1);
    camera.up.set(0, 0, 1);
    controls.update();

    const mat = new THREE.MeshStandardMaterial({ color: 0x__THEME__, metalness: 0.15, roughness: 0.55, flatShading: false });
    const mesh = new THREE.Mesh(geo, mat);
    scene.add(mesh);

    scene.add(new THREE.HemisphereLight(0xffffff, 0x444455, 0.9));
    const key = new THREE.DirectionalLight(0xffffff, 1.1); key.position.set(1, -1, 2); scene.add(key);
    const fill = new THREE.DirectionalLight(0xffffff, 0.5); fill.position.set(-1, 1, 0.5); scene.add(fill);

    const grid = new THREE.GridHelper(radius * 6, 24, 0x3a3d46, 0x2a2c33);
    grid.rotation.x = Math.PI / 2;           // grid in the X-Y (build) plane
    grid.position.z = -size.z / 2;           // under the part
    scene.add(grid);
    scene.add(new THREE.AxesHelper(radius * 1.4));

    addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });
    addEventListener('keydown', (e) => { if (e.key === 'r' || e.key === 'R') controls.reset(); });

    (function animate() {
      requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    })();
  } catch (e) {
    document.getElementById('err').style.display = 'grid';
    console.error(e);
  }
</script>
</body>
</html>
"##;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn html_inlines_three_and_model_offline() {
        let html = viewer_html("widget", "12 mm", "QUJD", "d9a441");
        assert!(html.contains("<title>widget"));
        assert!(html.contains("12 mm"));
        assert!(html.contains("QUJD")); // model base64
        assert!(html.contains("0xd9a441"));
        // Three.js is inlined as a data: URL module, not fetched from a CDN.
        assert!(html.contains("data:text/javascript;base64,"));
        assert!(!html.contains("unpkg.com"));
        assert!(!html.contains("http://"));
        assert!(!html.contains("https://"));
        // No leftover placeholders.
        for ph in [
            "__THREE_B64__",
            "__ORBIT_B64__",
            "__STLLOADER_B64__",
            "__MODEL_B64__",
            "__TITLE__",
            "__THEME__",
        ] {
            assert!(!html.contains(ph), "leftover placeholder {ph}");
        }
    }

    #[test]
    fn escapes_html_in_title() {
        let html = viewer_html("<x>&\"", "m", "AA", "fff");
        assert!(html.contains("&lt;x&gt;&amp;&quot;"));
    }
}
