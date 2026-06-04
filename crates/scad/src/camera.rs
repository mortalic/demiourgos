//! Named-view camera math.
//!
//! Demiurge owns the OpenSCAD camera string so callers never have to write raw
//! `--camera=` values. We use OpenSCAD's *gimbal* camera form:
//!
//! ```text
//! --camera=trans_x,trans_y,trans_z,rot_x,rot_y,rot_z,distance
//! ```
//!
//! The rotation triple is the object Euler rotation in degrees. The values below
//! match the standard view angles used by the OpenSCAD GUI (View ▸ Top/Front/…).
//! We pair the camera with `--viewall --autocenter` at render time so the object
//! is always framed regardless of its size, which keeps the math here focused on
//! *orientation* — the part that actually matters to the caller.

use std::fmt;
use std::str::FromStr;

/// A standard, named camera viewpoint.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum View {
    Front,
    Back,
    Left,
    Right,
    Top,
    Bottom,
    /// Isometric three-quarter view (OpenSCAD's default-ish orientation).
    Iso,
}

impl View {
    /// Object Euler rotation `(rot_x, rot_y, rot_z)` in degrees for this view.
    ///
    /// These correspond to the angles OpenSCAD's GUI applies for its standard
    /// view shortcuts.
    pub fn rotation(self) -> (f64, f64, f64) {
        match self {
            View::Front => (0.0, 0.0, 0.0),
            View::Back => (0.0, 0.0, 180.0),
            View::Left => (0.0, 0.0, 90.0),
            View::Right => (0.0, 0.0, 270.0),
            View::Top => (90.0, 0.0, 0.0),
            View::Bottom => (270.0, 0.0, 0.0),
            View::Iso => (55.0, 0.0, 25.0),
        }
    }

    /// Human-facing label, also used for contact-sheet captions.
    pub fn label(self) -> &'static str {
        match self {
            View::Front => "front",
            View::Back => "back",
            View::Left => "left",
            View::Right => "right",
            View::Top => "top",
            View::Bottom => "bottom",
            View::Iso => "iso",
        }
    }

    /// All views in a stable, sensible contact-sheet order.
    pub fn all() -> [View; 7] {
        [
            View::Front,
            View::Back,
            View::Left,
            View::Right,
            View::Top,
            View::Bottom,
            View::Iso,
        ]
    }
}

impl fmt::Display for View {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.label())
    }
}

impl FromStr for View {
    type Err = UnknownView;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "front" => Ok(View::Front),
            "back" | "rear" => Ok(View::Back),
            "left" => Ok(View::Left),
            "right" => Ok(View::Right),
            "top" => Ok(View::Top),
            "bottom" | "bot" => Ok(View::Bottom),
            "iso" | "isometric" | "3d" => Ok(View::Iso),
            _ => Err(UnknownView(s.to_string())),
        }
    }
}

/// Error returned when a view name cannot be parsed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnknownView(pub String);

impl fmt::Display for UnknownView {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "unknown view '{}' (expected one of: front, back, left, right, top, bottom, iso)",
            self.0
        )
    }
}

impl std::error::Error for UnknownView {}

/// A reasonable default camera distance. Overridden in practice by
/// `--viewall`, but the gimbal camera string requires a positive value.
pub const DEFAULT_DISTANCE: f64 = 500.0;

/// Build the `--camera` value (without the `--camera=` prefix) for a named view.
///
/// `distance` is the gimbal distance; pass [`DEFAULT_DISTANCE`] when relying on
/// `--viewall` to reframe.
pub fn camera_string(view: View, distance: f64) -> String {
    let (rx, ry, rz) = view.rotation();
    format!(
        "0,0,0,{},{},{},{}",
        fmt_num(rx),
        fmt_num(ry),
        fmt_num(rz),
        fmt_num(distance)
    )
}

/// Format a float without a trailing `.0` so camera strings stay tidy and
/// stable for golden tests (e.g. `90` not `90.0`).
fn fmt_num(v: f64) -> String {
    if v.fract() == 0.0 {
        format!("{}", v as i64)
    } else {
        format!("{v}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_known_views_case_insensitively() {
        assert_eq!("FRONT".parse::<View>().unwrap(), View::Front);
        assert_eq!("  iso ".parse::<View>().unwrap(), View::Iso);
        assert_eq!("rear".parse::<View>().unwrap(), View::Back);
        assert!("diagonal".parse::<View>().is_err());
    }

    #[test]
    fn camera_string_is_stable_and_clean() {
        assert_eq!(
            camera_string(View::Front, DEFAULT_DISTANCE),
            "0,0,0,0,0,0,500"
        );
        assert_eq!(
            camera_string(View::Top, DEFAULT_DISTANCE),
            "0,0,0,90,0,0,500"
        );
        assert_eq!(camera_string(View::Back, 250.0), "0,0,0,0,0,180,250");
        assert_eq!(camera_string(View::Iso, 500.0), "0,0,0,55,0,25,500");
    }

    #[test]
    fn fractional_distance_is_preserved() {
        assert_eq!(camera_string(View::Front, 12.5), "0,0,0,0,0,0,12.5");
    }

    #[test]
    fn all_views_round_trip_through_label() {
        for v in View::all() {
            assert_eq!(v.label().parse::<View>().unwrap(), v);
        }
    }
}
