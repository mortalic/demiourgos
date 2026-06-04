//! Conversion of tool parameters (JSON-ish) into OpenSCAD invocation inputs.

use std::collections::BTreeMap;

use demiourgos_scad::{Define, Projection, View};
use serde_json::Value;

/// Convert a map of variable overrides into OpenSCAD `-D` defines.
///
/// JSON numbers and booleans become bare OpenSCAD literals; JSON strings become
/// quoted OpenSCAD string literals. Arrays/objects are serialized as OpenSCAD
/// vectors/values via their JSON form (which is largely SCAD-compatible for
/// numeric vectors). This makes `{"height": 12, "label": "A"}` predictable.
pub fn defines_from_map(overrides: &BTreeMap<String, Value>) -> Vec<Define> {
    overrides
        .iter()
        .map(|(name, value)| Define::new(name.clone(), scad_expr(value)))
        .collect()
}

/// Render a JSON value as an OpenSCAD expression string.
fn scad_expr(value: &Value) -> String {
    match value {
        Value::Null => "undef".to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => n.to_string(),
        Value::String(s) => format!("\"{}\"", escape_scad_string(s)),
        // Arrays of numbers map cleanly to OpenSCAD vectors; nested values use
        // their JSON form which is compatible for numeric data.
        Value::Array(items) => {
            let parts: Vec<String> = items.iter().map(scad_expr).collect();
            format!("[{}]", parts.join(","))
        }
        // Objects have no direct SCAD analogue; emit undef rather than guess.
        Value::Object(_) => "undef".to_string(),
    }
}

fn escape_scad_string(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}

/// Parse a projection string (`o`/`ortho`/`orthographic` or `p`/`perspective`).
pub fn parse_projection(s: &str) -> Result<Projection, String> {
    match s.trim().to_ascii_lowercase().as_str() {
        "o" | "ortho" | "orthographic" => Ok(Projection::Ortho),
        "p" | "persp" | "perspective" => Ok(Projection::Perspective),
        other => Err(format!(
            "unknown projection '{other}' (expected 'ortho' or 'perspective')"
        )),
    }
}

/// Parse a view name into a [`View`], surfacing a friendly error.
pub fn parse_view(s: &str) -> Result<View, String> {
    s.parse::<View>().map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn map(pairs: &[(&str, Value)]) -> BTreeMap<String, Value> {
        pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.clone()))
            .collect()
    }

    #[test]
    fn numbers_and_bools_are_bare() {
        let d = defines_from_map(&map(&[("h", Value::from(12)), ("on", Value::from(true))]));
        let by: BTreeMap<_, _> = d
            .iter()
            .map(|d| (d.name.as_str(), d.expr.as_str()))
            .collect();
        assert_eq!(by["h"], "12");
        assert_eq!(by["on"], "true");
    }

    #[test]
    fn strings_are_quoted_and_escaped() {
        let d = defines_from_map(&map(&[("label", Value::from("a\"b"))]));
        assert_eq!(d[0].expr, "\"a\\\"b\"");
    }

    #[test]
    fn arrays_become_vectors() {
        let d = defines_from_map(&map(&[("size", serde_json::json!([1, 2, 3]))]));
        assert_eq!(d[0].expr, "[1,2,3]");
    }

    #[test]
    fn projection_parsing() {
        assert_eq!(parse_projection("ortho").unwrap(), Projection::Ortho);
        assert_eq!(parse_projection("P").unwrap(), Projection::Perspective);
        assert!(parse_projection("isometric").is_err());
    }
}
