//! On-disk persistence for profiles and outcomes.
//!
//! Two files live in the data directory:
//!
//! - `profiles.json` — a registry of **baseline** profiles (`id → Profile`):
//!   material defaults plus any manual edits. This records which profiles exist.
//! - `outcomes.ndjson` — an append-only log of real-world [`Outcome`]s, one JSON
//!   object per line (git-diff-friendly).
//!
//! The **effective** profile for an id is computed on demand by replaying the
//! outcome log over the baseline via [`crate::calibrate_from`].

use std::collections::BTreeMap;
use std::io::Write;
use std::path::{Path, PathBuf};

use crate::calibrate::calibrate_from;
use crate::outcome::Outcome;
use crate::profile::Profile;

/// Errors from the store.
#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("I/O error at {path}: {source}")]
    Io {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to parse {path}: {source}")]
    Parse {
        path: String,
        #[source]
        source: serde_json::Error,
    },
}

const PROFILES_FILE: &str = "profiles.json";
const OUTCOMES_FILE: &str = "outcomes.ndjson";

/// A filesystem-backed tolerance store.
#[derive(Debug, Clone)]
pub struct Store {
    dir: PathBuf,
}

impl Store {
    /// Open (creating the directory if needed) a store rooted at `dir`.
    pub fn open(dir: impl Into<PathBuf>) -> Result<Store, StoreError> {
        let dir = dir.into();
        std::fs::create_dir_all(&dir).map_err(|source| StoreError::Io {
            path: dir.display().to_string(),
            source,
        })?;
        Ok(Store { dir })
    }

    fn profiles_path(&self) -> PathBuf {
        self.dir.join(PROFILES_FILE)
    }

    fn outcomes_path(&self) -> PathBuf {
        self.dir.join(OUTCOMES_FILE)
    }

    /// Load the baseline registry (`id → Profile`).
    fn load_baselines(&self) -> Result<BTreeMap<String, Profile>, StoreError> {
        let path = self.profiles_path();
        match std::fs::read_to_string(&path) {
            Ok(text) => serde_json::from_str(&text).map_err(|source| StoreError::Parse {
                path: path.display().to_string(),
                source,
            }),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(BTreeMap::new()),
            Err(source) => Err(StoreError::Io {
                path: path.display().to_string(),
                source,
            }),
        }
    }

    fn save_baselines(&self, map: &BTreeMap<String, Profile>) -> Result<(), StoreError> {
        let path = self.profiles_path();
        let text = serde_json::to_string_pretty(map).map_err(|source| StoreError::Parse {
            path: path.display().to_string(),
            source,
        })?;
        write_atomic(&path, text.as_bytes())
    }

    /// The baseline profile for an id, if registered.
    pub fn baseline(&self, id: &str) -> Result<Option<Profile>, StoreError> {
        Ok(self.load_baselines()?.remove(id))
    }

    /// Ensure a baseline exists for `(printer, material, nozzle)`, creating it
    /// from material defaults if absent. Returns the baseline.
    pub fn register(
        &self,
        printer: &str,
        material: &str,
        nozzle_mm: f64,
    ) -> Result<Profile, StoreError> {
        let id = Profile::id(printer, material, nozzle_mm);
        let mut map = self.load_baselines()?;
        let profile = map
            .entry(id)
            .or_insert_with(|| Profile::default_for(printer, material, nozzle_mm))
            .clone();
        self.save_baselines(&map)?;
        Ok(profile)
    }

    /// Write (create or replace) a baseline profile — used for manual edits.
    pub fn save_baseline(&self, profile: &Profile) -> Result<(), StoreError> {
        let mut map = self.load_baselines()?;
        map.insert(profile.key(), profile.clone());
        self.save_baselines(&map)
    }

    /// Append an outcome to the log.
    pub fn append_outcome(&self, outcome: &Outcome) -> Result<(), StoreError> {
        let path = self.outcomes_path();
        let line = serde_json::to_string(outcome).map_err(|source| StoreError::Parse {
            path: path.display().to_string(),
            source,
        })?;
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)
            .map_err(|source| StoreError::Io {
                path: path.display().to_string(),
                source,
            })?;
        writeln!(file, "{line}").map_err(|source| StoreError::Io {
            path: path.display().to_string(),
            source,
        })
    }

    /// Read every recorded outcome. Malformed lines are skipped.
    pub fn outcomes(&self) -> Result<Vec<Outcome>, StoreError> {
        let path = self.outcomes_path();
        let text = match std::fs::read_to_string(&path) {
            Ok(t) => t,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(source) => {
                return Err(StoreError::Io {
                    path: path.display().to_string(),
                    source,
                })
            }
        };
        Ok(text
            .lines()
            .filter(|l| !l.trim().is_empty())
            .filter_map(|l| serde_json::from_str::<Outcome>(l).ok())
            .collect())
    }

    /// The effective (calibrated) profile for `(printer, material, nozzle)`:
    /// the baseline (or material defaults) with the outcome log replayed over it.
    pub fn effective(
        &self,
        printer: &str,
        material: &str,
        nozzle_mm: f64,
    ) -> Result<Profile, StoreError> {
        let id = Profile::id(printer, material, nozzle_mm);
        let base = self
            .baseline(&id)?
            .unwrap_or_else(|| Profile::default_for(printer, material, nozzle_mm));
        Ok(calibrate_from(base, &self.outcomes()?))
    }

    /// Effective profiles for every registered baseline, sorted by id.
    pub fn list_effective(&self) -> Result<Vec<Profile>, StoreError> {
        let baselines = self.load_baselines()?;
        let outcomes = self.outcomes()?;
        Ok(baselines
            .into_values()
            .map(|base| calibrate_from(base, &outcomes))
            .collect())
    }
}

/// Write a file atomically (write to a temp sibling, then rename).
fn write_atomic(path: &Path, bytes: &[u8]) -> Result<(), StoreError> {
    let tmp = path.with_extension("tmp");
    {
        let mut f = std::fs::File::create(&tmp).map_err(|source| StoreError::Io {
            path: tmp.display().to_string(),
            source,
        })?;
        f.write_all(bytes).map_err(|source| StoreError::Io {
            path: tmp.display().to_string(),
            source,
        })?;
    }
    std::fs::rename(&tmp, path).map_err(|source| StoreError::Io {
        path: path.display().to_string(),
        source,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fit::FitClass;
    use crate::outcome::Measurement;

    fn temp_store() -> (Store, PathBuf) {
        use std::sync::atomic::{AtomicU32, Ordering};
        static COUNTER: AtomicU32 = AtomicU32::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join(format!("demiourgos-store-{}-{n}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        (Store::open(&dir).unwrap(), dir)
    }

    #[test]
    fn register_then_effective_roundtrip() {
        let (store, dir) = temp_store();
        let base = store.register("ender3", "PETG", 0.4).unwrap();
        assert_eq!(base.clearance(FitClass::Slip), 0.25);

        store
            .append_outcome(&Outcome {
                profile_id: Profile::id("ender3", "PETG", 0.4),
                measurement: Measurement::Coupon {
                    fit_class: FitClass::Slip,
                    best_clearance_mm: 0.32,
                },
                note: None,
                timestamp: None,
            })
            .unwrap();

        let eff = store.effective("ender3", "PETG", 0.4).unwrap();
        // A precise coupon pulls the estimate close to 0.32 (Bayesian-smoothed).
        assert!((eff.clearance(FitClass::Slip) - 0.32).abs() < 0.02);
        assert_eq!(eff.samples, 1);

        let listed = store.list_effective().unwrap();
        assert_eq!(listed.len(), 1);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn manual_baseline_is_preserved_without_outcomes() {
        let (store, dir) = temp_store();
        let mut p = Profile::default_for("prusa", "PLA", 0.4);
        p.clearances_mm.set(FitClass::Snug, 0.07);
        store.save_baseline(&p).unwrap();

        let eff = store.effective("prusa", "PLA", 0.4).unwrap();
        assert_eq!(eff.clearance(FitClass::Snug), 0.07);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn missing_files_yield_empty() {
        let (store, dir) = temp_store();
        assert!(store.outcomes().unwrap().is_empty());
        assert!(store.list_effective().unwrap().is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }
}
