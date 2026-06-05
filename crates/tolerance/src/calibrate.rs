//! Calibration: fold recorded [`Outcome`]s into a [`Profile`].
//!
//! Each fit-class clearance is treated as an unknown with a **Normal prior**
//! (the material default ± [`crate::profile::PRIOR_STD_MM`]). Every coupon or
//! fit outcome is a noisy Normal observation; we combine them with the prior via
//! the conjugate Normal–Normal update, giving a posterior **mean** (the
//! recommendation) and **standard deviation** (the confidence, which shrinks as
//! evidence accumulates). This is a small, transparent Bayesian model — not a
//! full Gaussian-process optimizer — but it learns sensibly, fuses repeated
//! measurements instead of letting the last one win, and exposes uncertainty so
//! [`suggest_coupon_range`] can drive the next print toward convergence.

use crate::fit::FitClass;
use crate::outcome::{Feature, Measurement, Outcome, Verdict};
use crate::profile::{Profile, ProfileSource, PRIOR_STD_MM};

/// Observation noise (std, mm) for a fit-test coupon best-fit — precise.
const OBS_STD_COUPON: f64 = 0.03;
/// Observation noise for a "good" assembly verdict at a known clearance.
const OBS_STD_FIT_GOOD: f64 = 0.04;
/// Observation noise for tight/jam/loose verdicts (the implied clearance is fuzzier).
const OBS_STD_FIT_OTHER: f64 = 0.06;

/// Implied "right" clearance offsets for non-good verdicts (mm).
const TIGHT_BUMP_MM: f64 = 0.04;
const JAM_BUMP_MM: f64 = 0.10;
const LOOSE_TRIM_MM: f64 = 0.06;

/// Sane bounds for a per-side clearance (mm).
const CLEARANCE_MIN: f64 = -0.20;
const CLEARANCE_MAX: f64 = 1.00;

/// A single Normal observation `(value, std)`.
#[derive(Clone, Copy)]
struct Obs {
    value: f64,
    std: f64,
}

/// Recompute a profile for `(printer, material, nozzle)` from `outcomes`,
/// starting from the material defaults.
///
/// Outcomes whose `profile_id` does not match are ignored, so the full log can
/// be passed in.
pub fn calibrate(printer: &str, material: &str, nozzle_mm: f64, outcomes: &[Outcome]) -> Profile {
    calibrate_from(Profile::default_for(printer, material, nozzle_mm), outcomes)
}

/// Like [`calibrate`] but starting from an explicit baseline profile (e.g. one a
/// user manually registered/edited). The baseline's clearances act as the prior
/// means, so manual choices are respected but refined by real-world data.
pub fn calibrate_from(mut profile: Profile, outcomes: &[Outcome]) -> Profile {
    let id = profile.key();

    // Observations per fit class, plus caliper deltas for the dimensional offsets.
    let mut obs: [Vec<Obs>; 4] = [vec![], vec![], vec![], vec![]];
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
            } => obs[class_idx(*fit_class)].push(Obs {
                value: *best_clearance_mm,
                std: OBS_STD_COUPON,
            }),
            Measurement::Fit {
                fit_class,
                clearance_mm,
                verdict,
            } => {
                let (value, std) = match verdict {
                    Verdict::Good => (*clearance_mm, OBS_STD_FIT_GOOD),
                    Verdict::Tight => (*clearance_mm + TIGHT_BUMP_MM, OBS_STD_FIT_OTHER),
                    Verdict::Jam => (*clearance_mm + JAM_BUMP_MM, OBS_STD_FIT_OTHER),
                    Verdict::Loose => (*clearance_mm - LOOSE_TRIM_MM, OBS_STD_FIT_OTHER),
                };
                obs[class_idx(*fit_class)].push(Obs { value, std });
            }
        }
    }

    // Conjugate Normal–Normal posterior for each class's clearance.
    for class in FitClass::all() {
        let prior_mean = profile.clearance(class);
        let (mean, std) = posterior(prior_mean, PRIOR_STD_MM, &obs[class_idx(class)]);
        profile
            .clearances_mm
            .set(class, round3(mean.clamp(CLEARANCE_MIN, CLEARANCE_MAX)));
        profile.clearance_std_mm.set(class, round3(std));
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

/// Normal–Normal conjugate update: prior `N(prior_mean, prior_std²)` combined
/// with observations, returning the posterior `(mean, std)`.
fn posterior(prior_mean: f64, prior_std: f64, observations: &[Obs]) -> (f64, f64) {
    let mut precision = 1.0 / (prior_std * prior_std);
    let mut weighted = prior_mean * precision;
    for o in observations {
        let w = 1.0 / (o.std * o.std);
        precision += w;
        weighted += o.value * w;
    }
    (weighted / precision, (1.0 / precision).sqrt())
}

/// A proposed clearance range for the next fit-test coupon, chosen to reduce
/// the posterior uncertainty of a fit class (active learning).
#[derive(Debug, Clone, PartialEq)]
pub struct CouponSuggestion {
    pub fit_class: FitClass,
    pub center_mm: f64,
    pub std_mm: f64,
    pub min_mm: f64,
    pub max_mm: f64,
    pub step_mm: f64,
    /// True when the posterior is already tight enough to trust.
    pub well_calibrated: bool,
    pub rationale: String,
}

/// Propose the next coupon's clearance sweep for a fit class, centered on the
/// current estimate and widened by its uncertainty.
pub fn suggest_coupon_range(profile: &Profile, class: FitClass) -> CouponSuggestion {
    let center = profile.clearance(class);
    let std = profile.clearance_std(class);
    let well_calibrated = std <= 0.025;

    let half = if well_calibrated {
        0.05
    } else {
        (2.0 * std).clamp(0.08, 0.25)
    };
    let min = round2((center - half).max(0.0));
    let max = round2(center + half);
    // Aim for ~6–10 steps across the range.
    let step = round2(((max - min) / 8.0).clamp(0.02, 0.08));

    let rationale = if well_calibrated {
        format!(
            "{class} clearance is well calibrated ({center:.3} ± {std:.3} mm); a tight \
             confirmation sweep"
        )
    } else {
        format!(
            "{class} clearance is uncertain ({center:.3} ± {std:.3} mm); sweep {min:.2}–{max:.2} mm \
             to converge"
        )
    };

    CouponSuggestion {
        fit_class: class,
        center_mm: round3(center),
        std_mm: round3(std),
        min_mm: min,
        max_mm: max,
        step_mm: step,
        well_calibrated,
        rationale,
    }
}

fn class_idx(c: FitClass) -> usize {
    match c {
        FitClass::Slip => 0,
        FitClass::Snug => 1,
        FitClass::Press => 2,
        FitClass::Snap => 3,
    }
}

fn mean(v: &[f64]) -> Option<f64> {
    if v.is_empty() {
        None
    } else {
        Some(v.iter().sum::<f64>() / v.len() as f64)
    }
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
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
    fn no_outcomes_yields_default_with_prior_std() {
        let p = calibrate("ender3", "PLA", 0.4, &[]);
        assert_eq!(p.source, ProfileSource::Default);
        assert_eq!(p.clearance(FitClass::Slip), 0.20);
        assert!((p.clearance_std(FitClass::Slip) - PRIOR_STD_MM).abs() < 1e-9);
    }

    #[test]
    fn one_coupon_pulls_estimate_toward_observation_and_shrinks_std() {
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
        // PETG default slip is 0.25; a precise coupon at 0.30 dominates.
        assert!(
            (p.clearance(FitClass::Slip) - 0.30).abs() < 0.02,
            "got {}",
            p.clearance(FitClass::Slip)
        );
        assert!(p.clearance_std(FitClass::Slip) < PRIOR_STD_MM);
        assert_eq!(p.source, ProfileSource::Calibrated);
        assert_eq!(p.samples, 1);
    }

    #[test]
    fn repeated_coupons_fuse_evidence_and_shrink_further() {
        let id = Profile::id("ender3", "PLA", 0.4);
        let one = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[outcome(
                &id,
                Measurement::Coupon {
                    fit_class: FitClass::Slip,
                    best_clearance_mm: 0.24,
                },
            )],
        );
        let two = calibrate(
            "ender3",
            "PLA",
            0.4,
            &[
                outcome(
                    &id,
                    Measurement::Coupon {
                        fit_class: FitClass::Slip,
                        best_clearance_mm: 0.24,
                    },
                ),
                outcome(
                    &id,
                    Measurement::Coupon {
                        fit_class: FitClass::Slip,
                        best_clearance_mm: 0.26,
                    },
                ),
            ],
        );
        // Two consistent observations -> estimate between them, tighter than one.
        assert!(two.clearance(FitClass::Slip) > 0.23 && two.clearance(FitClass::Slip) < 0.27);
        assert!(two.clearance_std(FitClass::Slip) < one.clearance_std(FitClass::Slip));
        assert_eq!(two.samples, 2);
    }

    #[test]
    fn jam_pushes_clearance_open() {
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
    fn loose_recommends_less_than_what_was_tried() {
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
        assert!(p.clearance(FitClass::Slip) < 0.40);
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

    #[test]
    fn suggest_range_is_wide_when_uncertain_tight_when_calibrated() {
        let uncal = calibrate("e", "PLA", 0.4, &[]);
        let s = suggest_coupon_range(&uncal, FitClass::Slip);
        assert!(!s.well_calibrated);
        assert!(s.max_mm - s.min_mm > 0.1);
        assert!(s.step_mm >= 0.02);

        let id = Profile::id("e", "PLA", 0.4);
        let obs: Vec<_> = (0..6)
            .map(|_| {
                outcome(
                    &id,
                    Measurement::Coupon {
                        fit_class: FitClass::Slip,
                        best_clearance_mm: 0.25,
                    },
                )
            })
            .collect();
        let cal = calibrate("e", "PLA", 0.4, &obs);
        let s2 = suggest_coupon_range(&cal, FitClass::Slip);
        assert!(
            s2.well_calibrated,
            "std was {}",
            cal.clearance_std(FitClass::Slip)
        );
    }
}
