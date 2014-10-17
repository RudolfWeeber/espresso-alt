#include "ThreeParticleNonBondedInteractions.hpp"
#include "cells.hpp"
#include "domain_decomposition.hpp"
#include <vector>

ThreeParticleNonBondedInteractionList threeParticleNonBondedInteractions;

void ThreeParticleNonBondedInteractionList::add_forces(Particle* p1, Particle* p2, Particle* p3)
{
 for (ThreeParticleNonBondedInteractionList::iterator i =this->begin(); i!=this->end();i++)
   (*i)->add_force(p1,p2,p3);
}

double ThreeParticleNonBondedInteractionList::max_cut_off()
{
 double c=-1;

 for (ThreeParticleNonBondedInteractionList::iterator i =this->begin(); i!=this->end();i++)
   if ((*i)->max_cut_off()>c)
    c=(*i)->max_cut_off();
 
 return c;

}


std::vector<Particle*> search_for_third_particle(Particle* p1, Particle* p2)
{
 // Result vector containing pointers to all particles which form triplets with the first two particles.
 std::vector<Particle*> res;

    // Indices of the cells in which the colliding particles reside
    int cellIdx[2][3];
    
    // Iterate over collision queue

      dd_position_to_cell_indices(p1->r.p,cellIdx[0]);
      dd_position_to_cell_indices(p2->r.p,cellIdx[1]);

      // Iterate over the cells + their neighbors
      // if p1 and p2 are in the same cell, we don't need to consider it 2x
      int lim=1;

      if ((cellIdx[0][0]==cellIdx[1][0]) && (cellIdx[0][1]==cellIdx[1][1]) && (cellIdx[0][2]==cellIdx[1][2]))
        lim=0; // Only consider the 1st cell

      for (int j=0;j<=lim;j++)
      {
       // Iterate the cell with indices cellIdx[j][] and all its neighbors.
       // code taken from dd_init_cell_interactions()
       for(int p=cellIdx[j][0]-1; p<=cellIdx[j][0]+1; p++)	
         for(int q=cellIdx[j][1]-1; q<=cellIdx[j][1]+1; q++)
	   for(int r=cellIdx[j][2]-1; r<=cellIdx[j][2]+1; r++) {   
	    int ind2 = get_linear_index(p,q,r,dd.ghost_cell_grid);
	    Cell* cell=cells+ind2;

	    // Iterate over particles in this cell
            for (int a=0; a<cell->n; a++) {
               Particle* P=&cell->part[a];
               // for all p:
  	       // Check, whether p is equal to one of the particles in the
  	       // collision. If so, skip
  	       if ((P->p.identity ==p1->p.identity) || ( P->p.identity == p2->p.identity)) {
  		   continue;
  	       }

	       // To prevent double counting of triplets, we skip all those where the id of the 
	       // 3rd particle is not larger than the id of the first two.
	       if ((P->p.identity <p1->p.identity) || (P->p.identity< p2->p.identity))
  	         continue;

	       // Add Particle P to result list
	       res.push_back(P);
           } // Cell loop

	 } // Loop over 1st and 2nd particle, in case they are in diferent cells

        } // Loop over collision queue
    
  return res;
}
