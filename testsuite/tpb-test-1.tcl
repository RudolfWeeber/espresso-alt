# THREE-PARTICLE-BINDING-TEST

require_feature "COLLISION_DETECTION"
require_feature "VIRTUAL_SITES_RELATIVE"

puts "---------------------------------------------------------------"
puts "- Testcase collision-detection-three-particle-binding.tcl"
puts "---------------------------------------------------------------"

# Setup
setmd box_l 10 10 10

setmd periodic 1 1 1

thermostat off

setmd time_step 0.01

inter 0 0 lennard-jones 0.0001 2 2.1 auto

setmd skin 0

part 0 pos 0 0 0 
part 1 pos 2 0 0
part 2 pos 5 0 0

#---------------BONDED POTENTIALS-------------------#
inter 0 harmonic 200 1.0
# set of angle potentials
set angleres 180
for {set a 0} {$a <= $angleres} {incr a} {
  inter [expr 1 + $a] angle 100 [expr $a * [PI] / $angleres]
}

on_collision bind_three_particles 1.0 0 1 180

puts [on_collision]


exit


