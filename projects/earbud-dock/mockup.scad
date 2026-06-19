// mockup.scad — dock with ghost cases in place, to sanity-check fit & scale.
// Not for printing. Render: openscad mockup.scad
use <dock.scad>;

// keep these in sync with dock.scad
cases = [
    ["Buds 3",     58.9, 24.4, 48.7],
    ["Buds 3 Pro", 58.9, 24.4, 48.7],
    ["Buds 4 Pro", 51.0, 28.3, 51.0],
    ["Live",       50.2, 27.8, 50.0],
];
clear=0.6; wall=2.0; outer_wall=2.5; slab_h=22;
n=len(cases);
function fx(i)=cases[i][1]; function fy(i)=cases[i][2]; function fh(i)=cases[i][3];
function pw(i)=fx(i)+2*clear; function pd(i)=fy(i)+2*clear;
function psum(i)= i<=0?0:pw(i-1)+psum(i-1);
inner_span=psum(n)+wall*(n-1);
max_pd=max([for(i=[0:n-1]) pd(i)]); total_d=max_pd+2*outer_wall;
function px(i)=-inner_span/2+psum(i)+wall*i+pw(i)/2;
front_inner=-total_d/2+outer_wall;
function pcy(i)=front_inner+pd(i)/2;

dock();

// ghost cases standing port-down in each pocket
module rcase(w,d,h,r=3){
    hull() for(sx=[-1,1],sy=[-1,1])
        translate([sx*(w/2-r), sy*(d/2-r),0]) cylinder(r=r,h=h,$fn=32);
}
for (i=[0:n-1])
    color([0.82,0.84,0.9,0.65])
        translate([px(i), pcy(i), slab_h+0.4])
            rcase(fx(i), fy(i), fh(i));
