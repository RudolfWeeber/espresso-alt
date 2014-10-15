
#include "particle_data.hpp"
#include "Vector.hpp"
#include "config.hpp"

#ifndef MAGNETIZABLE_PARTICLES_HPP
#define MAGNETIZABLE_PARTICLES_HPP

#ifdef DIPOLES

class 
 MagnetizationCurve {
 public:
  virtual Vector3d M(Vector3d H);
};

class LinearMagnetization : MagnetizationCurve {
  public:
     LinearMagnetization(double chi);

     Vector3d M(Vector3d H);
  private:
    double m_chi;
}


double update_dipole_moment(Particle* p, MagnetizationCurve* M, double* local_field);

void update_all_dipole_moments(MagnetizableParticlesConfig* C);

typedef struct 
 {
   bool enabled;
   MagnetizationCurve M;
   // Convergence criterion: Maximum asbolute change of dipole moment between 2nd to last and last iteration
   double max_change;
   // Maximum number of iterations for updating the dipole moment
   int max_iterations;
  } MagnetizableParticlesConfig;

extern MagnetizableParticlesConfig magnetizableParticlesConfig;

#endif
#endif

