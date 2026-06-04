//! Contact-sheet compositing: arrange several rendered views into one labeled
//! grid image using the `image` crate and the tiny bundled [`font`].

use image::{Rgba, RgbaImage};

use crate::font;

/// White canvas background.
const BG: Rgba<u8> = Rgba([255, 255, 255, 255]);
/// Label strip background (light gray).
const LABEL_BG: Rgba<u8> = Rgba([235, 235, 235, 255]);
/// Label text color.
const TEXT: Rgba<u8> = Rgba([20, 20, 20, 255]);
/// Padding inside each cell, in pixels.
const PAD: u32 = 6;

/// One labeled cell: a caption and its rendered image.
pub struct Cell {
    pub label: String,
    pub image: RgbaImage,
}

/// Choose a grid `(cols, rows)` that is as square as possible for `n` cells.
fn grid_dims(n: usize) -> (u32, u32) {
    if n == 0 {
        return (1, 1);
    }
    let cols = (n as f64).sqrt().ceil() as u32;
    let rows = (n as u32).div_ceil(cols);
    (cols, rows)
}

/// Composite cells into a single labeled grid image. All cell images are
/// assumed to share the dimensions of the first cell; mismatched cells are
/// drawn clipped at the top-left.
pub fn contact_sheet(cells: &[Cell]) -> RgbaImage {
    let (cols, rows) = grid_dims(cells.len());

    let (cell_w, cell_h) = cells
        .first()
        .map(|c| c.image.dimensions())
        .unwrap_or((400, 300));

    // Pick a text scale that stays legible relative to cell width.
    let scale = (cell_w / 140).max(2);
    let label_h = font::GLYPH_H * scale + 2 * PAD;

    let tile_w = cell_w + 2 * PAD;
    let tile_h = cell_h + label_h + PAD;

    let sheet_w = tile_w * cols;
    let sheet_h = tile_h * rows;
    let mut canvas = RgbaImage::from_pixel(sheet_w, sheet_h, BG);

    for (i, cell) in cells.iter().enumerate() {
        let col = (i as u32) % cols;
        let row = (i as u32) / cols;
        let ox = col * tile_w;
        let oy = row * tile_h;

        // Label strip.
        for y in oy..(oy + label_h).min(sheet_h) {
            for x in ox..(ox + tile_w).min(sheet_w) {
                canvas.put_pixel(x, y, LABEL_BG);
            }
        }
        // Caption text, horizontally centered in the strip.
        let tw = font::text_width(&cell.label) * scale;
        let tx = ox + PAD + (cell_w.saturating_sub(tw)) / 2;
        let ty = oy + PAD;
        font::draw_text(&cell.label, tx, ty, scale, |px, py| {
            if px < sheet_w && py < sheet_h {
                canvas.put_pixel(px, py, TEXT);
            }
        });

        // The rendered view, below the label strip.
        let img_x = ox + PAD;
        let img_y = oy + label_h;
        image::imageops::overlay(&mut canvas, &cell.image, img_x as i64, img_y as i64);
    }

    canvas
}

#[cfg(test)]
mod tests {
    use super::*;

    fn solid(w: u32, h: u32, c: [u8; 4]) -> RgbaImage {
        RgbaImage::from_pixel(w, h, Rgba(c))
    }

    #[test]
    fn grid_dims_are_square_ish() {
        assert_eq!(grid_dims(1), (1, 1));
        assert_eq!(grid_dims(4), (2, 2));
        assert_eq!(grid_dims(7), (3, 3));
        assert_eq!(grid_dims(9), (3, 3));
    }

    #[test]
    fn contact_sheet_dimensions_scale_with_grid() {
        let cells = vec![
            Cell {
                label: "front".into(),
                image: solid(200, 150, [10, 20, 30, 255]),
            },
            Cell {
                label: "iso".into(),
                image: solid(200, 150, [40, 50, 60, 255]),
            },
        ];
        let sheet = contact_sheet(&cells);
        // 2 cells -> 2x1 grid (cols=ceil(sqrt2)=2, rows=1).
        assert!(sheet.width() > 200 * 2);
        assert!(sheet.height() > 150);
    }

    #[test]
    fn empty_cells_do_not_panic() {
        let sheet = contact_sheet(&[]);
        assert!(sheet.width() >= 1 && sheet.height() >= 1);
    }
}
