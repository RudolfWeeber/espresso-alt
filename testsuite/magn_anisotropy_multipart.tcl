##########################################################
# Copyright (C) 2011,2012,2013,2014 The ESPResSo project
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

###############################################################
#	       	      Multi-particles test
# of correctness of calculation of the rotation of  magnetic 
# moments of the particles with uniaxial magnetic anisotropy 
# in the ensemble with random distributions of easy axes in
# presence of the temperature and the external magnetic field
###############################################################

source "tests_common.tcl"

require_feature "DIPOLES"
require_feature "ROTATION_PER_PARTICLE"
require_feature "VIRTUAL_SITES_RELATIVE"
require_feature "VIRTUAL_SITES_THERMOSTAT"
require_feature "MAGN_ANISOTROPY"

setmd periodic 0 0 0
setmd box_l 100 1 1
#setmd max_num_cells 8000

set ma_energy 10
set dipm 1.0

setmd time_step 0.1
setmd skin 0

constraint magnetic_anisotropy

set part_n 100

puts "Start test for $part_n particles"

#setmd 10 10 10

# Setting up the ensembles of particles with random (fixed) 
# distribution of the easy axes
for {set i 0} {$i<$part_n} {incr i} {
 set q_costheta [expr [t_random]]
 set q_sintheta [expr sin(acos($q_costheta))]
 set q_phi [expr 2*[PI]*[expr [t_random]]] 
 
 set qx [expr $q_sintheta*cos($q_phi)]
#set qx 0
 set qy [expr $q_sintheta*sin($q_phi)]
#set qy 0
 set qz [expr $q_costheta]
#set qz 1.0
 
 part $i pos [expr $i*0.01] 0 0 magn_aniso_energy $ma_energy quatu $qx $qy $qz rotation 0
 part [expr 10000+$i] pos 0 0 0 virtual 1 vs_relative $i 0 dip 0 1 0
 part [expr 10000+$i] dipm $dipm
}

set temperature 1
set gamma 1

thermostat langevin $temperature $gamma

#set avdipm 0
#for {set i 0} {$i<$part_n} {incr i} {
#   set avdipm [expr $avdipm + ([lindex [part [expr $i+10000] print dip] 2]) ]
#}
#set avdipm [expr $avdipm/$part_n]
#puts "Init: Av.mu_z = $avdipm"

set ext_field 5
constraint ext_magn_field 0 0 $ext_field

# setmd time_step 0.01

# for {set i 0} {$i<$part_n} {incr i} {
#    part $i rotation 0
# }

set calc_portions 25

set avdipm 0
for {set k 0} {$k<$calc_portions} {incr k} {
   integrate 1000
#  puts "[expr $k+1]: mag.energy = [analyze energy magnetic]"

   for {set i 0} {$i<$part_n} {incr i} {
     set avdipm [expr $avdipm + ([lindex [part [expr $i+10000] print dip] 2]) ]
   }
#  puts "$k: av.moment = [expr $avdipm/$part_n/($k+1)]"
}
set avdipm [expr $avdipm/$part_n/$calc_portions]

puts "Final ensemble magnetization = $avdipm"
# puts "Rel.magn: [expr $avdipm/$dipm/100]"

set expect_magn 0.613807
if { abs($avdipm/$expect_magn-1.0) > 0.05 } {
 error "Deviation too large. Should be within 5% of $expect_magn."
}

puts "Calculated magnetization of the ensemble of the magnetic particles with random distribution of easy axes is correct."
exit 0

