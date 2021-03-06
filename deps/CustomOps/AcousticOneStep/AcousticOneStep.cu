#include "cuda.h"
#include "AcousticOneStep.h"


#define BX 32
#define BY 32

using namespace tensorflow;


__global__ void calculate_one_step_forward(
    const double*  w,
    const double*  wold,
    const double*  phi,
    const double*  psi,
    const double*  sigma,
    const double*  tau,
    const double*  c,
    double  dt,
    double  hx,
    double  hy,
    int64  NX,
    int64  NY,
    double*  u,
    double*  phiout,
    double*  psiout
){
    int i = BX * blockIdx.x + threadIdx.x;
    int j = BY * blockIdx.y + threadIdx.y;
    int IJ = i * (NY+2) + j;
    int IpJ = (i + 1) * (NY+2) + j;
    int InJ = (i - 1) * (NY+2) + j;
    int IJp = i * (NY+2) + j + 1;
    int IJn = i * (NY+2) + j - 1;


    if (i==0 || i==NX+1 || j==0 || j==NY+1){
        if (i>NX+1 || i<0 || j>NY+1 || j<0)
            return;
        u[IJ] = 0.0;
        phiout[IJ] = 0.0;
        psiout[IJ] = 0.0;
        return;
    }
    if (i>=NX+1 || i<=0 || j>=NY+1 || j<=0)
        return;
    
    

    u[IJ] = (2 - sigma[IJ]*tau[IJ]*dt*dt - 2*dt*dt/hx/hx * c[IJ] - 2*dt*dt/hy/hy * c[IJ]) * w[IJ] +
            c[IJ] * (dt/hx)*(dt/hx)  *  (w[IpJ]+w[InJ]) +
            c[IJ] * (dt/hy)*(dt/hy)  *  (w[IJp]+w[IJn]) +
            (dt*dt/(2.0*hx))*(phi[IpJ]-phi[InJ]) +
            (dt*dt/(2.0*hy))*(psi[IJp]-psi[IJn]) -
                (1 - (sigma[IJ]+tau[IJ])*dt/2) * wold[IJ];
    u[IJ] = u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    phiout[IJ] = (1. -dt*sigma[IJ]) * phi[IJ] + dt * c[IJ] * (tau[IJ] -sigma[IJ])/2.0/hx *  
        (w[IpJ]-w[InJ]);
    psiout[IJ] = (1. -dt*tau[IJ]) * psi[IJ] + dt * c[IJ] * (sigma[IJ] -tau[IJ])/2.0/hy * 
        (w[IJp]-w[IJn]);
}



__global__ void calculate_one_step_backward(
    double*  grad_w,
    double*  grad_wold,
    double*  grad_phi,
    double*  grad_psi,
    double*  grad_c,
    const double*  grad_u,
    const double*  grad_phiout,
    const double*  grad_psiout,
    const double*  w,
    const double*  wold,
    const double*  phi,
    const double*  psi,
    const double*  sigma,
    const double*  tau,
    const double*  c,
    double  dt,
    double  hx,
    double  hy,
    int64  NX,
    int64  NY,
    const double*  u,
    const double*  phiout,
    const double*  psiout
){
    int i = BX * blockIdx.x + threadIdx.x;
    int j = BY * blockIdx.y + threadIdx.y;
    if (i>=NX+1 || i<=0 || j>=NY+1 || j<=0)
        return;
    
    int IJ = i * (NY+2) + j;
    int IpJ = (i + 1) * (NY+2) + j;
    int InJ = (i - 1) * (NY+2) + j;
    int IJp = i * (NY+2) + j + 1;
    int IJn = i * (NY+2) + j - 1;

    // u[IJ] = (2 - sigma[IJ]*tau[IJ]*dt*dt - 2*dt*dt/hx/hx * c[IJ] - 2*dt*dt/hy/hy * c[IJ]) * w[IJ] +
    //         c[IJ] * (dt/hx)*(dt/hx)  *  (w[IpJ]+w[InJ]) +
    //         c[IJ] * (dt/hy)*(dt/hy)  *  (w[IJp]+w[IJn]) +
    //         (dt*dt/(2.0*hx))*(phi[IpJ]-phi[InJ]) +
    //         (dt*dt/(2.0*hy))*(psi[IJp]-psi[IJn]) -
    //             (1 - (sigma[IJ]+tau[IJ])*dt/2) * wold[IJ];
    // u[IJ] = u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);

    grad_c[IJ] += ((- 2*dt*dt/hx/hx - 2*dt*dt/hy/hy ) * w[IJ] + (dt/hx)*(dt/hx)  *  (w[IpJ]+w[InJ]) + 
                    (dt/hy)*(dt/hy)  *  (w[IJp]+w[IJn])) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    grad_c[IJ] += dt *  (tau[IJ] -sigma[IJ])/2.0/hx *  (w[IpJ]-w[InJ]) * grad_phiout[IJ];
    grad_c[IJ] += dt * (sigma[IJ] -tau[IJ])/2.0/hy * (w[IJp]-w[IJn]) * grad_psiout[IJ];
    grad_wold[IJ] += -(1 - (sigma[IJ]+tau[IJ])*dt/2) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);

    grad_w[IJ] += (2 - sigma[IJ]*tau[IJ]*dt*dt - 2*dt*dt/hx/hx * c[IJ] - 2*dt*dt/hy/hy * c[IJ]) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);

    grad_phi[IJ] += (1. -dt*sigma[IJ]) * grad_phiout[IJ];
    grad_psi[IJ] += (1. -dt*tau[IJ]) * grad_psiout[IJ]; 



    // grad_w[IpJ] += c[IJ] * (dt/hx)*(dt/hx) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt) +
    //                 dt * c[IJ] * (tau[IJ] -sigma[IJ])/2.0/hx * grad_phiout[IJ];
    // grad_phi[IpJ] += (dt*dt/(2.0*hx)) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    // grad_psi[IJp] += (dt*dt/(2.0*hy)) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    // grad_phi[InJ] += -(dt*dt/(2.0*hx)) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    // grad_psi[IJn] += -(dt*dt/(2.0*hy)) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt);
    // grad_w[InJ] += c[IJ] * (dt/hx)*(dt/hx) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt) - 
    //                dt * c[IJ] * (tau[IJ] -sigma[IJ])/2.0/hx * grad_phiout[IJ];   
    // grad_w[IJp] +=  c[IJ] * (dt/hy)*(dt/hy) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt) + 
    //                     dt * c[IJ] * (sigma[IJ] -tau[IJ])/2.0/hy * grad_psiout[IJ];
    // grad_w[IJn] +=  c[IJ] * (dt/hy)*(dt/hy) * grad_u[IJ] / (1 + (sigma[IJ]+tau[IJ])/2*dt) -
    //                 dt * c[IJ] * (sigma[IJ] -tau[IJ])/2.0/hy * grad_psiout[IJ];

    __syncthreads();

    if (i>0){
        grad_w[IJ] += c[InJ] * (dt/hx)*(dt/hx) * grad_u[InJ] / (1 + (sigma[InJ]+tau[InJ])/2*dt) +
         dt * c[InJ] * (tau[InJ] -sigma[InJ])/2.0/hx * grad_phiout[InJ];
        grad_phi[IJ] += (dt*dt/(2.0*hx)) * grad_u[InJ] / (1 + (sigma[InJ]+tau[InJ])/2*dt);
    }

    __syncthreads();
    
    
    if (j>0){
        grad_psi[IJ] += (dt*dt/(2.0*hy)) * grad_u[IJn] / (1 + (sigma[IJn]+tau[IJn])/2*dt);
        grad_w[IJ] +=  c[IJn] * (dt/hy)*(dt/hy) * grad_u[IJn] / (1 + (sigma[IJn]+tau[IJn])/2*dt) + 
                            dt * c[IJn] * (sigma[IJn] -tau[IJn])/2.0/hy * grad_psiout[IJn];
    }

    __syncthreads();
        

    if (i<NX+1){
        grad_phi[IJ] += -(dt*dt/(2.0*hx)) * grad_u[IpJ] / (1 + (sigma[IpJ]+tau[IpJ])/2*dt);
        grad_w[IJ] += c[IpJ] * (dt/hx)*(dt/hx) * grad_u[IpJ] / (1 + (sigma[IpJ]+tau[IpJ])/2*dt) - 
                    dt * c[IpJ] * (tau[IpJ] -sigma[IpJ])/2.0/hx * grad_phiout[IpJ]; 
    }

    __syncthreads();
        
    
    if (j<NY+1){
        grad_w[IJ] +=  c[IJp] * (dt/hy)*(dt/hy) * grad_u[IJp] / (1 + (sigma[IJp]+tau[IJp])/2*dt) -
                        dt * c[IJp] * (sigma[IJp] -tau[IJp])/2.0/hy * grad_psiout[IJp];
        grad_psi[IJ] += -(dt*dt/(2.0*hy)) * grad_u[IJp] / (1 + (sigma[IJp]+tau[IJp])/2*dt);
    }
    
    
}

__global__ void zero_out(double*  grad_w,
    double*  grad_wold,
    double*  grad_phi,
    double*  grad_psi,
    double*  grad_c,
    int NX, int NY){
    int i = BX * blockIdx.x + threadIdx.x;
    int j = BY * blockIdx.y + threadIdx.y;
    if (i>=NX+2 || j>=NY+2)
        return;
    int IJ = i * (NY+2) + j;
    grad_w[IJ] = 0.0;
    grad_wold[IJ] = 0.0;
    grad_phi[IJ] = 0.0;
    grad_psi[IJ] = 0.0;
    grad_c[IJ] = 0.0;
}

void AcousticOneStepForward(const double*  w,
    const double*  wold,
    const double*  phi,
    const double*  psi,
    const double*  sigma,
    const double*  tau,
    const double*  c,
    double  dt,
    double  hx,
    double  hy,
    int64  NX,
    int64  NY,
    double*  u,
    double*  phiout,
    double*  psiout){
    
    dim3 gridDim((NX+2-1)/BX+1, (NY+2-1)/BY+1,1);
    dim3 blockDim(BX, BY, 1);
    calculate_one_step_forward<<<gridDim, blockDim>>>(
        w, wold, phi, psi, sigma, tau, c, dt, hx, hy, NX, NY, u, phiout, psiout
    );
    cudaDeviceSynchronize();
}


void AcousticOneStepBackward(
    double*  grad_w,
    double*  grad_wold,
    double*  grad_phi,
    double*  grad_psi,
    double*  grad_c,
    const double*  grad_u,
    const double*  grad_phiout,
    const double*  grad_psiout,
    const double*  w,
    const double*  wold,
    const double*  phi,
    const double*  psi,
    const double*  sigma,
    const double*  tau,
    const double*  c,
    double  dt,
    double  hx,
    double  hy,
    int64  NX,
    int64  NY,
    const double*  u,
    const double*  phiout,
    const double*  psiout){
    
    dim3 gridDim((NX+2-1)/BX+1, (NY+2-1)/BY+1,1);
    dim3 blockDim(BX, BY, 1);
    zero_out<<<gridDim, blockDim>>>(grad_w,
        grad_wold,
        grad_phi,
        grad_psi,
        grad_c,
        NX, NY);
    calculate_one_step_backward<<<gridDim, blockDim>>>(
        grad_w,
        grad_wold,
        grad_phi,
        grad_psi,
        grad_c,
        grad_u,
        grad_phiout,
        grad_psiout,
        w, wold, phi, psi, sigma, tau, c, dt, hx, hy, NX, NY, u, phiout, psiout
    );
    cudaDeviceSynchronize();
}
