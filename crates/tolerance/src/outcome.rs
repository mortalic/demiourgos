//! Real-world print outcomes — the feedback that turns default profiles into
//! calibrated ones. Each outcome is appended to an NDJSON log and replayed by
//! [`crate::calibrate`].

use serde::{Deserialize, Serialize};

use crate::fit::FitClass;

/// Which kind of feature a caliper measurement refers to.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Feature {
    /// An external dimension (width, length, peg diameter).
    Outer,
    /// An internal dimension (a hole or bore diameter).
    Hole,
}

/// A qualitative judgement of how an assembled fit felt.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Verdict {
    /// Has play / falls out — too much clearance.
    Loose,
    /// Just right.
    Good,
    /// Goes together with effort — borderline.
    Tight,
    /// Won't assemble — too little clearance.
    Jam,
}

impl std::str::FromStr for Verdict {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "loose" | "sloppy" | "fell out" | "fellout" => Ok(Verdict::Loose),
            "good" | "perfect" | "ok" => Ok(Verdict::Good),
            "tight" | "stiff" => Ok(Verdict::Tight),
            "jam" | "jammed" | "stuck" | "nofit" | "no fit" => Ok(Verdict::Jam),
            other => Err(format!(
                "unknown verdict '{other}' (expected loose, good, tight, or jam)"
            )),
        }
    }
}

/// The substance of an outcome.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Measurement {
    /// A caliper reading of a printed feature versus its nominal design value.
    /// Drives the dimensional offsets.
    Caliper {
        feature: Feature,
        nominal_mm: f64,
        measured_mm: f64,
    },
    /// The clearance step from a fit-test coupon that gave the desired fit class.
    /// Directly sets that class's recommended clearance.
    Coupon {
        fit_class: FitClass,
        best_clearance_mm: f64,
    },
    /// Qualitative feedback on an assembled fit at a known clearance. Nudges the
    /// class's clearance up (jam/tight) or down (loose).
    Fit {
        fit_class: FitClass,
        clearance_mm: f64,
        verdict: Verdict,
    },
}

/// A single recorded outcome for one profile.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Outcome {
    pub profile_id: String,
    #[serde(flatten)]
    pub measurement: Measurement,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub note: Option<String>,
    /// Optional caller-supplied timestamp (this crate never reads the clock).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timestamp: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outcome_round_trips_through_json() {
        let o = Outcome {
            profile_id: "ender3/petg/0.4".into(),
            measurement: Measurement::Coupon {
                fit_class: FitClass::Slip,
                best_clearance_mm: 0.25,
            },
            note: Some("drawer".into()),
            timestamp: None,
        };
        let s = serde_json::to_string(&o).unwrap();
        let back: Outcome = serde_json::from_str(&s).unwrap();
        assert_eq!(o, back);
        // The flattened tag is present.
        assert!(s.contains("\"kind\":\"coupon\""));
    }

    #[test]
    fn verdict_parses() {
        assert_eq!("jammed".parse::<Verdict>().unwrap(), Verdict::Jam);
        assert_eq!("perfect".parse::<Verdict>().unwrap(), Verdict::Good);
    }
}
