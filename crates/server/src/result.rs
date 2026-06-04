//! Helpers for building MCP tool results and mapping errors.

use base64::Engine;
use image::RgbaImage;
use rmcp::model::{CallToolResult, Content};
use rmcp::ErrorData as McpError;
use serde_json::Value;

/// A client-facing usage error (bad arguments).
pub fn invalid(msg: impl Into<String>) -> McpError {
    McpError::invalid_params(msg.into(), None)
}

/// An internal/server error (OpenSCAD missing, I/O failure, …).
pub fn internal(msg: impl Into<String>) -> McpError {
    McpError::internal_error(msg.into(), None)
}

/// Build a successful result carrying both a human-readable summary and a
/// structured JSON payload.
pub fn json_result(summary: impl Into<String>, structured: Value) -> CallToolResult {
    let mut result = CallToolResult::success(vec![Content::text(summary.into())]);
    result.structured_content = Some(structured);
    result
}

/// Like [`json_result`] but flagged as an error condition (e.g. a failed
/// compile). The structured payload still describes what went wrong.
pub fn json_error(summary: impl Into<String>, structured: Value) -> CallToolResult {
    let mut result = CallToolResult::success(vec![Content::text(summary.into())]);
    result.structured_content = Some(structured);
    result.is_error = Some(true);
    result
}

/// Build a result containing an image plus a summary and structured payload.
pub fn image_result(
    summary: impl Into<String>,
    png_base64: String,
    structured: Value,
) -> CallToolResult {
    let mut result = CallToolResult::success(vec![
        Content::text(summary.into()),
        Content::image(png_base64, "image/png"),
    ]);
    result.structured_content = Some(structured);
    result
}

/// Base64-encode raw bytes (standard alphabet).
pub fn base64_encode(bytes: &[u8]) -> String {
    base64::engine::general_purpose::STANDARD.encode(bytes)
}

/// Encode an RGBA image to in-memory PNG bytes.
pub fn encode_png(img: &RgbaImage) -> Result<Vec<u8>, McpError> {
    let mut buf = std::io::Cursor::new(Vec::new());
    img.write_to(&mut buf, image::ImageFormat::Png)
        .map_err(|e| internal(format!("failed to encode PNG: {e}")))?;
    Ok(buf.into_inner())
}
