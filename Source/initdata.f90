module init_module

  use bl_types
  use bl_constants_module
  use bc_module
  use multifab_physbc_module
  use define_bc_module
  use multifab_module
  use fill_3d_module
  use eos_module
  use variables
  use network
  use geometry
  use probin_module, only: grav_const

  implicit none

  private
  public :: initscalardata, initveldata, scalar_diags

contains

  subroutine initscalardata (s,s0,p0,dx,perturb_model, &
                             prob_lo,prob_hi,bc)

    type(multifab) , intent(inout) :: s
    real(kind=dp_t), intent(in   ) ::    s0(0:,:)
    real(kind=dp_t), intent(in   ) ::    p0(0:)
    real(kind=dp_t), intent(in   ) :: dx(:)
    logical,         intent(in   ) :: perturb_model
    real(kind=dp_t), intent(in   ) :: prob_lo(:)
    real(kind=dp_t), intent(in   ) :: prob_hi(:)
    type(bc_level) , intent(in   ) :: bc

    real(kind=dp_t), pointer:: sop(:,:,:,:)
    integer :: lo(s%dim),hi(s%dim),ng,dm
    integer :: i,n
    
    ng = s%ng
    dm = s%dim

    do i = 1, s%nboxes
       if ( multifab_remote(s, i) ) cycle
       sop => dataptr(s, i)
       lo =  lwb(get_box(s, i))
       hi =  upb(get_box(s, i))

       select case (dm)
       case (2)
          call initscalardata_2d(sop(:,:,1,:), lo, hi, ng, dx, perturb_model, &
                                 prob_lo, prob_hi, s0, p0)
       case (3)
          call initscalardata_3d(sop(:,:,:,:), lo, hi, ng, dx, perturb_model, &
                                 prob_lo, prob_hi, s0, p0)
       end select
    end do

    call multifab_fill_boundary(s)
    call multifab_physbc(s,rho_comp,dm+rho_comp,nscal,dx,bc)

  end subroutine initscalardata

  subroutine initscalardata_2d (s,lo,hi,ng,dx, perturb_model, &
                                prob_lo,prob_hi,s0,p0)

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) :: s(lo(1)-ng:,lo(2)-ng:,:)  
    real (kind = dp_t), intent(in ) :: dx(:)
    logical,            intent(in ) :: perturb_model
    real (kind = dp_t), intent(in ) :: prob_lo(:)
    real (kind = dp_t), intent(in ) :: prob_hi(:)
    real(kind=dp_t), intent(in   ) ::    s0(0:,:)
    real(kind=dp_t), intent(in   ) ::    p0(0:)

    !     Local variables
    integer :: i, j, n
    real(kind=dp_t) :: x,y,r,r0,r1,r2,temp
    real(kind=dp_t) :: dens_pert, rhoh_pert, temp_pert
    real(kind=dp_t) :: rhoX_pert(nspec), trac_pert(ntrac)

    ! initial the domain with the base state
    s = ZERO

    ! initialize the scalars
    do j = lo(2), hi(2)
       do i = lo(1), hi(1)
          s(i,j,rho_comp)  = s0(j,rho_comp)
          s(i,j,rhoh_comp) = s0(j,rhoh_comp)
          s(i,j,temp_comp) = s0(j,temp_comp)

          s(i,j,spec_comp:spec_comp+nspec-1) = &
               s0(j,spec_comp:spec_comp+nspec-1)
       enddo
    enddo
    
    ! add an optional perturbation
    if (perturb_model) then
       do j = lo(2), hi(2)
          y = prob_lo(2) + (dble(j)+HALF) * dx(2)
       
          do i = lo(1), hi(1)
             x = prob_lo(1) + (dble(i)+HALF) * dx(1)
          
             call perturb_2d(x, y, p0(j), s0(j,:), &
                             dens_pert, rhoh_pert, rhoX_pert, temp_pert, trac_pert)

             s(i,j,rho_comp) = dens_pert
             s(i,j,rhoh_comp) = rhoh_pert
             s(i,j,temp_comp) = temp_pert
             s(i,j,spec_comp:spec_comp+nspec-1) = rhoX_pert(1:)
             s(i,j,trac_comp:trac_comp+ntrac-1) = trac_pert(:)
          enddo
       enddo
    endif
    
  end subroutine initscalardata_2d

  subroutine initscalardata_3d (s,lo,hi,ng,dx, perturb_model, &
                                prob_lo,prob_hi,s0,p0)

    implicit none

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) :: s(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)  
    real (kind = dp_t), intent(in ) :: dx(:)
    logical,            intent(in ) :: perturb_model
    real (kind = dp_t), intent(in ) :: prob_lo(:)
    real (kind = dp_t), intent(in ) :: prob_hi(:)
    real(kind=dp_t), intent(in   ) ::    s0(0:,:)
    real(kind=dp_t), intent(in   ) ::    p0(0:)

    !     Local variables
    integer :: i, j, k, comp
    real(kind=dp_t) :: x,y,z,r,r0,r1,r2,temp
    real(kind=dp_t) :: dens_pert, rhoh_pert, temp_pert
    real(kind=dp_t) :: rhoX_pert(nspec), trac_pert(ntrac)

    ! initial the domain with the base state
    s = ZERO
  
    if (spherical .eq. 1) then

       ! initialize the scalars
       call fill_3d_data (s(:,:,:,rho_comp), s0(:,rho_comp), lo,hi,dx,ng)
       call fill_3d_data (s(:,:,:,rhoh_comp),s0(:,rhoh_comp),lo,hi,dx,ng)
       call fill_3d_data (s(:,:,:,temp_comp),s0(:,temp_comp),lo,hi,dx,ng)

       do comp = spec_comp, spec_comp+nspec-1
          call fill_3d_data (s(:,:,:,comp),s0(:,comp),lo,hi,dx,ng)
       end do

    else 

       ! initialize the scalars
       do k = lo(3), hi(3)
          do j = lo(2), hi(2)
             do i = lo(1), hi(1)
                s(i,j,k,rho_comp)  = s0(k,rho_comp)
                s(i,j,k,rhoh_comp) = s0(k,rhoh_comp)
                s(i,j,k,temp_comp) = s0(k,temp_comp)

                s(i,j,k,spec_comp:spec_comp+nspec-1) = &
                     s0(k,spec_comp:spec_comp+nspec-1)
             enddo
          enddo
       enddo
       
       if (perturb_model) then

          ! add an optional perturbation
          do k = lo(3), hi(3)
             z = prob_lo(3) + (dble(k)+HALF) * dx(3)
             
             do j = lo(2), hi(2)
                y = prob_lo(2) + (dble(j)+HALF) * dx(2)
                
                do i = lo(1), hi(1)
                   x = prob_lo(1) + (dble(i)+HALF) * dx(1)
                   
                   call perturb_3d(x, y, z, p0(k), s0(k,:), &
                                   dens_pert, rhoh_pert, rhoX_pert, temp_pert, trac_pert)

                   s(i,j,k,rho_comp) = dens_pert
                   s(i,j,k,rhoh_comp) = rhoh_pert
                   s(i,j,k,temp_comp) = temp_pert
                   s(i,j,k,spec_comp:spec_comp+nspec-1) = rhoX_pert(:)
                   s(i,j,k,trac_comp:trac_comp+ntrac-1) = trac_pert(:)
                enddo
             enddo
          enddo
       endif

    end if
    
  end subroutine initscalardata_3d

  subroutine initveldata (u,s0,p0,dx,prob_lo,prob_hi,bc)

    type(multifab) , intent(inout) :: u
    real(kind=dp_t), intent(in   ) ::    s0(:,:)
    real(kind=dp_t), intent(in   ) ::    p0(:)
    real(kind=dp_t), intent(in   ) :: dx(:)
    real(kind=dp_t), intent(in   ) :: prob_lo(:)
    real(kind=dp_t), intent(in   ) :: prob_hi(:)
    type(bc_level) , intent(in   ) :: bc

    real(kind=dp_t), pointer:: uop(:,:,:,:)
    integer :: lo(u%dim),hi(u%dim),ng,dm
    integer :: i,n
    
    ng = u%ng
    dm = u%dim

    do i = 1, u%nboxes
       if ( multifab_remote(u, i) ) cycle
       uop => dataptr(u, i)
       lo =  lwb(get_box(u, i))
       hi =  upb(get_box(u, i))
       select case (dm)
       case (2)
          call initveldata_2d(uop(:,:,1,:), lo, hi, ng, dx, &
                              prob_lo, prob_hi, s0, p0)
       case (3)
          call initveldata_3d(uop(:,:,:,:), lo, hi, ng, dx, &
                              prob_lo, prob_hi, s0, p0)
       end select
    end do

    call multifab_fill_boundary(u)
    call multifab_physbc(u,1,1,dm,dx,bc)

  end subroutine initveldata

  subroutine initveldata_2d (u,lo,hi,ng,dx, &
                             prob_lo,prob_hi,s0,p0)

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(out) :: u(lo(1)-ng:,lo(2)-ng:,:)  
    real (kind = dp_t), intent(in ) :: dx(:)
    real (kind = dp_t), intent(in ) :: prob_lo(:)
    real (kind = dp_t), intent(in ) :: prob_hi(:)
    real(kind=dp_t), intent(in   ) ::    s0(0:,:)
    real(kind=dp_t), intent(in   ) ::    p0(0:)

    !     Local variables
    integer :: i, j, n
    real(kind=dp_t) :: x,y,r,r0,r1,r2,temp
    real(kind=dp_t) :: dens_pert, rhoh_pert, rhoX_pert(nspec), trac_pert(ntrac)

    ! initial the velocity
    u = ZERO

  end subroutine initveldata_2d

  subroutine initveldata_3d (u,lo,hi,ng,dx, &
                             prob_lo,prob_hi,s0,p0)

    implicit none

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(out) :: u(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)  
    real (kind = dp_t), intent(in ) :: dx(:)
    real (kind = dp_t), intent(in ) :: prob_lo(:)
    real (kind = dp_t), intent(in ) :: prob_hi(:)
    real(kind=dp_t), intent(in   ) ::    s0(0:,:)
    real(kind=dp_t), intent(in   ) ::    p0(0:)

    !     Local variables
    integer :: i, j, k, n
    real(kind=dp_t) :: x,y,z,r,r0,r1,r2,temp
    real(kind=dp_t) :: dens_pert, rhoh_pert, rhoX_pert(nspec), trac_pert(ntrac)

    ! initial the velocity
    u = ZERO
    
  end subroutine initveldata_3d


  subroutine perturb_2d(x, y, p0, s0, dens_pert, rhoh_pert, rhoX_pert, temp_pert, trac_pert)

    ! apply an optional perturbation to the initial temperature field
    ! to see some bubbles

    real(kind=dp_t), intent(in ) :: x, y
    real(kind=dp_t), intent(in ) :: p0, s0(:)
    real(kind=dp_t), intent(out) :: dens_pert, rhoh_pert, temp_pert
    real(kind=dp_t), intent(out) :: rhoX_pert(:)
    real(kind=dp_t), intent(out) :: trac_pert(:)

    real(kind=dp_t) :: temp,t0
    real(kind=dp_t) :: x0, y0, x1, y1, x2, y2
    integer :: i, j
    real(kind=dp_t) :: r0, r1, r2

    t0 = s0(temp_comp)

    x0 = 5.0d7
    y0 = 6.5d7
    
    x1 = 1.2d8
    y1 = 8.5d7
    
    x2 = 2.0d8
    y2 = 7.5d7

    ! Tanh bubbles
    r0 = sqrt( (x-x0)**2 +(y-y0)**2 ) / 2.5e6
    r1 = sqrt( (x-x1)**2 +(y-y1)**2 ) / 2.5e6
    r2 = sqrt( (x-x2)**2 +(y-y2)**2 ) / 2.5e6
    
    ! This case works
    temp = t0 * (ONE + TWO * ( &
         .15_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r0))) + &
         .3_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r1))) + &
         .225_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r2)))  ) )

    ! This case breaks
!   temp = t0 * (ONE + FOUR * ( &
!        .15_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r0))) + &
!        .3_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r1))) + &
!        .225_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r2)))  ) )
          
    ! Use the EOS to make this temperature perturbation occur at constant 
    ! pressure
    temp_eos(1) = temp
    p_eos(1) = p0
    den_eos(1) = s0(rho_comp)
    xn_eos(1,:) = s0(spec_comp:spec_comp+nspec-1)/s0(rho_comp)

    call eos(eos_input_tp, den_eos, temp_eos, &
             npts, nspec, &
             xn_eos, &
             p_eos, h_eos, e_eos, &
             cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
             dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
             dpdX_eos, dhdX_eos, &
             gam1_eos, cs_eos, s_eos, &
             dsdt_eos, dsdr_eos, &
             do_diag)

    dens_pert = den_eos(1)
    rhoh_pert = den_eos(1)*h_eos(1)
    rhoX_pert(:) = dens_pert*xn_eos(1,:)

    temp_pert = temp
    
!   if ( (r0 .lt. 2.0) .or. (r1 .lt. 2.0) .or. (r2 .lt. 2.0) ) then
!     trac_pert(:) = ONE
!   else
      trac_pert(:) = ZERO
!   end if

  end subroutine perturb_2d

  subroutine perturb_3d(x, y, z, p0, s0, dens_pert, rhoh_pert, rhoX_pert, temp_pert, trac_pert)

    ! apply an optional perturbation to the initial temperature field
    ! to see some bubbles

    real(kind=dp_t), intent(in ) :: x, y, z
    real(kind=dp_t), intent(in ) :: p0, s0(:)
    real(kind=dp_t), intent(out) :: dens_pert, rhoh_pert, temp_pert
    real(kind=dp_t), intent(out) :: rhoX_pert(:)
    real(kind=dp_t), intent(out) :: trac_pert(:)

    real(kind=dp_t) :: temp, t0
    real(kind=dp_t) :: x0, y0, z0, x1, y1, z1, x2, y2, z2
    integer :: i, j, k
    real(kind=dp_t) :: r0, r1, r2

    t0 = s0(temp_comp)

    x0 = 5.0d7
    y0 = 5.0d7
    z0 = 6.5d7
    
    x1 = 1.2d8
    y1 = 1.2d8
    z1 = 8.5d7
    
    x2 = 2.0d8
    y2 = 2.0d8
    z2 = 7.5d7

!   temp = t0 * (ONE + TWO * ( &
!        .0625_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r0))) + &
!        .1875_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r1))) + &
!        .1250_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r2)))  ) )

    ! Tanh bubbles from perturb_2d
    r0 = sqrt( (y-y0)**2 +(z-z0)**2 ) / 2.5e6
    r1 = sqrt( (y-y1)**2 +(z-z1)**2 ) / 2.5e6
    r2 = sqrt( (y-y2)**2 +(z-z2)**2 ) / 2.5e6
    
    ! This case works
    temp = t0 * (ONE + TWO * ( &
         .150_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r0))) + &
         .300_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r1))) + &
         .225_dp_t * 0.5_dp_t * (1.0_dp_t + tanh((2.0-r2)))  ) )

    ! Use the EOS to make this temperature perturbation occur at constant 
    ! pressure
    temp_eos(1) = temp
    p_eos(1) = p0
    den_eos(1) = s0(rho_comp)
    xn_eos(1,:) = s0(spec_comp:spec_comp+nspec-1)/s0(rho_comp)

    call eos(eos_input_tp, den_eos, temp_eos, &
             npts, nspec, &
             xn_eos, &
             p_eos, h_eos, e_eos, &
             cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
             dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
             dpdX_eos, dhdX_eos, &
             gam1_eos, cs_eos, s_eos, &
             dsdt_eos, dsdr_eos, &
             do_diag)

    dens_pert = den_eos(1)
    rhoh_pert = den_eos(1)*h_eos(1)
    rhoX_pert(:) = dens_pert*xn_eos(1,:)

    temp_pert = temp
    
!   if (r1 .lt. 2.0) then
!     trac_pert(:) = ONE
!   else
      trac_pert(:) = ZERO
!   end if

  end subroutine perturb_3d

  subroutine scalar_diags (istep,s,s0,p0,dx)

    integer        , intent(in   ) :: istep
    type(multifab) , intent(inout) :: s
    real(kind=dp_t), intent(in)    :: s0(:,:)
    real(kind=dp_t), intent(in)    :: p0(:)
    real(kind=dp_t), intent(in)    :: dx(:)

    real(kind=dp_t), pointer:: sop(:,:,:,:)
    integer :: lo(s%dim),hi(s%dim),ng,dm
    integer :: i,n
    
    ng = s%ng
    dm = s%dim

    do i = 1, s%nboxes
       if ( multifab_remote(s, i) ) cycle
       sop => dataptr(s, i)
       lo =  lwb(get_box(s, i))
       hi =  upb(get_box(s, i))

       select case (dm)
       case (2)
          call scalar_diags_2d(istep, sop(:,:,1,:), lo, hi, ng, dx, s0, p0)
       case (3)
!         call scalar_diags_3d(istep, sop(:,:,:,:), lo, hi, ng, dx, s0)
       end select
    end do

  end subroutine scalar_diags

  subroutine scalar_diags_2d (istep, s,lo,hi,ng,dx,s0,p0)

    integer, intent(in) :: istep, lo(:), hi(:), ng
    real (kind = dp_t), intent(in) ::  s(lo(1)-ng:,lo(2)-ng:,:)
    real (kind = dp_t), intent(in) :: dx(:)
    real(kind=dp_t)   , intent(in) :: s0(0:,:)
    real(kind=dp_t)   , intent(in) :: p0(0:)

    ! Local variables
    integer :: i, j, n
    real(kind=dp_t) :: fac, mass, mass0
    real(kind=dp_t), allocatable ::  rhoavg(:)
    real(kind=dp_t), allocatable :: rhopert(:)
    real(kind=dp_t), allocatable ::    pavg(:)
    character(len=11) :: file_name
    character(len=10) :: file_name2
    character(len= 8) :: file_name3

    allocate(rhopert(lo(2):hi(2)))
    allocate( rhoavg(lo(2):hi(2)))
    allocate(   pavg(lo(2):hi(2)))

    write(unit=file_name ,fmt='("rhopert",i4.4)') istep
    write(unit=file_name2,fmt='("rhoavg",i4.4)') istep
    write(unit=file_name3,fmt='("pavg",i4.4)') istep
    open(90,file=file_name)
    open(91,file=file_name2)
    open(92,file=file_name3)

    fac = ONE / dble(hi(1)-lo(1)+1)
    mass  = ZERO
    mass0 = ZERO
    do j = lo(2), hi(2)
      rhoavg(j) = ZERO
      rhopert(j) = ZERO
      do i = lo(1), hi(1)
         rhopert(j) = rhopert(j) + (s(i,j,rho_comp) - s0(j,rho_comp))
         rhoavg(j) = rhoavg(j) +  s(i,j,rho_comp)
      enddo
      rhoavg(j)  = rhoavg(j) * fac
      rhopert(j)  = rhopert(j) * fac
      write(90,*) (dble(j)+HALF)*dx(2),rhopert(j)
      write(91,*) (dble(j)+HALF)*dx(2),rhoavg(j)
      mass  = mass  + rhoavg(j)
      mass0 = mass0 + s0(j,rho_comp)
    enddo

!   print *,'TOTAL MASS ',istep, mass, mass0

    pavg(hi(2)) = p0(hi(2))
    do j = hi(2)-1,lo(2),-1
      pavg(j) = pavg(j+1) + 0.5d0 * (rhoavg(j+1)+rhoavg(j))*abs(grav_const)*dx(2)
    enddo
    do j = lo(2),hi(2)
      write(92,*) (dble(j)+HALF)*dx(2),p0(j),pavg(j)
    enddo

    deallocate(rhoavg,rhopert,pavg)

  end subroutine scalar_diags_2d


end module init_module
