//! Parsing of OpenSCAD's stderr/stdout into structured diagnostics.
//!
//! OpenSCAD prints human-readable lines such as:
//!
//! ```text
//! ECHO: "hello", 42
//! WARNING: Ignoring unknown variable 'foo' in file part.scad, line 12
//! ERROR: Parser error: syntax error in file part.scad, line 7
//! ERROR: Parser error in line 7: syntax error
//! ```
//!
//! We extract a [`Severity`], the message text, and a line number where one is
//! present. ECHO output is captured separately because it is the program's
//! intentional output, not a problem.

use serde::Serialize;

/// Severity of a parsed diagnostic.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Error,
    Warning,
    /// `TRACE:`/`DEBUG:` and other informational prefixes.
    Info,
}

/// A single parsed OpenSCAD diagnostic.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Diagnostic {
    pub severity: Severity,
    pub message: String,
    /// 1-based source line, when OpenSCAD reported one.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub line: Option<u32>,
}

/// Result of scanning an OpenSCAD run's textual output.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct ParsedOutput {
    pub diagnostics: Vec<Diagnostic>,
    /// `ECHO:` payloads with the prefix stripped.
    pub echos: Vec<String>,
}

impl ParsedOutput {
    pub fn has_errors(&self) -> bool {
        self.diagnostics
            .iter()
            .any(|d| d.severity == Severity::Error)
    }

    pub fn errors(&self) -> impl Iterator<Item = &Diagnostic> {
        self.diagnostics
            .iter()
            .filter(|d| d.severity == Severity::Error)
    }

    pub fn warnings(&self) -> impl Iterator<Item = &Diagnostic> {
        self.diagnostics
            .iter()
            .filter(|d| d.severity == Severity::Warning)
    }
}

/// Parse a blob of OpenSCAD output (typically stderr, optionally with stdout
/// merged) into structured diagnostics and echo lines.
pub fn parse(output: &str) -> ParsedOutput {
    let mut parsed = ParsedOutput::default();

    for raw in output.lines() {
        let line = raw.trim_end();
        let trimmed = line.trim_start();

        if let Some(rest) = trimmed.strip_prefix("ECHO:") {
            parsed.echos.push(rest.trim().to_string());
            continue;
        }

        let (severity, rest) = if let Some(rest) = trimmed.strip_prefix("ERROR:") {
            (Severity::Error, rest)
        } else if let Some(rest) = trimmed.strip_prefix("WARNING:") {
            (Severity::Warning, rest)
        } else if let Some(rest) = trimmed.strip_prefix("TRACE:") {
            (Severity::Info, rest)
        } else if let Some(rest) = trimmed.strip_prefix("DEBUG:") {
            (Severity::Info, rest)
        } else {
            // Lines without a recognized prefix are noise (banner text, blank
            // lines, "Current top level object is empty", etc.). Skip them.
            continue;
        };

        let message = rest.trim().to_string();
        let line_no = extract_line_number(&message);
        parsed.diagnostics.push(Diagnostic {
            severity,
            message,
            line: line_no,
        });
    }

    parsed
}

/// Find a `line N` reference anywhere in a message, returning the number.
///
/// Handles both `in line 7` and `, line 12` phrasings without a regex dep.
fn extract_line_number(message: &str) -> Option<u32> {
    let lower = message.to_ascii_lowercase();
    let mut search_from = 0;
    while let Some(idx) = lower[search_from..].find("line ") {
        let abs = search_from + idx + "line ".len();
        let digits: String = message[abs..]
            .chars()
            .take_while(|c| c.is_ascii_digit())
            .collect();
        if let Ok(n) = digits.parse::<u32>() {
            return Some(n);
        }
        search_from = abs;
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_echo_lines() {
        let out = parse("ECHO: \"hello\", 42\nECHO: 3.14");
        assert_eq!(
            out.echos,
            vec!["\"hello\", 42".to_string(), "3.14".to_string()]
        );
        assert!(out.diagnostics.is_empty());
    }

    #[test]
    fn parses_error_with_line_number() {
        let out = parse("ERROR: Parser error: syntax error in file part.scad, line 7");
        assert_eq!(out.diagnostics.len(), 1);
        let d = &out.diagnostics[0];
        assert_eq!(d.severity, Severity::Error);
        assert_eq!(d.line, Some(7));
        assert!(out.has_errors());
    }

    #[test]
    fn parses_in_line_phrasing() {
        let out = parse("ERROR: Parser error in line 12: syntax error");
        assert_eq!(out.diagnostics[0].line, Some(12));
    }

    #[test]
    fn parses_warning_without_line() {
        let out = parse("WARNING: Object may not be a valid 2-manifold");
        assert_eq!(out.diagnostics.len(), 1);
        assert_eq!(out.diagnostics[0].severity, Severity::Warning);
        assert_eq!(out.diagnostics[0].line, None);
        assert!(!out.has_errors());
        assert_eq!(out.warnings().count(), 1);
    }

    #[test]
    fn ignores_banner_noise() {
        let out = parse("OpenSCAD version 2021.01\n\nCompiling design (CSG Tree generation)...");
        assert!(out.diagnostics.is_empty());
        assert!(out.echos.is_empty());
    }

    #[test]
    fn handles_indented_diagnostics() {
        let out = parse("   WARNING: something happened, line 3");
        assert_eq!(out.diagnostics[0].severity, Severity::Warning);
        assert_eq!(out.diagnostics[0].line, Some(3));
    }
}
