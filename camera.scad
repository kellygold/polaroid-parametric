// Parametric Land Camera 1000 / OneStep display model.
// Units: mm. X = width; front = negative Y; Z = height.
// Rebuilt parametrically with a purchased model as a dimensional reference.
// Burner Tools. SPDX-License-Identifier: CC-BY-NC-SA-4.0
// See README.md for attribution and reference provenance.



$fn = 80;

W = 109; r_edge = 2; explode = 0;
board_y = -33;
door_y  = -75;

back_sq = 1;

profile = [ [-75,0],[-75,36],[-33,48],[-33,92],[-33,95],[10*back_sq,95],[15*back_sq,93.5],[20*back_sq,88],[26*back_sq,78],[44*back_sq,60],[60*back_sq,44],[71*back_sq,34],[71*back_sq,0] ];

lens_x=0;  lens_z=72; lens_d=37; lens_rim_out=13; lens_flange_d=38;
redbtn_x=-37; redbtn_z=57; redbtn_d=14; redbtn_sleeve_d=18; redbtn_sleeve_h=5.5;
focus_x= 31.6;  focus_z=57;
vf_x=38; vf_z=79; vf_w=16; vf_h=14;
badge_x=-36; badge_z=78;
slot_z=12;

show_card=true; cardw=88; cardl=108; cardt=2.2; cimg=79; cside=4.5; cbottom=24.5; cinsert=14;
photo_t = 1.6;
module card_slot() translate([0, door_y+12, slot_z]) cube([cardw+2, 36, photo_t+0.7], center=true);
module card(){
  trail = door_y + cinsert;
  color(col_white) translate([0, trail-cardl/2, slot_z]) cube([cardw, cardl, cardt], center=true);
  color(col_black) translate([0, trail-cbottom-cimg/2, slot_z+cardt/2]) linear_extrude(0.5)
    difference(){ square([cimg,cimg],center=true); offset(-1.5) square([cimg,cimg],center=true); }
  color(col_black) translate([0, trail-cbottom/2, slot_z+cardt/2]) linear_extrude(0.5) square([cimg-24,1.4],center=true);
}

badge_w=30; badge_h=12; badge_corner=3;
module badge_engrave() translate([badge_x, board_y+0.0, badge_z]) rotate([90,0,0]) linear_extrude(0.9, center=true){
  difference(){ rsq(badge_w, badge_h, badge_corner); rsq(badge_w-1.6, badge_h-1.6, max(badge_corner-0.8,0.6)); }
  difference(){ text("1000", size=8.5, font="Liberation Sans:style=Bold", halign="center", valign="center");
                offset(-0.9) text("1000", size=8.5, font="Liberation Sans:style=Bold", halign="center", valign="center"); }
}

badge_depth = 0.7;
module badge_shape() difference(){ rsq(badge_w, badge_h, badge_corner); text("1000", size=8.5, font="Liberation Sans:style=Bold", halign="center", valign="center"); }
module badge_vol() translate([badge_x, board_y+badge_depth/2, badge_z]) rotate([90,0,0]) linear_extrude(badge_depth, center=true) badge_shape();

col_white="#ece8e0"; col_black="#1c1c1c"; col_red="#cf2b2b"; col_chrome="#c9ccce"; col_glass="#0c0c0c";
col_logo="#ffffff";
rb=["#C63D96","#D8352A","#EE7D2A","#F5C518","#6F8F3E","#2F6FD0"];

rb_raise = 0.7;
rb_bottom = 30.5;
module rainbow_band2d() intersection(){
  difference(){ offset(rb_raise) rprofile(); rprofile(); }
  translate([-53,(58+rb_bottom)/2]) square([47,58-rb_bottom], center=true);
}
rb_band = -1;

rb_lens_gap = 0;
module rainbow_lensclip() translate([lens_x, board_y, lens_z]) rotate([90,0,0]) cylinder(d=lens_flange_d+2*rb_lens_gap, h=80, center=true, $fn=96);
module rainbow_fill(){ for(i=[0:5]) if(rb_band<0 || rb_band==i) color(rb[i]) difference(){
  translate([-5+i*2.0,0,0]) rotate([90,0,90]) linear_extrude(2.0, center=true) rainbow_band2d();
  rainbow_lensclip(); } }

module rprofile() offset(r_edge) offset(-2*r_edge) offset(r_edge) polygon(profile);

module body_xtaper() hull(){
  translate([0,0,26]) cube([W,   340, 52],  center=true);
  translate([0,0,98]) cube([W-5, 340, 0.2], center=true);
}

eye_web = 0;
module eyepiece_web() if(eye_web>0) hull(){
  translate([eye_x-1, 13, 90]) rotate([-90,0,0]) linear_extrude(0.1) rsq(15, 6, 3);
  translate([eye_x,   34, 87])  rotate([-90,0,0]) linear_extrude(0.1) rsq(18, 7, 4);
  translate([eye_x,   49, eye_z+7]) rotate([-90,0,0]) linear_extrude(0.1) rsq(18, 7, 4);
}
body_taper = 1;
module body_solid() union(){
  if(body_taper>0) intersection(){ minkowski(){ rotate([90,0,90]) linear_extrude(W-2*r_edge,center=true) offset(-r_edge) rprofile(); sphere(r_edge,$fn=18); } body_xtaper(); }
  else             minkowski(){ rotate([90,0,90]) linear_extrude(W-2*r_edge,center=true) offset(-r_edge) rprofile(); sphere(r_edge,$fn=18); }
  scale([1,back_sq,1]) eyepiece_housing();
  scale([1,back_sq,1]) eyepiece_web();
}

module whiteface_vol() rotate([90,0,90]) linear_extrude(W+4, center=true)
  polygon([[-80,36],[-35,48],[-35,97],[-22,97],[-22,48],[-64,36]]);
module rsq(w,h,r) offset(r) offset(-r) square([w,h],center=true);

module tvscreen(w,h,n=2.6,seg=72) polygon([for(i=[0:seg-1]) let(t=360.0*i/seg)
  [ (w/2)*(cos(t)>=0?1:-1)*pow(abs(cos(t)),2/n), (h/2)*(sin(t)>=0?1:-1)*pow(abs(sin(t)),2/n) ]]);

module lens(){
  translate([lens_x, board_y, lens_z]) rotate([90,0,0]){
    color(col_chrome) translate([0,0,-1.0]) cylinder(d1=lens_flange_d, d2=lens_flange_d-3.5, h=2.2, $fn=80);
    color(col_black) difference(){
      union(){
        cylinder(d=lens_d, h=lens_rim_out-3, $fn=80);
        translate([0,0,lens_rim_out-3]) cylinder(d1=lens_d, d2=lens_d-5, h=3, $fn=80);
      }
      for(i=[0:11]) translate([0,0,1+i*1.0]) cylinder(d=14+i*1.25, h=lens_rim_out, $fn=72);
      for(i=[0:1]) translate([0,0,3.5+i*5]) rotate_extrude($fn=80) translate([lens_d/2,0]) circle(d=0.5,$fn=10);
    }
    color(col_glass) translate([0,0,1.0]) intersection(){ cylinder(d=14, h=2.2, $fn=56); translate([0,0,-23]) sphere(r=25, $fn=80); }
    color("#3a3a3a") translate([0,0,1.7]) cylinder(d=7, h=0.3, $fn=48);
  }
}

module vf_recess() translate([vf_x, board_y+1.1, vf_z]) rotate([90,0,0]) linear_extrude(2.6, center=true) rsq(vf_w+6, vf_h+6, 3.8);
module vf_glass(){

  color(col_black) translate([vf_x, board_y+2.0, vf_z]) rotate([90,0,0])
    hull(){ linear_extrude(0.9) rsq(vf_w, vf_h, 2.5);
            translate([0,0,1.5]) linear_extrude(0.01) rsq(vf_w-1.2, vf_h-1.2, 2.1); }
}

module focus_index() translate([focus_x, board_y+0.3, 66.0]) rotate([90,0,0]) linear_extrude(1.6, center=true)
  difference(){ polygon([[-2.4,2.1],[2.4,2.1],[0,-2.0]]); offset(-0.6) polygon([[-2.4,2.1],[2.4,2.1],[0,-2.0]]); };
module knob(x,z,d,col,h=4){ color(col) translate([x,board_y,z]) rotate([90,0,0]){ cylinder(d=d,h=h); color(col_chrome) translate([0,0,h]) cylinder(d=d*0.45,h=1);} }

module seams(){
  translate([0, door_y+0.45, 35.6]) rotate([0,90,0]) cylinder(d=1.1, h=W-8, center=true, $fn=10);
  translate([0, door_y+0.45, 33.4]) rotate([0,90,0]) cylinder(d=0.7, h=W-8, center=true, $fn=10);
  translate([-50, door_y+0.45, 18]) cylinder(d=0.8, h=33, center=true, $fn=8);
  translate([ 50, door_y+0.45, 18]) cylinder(d=0.8, h=33, center=true, $fn=8);
}

module door_detail(){
  translate([0, door_y+0.7, 21.5]) rotate([90,0,0]) linear_extrude(1.5, center=true) difference(){ rsq(94,18,3); rsq(90,14,2); }
  for(i=[0:12]) translate([0, door_y+0.55, 15+i*1.05]) rotate([0,90,0]) cylinder(d=0.55, h=88, center=true, $fn=8);
}

module strap_lug() color(col_black) translate([-55.4, 16, 50]) rotate([0,-90,0]) minkowski(){ cube([8,4.5,1.6],center=true); sphere(1.2,$fn=18); }

module btn_sleeve() color(col_white) translate([redbtn_x, board_y, redbtn_z]) rotate([90,0,0])
  difference(){ minkowski(){ cylinder(d=redbtn_sleeve_d-2.4, h=redbtn_sleeve_h-1.2, $fn=56); sphere(1.2,$fn=20); }
                translate([0,0,1.2]) cylinder(d=redbtn_d+1.0, h=redbtn_sleeve_h+2, $fn=56); }
module redbutton() color(col_red) translate([redbtn_x, board_y, redbtn_z]) rotate([90,0,0]){
  cylinder(d=redbtn_d, h=redbtn_sleeve_h, $fn=48);
  translate([0,0,redbtn_sleeve_h]) scale([1,1,0.30]) sphere(d=redbtn_d, $fn=48); }
module focusknob() color("#1c1c1c") translate([focus_x, board_y, focus_z]) rotate([90,0,0]){
  cylinder(d1=14.2, d2=13.4, h=11, $fn=56);
  for(i=[0:4]) color("#0d0d0d") translate([0,0,1+i*2]) cylinder(d=14.4-i*0.18, h=1, $fn=56); }
module top_rect() minkowski(){ translate([0,-20.5,95.0]) cube([33,12,0.5], center=true); sphere(2.6,$fn=26); }

module top_slit(){
  translate([0,-20.5,96.6]) cube([24, 4.6, 5], center=true);
  for(i=[0:9]) translate([-11+i*2.45,-18.7,96.2]) cube([1.3, 1.3, 4.2], center=true);
}

eye_x=41.2; eye_z=82.0;
module eyeslice(w,h,r) rotate([-90,0,0]) linear_extrude(0.1) rsq(w,h,r);
module eyepiece_housing() union(){
  hull(){
    translate([eye_x,  0, eye_z]) eyeslice(21, 23, 4);
    translate([eye_x, 30, eye_z]) eyeslice(21, 23, 4);
    translate([eye_x, 52, eye_z]) eyeslice(20.5, 23, 4);
  }
  eyepiece_collar();
}

module eyepiece_collar() hull(){
  translate([eye_x, 51.5, eye_z]) eyeslice(24,   26,   4.5);
  translate([eye_x, 54,   eye_z]) eyeslice(24,   26,   4.5);
  translate([eye_x, 56.5, eye_z]) eyeslice(20.5, 22.5, 4.2);
  translate([eye_x, 61,   eye_z]) eyeslice(20.5, 22.5, 4.2);
}
module eyepiece_recess(){

  hull(){
    translate([eye_x, 61.8, eye_z]) eyeslice(12.5, 14.7, 4.8);
    translate([eye_x, 56.5, eye_z]) eyeslice(9,    11.6, 3.4);
  }
  translate([eye_x, 53, eye_z]) rotate([-90,0,0]) linear_extrude(4.0) rsq(9, 11.6, 3.4);
}
module eyepiece_parts(){
  color([0.70,0.80,0.92,0.85]) translate([eye_x, 53.3, eye_z]) rotate([-90,0,0])
    intersection(){ linear_extrude(3) rsq(7, 9.5, 3); translate([0,0,3+10]) sphere(d=30,$fn=56); }
}

module branding(){

  rainbow_fill();

  color(col_white) translate([-44, door_y+0.25, 19]) rotate([90,0,0])
    linear_extrude(0.85) text("POLAROID LAND CAMERA", size=2.6, font="Liberation Sans:style=Bold", halign="left", valign="center");
}

module door_tab() color("#8a8c8e") translate([-48, door_y-0.6, 11]) rotate([90,0,0]) minkowski(){ cube([5, 11, 0.1], center=true); sphere(1.3,$fn=20); }
module body_slotted() difference(){ body_solid(); card_slot(); vf_recess(); badge_vol(); focus_index(); seams(); door_detail(); scale([1,back_sq,1]) eyepiece_recess(); }

squish   = 0;
sq_front = 0.90;
sq_mid   = 0.80;
sq_back  = 0.50;
SQ_ANCHOR = -33;
SQ_MIDBACK = 20;
SQ_CM  = SQ_ANCHOR*(1-sq_mid);
SQ_Y20 = sq_mid*SQ_MIDBACK + SQ_CM;
module sq_slab(y0,y1,f,c) translate([0,c,0]) scale([1,f,1])
  intersection(){ union() children(); translate([0,(y0+y1)/2,0]) cube([400, y1-y0, 400], center=true); }
module squish_y(){
  if(squish<=0) children();
  else {
    sq_slab(-300, SQ_ANCHOR,    sq_front, SQ_ANCHOR*(1-sq_front)) children();
    sq_slab(SQ_ANCHOR, SQ_MIDBACK, sq_mid, SQ_CM)                 children();
    sq_slab(SQ_MIDBACK, 300,    sq_back,  SQ_Y20 - sq_back*SQ_MIDBACK) children();
  }
}

top_slot = 0;
ts_y     = -2;
ts_top   = 95;
ts_depth = 8;
ts_w     = photo_t+0.7;
ts_len   = cardw+2;
module top_card_slot() translate([0, ts_y, ts_top-ts_depth])
  linear_extrude(100-(ts_top-ts_depth)) rsq(ts_len, ts_w, ts_w/2-0.1);

part = "all";
scl  = 1;
sy   = 1;
function inp(p) = (part=="all" || part==p);

piece  = "all";
chop_y = -11;
module by_piece(){
  if(piece=="all") children();
  else intersection(){ children(); translate([0, chop_y + (piece=="face" ? -300 : 300), 0]) cube([900,600,900], center=true); }
}
module placed(){
  if(piece=="face") translate([0,0,chop_y]) rotate([-90,0,0]) by_piece() children();
  else              by_piece() children();
}

placed() scale([scl, scl*sy, scl]){
  if(inp("black")){
    difference(){
      squish_y() color(col_black) render() difference(){ body_slotted(); whiteface_vol(); }
      if(top_slot) top_card_slot();
    }
    squish_y(){
      lens(); color(col_black) difference(){ top_rect(); top_slit(); } focusknob(); strap_lug();
      vf_glass(); scale([1,back_sq,1]) eyepiece_parts();
      color(col_black) badge_vol();
    }
  }
  if(inp("cream")) squish_y(){
    translate([0,-explode,0]) color(col_white) render() intersection(){ body_slotted(); whiteface_vol(); }
    btn_sleeve();
  }
  if(inp("white")) squish_y()
    color(col_logo) translate([-44, door_y+0.25, 19]) rotate([90,0,0]) linear_extrude(0.85)
      text("POLAROID LAND CAMERA", size=2.6, font="Liberation Sans:style=Bold", halign="left", valign="center");
  if(inp("rainbow")) squish_y() rainbow_fill();
  if(inp("red"))  squish_y() translate([0,-explode*1.7,0]) redbutton();
  if(inp("card")) if(show_card) translate([0,-explode*0.4,0]) card();
}
