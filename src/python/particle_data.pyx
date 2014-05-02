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


# Velocity

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


cdef class particleList:
  """Provides access to the particles via [i], where i is the particle id. Returns a ParticleHandle object """
  def __getitem__(self, key):
    return ParticleHandle(key)


