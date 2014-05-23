
# Copyright (C) 2011,2012,2013 The ESPResSo project
#  
# This file is part of ESPResSo.
#  
# ESPResSo is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#  
# ESPResSo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#  
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 

# 
#############################################################
#                                                           #
#  Test collision detection with binding of centers of colliding particles
#                                                           #
#############################################################
source "tests_common.tcl"


# Note that there are several physically equivalent possibilities to create the bonds
# the specific way in which this will happen depends on the order of placing the particles
# and the cell system. Changing any of this in this test case will make an adaption 
# of the test criteria necessary.


require_feature "COLLISION_DETECTION"
require_max_nodes_per_side {1 1 1}

puts "---------------------------------------------------------------"
puts "- Testcase collision-detection-three-particle-binding.tcl"
puts "---------------------------------------------------------------"

# Setup
setmd box_l 10 10 10

setmd periodic 1 1 1

thermostat off

setmd time_step 0.01

inter 0 0 lennard-jones 0.0001 2 2.0001 auto

setmd skin 0

part 0 pos 0 0 0 
part 1 pos 2 0 0

#---------------BONDED POTENTIALS-------------------#
inter 0 harmonic 200 2.0
# set of angle potentials
set angleres 181
for {set a 0} {$a < $angleres} {incr a} {
  inter [expr 1 + $a] angle 100 [expr $a * [PI] / $angleres]
}

on_collision bind_three_particles 2.2 0 1 181

set res [on_collision]
if { $res != "bind_three_particles 2.200000 0 1 181"} {
 error_exit "Setting collision detection parameters for three particle binding failed. $res"
}

# Check bonds
integrate 1
set b0 [part 0 print bonds]
set b1 [part 1 print bonds]
# P0 should have a harmonic bond to p1
if { "$b0" != "{ {0 1} } " } {
 error_exit "Two particle Bond on particle 0  incorrect. Got $b0"
}
# p1 should have no bonds
if { "$b1" != "{ } " } {
 error_exit "Two particle bond on particle 1, where there should not be one. Got $b1"
}


# Place a 3rd particle. Now particle 1 should get two extra bonds
part 2 pos 4 0 0
integrate 0

set b0 [part 0 print bonds]
set b1 [part 1 print bonds]
set b2 [part 2 print bonds]


# P0 should have harmonic bond to p1
if { "$b0" != "{ {0 1} } " } {
 error_exit "Two particle Bond on particle 0  incorrect. Got $b0"
}
# P1 should have harmonic bond to p2 and angle bond with id 181 to p2 and p0 
if { "$b1" != "{ {0 2} {181 2 0} } " } {
 error_exit "Bonds on particle 1  incorrect. Got $b1"
}
if { "$b2" != "{ } " } {
 error_exit "Two particle bond on particle 2, where there should not be one. Got $b2"
}


# Test binding of three particles in one step
part delete

# Three particles in contact
part 0 pos 0 0 0 
part 1 pos 2 0 0
# Hcp stacking y=sin(Pi/3)*2
part 2 pos 1 1.7320508 0 

integrate 0

set b0 [part 0 print bonds]
set b1 [part 1 print bonds]
set b2 [part 2 print bonds]


# p0  should have harmonic bonds to p1 and p2  and an angle bond with id 61 to p1 and p2
if { "$b0" != "{ {0 1} {0 2} {61 1 2} } " } {
 error_exit "Bonds on particle 0  incorrect. Got $b0"
}

# p1: harmonic bond to p2, angle bond of type 61 to p2 and p0
if { "$b1" != "{ {0 2} {61 2 0} } " } {
 error_exit "Bonds on particle 1  incorrect. Got $b1"
}

# p2: angle bond with id 61 to p0 and p1
if { "$b1" != "{ {0 2} {61 2 0} } " } {
 error_exit "Bonds on particle 1  incorrect. Got $b1"
}
if { "$b2" != "{ {61 0 1} } " } {
 error_exit "Bonds on particle 2  incorrect. Got $b2"
}
