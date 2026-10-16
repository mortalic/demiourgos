// Pixel 9a rugged TPU case with an inner credit-card recess.
// Own design; cutout positions measured from a CC BY-SA reference case.
// Modeled in print orientation: back face on the bed (z=0), opening up (+z).
// Phone frame: +y toward the camera end, buttons on the +x wall.

$fn = 72;
eps = 0.01;

// ---- phone (Google published dims) ----
phone_w = 73.3;
phone_l = 154.7;
phone_t = 8.9;
phone_r = 12.3;          // corner radius
stretch = 0.4;           // cavity undersize for TPU grip (total per dimension)

// ---- case shell ----
wall     = 1.85;         // side wall
back     = 2.4;          // back thickness, including the card-recess floor
rim      = 2.0;          // bezel height above the screen
lip_in   = 1.2;          // inward lip over the screen edge
lip_h    = 1.2;          // lip rises at 45 deg (lip_h == lip_in) -> support free
entry    = 0.6;          // entry chamfer at the top of the lip
floor_ch = 1.0;          // chamfer at inner floor/wall junction (matches phone back edge)
out_ch   = 1.0;          // outer edge chamfers

// ---- credit card, ISO/IEC 7810 ID-1 ----
card_w     = 53.98;
card_l     = 85.60;
card_t     = 0.76;       // nominal; embossed cards run ~0.84
card_clr   = 0.3;        // per side
card_depth = 0.9;        // recess depth into the inner back face
card_y     = -12;        // recess center along phone length (negative = toward USB end)
card_r     = 3.2;        // card corner radius
notch_d    = 14;         // fingernail notch at the recess's bottom edge

// ---- camera (offsets from phone center) ----
cam_c   = [13.7, 53.6];  // pill center
cam_sz  = [32, 18.5];    // pill size at the inner face
cam_ch  = 1.5;           // outward 45 deg chamfer so the ultrawide isn't vignetted
flash_c = [-10, 53.6];
flash_d = 6.6;
flash_ch = 1.0;

// ---- buttons, +x wall (y offsets from phone center) ----
btn_depth = 1.0;         // outer pocket depth (membrane = wall - btn_depth)
btn_h     = 6.1;         // pocket height
nub_h     = 2.5;
nub_p     = btn_depth + 0.3;   // nub stands 0.3 proud of the wall
vol_pocket = [4.8, 24.6];      // [y center, length]
pwr_pocket = [28.65, 14.9];
nubs = [[-1.75, 8], [11.3, 8], [28.65, 11.3]];   // [y center, length]

// ---- bottom (-y) and top (+y) edge openings ----
usb_w = 16.5;  usb_h = 8.0;  usb_z0 = 0.6;   // slot bottom sits usb_z0 above the floor
spk_x = 17.95; spk_w = 15.8; spk_h = 3.5;
mic_x = -17.95; mic_w = 5.0; mic_h = 3.5;     // bottom mic: position estimated, not measured
tmic_x = 22.85; tmic_w = 3.4; tmic_h = 3.4;   // top mic

// ---- derived ----
cw = phone_w - stretch;  cl = phone_l - stretch;  cr = phone_r - stretch/2;
W  = cw + 2*wall;        L  = cl + 2*wall;        R  = cr + wall;
z_screen = back + phone_t;
H  = z_screen + rim;
zc = back + phone_t/2;   // phone mid-thickness

echo(str("outer ", W, " x ", L, " x ", H, " mm; cavity ", cw, " x ", cl, "; floor under card ", back - card_depth, " mm"));

module rr(w, l, r) { offset(r = r) square([w - 2*r, l - 2*r], center = true); }
module slab(w, l, r, z0, h) { translate([0, 0, z0]) linear_extrude(h) rr(w, l, r); }
module pill2d(w, h) { hull() for (s = [-1, 1]) translate([s*(w - h)/2, 0]) circle(d = h); }

module body() {
    hull() {
        slab(W - 2*out_ch, L - 2*out_ch, R - out_ch, 0, eps);
        slab(W, L, R, out_ch, H - 2*out_ch);
        slab(W - 2*out_ch, L - 2*out_ch, R - out_ch, H - eps, eps);
    }
}

module cavity() {
    // floor chamfer
    hull() {
        slab(cw - 2*floor_ch, cl - 2*floor_ch, cr - floor_ch, back, eps);
        slab(cw, cl, cr, back + floor_ch, eps);
    }
    // phone body
    slab(cw, cl, cr, back + floor_ch - eps, phone_t - floor_ch + 2*eps);
    // 45 deg lip over the screen edge
    hull() {
        slab(cw, cl, cr, z_screen - eps, eps);
        slab(cw - 2*lip_in, cl - 2*lip_in, cr - lip_in, z_screen + lip_h, eps);
    }
    // straight bezel, then entry chamfer
    slab(cw - 2*lip_in, cl - 2*lip_in, cr - lip_in, z_screen + lip_h - eps, H - entry - (z_screen + lip_h) + 2*eps);
    hull() {
        slab(cw - 2*lip_in, cl - 2*lip_in, cr - lip_in, H - entry, eps);
        slab(cw - 2*lip_in + 2*entry, cl - 2*lip_in + 2*entry, cr - lip_in + entry, H, 1);
    }
}

module card_recess() {
    translate([0, card_y, back - card_depth]) linear_extrude(card_depth + eps) union() {
        rr(card_w + 2*card_clr, card_l + 2*card_clr, card_r + card_clr);
        translate([0, -(card_l/2 + card_clr)]) circle(d = notch_d);
    }
}

module camera_cuts() {
    // pill: straight bore from the inside, 45 deg outward chamfer at the back face
    translate([cam_c[0], cam_c[1], 0]) hull() {
        translate([0, 0, cam_ch]) linear_extrude(back - cam_ch + eps) pill2d(cam_sz[0], cam_sz[1]);
        translate([0, 0, -eps]) linear_extrude(eps) pill2d(cam_sz[0] + 2*cam_ch, cam_sz[1] + 2*cam_ch);
    }
    translate([flash_c[0], flash_c[1], 0]) hull() {
        translate([0, 0, flash_ch]) cylinder(d = flash_d, h = back - flash_ch + eps);
        translate([0, 0, -eps]) cylinder(d = flash_d + 2*flash_ch, h = eps);
    }
}

// slot through a y-facing end wall; 2D profile drawn in (x, z)
module y_slot(x, z, w, h, r, y0, y1) {
    translate([x, y0, z]) rotate([-90, 0, 0]) linear_extrude(y1 - y0) rr(w, h, r);
}

module edge_cuts() {
    y_out = -L/2 - 1;  y_in = -cl/2 + 2;
    y_slot(0, back + usb_z0 + usb_h/2, usb_w, usb_h, 3, y_out, y_in);
    y_slot(spk_x, zc, spk_w, spk_h, 1.2, y_out, y_in);
    y_slot(mic_x, zc, mic_w, mic_h, 1.2, y_out, y_in);
    y_slot(tmic_x, zc, tmic_w, tmic_h, 1.2, cl/2 - 2, L/2 + 1);
}

// pocket into the +x wall from outside; top ceiling chamfered 45 deg, flat floor
module side_pocket(yc, len) {
    hull() {
        translate([W/2 - btn_depth, yc - len/2, zc - btn_h/2]) cube([btn_depth + 1, len, btn_h - btn_depth]);
        translate([W/2, yc - len/2, zc - btn_h/2]) cube([1, len, btn_h]);
    }
}

// button nub standing on the membrane, underside sloped 45 deg
module nub(yc, len) {
    x0 = W/2 - btn_depth;
    hull() {
        translate([x0 - eps, yc - len/2, zc - nub_h/2]) cube([eps, len, nub_h]);
        translate([x0 + nub_p - eps, yc - len/2, zc - nub_h/2 + nub_p]) cube([eps, len, nub_h - nub_p]);
    }
}

module case() {
    union() {
        difference() {
            body();
            cavity();
            card_recess();
            camera_cuts();
            edge_cuts();
            side_pocket(vol_pocket[0], vol_pocket[1]);
            side_pocket(pwr_pocket[0], pwr_pocket[1]);
        }
        for (n = nubs) nub(n[0], n[1]);
    }
}

case();
