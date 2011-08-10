#include "particle_data.h"
#include "interaction_data.h"
#include "virtual_sites_relative.h"
#include "collision.h"
#include "virtual_sites.h"
#include "integrate.h"
#include "cells.h"


#ifdef COLLISION_DETECTION




// During force calculation, colliding particles are recorded in thequeue
// The queue is processed after force calculation, when it is save to add
// particles
collision_struct * collision_queue;

// Number of collisions recoreded in the queue
int number_of_collisions;

// Bond type used for marker bonds
int collision_detection_bond_marker;


// bond type used between virtual sites 
int collision_detection_bond_marker;


// Detect a collision between the given particles.
// In case of a collision, a bond is added between them as marker
// and the collision is recorded in the queue
void detect_collision(Particle* p1, Particle* p2)
{
  
    double dist_betw_part, vec21[3], collisioncriter=1.1;
    int part1, part2, the_bond_type_added_on_collision=0, size;

    // Obtain distance between particles
    dist_betw_part = distance2vec(p1->r.p, p2->r.p, vec21);
    if (dist_betw_part > collisioncriter)
       return;

      part1 = p1->p.identity;
      part2 = p2->p.identity;
      
      // Retrieving the particles from local_particles is necessary, because the particle might be a
      // ghost, and those don't contain bonding info
      p1 = local_particles[part1];
      p2 = local_particles[part2];

      // Ignore virtual particles
      if ((p1->p.isVirtual) || (p2->p.isVirtual))
       return;


      // Check, if there's already a bond between the particles
      // First check the bonds of p1 
      int i = 0;
      int found = 0;
      while(i < p1->bl.n) {
        size = bonded_ia_params[p1->bl.e[i]].num;

        if (p1->bl.e[i] == the_bond_type_added_on_collision &&
        p1->bl.e[i + 1] == part2) {
          // There's a bond, already. Nothing to do for these particles
          return;
        }
        i += size + 1;
      }
      
      // Check, if a bond is already stored in p2
      i = 0;
      while(i < p2->bl.n) {
        size = bonded_ia_params[p2->bl.e[i]].num;

        /* COMPARE P2 WITH P1'S BONDED PARTICLES*/

        if (p2->bl.e[i] == the_bond_type_added_on_collision &&
        p2->bl.e[i + 1] == part1) {
          return;
        }
        i += size + 1;
      }


      // If we're still here, there is no previous bond between the particles

      // Create the marker bond between the particles
      int bondG[2];
      bondG[0]=collision_detection_bond_marker;
      bondG[1]=part2;
      local_change_bond(part1, bondG, 0);
      
      // Insert collision info into the queue
      
      // Point of collision
      double new_position[3];
      for (i=0;i<3;i++) {
        new_position[i] =p1->r.p[i] - vec21[i] * 0.50;
       }
       
       number_of_collisions = number_of_collisions+1;
       
      // Allocate mem for the new collision info
      collision_queue = (collision_struct *) realloc (collision_queue, (number_of_collisions) * sizeof(collision_struct));
      
      // Save the collision      
      collision_queue[number_of_collisions-1].pp1 = part1;
      collision_queue[number_of_collisions-1].pp2 = part2;
      for (i=0;i<3;i++) {
        collision_queue[number_of_collisions-1].point_of_collision[i] = new_position[i]; 
      }

}

void prepare_collision_queue()
{
  
number_of_collisions=0;

collision_queue = (collision_struct *) malloc (sizeof(collision_struct));

}


// Handle the collisions stored in the queue
void handle_collisions ()
{
  
int delete =0, bondG[2], i;

 // Go through the queue
 for (i=0;i<number_of_collisions;i++)
 {
//  printf("Handling collision of particles %d %d\n", collision_queue[i].pp1, collision_queue[i].pp2);
//  fflush(stdout);
   
   int j;

// The following lines will remove the relative velocity from
// colliding particles
//   double v[3];
//   for (j=0;j<3;j++)
//   {
//    v[j] =0.5 *((local_particles[collision_queue[i].pp1])->m.v[j] +(local_particles[collision_queue[i].pp2])->m.v[j]);
//    (local_particles[collision_queue[i].pp1])->m.v[j] =v[j];
//    (local_particles[collision_queue[i].pp2])->m.v[j] =v[j];
//   }

  // Create virtual sites and bind them gotether
  
  // Virtual site related to first particle in the collision
  place_particle(max_seen_particle+1,collision_queue[i].point_of_collision);
  vs_relate_to(max_seen_particle,collision_queue[i].pp1);
  (local_particles[max_seen_particle])->p.isVirtual=1;
  
  
  // Virtual particle related to 2nd particle of the collision
  place_particle(max_seen_particle+1,collision_queue[i].point_of_collision);
  vs_relate_to(max_seen_particle,collision_queue[i].pp2);
  (local_particles[max_seen_particle])->p.isVirtual=1;
  
  
  // Create bond between the virtual particles
  bondG[0] =collision_detection_bond_virtual_sites;
  bondG[1] =max_seen_particle-1;
  local_change_bond(max_seen_particle, bondG, 0);
}

// Resort particles and update local_particles[]
int c;
for(c=0; c<local_cells.n; c++) {
    update_local_particles(local_cells.cell[c]);
}

cells_resort_particles(1);
on_particle_change();

}
 



// Reset the collision queue	 
number_of_collisions = 0;
free(collision_queue);

}



int tclcommand_collision_detection_parse_collision(Tcl_Interp *interp, int argc, char **argv) 
{

  /* check number of arguments */
  int print_syntax=0;
  if (argc < 1) {
   print_syntax=1;
  else
  {
   
    Tcl_AppendResult(interp, "wrong # args:  should be \n\"",
		     " <mode> <c_criter> <c_rbond_type> <c_vbond_type>\"", (char *)NULL);
    return (TCL_ERROR);
  }

  /* check argument types */
  if ( !ARG_IS_I(0, c_detection) || !ARG_IS_D(1, c_criter) || !ARG_IS_I(2, c_rbond_type) || !ARG_IS_I(3, c_vbond_type)) {
    Tcl_AppendResult(interp, argv[0]," ",argv[1]," ",argv[2]," ",argv[3]," needs one double 3 integers", (char *)NULL);
    return (TCL_ERROR);
  }

  if (c_criter < 0 || c_detection < 0 || c_detection > 1) {
    Tcl_AppendResult(interp, "collision criteria must be positive and Collision_detection_enabled must be 0 or 1", (char *)NULL);
    return (TCL_ERROR);
  }

  /* broadcast parameters */
  collision_criter = c_criter;
  collision_real_bond_type = c_rbond_type;
  collision_virtual_bond_type = c_vbond_type;
  collision_detection_enabled = c_detection;
//  mpi_bcast_parameter(FIELD_COLLISION_SWITCH);
//  mpi_bcast_parameter(FIELD_COLLISION_CRITER);
//  mpi_bcast_parameter(FIELD_COLLISION_BOND_TYPE);
  return (TCL_OK);
}


int tclcommand_collision_print_all(Tcl_Interp *interp)
{
 
  char buffer[TCL_DOUBLE_SPACE];
  /* collision not initialized */
  if(collision_criter == -1.0) {
    Tcl_AppendResult(interp,"{ not initialized } ", (char *)NULL);
    return (TCL_OK);
  }

  /* no collision on */
  if(collision_detection_enabled == 0) {
    Tcl_AppendResult(interp,"{ no collision detection } ", (char *)NULL);
    return (TCL_OK);
  }

  /* collision */
  if (collision_detection_enabled == 1 ) {
    Tcl_PrintDouble(interp, collision_criter, buffer);
    Tcl_AppendResult(interp,"{ collision ",buffer, (char *)NULL);
    Tcl_PrintDouble(interp, collision_real_bond_type, buffer);
    Tcl_PrintDouble(interp, collision_virtual_bond_type, buffer);    
    Tcl_AppendResult(interp," ",buffer," } ", (char *)NULL);
  }
    
  return (TCL_OK);
}

int tclcommand_collision_print_usage(Tcl_Interp *interp, int argc, char **argv)
{
  Tcl_AppendResult(interp, "Usage of tcl-command collision:\n", (char *)NULL);
  Tcl_AppendResult(interp, "'", argv[0], "' for status return or \n ", (char *)NULL);
  Tcl_AppendResult(interp, "'", argv[0], " set 0 to deactivate it \n ", (char *)NULL);
  Tcl_AppendResult(interp, "'", argv[0], " set collision <c_detection> <c_criter> <c_rbond_type> <c_vbond_type>' or \n ", (char *)NULL);

  return (TCL_ERROR);
}


int tclcommand_collision_detection(ClientData data, Tcl_Interp *interp, int argc, char **argv) 
{
  

  int err = TCL_OK;
  
  if ( ARG1_IS_S("set") )          {
    argc--;
    argv++;

    if (argc == 1) {
      Tcl_AppendResult(interp, "wrong # args: \n", (char *)NULL);
      return tclcommand_collision_print_usage(interp, argc, argv);
    }
  }
  if ( ARG1_IS_S("0") )
    err = tclcommand_collision_parse_off(interp, argc, argv);
  else if ( ARG1_IS_S("1"))
    err = tclcommand_collision_detection_parse_collision(interp, argc, argv);
  else {
    Tcl_AppendResult(interp, " No Collision option ", argv[1], "\n", (char *)NULL);
    return tclcommand_collision_print_usage(interp, argc, argv);
  }
//  return mpi_gather_runtime_errors(interp, err);
}


