//! Golden integration test: export and measure the `dovetail-bin` example with
//! a real OpenSCAD binary and assert its known dimensions against the checked-in
//! reference in `tests/golden/`.
//!
//! Marked `#[ignore]` because it requires the `openscad` binary. CI (and anyone
//! with OpenSCAD installed) runs it via `cargo test -- --include-ignored`.

use std::path::PathBuf;
use std::time::Duration;

use demiourgos_mesh::Mesh;
use demiourgos_scad::{ExportFormat, OpenScad};

/// Repo root, derived from this crate's manifest dir (`crates/server`).
fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("..")
        .canonicalize()
        .expect("canonicalize repo root")
}

#[tokio::test]
#[ignore = "requires the openscad binary; run with --include-ignored"]
async fn dovetail_bin_matches_golden() {
    let root = repo_root();
    let scad_file = root.join("examples/dovetail-bin/dovetail-bin.scad");
    assert!(
        scad_file.is_file(),
        "missing example: {}",
        scad_file.display()
    );

    let golden: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(root.join("tests/golden/dovetail-bin.measure.json"))
            .expect("read golden"),
    )
    .expect("parse golden");

    let scad = OpenScad::discover()
        .await
        .expect("OpenSCAD must be installed to run this test");

    let out_dir = std::env::temp_dir().join(format!("demiourgos-golden-{}", std::process::id()));
    std::fs::create_dir_all(&out_dir).unwrap();
    let stl = out_dir.join("dovetail-bin.stl");

    let run = scad
        .export(
            &scad_file,
            &stl,
            ExportFormat::BinStl,
            None,
            &[],
            Duration::from_secs(120),
        )
        .await
        .expect("export should run");
    assert!(run.success, "export failed: {}", run.stderr);
    assert!(stl.is_file(), "no STL produced");

    let mesh = Mesh::from_stl_path(&stl).expect("load STL");
    let analysis = mesh.analyze().expect("analyze mesh");

    // Bounding box is exact (clean integer dimensions).
    let size = &analysis.bounding_box.size;
    let gsize = golden["bounding_box_size"].as_array().unwrap();
    for (k, g) in gsize.iter().enumerate() {
        let expected = g.as_f64().unwrap();
        assert!(
            (size[k] - expected).abs() < 1e-6,
            "bbox axis {k}: got {}, expected {expected}",
            size[k]
        );
    }

    // Volume within a small tolerance.
    let expected_vol = golden["volume_mm3"].as_f64().unwrap();
    assert!(
        (analysis.volume - expected_vol).abs() < 1.0,
        "volume: got {}, expected {expected_vol}",
        analysis.volume
    );

    assert_eq!(
        analysis.watertight,
        golden["watertight"].as_bool().unwrap(),
        "watertightness mismatch"
    );
    assert_eq!(
        analysis.triangle_count as u64,
        golden["triangle_count"].as_u64().unwrap(),
        "triangle count regressed"
    );

    let _ = std::fs::remove_dir_all(&out_dir);
}
