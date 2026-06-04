//! A tiny self-contained 3×5 bitmap font, just enough to label contact-sheet
//! cells with view names. Avoids pulling in a TrueType stack for a handful of
//! lowercase letters and digits.
//!
//! Each glyph is 5 rows tall and 3 columns wide. A row is the low 3 bits of a
//! byte, MSB = leftmost column.

/// Width of a glyph in pixels (before scaling).
pub const GLYPH_W: u32 = 3;
/// Height of a glyph in pixels (before scaling).
pub const GLYPH_H: u32 = 5;
/// Horizontal gap between glyphs in pixels (before scaling).
pub const GLYPH_GAP: u32 = 1;

/// Return the 5-row bitmap for a character, or `None` if unsupported.
fn glyph(c: char) -> Option<[u8; 5]> {
    let g = match c.to_ascii_lowercase() {
        'a' => [0b010, 0b101, 0b111, 0b101, 0b101],
        'b' => [0b110, 0b101, 0b110, 0b101, 0b110],
        'c' => [0b011, 0b100, 0b100, 0b100, 0b011],
        'd' => [0b110, 0b101, 0b101, 0b101, 0b110],
        'e' => [0b111, 0b100, 0b110, 0b100, 0b111],
        'f' => [0b111, 0b100, 0b110, 0b100, 0b100],
        'g' => [0b011, 0b100, 0b101, 0b101, 0b011],
        'h' => [0b101, 0b101, 0b111, 0b101, 0b101],
        'i' => [0b111, 0b010, 0b010, 0b010, 0b111],
        'k' => [0b101, 0b110, 0b100, 0b110, 0b101],
        'l' => [0b100, 0b100, 0b100, 0b100, 0b111],
        'm' => [0b101, 0b111, 0b111, 0b101, 0b101],
        'n' => [0b101, 0b111, 0b111, 0b111, 0b101],
        'o' => [0b010, 0b101, 0b101, 0b101, 0b010],
        'p' => [0b110, 0b101, 0b110, 0b100, 0b100],
        'r' => [0b110, 0b101, 0b110, 0b101, 0b101],
        's' => [0b011, 0b100, 0b010, 0b001, 0b110],
        't' => [0b111, 0b010, 0b010, 0b010, 0b010],
        'u' => [0b101, 0b101, 0b101, 0b101, 0b111],
        'x' => [0b101, 0b101, 0b010, 0b101, 0b101],
        'y' => [0b101, 0b101, 0b010, 0b010, 0b010],
        '0' => [0b111, 0b101, 0b101, 0b101, 0b111],
        '1' => [0b010, 0b110, 0b010, 0b010, 0b111],
        '2' => [0b110, 0b001, 0b010, 0b100, 0b111],
        '3' => [0b110, 0b001, 0b010, 0b001, 0b110],
        ' ' => [0, 0, 0, 0, 0],
        _ => return None,
    };
    Some(g)
}

/// The pixel width a string will occupy at scale 1 (before scaling).
pub fn text_width(text: &str) -> u32 {
    let n = text.chars().count() as u32;
    if n == 0 {
        0
    } else {
        n * GLYPH_W + (n - 1) * GLYPH_GAP
    }
}

/// Invoke `plot(x, y)` for every lit pixel of `text` rendered at `scale`, with
/// the top-left of the text at `(ox, oy)`. Unsupported characters render blank.
pub fn draw_text<F: FnMut(u32, u32)>(text: &str, ox: u32, oy: u32, scale: u32, mut plot: F) {
    let mut cursor = ox;
    for c in text.chars() {
        if let Some(rows) = glyph(c) {
            for (ry, row) in rows.iter().enumerate() {
                for cx in 0..GLYPH_W {
                    let bit = (row >> (GLYPH_W - 1 - cx)) & 1;
                    if bit == 1 {
                        // Fill a scale×scale block per source pixel.
                        for sy in 0..scale {
                            for sx in 0..scale {
                                plot(cursor + cx * scale + sx, oy + ry as u32 * scale + sy);
                            }
                        }
                    }
                }
            }
        }
        cursor += (GLYPH_W + GLYPH_GAP) * scale;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_width_accounts_for_gaps() {
        // 3 chars: 3*3 + 2*1 = 11
        assert_eq!(text_width("iso"), 11);
        assert_eq!(text_width(""), 0);
        assert_eq!(text_width("a"), 3);
    }

    #[test]
    fn draws_some_pixels_for_known_letters() {
        let mut count = 0;
        draw_text("front", 0, 0, 1, |_, _| count += 1);
        assert!(count > 0);
    }

    #[test]
    fn unknown_chars_are_blank_but_advance() {
        let mut count = 0;
        draw_text("\u{2603}", 0, 0, 1, |_, _| count += 1);
        assert_eq!(count, 0);
    }
}
