#from espresso.utils cimport ERROR 
cimport numpy as np
import numpy as np
cimport utils
from utils cimport *
include "myconfig.pxi"


cdef class ParticleHandle:
  def __cinit__(self, _id):
#    utils.init_intlist(self.particleData.el)
    utils.init_intlist(&(self.particleData.bl))
    self.id=_id

  cdef int update_particle_data(self) except -1:
#    utils.realloc_intlist(self.particleData.el, 0)
    utils.realloc_intlist(&(self.particleData.bl), 0)
      
    if get_particle_data(self.id, &self.particleData):
      raise Exception("Error updating particle data")
    else: 
      return 0

  property type:
    """Particle type"""
    def __set__(self, _type):
      if isinstance(_type, int) and _type >= 0:  
        if set_particle_type(self.id, _type) == 1:
          raise Exception("set particle position first")
      else:
        raise ValueError("type must be an integer >= 0")
    def __get__(self):
      self.update_particle_data()
      return self.particleData.p.type

  property pos:
    """Particle position (not folded into periodic box)"""
    def __set__(self, _pos):
      cdef double mypos[3]
      checkTypeOrExcept(_pos, 3,float,"Postion must be 3 floats")
      for i in range(3): mypos[i]=_pos[i]
      if place_particle(self.id, mypos) == -1:
        raise Exception("particle could not be set")

    def __get__(self):
      self.update_particle_data()
      return np.array([self.particleData.r.p[0],\
                       self.particleData.r.p[1],\
                       self.particleData.r.p[2]])


<<<<<<< HEAD

=======
# Velocity

=======
>>>>>>> 845d6b43775ee07f18903eb81cc7587ef7502ea8
  property v:
    """Particle velocity""" 
    def __set__(self, _v):
      cdef double myv[3]
      checkTypeOrExcept(_v,3,float,"Velocity has to be floats")
      for i in range(3):
          myv[i]=_v[i]
      if set_particle_v(self.id, myv) == 1:
        raise Exception("set particle position first")
    def __get__(self):
      self.update_particle_data()
      return np.array([ self.particleData.m.v[0],\
                        self.particleData.m.v[1],\
                        self.particleData.m.v[2]])

  property f:
    """Particle force"""
    def __set__(self, _f):
      cdef double myf[3]
      checkTypeOrExcept(_f,3,float, "Force has to be floats")
      for i in range(3):
          myf[i]=_f[i]
      if set_particle_f(self.id, myf) == 1:
        raise Exception("set particle position first")
    def __get__(self):
      self.update_particle_data()
      return np.array([ self.particleData.f.f[0],\
                        self.particleData.f.f[1],\
                        self.particleData.f.f[2]])

  IF ELECTROSTATICS == 1:
    property q:
      """particle charge"""
      def __set__(self, _q):
        cdef double myq
        checkTypeOrExcept(_q,1,float, "Charge has to be floats")
        myq=_q
        if set_particle_q(self.id, myq) == 1:
          raise Exception("set particle position first")
      def __get__(self):
        self.update_particle_data()
        return self.particleData.p.q

# Bonds
  property bonds:
    """Bond partners with respect to bonded interactions."""
    
    def __set__(self,_bonds):
      # First, we check that we got a list/tuple. 
      if not hasattr(_bonds, "__getitem__"):
        raise ValueError("bonds have to specified as a tuple of tuples. (Lists can also be used)")
      # Check individual bonds
      for bond in _bonds: 
        self.checkBondOrThrowException(bond)
    
      # Assigning to the bond property means replacing the existing value
      # i.e., we delete all existing bonds
      if change_particle_bond(self.id,NULL,1):
        raise Exception("Deleting existing bonds failed.")
      
      # And add the new ones
      for bond in _bonds:
        self.addVerifiedBond(bond)
   
   
    def __get__(self):
      self.updateParticleData()
      bonds =[]
      # Go through the bond list of the particle
      i=0
      while i<self.particleData.bl.n:
        bond=[]
        # Bond type:
        bond.append(self.particleData.bl.e[i])
        i+=1
        # Number of partners
        nPartners=bonded_ia_params[i].num
        
        # Copy bond partners
        for j in range(nPartners):
          bond.append(self.particleData.bl.e[i])
          i+=1
        bonds.append(tuple(bond))
      
      return tuple(bonds)
      

# Bond related methods
  def addVerifiedBond(self,bond):
    """Add a bond, the validity of which has already been verified"""
    # If someone adds bond types with more than four partners, this has to be changed
    cdef int bondInfo[5] 
    for i in range(len(bond)):
       bondInfo[i]=bond[i]
    if change_particle_bond(self.id,bondInfo,0): 
      raise Exception("Adding the bond failed.")

  def deleteVerifiedBond(self,bond):
    """Delete a bond, the validity of which has already been verified"""
    # If someone adds bond types with more than four partners, this has to be changed
    cdef int bondInfo[5] 
    for i in range(len(bond)):
       bondInfo[i]=bond[i]
    if change_particle_bond(self.id,bondInfo,1):
      raise Exception("Deleting the bond failed.")

  def checkBondOrThrowException(self,bond)      :
    """Checks the validity of the given bond:
    * if the bond is given as a tuple
    * if it contains at least two values.
    * if all elements are of type int
    * If the bond type used exists (is lower than n_bonded_ia)
    * If the number of bond partners fits the bond type
    Throw an exception if any of these are not met"""
    if not hasattr(bond,"__getitem__"):
       raise ValueError("Elements of the bond list have to be tuples of the form (bondType,bondPartner)")
    if len(bond) <2:
      raise ValueError("Elements of the bond list have to be tuples of the form (bondType,bondPartner)")
      
    for y in bond:
      if not isinstance(y,int):
        raise ValueError("The bond type and bond partners have to be integers.")
    if bond[0] >= n_bonded_ia:
      raise ValueError("The bond type",bond[0], "does not exist.")
    
    if bonded_ia_params[bond[0]].num != len(bond)-1:
      raise ValueError("Bond of type",bond[0],"needs",bonded_ia_params[bond[0]],"partners.")
      

  def addBond(self,bond):
    """Add a single bond to the particel"""
    self.checkBondOrThrowException(bond)
    self.addVerifiedBond(bond)
    
  def deleteBond(self, bond):
    """Delete a single bond from the particle"""
    self.checkBondOrThrowException(bond)
    self.deleteVerifiedBond(bond)

  def deleteAllBonds(self):
    if change_particle_bond(self.id,NULL,1):
      raise Exception("Deleting all bonds failed.")


cdef class particleList:
  """Provides access to the particles via [i], where i is the particle id. Returns a ParticleHandle object """
  def __getitem__(self, key):
    return ParticleHandle(key)


