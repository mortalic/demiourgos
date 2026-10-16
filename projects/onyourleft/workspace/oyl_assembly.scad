// oyl_assembly.scad — all 12 parts in their original positions
// Each module is defined in its own file in this workspace; transforms were
// solved by registering each copy's vertices against the canonical part
// (max registration error < 0.02 mm except where noted).

use <oyl_bezel.scad>
use <oyl_trim_strip.scad>
use <oyl_mount_tab.scad>
use <oyl_disc_pad.scad>

module assembly() {
    multmatrix([[1, 0, 0, -214.5012], [0, 1, 0, -15.3696], [0, 0, 1, 95.4855], [0, 0, 0, 1]]) bezel();  // part01_a
    multmatrix([[-1, 0, 0, 62.3167], [0, 1, 0, -15.3696], [0, 0, 1, 95.4855], [0, 0, 0, 1]]) bezel();  // part01_b
    multmatrix([[1, 0, 0, -137.7886], [0, 0, 1, 222.6482], [0, 1, 0, 28.0150], [0, 0, 0, 1]]) trim_strip();  // part02_a
    multmatrix([[-1, 0, 0, -308.8934], [0, 0, 1, 222.6482], [0, 1, 0, 28.0150], [0, 0, 0, 1]]) trim_strip();  // part02_b
    multmatrix([[-1, 0, 0, -14.3959], [0, 0, 1, 222.6482], [0, 1, 0, 28.0150], [0, 0, 0, 1]]) trim_strip();  // part02_c
    multmatrix([[1, 0, 0, 156.7089], [0, 0, 1, 222.6482], [0, 1, 0, 28.0150], [0, 0, 0, 1]]) trim_strip();  // part02_d
    multmatrix([[1, 0, 0, -295.0922], [0, 1, 0, -7.5394], [0, 0, 1, 269.7413], [0, 0, 0, 1]]) mount_tab();  // part03_a
    multmatrix([[-1, 0, 0, 142.9078], [0, 1, 0, -7.5394], [0, 0, 1, 269.7413], [0, 0, 0, 1]]) mount_tab();  // part03_b
    multmatrix([[1, 0, 0, -160.4399], [0, 1, 0, -11.4982], [0, 0, 1, -101.1000], [0, 0, 0, 1]]) disc_pad();  // part04_a
    multmatrix([[1, 0, 0, -280.4741], [0, 1, 0, -11.4982], [0, 0, 1, -101.1000], [0, 0, 0, 1]]) disc_pad();  // part04_b
    multmatrix([[1, 0, 0, 8.2554], [0, 1, 0, -11.4982], [0, 0, 1, -101.1000], [0, 0, 0, 1]]) disc_pad();  // part04_c
    multmatrix([[1, 0, 0, 128.2896], [0, 1, 0, -11.4982], [0, 0, 1, -101.1000], [0, 0, 0, 1]]) disc_pad();  // part04_d
}

assembly();
