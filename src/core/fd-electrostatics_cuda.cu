//TODO: throw exceptions upon errors initialization

#include <cuda.h>
#include <cufft.h>
#include <fd-electrostatics.hpp>
#include <cuda_utils.hpp>
//#include <cuda_interface.hpp>


__global__ void createGreensfcn();
__global__ void multiplyGreensfcn();


static __device__ __constant__ FdElectrostatics::Parameters fde_parameters_gpu;


__device__ unsigned int fde_getThreadIndex() {

  return blockIdx.y * gridDim.x * blockDim.x +
         blockDim.x * blockIdx.x +
         threadIdx.x;
}


FdElectrostatics::~FdElectrostatics()
{
  cufftDestroy(plan_ifft);
  cufftDestroy(plan_fft);

  void* symbol;
  cudaGetSymbolAddress(&symbol, "fde_parameters_gpu");
  cuda_safe_mem( cudaFree(symbol) );

  cuda_safe_mem( cudaFree(parameters.greensfcn) );
  cuda_safe_mem( cudaFree(parameters.charge_potential) );
}


FdElectrostatics::FdElectrostatics(InputParameters inputParameters, cudaStream_t stream)
  : parameters(inputParameters), cuda_stream(stream)
{
  cuda_safe_mem( cudaMalloc( (void**) &parameters.charge_potential,
                             sizeof( cufftComplex ) *
                             parameters.dim_z * parameters.dim_y * ( parameters.dim_x / 2 + 1 ) ) );

  cuda_safe_mem( cudaMalloc( (void**) &parameters.greensfcn,
                             sizeof( cufftReal ) * 
                             parameters.dim_z * parameters.dim_y * ( parameters.dim_x / 2 + 1 ) ) );
  
  if( cudaGetLastError() != cudaSuccess ) 
  {
    fprintf(stderr, "ERROR: Failed to allocate\n");
    return;
  }

  cuda_safe_mem( cudaMemcpyToSymbol( fde_parameters_gpu, &parameters, sizeof( Parameters ) ) );
  
  int threads_per_block = 64;
  int blocks_per_grid_y = 4;
  int blocks_per_grid_x =
    ( parameters.dim_z * parameters.dim_y * (parameters.dim_x / 2 + 1) +
      threads_per_block * blocks_per_grid_y - 1
    ) / ( threads_per_block * blocks_per_grid_y );
  dim3 dim_grid = make_uint3( blocks_per_grid_x, blocks_per_grid_y, 1 );
  KERNELCALL_stream( createGreensfcn, dim_grid, threads_per_block, stream, () );

  /* create 3D FFT plans */
  
  if( cufftPlan3d( &plan_fft,
                   parameters.dim_z,
                   parameters.dim_y,
                   parameters.dim_x,
                   CUFFT_R2C ) != CUFFT_SUCCESS ) 
  {
    fprintf(stderr, "ERROR: Unable to create fft plan\n");
    return;
  }
  
  if( cufftSetCompatibilityMode( plan_fft, CUFFT_COMPATIBILITY_NATIVE ) != CUFFT_SUCCESS ) 
  {    
    fprintf(stderr, "ERROR: Unable to set fft compatibility mode to native\n");
    return;
  }
  
  if( cufftSetStream( plan_fft, cuda_stream) != CUFFT_SUCCESS ) 
  {
    fprintf(stderr, "ERROR: Unable to assign FFT to cuda stream\n");
    return;
  }

  if( cufftPlan3d( &plan_ifft,
                   parameters.dim_z,
                   parameters.dim_y,
                   parameters.dim_x,
                   CUFFT_C2R ) != CUFFT_SUCCESS ) 
  {   
    fprintf(stderr, "ERROR: Unable to create ifft plan\n");
    return;
  }
  
  if( cufftSetCompatibilityMode( plan_ifft, CUFFT_COMPATIBILITY_NATIVE ) != CUFFT_SUCCESS) 
  {   
    fprintf(stderr, "ERROR: Unable to set ifft compatibility mode to native\n");
    return;
  }
  
  if( cufftSetStream( plan_ifft, cuda_stream ) != CUFFT_SUCCESS )
  {    
    fprintf(stderr, "ERROR: Unable to assign FFT to cuda stream\n");
    return;
  }

  initialized = true;
}


__global__ void createGreensfcn() {
  unsigned int index = fde_getThreadIndex();
  unsigned int tmp;
  unsigned int coord[3];
  
  coord[0] = index % ( fde_parameters_gpu.dim_x / 2 + 1 );
  tmp      = index / ( fde_parameters_gpu.dim_x / 2 + 1 );
  coord[1] = tmp % fde_parameters_gpu.dim_y;
  coord[2] = tmp / fde_parameters_gpu.dim_y;
  
  if( index < fde_parameters_gpu.dim_z *
              fde_parameters_gpu.dim_y *
              ( fde_parameters_gpu.dim_x / 2 + 1 ) ) 
  {
              
    if( index == 0 ) 
    {
      //setting 0th fourier mode to 0 enforces charge neutrality
      fde_parameters_gpu.greensfcn[index] = 0.0f;
    }
    else 
    {
      fde_parameters_gpu.greensfcn[ index ] =
        -4.0f * PI_FLOAT * fde_parameters_gpu.bjerrum_length *
        fde_parameters_gpu.kT * fde_parameters_gpu.agrid * fde_parameters_gpu.agrid *
        0.5f /
        ( cos( 2.0f * PI_FLOAT * coord[0] / (cufftReal) fde_parameters_gpu.dim_x ) +
          cos( 2.0f * PI_FLOAT * coord[1] / (cufftReal) fde_parameters_gpu.dim_y ) +
          cos( 2.0f * PI_FLOAT * coord[2] / (cufftReal) fde_parameters_gpu.dim_z ) -
          3.0f
        ) /
        ( fde_parameters_gpu.dim_x *
          fde_parameters_gpu.dim_y *
          fde_parameters_gpu.dim_z
        );
    }
  }
}


__global__ void multiplyGreensfcn() {

  unsigned int index = fde_getThreadIndex();
  
  if( index < fde_parameters_gpu.dim_z * fde_parameters_gpu.dim_y * (fde_parameters_gpu.dim_x / 2 + 1) ) 
  {
    fde_parameters_gpu.charge_potential[ index ].x *= fde_parameters_gpu.greensfcn[ index ];
    fde_parameters_gpu.charge_potential[ index ].y *= fde_parameters_gpu.greensfcn[ index ];
  }
}


void FdElectrostatics::calculatePotential() {
  
  if( cufftExecR2C( plan_fft,
                    (cufftReal*) parameters.charge_potential,
                    parameters.charge_potential               ) != CUFFT_SUCCESS ) 
  {
                    
    fprintf(stderr, "ERROR: Unable to execute FFT plan\n");
  }
  
  int threads_per_block = 64;
  int blocks_per_grid_y = 4;
  int blocks_per_grid_x =
    ( parameters.dim_z * parameters.dim_y * ( parameters.dim_x / 2 + 1 ) +
      threads_per_block * blocks_per_grid_y - 1) / 
    ( threads_per_block * blocks_per_grid_y );
  dim3 dim_grid = make_uint3( blocks_per_grid_x, blocks_per_grid_y, 1 );

  KERNELCALL( multiplyGreensfcn, dim_grid, threads_per_block, () );
    
  if( cufftExecC2R( plan_ifft,
                    parameters.charge_potential,
                    (cufftReal*) parameters.charge_potential ) != CUFFT_SUCCESS )
  {
                    
    fprintf(stderr, "ERROR: Unable to execute iFFT plan\n");
  }
}


FdElectrostatics::Grid FdElectrostatics::getGrid()
{
  Grid g;
  //g.grid = static_cast<float*>(parameters.charge_potential);
  g.grid = (float*) parameters.charge_potential;
  g.dim_x = parameters.dim_x;
  g.dim_y = parameters.dim_y;
  g.dim_z = parameters.dim_z;
  g.agrid = parameters.agrid;
  return g;
  //return Grid((float*) parameters.charge_potential, parameters.dim_x, parameters.dim_y, parameters.dim_z, agrid);
}
