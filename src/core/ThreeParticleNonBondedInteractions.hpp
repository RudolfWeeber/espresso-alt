#ifndef THREE_PARTICLE_NON_BONDED_INTERACTIONS
#define THREE_PARTICLE_NON_BONDED_INTERACTIONS
#include "particle_data.hpp"
#include <vector>



class ThreeParticleNonBondedInteraction {
 public:
   virtual double energy(Particle* p1, Particle* p2, Particle* p3) =0;
   virtual void add_force(Particle* p1, Particle* p2, Particle* p3) =0;
   virtual double max_cut_off() = 0;
};


class ThreeParticleDebugInteraction : ThreeParticleNonBondedInteraction {
 public:
   double energy(Particle* p1, Particle* p2, Particle* p3) {
     printf("Three particle potential energy called for particles %d %d %d\n",
       p1->p.identity,
       p2->p.identity,
       p3->p.identity);
     return 0;
   }
   void add_force(Particle* p1, Particle* p2, Particle* p3) {
     printf("Three particle potential energy called for particles %d %d %d\n",
       p1->p.identity,
       p2->p.identity,
       p3->p.identity);
   }
   double max_cut_off() { 
    return m_max_cut_off; 
   }
   double m_max_cut_off;
};





class ThreeParticleNonBondedInteractionList : public std::vector<ThreeParticleNonBondedInteraction*> {
  public:
    void add_forces(Particle* p1, Particle* p2, Particle* p3);
    double max_cut_off();
};

extern ThreeParticleNonBondedInteractionList threeParticleNonBondedInteractions;

std::vector<Particle*> search_for_third_particle(Particle* p1, Particle* p2);

#endif

