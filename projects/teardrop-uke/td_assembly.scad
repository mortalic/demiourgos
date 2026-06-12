include <td_dims.scad>
use <td_body.scad>
use <td_neck.scad>
$fn = 96;

rotate([90, 0, 0]) {
    body();
    neck();
}
