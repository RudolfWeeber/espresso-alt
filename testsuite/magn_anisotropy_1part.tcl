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
#		Single-particle test
# of correctness of calculation of the energy and coordinates 
# of magnetic moment and magnetic anisotropy axis 
# of the free particle at zero field and temperuture 
###############################################################

source "tests_common.tcl"

require_feature "DIPOLES"
require_feature "ROTATION"
require_feature "VIRTUAL_SITES_RELATIVE"
require_feature "MAGN_ANISOTROPY"

# Setup
cellsystem nsquare

set ma_energy 2.345
set dipm 6

part 0 pos 0 0 0 magn_aniso_energy $ma_energy fix 1 1 1 quatu 0 0 1
part 10000 pos 0 0 0 vs_relative 0 0 virtual 1 dip 1 0 0 
part 10000 dipm $dipm

setmd time_step 0.01
setmd skin 0
thermostat langevin 0 1

set calc_accuracy 1e-6

constraint magnetic_anisotropy

# Calculation
puts "Start single particle test on the magnetic anisotropy"
integrate 10000

# Check energy
if {[expr abs([analyze energy magnetic]-(-[part 0 print magn_aniso_energy]))]>$calc_accuracy} {
error "Calculated value of the magnetic anisotropy energy is wrong: [analyze energy magnetic] (must be: -[part 0 print magn_aniso_energy])"
return 1
} else {
puts "1. Calculated value of magnetic anisotropy energy is correct: [analyze energy magnetic]"
}

# Check coordinates
if { [expr abs( sin([PI]/4)-[lindex [part 10000 print quatu] 0] )]>$calc_accuracy || [expr abs( sin([PI]/4)-[lindex [part 0 print quatu] 0] )]>$calc_accuracy } {
error "The result X-coordinate of the magnetic moment ([lindex [part 10000 print dip] 0]) and/or anisotropy axis ([lindex [part 0 print quatu] 0]) is wrong and must be: [expr sin([PI]/4)]"
return 1
} else {
puts "2. Calculated coordinates of the particle magnetic moment and easy axis are correct"
}

return 0
