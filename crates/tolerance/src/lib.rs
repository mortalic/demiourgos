//! `demiourgos-tolerance` — the learning half of Demiourgos.
//!
//! Where `demiourgos-mesh` measures the *digital* model, this crate captures
//! what happens when it meets a *physical* printer. It holds:
//!
//! - [`Profile`] — the calibrated dimensional behavior of one
//!   `(printer, material, nozzle)`, with per-[`FitClass`] clearances seeded from
//!   literature defaults.
//! - [`Outcome`] — real-world feedback (caliper readings, fit-test coupon
//!   results, assembly verdicts) recorded against a profile.
//! - [`calibrate`] / [`calibrate_from`] — fold outcomes into a profile so it
//!   improves with every print.
//! - [`coupon`] — generate a one-print fit-test coupon to calibrate a profile
//!   in a single pass.
//! - [`Store`] — git-friendly on-disk persistence (`profiles.json` +
//!   `outcomes.ndjson`).
//!
//! The whole point is to cut down reprint iterations: learn each printer/material
//! once, then reuse the right clearances forever.

pub mod calibrate;
pub mod coupon;
pub mod fit;
pub mod outcome;
pub mod profile;
pub mod store;

pub use calibrate::{calibrate, calibrate_from, suggest_coupon_range, CouponSuggestion};
pub use coupon::{clearance_steps, coupon_scad, CouponSpec};
pub use fit::FitClass;
pub use outcome::{Feature, Measurement, Outcome, Verdict};
pub use profile::{material_defaults, Clearances, Profile, ProfileSource};
pub use store::{Store, StoreError};
