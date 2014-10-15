#include "Vector.hpp"
#include "magnetizable_particles.hpp"
#include "particle_data.hpp"
#include <map>
#include "config.hpp"
#include "p3m-dipolar.hpp"


using namespace std;

#ifdef DIPOLES

MagnetizableParticlesConfig magnetizableParticlesConfig;


void init_magnetizable_particle_config()
{
 magnetizableParticlesConfig.enabled=False;
 magnetizableParticlesCofnig.max_iterations=100;
}

map<int, Vector3d> local_field;




LinearMagnetization::LinearMagnetization(double chi)
{
   m_chi=chi;
};

Vector3d LinearMagnetization::M(Vector3d H)
{
      return m_chi*H;
};


double update_dipole_moment(Particle* p, MagnetizationCurve* M, double* local_field)
{
 m_old=Vector3d(p->r.dip)
 Vector3d m=M->M(Vector3d(local_field));
 m.to_scalar_array(p->r.dip);
 p->p.dipm=m.length();
 return (m-m_old).length();
}


void update_local_field_p3m_real_space_part()
{
  int c, np, n, i;
  Cell *cell;
  Particle *p1, *p2, **pairs;
  double dist2, vec21[3];

  /* Loop local cells */
  for (c = 0; c < local_cells.n; c++) {
    cell = local_cells.cell[c];
    p1   = cell->part;
    np  = cell->n;
    /* Loop cell neighbors */
    for (n = 0; n < dd.cell_inter[c].n_neighbors; n++) {
      pairs = dd.cell_inter[c].nList[n].vList.pair;
      np    = dd.cell_inter[c].nList[n].vList.n;
      /* verlet list loop */
      for(i=0; i<2*np; i+=2) {
	      p1 = pairs[i];                    /* pointer to particle 1 */
	      p2 = pairs[i+1];                  /* pointer to particle 2 */
	      dist2 = distance2vec(p1->r.p, p2->r.p, vec21); 
	      dp3m_calc_local_field(p1,p2,vec21,sqrt(dist2),dist2);
      }
    }
  }
}


void update_all_dipole_moments(MagnetizableParticlesConfig* C)
{

 // Local fields for all particles are stored in a hashmap with the particle id as key
 local_field.clear();
  
  // Initialize the local field to the external field if enabled, otherwise to 0.
  Vector3d init_field;

  // Find out whether there is an external field on
  // First of all we need to find the constraint number, corresponding to ext.magn.field
  int constrN;
  for (constrN = 0; constrN<n_constraints; constrN++)
  {
    if (constraints[constrN].type == CONSTRAINT_EXT_MAGN_FIELD)
      break;
  }
  if (constrN==n_constraints)
  {
    init_field[0]=init_field[1]=init_field[2] =0;
  }
  else
  {
   init_field=Vector3d(constraints[constrN].c.emfield.ext_magn_field);
  }

  // Store the init_field in the hash map for all particle ids
  for (c = 0; c < local_cells.n; c++) {
    cell = local_cells.cell[c];
    p  = cell->part;
    np = cell->n;
    for (i = 0; i < np; i++)
    {
      local_field[p[i].p.identity]=init_field;
    }
  }
  
 
 // Iterative procedure. Calc local fields, update dipole moments, calc field ...
 bool convergence =False;
 
 // Iteration couter
 int iter=0;

 while (!convergence) 
 {
  if (iter ==C.max_iterations)
  {
        ostringstream msg;
        msg <<"Dipole moments did not converge after the maximum number of allowed iterations.";
        runtimeError(msg);
        break;
  }
   
  // Calculate local field due to dipole-dipole interactions
  switch (coulomb.Dmethod) {
#ifdef DP3M
//  case DIPOLAR_MDLC_P3M:
//    add_mdlc_force_corrections();
//    //fall through 
  case DIPOLAR_P3M:
    dp3m_dipole_assign();
    dp3m_calc_kspace_forces(1,0);
    // ___ Do real spcae work missing
    break;
#endif
  case DIPOLAR_ALL_WITH_ALL_AND_NO_REPLICA: 
    dawaanr_calculations(DIPOLAR_CALC_LOCAL_FIELD);
    break;
//  case DIPOLAR_MDLC_DS:
//    add_mdlc_force_corrections();
//    //fall through 
//  case DIPOLAR_DS: 
//    magnetic_dipolar_direct_sum_calculations(DIPOLAR_CALC_LOCAL_FIELD);
//    break;
  case DIPOLAR_NONE:
      break;
  default:
      ostringstream msg;
      msg <<"Magnetizable particles are not supported with the selected dipolar interaction method";
      runtimeError(msg);
      break;
 }
 
 // Absolute change per dipole moment
 double change =0;
 int n=0;
 for (c = 0; c < local_cells.n; c++) {
    cell = local_cells.cell[c];
    p  = cell->part;
    np = cell->n;
    for (i = 0; i < np; i++)
    {
      change +=update_dipole_moment(&p[i],C->M,local_field[p[i].p.identity]=init_field);
      n++;
    }
  }
  change/=n;

  if (change <=C->max_change) 
   convergence=True;
  
  iter++;
 }

}
#endif

