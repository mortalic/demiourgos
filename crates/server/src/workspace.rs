//! The workspace: a directory of `.scad` models plus an `artifacts/` subdir for
//! rendered images and exported meshes.
//!
//! Model names are sanitized so a tool call can never read or write outside the
//! workspace (no path separators, no `..`).

use std::path::{Path, PathBuf};

/// Subdirectory (under the workspace root) for generated artifacts.
const ARTIFACTS_DIR: &str = "artifacts";

/// The self-supporting helper library installed into every workspace.
const SUPPORT_LIB_NAME: &str = "demiourgos_support.scad";
const SUPPORT_LIB_SRC: &str = include_str!("../assets/scad/demiourgos_support.scad");

/// Manages the on-disk workspace.
#[derive(Debug, Clone)]
pub struct Workspace {
    root: PathBuf,
    artifacts: PathBuf,
}

/// A model name that has been validated as a safe, single-segment `.scad` file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelName(String);

impl ModelName {
    /// The file name including the `.scad` extension.
    pub fn file_name(&self) -> &str {
        &self.0
    }

    /// The name without the `.scad` extension (used to name artifacts).
    pub fn stem(&self) -> &str {
        self.0.strip_suffix(".scad").unwrap_or(&self.0)
    }
}

impl Workspace {
    /// Open (creating if necessary) the workspace rooted at `root`.
    pub fn open(root: impl Into<PathBuf>) -> std::io::Result<Workspace> {
        let root = root.into();
        let artifacts = root.join(ARTIFACTS_DIR);
        std::fs::create_dir_all(&artifacts)?;
        let root = root.canonicalize()?;
        let artifacts = artifacts.canonicalize()?;

        // Install (refresh) the self-supporting helper library so models can
        // `use <demiourgos_support.scad>;`. Only rewrite when the content differs.
        let lib_path = root.join(SUPPORT_LIB_NAME);
        let needs_write = std::fs::read_to_string(&lib_path)
            .map(|existing| existing != SUPPORT_LIB_SRC)
            .unwrap_or(true);
        if needs_write {
            let _ = std::fs::write(&lib_path, SUPPORT_LIB_SRC);
        }

        Ok(Workspace { root, artifacts })
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn artifacts_dir(&self) -> &Path {
        &self.artifacts
    }

    /// Validate and normalize a user-supplied model name. Appends `.scad` if the
    /// caller omitted it. Rejects anything that isn't a single safe path segment.
    pub fn validate_name(name: &str) -> Result<ModelName, String> {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err("model name must not be empty".to_string());
        }
        if trimmed.contains('/') || trimmed.contains('\\') {
            return Err(format!(
                "model name '{trimmed}' must not contain path separators"
            ));
        }
        if trimmed == "." || trimmed == ".." || trimmed.contains("..") {
            return Err(format!("model name '{trimmed}' is not allowed"));
        }
        // Defense in depth: a sanitized name must be exactly its own file name.
        if Path::new(trimmed).file_name().and_then(|s| s.to_str()) != Some(trimmed) {
            return Err(format!("model name '{trimmed}' is not a simple file name"));
        }
        let file_name = if trimmed.ends_with(".scad") {
            trimmed.to_string()
        } else {
            format!("{trimmed}.scad")
        };
        // Re-validate the bare stem allows a sensible character set.
        let stem = file_name.strip_suffix(".scad").unwrap_or(&file_name);
        if !stem
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == '.')
        {
            return Err(format!(
                "model name '{stem}' may only contain letters, digits, '_', '-', and '.'"
            ));
        }
        Ok(ModelName(file_name))
    }

    /// Absolute path to a model's `.scad` file (whether or not it exists).
    pub fn model_path(&self, name: &ModelName) -> PathBuf {
        self.root.join(&name.0)
    }

    /// Absolute path for a generated artifact file name.
    pub fn artifact_path(&self, file_name: &str) -> PathBuf {
        self.artifacts.join(file_name)
    }

    /// Write (create or overwrite) a model's source, returning its path.
    pub fn write_model(&self, name: &ModelName, source: &str) -> std::io::Result<PathBuf> {
        let path = self.model_path(name);
        std::fs::write(&path, source)?;
        Ok(path)
    }

    /// Read a model's source.
    pub fn read_model(&self, name: &ModelName) -> std::io::Result<String> {
        std::fs::read_to_string(self.model_path(name))
    }

    /// Whether a model file exists.
    pub fn model_exists(&self, name: &ModelName) -> bool {
        self.model_path(name).is_file()
    }

    /// List all `.scad` model file names in the workspace, sorted.
    pub fn list_models(&self) -> std::io::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in std::fs::read_dir(&self.root)? {
            let entry = entry?;
            if !entry.file_type()?.is_file() {
                continue;
            }
            let name = entry.file_name();
            if let Some(name) = name.to_str() {
                // Skip the installed helper library — it isn't a user model.
                if name.ends_with(".scad") && name != SUPPORT_LIB_NAME {
                    names.push(name.to_string());
                }
            }
        }
        names.sort();
        Ok(names)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn appends_scad_extension() {
        let n = Workspace::validate_name("bracket").unwrap();
        assert_eq!(n.file_name(), "bracket.scad");
        assert_eq!(n.stem(), "bracket");
    }

    #[test]
    fn keeps_existing_extension() {
        let n = Workspace::validate_name("bracket.scad").unwrap();
        assert_eq!(n.file_name(), "bracket.scad");
        assert_eq!(n.stem(), "bracket");
    }

    #[test]
    fn rejects_path_traversal() {
        assert!(Workspace::validate_name("../evil").is_err());
        assert!(Workspace::validate_name("sub/dir").is_err());
        assert!(Workspace::validate_name("a\\b").is_err());
        assert!(Workspace::validate_name("..").is_err());
        assert!(Workspace::validate_name("").is_err());
    }

    #[test]
    fn rejects_odd_characters() {
        assert!(Workspace::validate_name("na me").is_err());
        assert!(Workspace::validate_name("we!rd").is_err());
    }

    #[test]
    fn read_write_list_roundtrip() {
        let tmp = std::env::temp_dir().join(format!("demiourgos-ws-test-{}", std::process::id()));
        let ws = Workspace::open(&tmp).unwrap();
        let name = Workspace::validate_name("cube").unwrap();
        ws.write_model(&name, "cube(10);").unwrap();
        assert!(ws.model_exists(&name));
        assert_eq!(ws.read_model(&name).unwrap(), "cube(10);");
        assert!(ws.list_models().unwrap().contains(&"cube.scad".to_string()));
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
