//! Calibration: fold recorded [`Outcome`]s into a [`Profile`].
//!
//! The model is intentionally simple and **deterministic** — replay every
//! outcome for a profile in order and let the most recent real-world feedback
//! win per fit class. Caliper readings average into signed dimensional offsets.
//! This is a transparent baseline; a Bayesian/regression layer can replace the
//! per-class update later without changing the data model.

use crate::fit::FitClass;
use crate::outcome::{Feature, Measurement, Outcome, Verdict};
use crate::profile::{Profile, ProfileSource};

/// How much to open up a clearance that came back too tight or jammed.
const TIGHT_BUMP_MM: f64 = 0.025;
const JAM_BUMP_MM: f64 = 0.075;
/// How much to close up a clearance that came back loose.
const LOOSE_TRIM_MM: f64 = 0.05;

/// Sane bounds for a per-side clearance (mm).
const CLEARANCE_MIN: f64 = -0.20;
const CLEARANCE_MAX: f64 = 1.00;

/// Recompute a profile for `(printer, material, nozzle)` from `outcomes`,
/// starting from the material defaults.
///
/// Outcomes whose `profile_id` does not match are ignored, so the full log can
/// be passed in.
pub fn calibrate(printer: &str, material: &str, nozzle_mm: f64, outcomes: &[Outcome]) -> Profile {
    calibrate_from(Profile::default_for(printer, material, nozzle_mm), outcomes)
}

/// Like [`calibrate`] but starting from an explicit baseline profile (e.g. one a
/// user manually registered/edited). Outcomes adjust the baseline rather than the
/// bare material defaults, so manual choices are preserved unless overridden by
/// real-world feedback.
pub fn calibrate_from(mut profile: Profile, outcomes: &[Outcome]) -> Profile {
    let id = profile.key();

    let mut outer_deltas: Vec<f64> = Vec::new();
    let mut hole_deltas: Vec<f64> = Vec::new();
    let mut count = 0u32;

    for outcome in outcomes.iter().filter(|o| o.profile_id == id) {
        count += 1;
        match &outcome.measurement {
            Measurement::Caliper {
                feature,
                nominal_mm,
                measured_mm,
            } => {
                let delta = measured_mm - nominal_mm;
                match feature {
                    Feature::Outer => outer_deltas.push(delta),
                    Feature::Hole => hole_deltas.push(delta),
                }
            }
            Measurement::Coupon {
                fit_class,
                best_clearance_mm,
            } => {
                set_clearance(&mut profile, *fit_class, *best_clearance_mm);
            }
            Measurement::Fit {
                fit_class,
                clearance_mm,
                verdict,
            } => {
                let target = match verdict {
                    Verdict::Good => *clearance_mm,
                    Verdict::Tight => *clearance_mm + TIGHT_BUMP_MM,
                    Verdict::Jam => *clearance_mm + JAM_BUMP_MM,
                    Verdict::Loose => *clearance_mm - LOOSE_TRIM_MM,
                };
                set_clearance(&mut profile, *fit_class, target);
            }
        }
    }

    if let Some(avg) = mean(&outer_deltas) {
        profile.xy_offset_mm = round3(avg);
    }
    if let Some(avg) = mean(&hole_deltas) {
        profile.hole_offset_mm = round3(avg);
    }

    profile.samples = count;
    if count > 0 {
        profile.source = ProfileSource::Calibrated;
    }
    profile
}

fn set_clearance(profile: &mut Profile, class: FitClass, value: f64) {
    let clamped = round3(value.clamp(CLEARANCE_MIN, CLEARANCE_MAX));
    profile.clearances_mm.set(class, clamped);
}

fn mean(v: &[f64]) -> Option<f64> {
    if v.is_empty() {
        None
    } else {
        Some(v.iter().sum::<f64>() / v.len() as f64)
    }
}

fn round3(v: f64) -> f64 {
    (v * 1000.0).round() / 1000.0
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::outcome::Outcome;

    fn outcome(id: &str, m: Measurement) -> Outcome {
        Outcome {
            profile_id: id.to_string(),
            measurement: m,
            note: None,
            timestamp: None,
        }
    }

    #[test]
    fn no_outcomes_yields_default() {
        let p = calibrate("ender3", "PLA", 0.4, &[]);
        assert_eq!(p.source, ProfileSource::Default);
        assert_eq!(p.clearance(FitClass::Slip), 0.20);
    }

    #[test]
    fn coupon_sets_clearance_directly() {
        let id = Profile::id("ender3", "PETG", 0.4);
        let p = calibrate(
            "ender3",
            "PETG",
            0.4,
            &[outcome(
                &id,
                Measurement::Coupon {
                    fit_class: FitClass::Slip,
                    best_clearance_mm: 0.30,
                },
            )],
        );
        assert_eq!(p.clearance(FitClass::Slip), 0.30);
        assert_eq!(p.source, ProfileSource::Calibrated);
        assert_eq!(p.samples, 1);
    }

    #[test]
    fn jam_opens_clearance_above_what_was_tried() {
        let id = Profile::id("ender3", "PLA", 0.4);
        let p = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[outcome(
                &id,
                Measurement::Fit {
                    fit_class: FitClass::Snug,
                    clearance_mm: 0.10,
                    verdict: Verdict::Jam,
                },
            )],
        );
        assert!(p.clearance(FitClass::Snug) > 0.10);
    }

    #[test]
    fn loose_trims_clearance() {
        let id = Profile::id("ender3", "PLA", 0.4);
        let p = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[outcome(
                &id,
                Measurement::Fit {
                    fit_class: FitClass::Slip,
                    clearance_mm: 0.40,
                    verdict: Verdict::Loose,
                },
            )],
        );
        assert!((p.clearance(FitClass::Slip) - 0.35).abs() < 1e-9);
    }

    #[test]
    fn latest_outcome_wins_per_class() {
        let id = Profile::id("ender3", "PLA", 0.4);
        let p = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[
                outcome(
                    &id,
                    Measurement::Coupon {
                        fit_class: FitClass::Slip,
                        best_clearance_mm: 0.20,
                    },
                ),
                outcome(
                    &id,
                    Measurement::Coupon {
                        fit_class: FitClass::Slip,
                        best_clearance_mm: 0.28,
                    },
                ),
            ],
        );
        assert_eq!(p.clearance(FitClass::Slip), 0.28);
        assert_eq!(p.samples, 2);
    }

    #[test]
    fn caliper_averages_into_offsets() {
        let id = Profile::id("ender3", "PLA", 0.4);
        let p = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[
                outcome(
                    &id,
                    Measurement::Caliper {
                        feature: Feature::Hole,
                        nominal_mm: 5.0,
                        measured_mm: 4.85,
                    },
                ),
                outcome(
                    &id,
                    Measurement::Caliper {
                        feature: Feature::Hole,
                        nominal_mm: 10.0,
                        measured_mm: 9.87,
                    },
                ),
            ],
        );
        // mean delta = (-0.15 + -0.13)/2 = -0.14
        assert!((p.hole_offset_mm - (-0.14)).abs() < 1e-9);
    }

    #[test]
    fn ignores_other_profiles() {
        let p = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[outcome(
                "other/abs/0.6",
                Measurement::Coupon {
                    fit_class: FitClass::Slip,
                    best_clearance_mm: 0.9,
                },
            )],
        );
        assert_eq!(p.samples, 0);
        assert_eq!(p.clearance(FitClass::Slip), 0.20);
    }
}
