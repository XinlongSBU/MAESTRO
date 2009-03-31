module rhoh_vs_t_module

  use bl_types
  use multifab_module
  use ml_layout_module
  use define_bc_module

  implicit none

  private

  public :: makeHfromRhoT_edge, makeTfromRhoH, makeTfromRhoP, makePfromRhoH, makeTHfromRhoP
  
contains
  
  subroutine makeHfromRhoT_edge(u,sedge, &
                                rho0_old,rhoh0_old,t0_old, &
                                rho0_edge_old,rhoh0_edge_old,t0_edge_old, &
                                rho0_new,rhoh0_new,t0_new, &
                                rho0_edge_new,rhoh0_edge_new,t0_edge_new, &
                                the_bc_level,dx,mla)

    use bl_prof_module
    use bl_constants_module
    use geometry, only: spherical, nr_fine, dm, nlevs
    use variables
    use network
    use fill_3d_module
    use multifab_physbc_module

    type(multifab) , intent(in   ) :: u(:)
    type(multifab) , intent(inout) :: sedge(:,:)
    real(kind=dp_t), intent(in   ) :: rho0_old(:,0:)
    real(kind=dp_t), intent(in   ) :: rhoh0_old(:,0:)
    real(kind=dp_t), intent(in   ) :: t0_old(:,0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_old(:,0:)
    real(kind=dp_t), intent(in   ) :: rhoh0_edge_old(:,0:)
    real(kind=dp_t), intent(in   ) :: t0_edge_old(:,0:)
    real(kind=dp_t), intent(in   ) :: rho0_new(:,0:)
    real(kind=dp_t), intent(in   ) :: rhoh0_new(:,0:)
    real(kind=dp_t), intent(in   ) :: t0_new(:,0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_new(:,0:)
    real(kind=dp_t), intent(in   ) :: rhoh0_edge_new(:,0:)
    real(kind=dp_t), intent(in   ) :: t0_edge_new(:,0:)
    type(bc_level) , intent(in   ) :: the_bc_level(:)
    real(kind=dp_t), intent(in   ) :: dx(:,:)
    type(ml_layout), intent(in   ) :: mla
    
    ! local
    integer :: i,r,n,ng_u,ng_se,ng_r0,ng_rh0,ng_t0
    integer :: lo(dm),hi(dm)
    real(kind=dp_t), pointer :: sepx(:,:,:,:)
    real(kind=dp_t), pointer :: sepy(:,:,:,:)
    real(kind=dp_t), pointer :: sepz(:,:,:,:)
    real(kind=dp_t), pointer ::   rp(:,:,:,:)
    real(kind=dp_t), pointer ::  rhp(:,:,:,:)
    real(kind=dp_t), pointer ::   tp(:,:,:,:)

    real(kind=dp_t) ::  rho0_halftime(1,0:nr_fine-1)
    real(kind=dp_t) :: rhoh0_halftime(1,0:nr_fine-1)
    real(kind=dp_t) ::    t0_halftime(1,0:nr_fine-1)
    type(multifab)  ::  rho0_cart(nlevs)
    type(multifab)  :: rhoh0_cart(nlevs)
    type(multifab)  ::    t0_cart(nlevs)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "makeHfromRhoT_edge")

    ng_u = u(1)%ng
    ng_se = sedge(1,1)%ng

    if (spherical .eq. 1) then

       do n=1,nlevs
          call multifab_build( rho0_cart(n),u(n)%la,1,2)
          call multifab_build(rhoh0_cart(n),u(n)%la,1,2)
          call multifab_build(   t0_cart(n),u(n)%la,1,2)
       end do

       ng_r0 = rho0_cart(1)%ng
       ng_rh0 = rhoh0_cart(1)%ng
       ng_t0  = t0_cart(1)%ng

       do r=0,nr_fine-1
          rho0_halftime(1,r)  = HALF * (rho0_old(1,r)  + rho0_new(1,r)  )
          rhoh0_halftime(1,r) = HALF * (rhoh0_old(1,r) + rhoh0_new(1,r) )
          t0_halftime(1,r)    = HALF * (t0_old(1,r)    + t0_new(1,r) )
       end do

       call put_1d_array_on_cart(rho0_halftime,rho0_cart,dm+rho_comp,.false.,.false.,dx, &
                                 the_bc_level,mla)
       call put_1d_array_on_cart(rhoh0_halftime,rhoh0_cart,dm+rhoh_comp,.false.,.false.,dx, &
                                 the_bc_level,mla)
       call put_1d_array_on_cart(t0_halftime,t0_cart,dm+temp_comp,.false.,.false.,dx, &
                                 the_bc_level,mla)
   endif

   do n=1,nlevs

       do i=1,u(n)%nboxes
          if ( multifab_remote(u(n),i) ) cycle
          sepx => dataptr(sedge(n,1), i)
          sepy => dataptr(sedge(n,2), i)
          lo = lwb(get_box(u(n),i))
          hi = upb(get_box(u(n),i))
          select case (dm)
          case (2)
             call makeHfromRhoT_edge_2d(sepx(:,:,1,:), sepy(:,:,1,:), ng_se, &
                                        rho0_old(n,:), rhoh0_old(n,:), t0_old(n,:), &
                                        rho0_edge_old(n,:), rhoh0_edge_old(n,:), &
                                        t0_edge_old(n,:), rho0_new(n,:), rhoh0_new(n,:), &
                                        t0_new(n,:), rho0_edge_new(n,:), &
                                        rhoh0_edge_new(n,:), t0_edge_new(n,:), lo, hi)
          case (3)
             sepz => dataptr(sedge(n,3),i)
             if (spherical .eq. 1) then
               rp   => dataptr( rho0_cart(n), i)
               rhp  => dataptr(rhoh0_cart(n), i)
               tp   => dataptr(   t0_cart(n), i)
               call makeHfromRhoT_edge_3d_sphr(sepx(:,:,:,:), sepy(:,:,:,:), sepz(:,:,:,:), &
                                               ng_se, rp(:,:,:,1), ng_r0, rhp(:,:,:,1), &
                                               ng_rh0, tp(:,:,:,1), ng_t0, lo, hi)
             else
               call makeHfromRhoT_edge_3d_cart(sepx(:,:,:,:), sepy(:,:,:,:), sepz(:,:,:,:), &
                                               ng_se, rho0_old(n,:), rhoh0_old(n,:), &
                                               t0_old(n,:), rho0_edge_old(n,:), &
                                               rhoh0_edge_old(n,:), t0_edge_old(n,:), &
                                               rho0_new(n,:), rhoh0_new(n,:), &
                                               t0_new(n,:), rho0_edge_new(n,:), &
                                               rhoh0_edge_new(n,:), t0_edge_new(n,:), &
                                               lo, hi)
             end if
          end select
       end do

    end do

    if (spherical .eq. 1) then
       do n=1,nlevs
          call destroy( rho0_cart(n))
          call destroy(rhoh0_cart(n))
          call destroy(   t0_cart(n))
       end do
    end if

    call destroy(bpt)
    
  end subroutine makeHfromRhoT_edge

  subroutine makeHfromRhoT_edge_2d(sx,sy,ng_se, &
                                   rho0_old,rhoh0_old,t0_old, &
                                   rho0_edge_old,rhoh0_edge_old,t0_edge_old, &
                                   rho0_new,rhoh0_new,t0_new, &
                                   rho0_edge_new,rhoh0_edge_new,t0_edge_new, &
                                   lo,hi)

    use bl_constants_module
    use variables,     only: rho_comp, temp_comp, spec_comp, rhoh_comp
    use eos_module
    use probin_module, only: enthalpy_pred_type, small_temp
    use pred_parameters

    integer        , intent(in   ) :: lo(:),hi(:),ng_se
    real(kind=dp_t), intent(inout) :: sx(lo(1)-ng_se:,lo(2)-ng_se:,:)
    real(kind=dp_t), intent(inout) :: sy(lo(1)-ng_se:,lo(2)-ng_se:,:)
    real(kind=dp_t), intent(in   ) :: rho0_old(0:),rhoh0_old(0:),t0_old(0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_old(0:),rhoh0_edge_old(0:),t0_edge_old(0:)
    real(kind=dp_t), intent(in   ) :: rho0_new(0:),rhoh0_new(0:),t0_new(0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_new(0:),rhoh0_edge_new(0:),t0_edge_new(0:)
 
    integer :: i,j
    real(kind=dp_t) :: t0_edge
    
    do_diag = .false.
    
    do j = lo(2), hi(2)
       do i = lo(1), hi(1)+1
          
          if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
             t0_edge = HALF*(t0_old(j)+t0_new(j))
             temp_eos(1) = max(sx(i,j,temp_comp)+t0_edge,small_temp)
          else
             temp_eos(1) = max(sx(i,j,temp_comp),small_temp)
          end if
          den_eos(1)  = sx(i,j,rho_comp) + HALF * (rho0_old(j) + rho0_new(j))

          ! sx(i,j,spec_comp:spec_comp+nspec-1) holds X
          xn_eos(1,:) = sx(i,j,spec_comp:spec_comp+nspec-1)
          
          call eos(eos_input_rt, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)
          
          if (enthalpy_pred_type .eq. predict_T_then_h .or. &
              enthalpy_pred_type .eq. predict_Tprime_then_h) then
             sx(i,j,rhoh_comp) = h_eos(1)
          else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
             sx(i,j,rhoh_comp) = den_eos(1)*h_eos(1) - HALF*(rhoh0_old(j)+rhoh0_new(j))
          end if
          
       enddo
    enddo
    
    do j = lo(2), hi(2)+1
       do i = lo(1), hi(1)
              
          if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
             t0_edge = HALF*(t0_edge_old(j)+t0_edge_new(j))
             temp_eos(1) = max(sx(i,j,temp_comp)+t0_edge,small_temp)
          else
             temp_eos(1) = max(sy(i,j,temp_comp),small_temp)
          end if
          den_eos(1)  = sy(i,j,rho_comp) + HALF * (rho0_edge_old(j) + rho0_edge_new(j))
          
          ! sy(i,j,spec_comp:spec_comp+nspec-1) holds X
          xn_eos(1,:) = sy(i,j,spec_comp:spec_comp+nspec-1)
          
          call eos(eos_input_rt, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)
          
          if (enthalpy_pred_type .eq. predict_T_then_h .or. &
              enthalpy_pred_type .eq. predict_Tprime_then_h) then
             sy(i,j,rhoh_comp) = h_eos(1) 
          else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
             sy(i,j,rhoh_comp) = den_eos(1)*h_eos(1) &
                  - HALF*(rhoh0_edge_old(j) + rhoh0_edge_new(j))
          end if
          
       enddo
    enddo
    
  end subroutine makeHfromRhoT_edge_2d
  
  subroutine makeHfromRhoT_edge_3d_cart(sx,sy,sz,ng_se, &
                                        rho0_old,rhoh0_old,t0_old, &
                                        rho0_edge_old,rhoh0_edge_old,t0_edge_old, &
                                        rho0_new,rhoh0_new,t0_new, &
                                        rho0_edge_new,rhoh0_edge_new,t0_edge_new, &
                                        lo,hi)

    use variables,     only: rho_comp, temp_comp, spec_comp, rhoh_comp
    use eos_module
    use probin_module, only: enthalpy_pred_type, small_temp
    use pred_parameters
    use bl_constants_module

    integer        , intent(in   ) :: lo(:),hi(:),ng_se
    real(kind=dp_t), intent(inout) :: sx(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(inout) :: sy(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(inout) :: sz(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(in   ) :: rho0_old(0:),rhoh0_old(0:),t0_old(0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_old(0:),rhoh0_edge_old(0:),t0_edge_old(0:)
    real(kind=dp_t), intent(in   ) :: rho0_new(0:),rhoh0_new(0:),t0_new(0:)
    real(kind=dp_t), intent(in   ) :: rho0_edge_new(0:),rhoh0_edge_new(0:),t0_edge_new(0:)
    
    integer         :: i,j,k
    real(kind=dp_t) :: t0_edge
    
    do_diag = .false.
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)+1
              
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF*(t0_old(k)+t0_new(k))
                temp_eos(1) = max(sx(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sx(i,j,k,temp_comp),small_temp)
             end if
             den_eos(1) = sx(i,j,k,rho_comp) + HALF * (rho0_old(k) + rho0_new(k))

             ! sx(i,j,k,spec_comp:spec_comp+nspec-1) holds X
             xn_eos(1,:) = sx(i,j,k,spec_comp:spec_comp+nspec-1)
             
             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sx(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                sx(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1) - HALF*(rhoh0_old(k)+rhoh0_new(k))
             end if
             
          enddo
       enddo
    enddo
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)+1
          do i = lo(1), hi(1)
             
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF*(t0_old(k)+t0_new(k))
                temp_eos(1) = max(sx(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sy(i,j,k,temp_comp),small_temp)
             end if
             den_eos(1)  = sy(i,j,k,rho_comp) + HALF * (rho0_old(k) + rho0_new(k))

             ! sy(i,j,k,spec_comp:spec_comp+nspec-1) holds X
             xn_eos(1,:) = sy(i,j,k,spec_comp:spec_comp+nspec-1)
             
             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sy(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                sy(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1) - HALF*(rhoh0_old(k)+rhoh0_new(k))
             end if

          enddo
       enddo
    enddo

    do k = lo(3), hi(3)+1
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF*(t0_edge_old(k)+t0_edge_new(k))
                temp_eos(1) = max(sx(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sz(i,j,k,temp_comp),small_temp)
             end if
             den_eos(1) = sz(i,j,k,rho_comp) + HALF * (rho0_edge_old(k) + rho0_edge_new(k))

             ! sz(i,j,k,spec_comp:spec_comp+nspec-1) X
             xn_eos(1,:) = sz(i,j,k,spec_comp:spec_comp+nspec-1)

             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sz(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                sz(i,j,k,rhoh_comp) =  den_eos(1)*h_eos(1) &
                     - HALF*(rhoh0_edge_old(k)+rhoh0_edge_new(k))
             end if
             
          enddo
       enddo
    enddo
    
  end subroutine makeHfromRhoT_edge_3d_cart

  subroutine makeHfromRhoT_edge_3d_sphr(sx,sy,sz,ng_se,rho0_cart,ng_r0,rhoh0_cart,ng_rh0, &
                                        t0_cart,ng_t0,lo,hi)

    use variables,     only: rho_comp, temp_comp, spec_comp, rhoh_comp
    use geometry,      only: spherical
    use eos_module
    use probin_module, only: enthalpy_pred_type, small_temp
    use pred_parameters
    use bl_constants_module

    integer        , intent(in   ) :: ng_se,ng_r0,ng_rh0,ng_t0
    integer        , intent(in   ) :: lo(:),hi(:)
    real(kind=dp_t), intent(inout) :: sx(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(inout) :: sy(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(inout) :: sz(lo(1)-ng_se:,lo(2)-ng_se:,lo(3)-ng_se:,:)
    real(kind=dp_t), intent(in   ) ::  rho0_cart(lo(1)-ng_r0:,lo(2)-ng_r0:,lo(3)-ng_r0:)
    real(kind=dp_t), intent(in   ) :: rhoh0_cart(lo(1)-ng_rh0:,lo(2)-ng_rh0:,lo(3)-ng_rh0:)
    real(kind=dp_t), intent(in   ) ::    t0_cart(lo(1)-ng_t0 :,lo(2)-ng_t0 :,lo(3)-ng_t0 :)
    
    ! Local variables
    integer :: i, j, k
    real(kind=dp_t) rho0_edge, rhoh0_edge, t0_edge
    
    do_diag = .false.

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)+1
             
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF* (t0_cart(i-1,j,k) + t0_cart(i,j,k))
                temp_eos(1) = max(sx(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sx(i,j,k,temp_comp),small_temp)
             end if

             rho0_edge = HALF * (rho0_cart(i-1,j,k) + rho0_cart(i,j,k))
             den_eos(1) = sx(i,j,k,rho_comp) + rho0_edge

             ! sx(i,j,k,spec_comp:spec_comp+nspec-1) holds X
             xn_eos(1,:) = sx(i,j,k,spec_comp:spec_comp+nspec-1)

             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sx(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                rhoh0_edge = HALF * (rhoh0_cart(i-1,j,k) + rhoh0_cart(i,j,k))
                sx(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1) - rhoh0_edge
             end if

          enddo
       enddo
    enddo

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)+1
          do i = lo(1), hi(1)
             
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF * (t0_cart(i,j-1,k) + t0_cart(i,j,k))
                temp_eos(1) = max(sy(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sy(i,j,k,temp_comp),small_temp)
             end if

             rho0_edge = HALF * (rho0_cart(i,j-1,k) + rho0_cart(i,j,k))
             den_eos(1) = sy(i,j,k,rho_comp) + rho0_edge

             ! sy(i,j,k,spec_comp:spec_comp+nspec-1) holds X
             xn_eos(1,:) = sy(i,j,k,spec_comp:spec_comp+nspec-1) 

             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sy(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                rhoh0_edge = HALF * (rhoh0_cart(i,j-1,k) + rhoh0_cart(i,j,k))
                sy(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1) - rhoh0_edge
             end if
             
          enddo
       enddo
    enddo

    do k = lo(3), hi(3)+1
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
                 
             if (enthalpy_pred_type .eq. predict_Tprime_then_h) then
                t0_edge = HALF * (t0_cart(i,j,k-1) + t0_cart(i,j,k))
                temp_eos(1) = max(sz(i,j,k,temp_comp)+t0_edge,small_temp)
             else
                temp_eos(1) = max(sz(i,j,k,temp_comp),small_temp)
             end if

             rho0_edge = HALF * (rho0_cart(i,j,k-1) + rho0_cart(i,j,k))             
             den_eos(1) = sz(i,j,k,rho_comp) + rho0_edge
             
             ! sz(i,j,k,spec_comp:spec_comp+nspec-1) holds X
             xn_eos(1,:) = sz(i,j,k,spec_comp:spec_comp+nspec-1) 

             call eos(eos_input_rt, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             if (enthalpy_pred_type .eq. predict_T_then_h .or. &
                 enthalpy_pred_type .eq. predict_Tprime_then_h) then
                sz(i,j,k,rhoh_comp) = h_eos(1)
             else if (enthalpy_pred_type .eq. predict_T_then_rhohprime) then
                rhoh0_edge = HALF * (rhoh0_cart(i,j,k-1) + rhoh0_cart(i,j,k))
                sz(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1) - rhoh0_edge
             end if
             
          enddo
       enddo
    enddo
    
  end subroutine makeHfromRhoT_edge_3d_sphr
  
  subroutine makeTfromRhoH(s,tempbar,mla,the_bc_level,dx)

    use variables,             only: temp_comp
    use bl_prof_module
    use ml_restriction_module, only: ml_cc_restriction_c
    use multifab_physbc_module
    use multifab_fill_ghost_module
    use geometry, only: dm, nlevs, spherical

    type(multifab)    , intent(inout) :: s(:)
    real (kind = dp_t), intent(in   ) :: tempbar(:,0:)
    type(ml_layout)   , intent(in   ) :: mla
    type(bc_level)    , intent(in   ) :: the_bc_level(:)
    real(kind=dp_t)   , intent(in   ) :: dx(:,:)

    ! local
    integer                  :: i,ng,n
    integer                  :: lo(dm),hi(dm)
    real(kind=dp_t), pointer :: snp(:,:,:,:)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "makeTfromRhoH")

    ng = s(1)%ng

    do n=1,nlevs

       do i=1,s(n)%nboxes
          if (multifab_remote(s(n),i)) cycle
          snp => dataptr(s(n),i)
          lo = lwb(get_box(s(n),i))
          hi = upb(get_box(s(n),i))
          select case (dm)
          case (2)
             call makeTfromRhoH_2d(snp(:,:,1,:), lo, hi, ng, tempbar(n,:))
          case (3)
             if (spherical .eq. 1) then
                call makeTfromRhoH_3d_sphr(snp(:,:,:,:), lo, hi, ng, tempbar(1,:), dx(n,:))
             else
                call makeTfromRhoH_3d(snp(:,:,:,:), lo, hi, ng, tempbar(n,:))
             end if
          end select
       end do

    end do

    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary_c(s(nlevs),temp_comp,1)

       ! fill non-periodic domain boundary ghost cells
       call multifab_physbc(s(nlevs),temp_comp,dm+temp_comp,1,the_bc_level(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the finer grids are done first
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n data covering it
          call ml_cc_restriction_c(s(n-1),temp_comp,s(n),temp_comp,mla%mba%rr(n-1,:),1)

          ! fill level n ghost cells using interpolation from level n-1 data
          ! note that multifab_fill_boundary and multifab_physbc are called for
          ! both levels n-1 and n
          call multifab_fill_ghost_cells(s(n),s(n-1),ng,mla%mba%rr(n-1,:), &
                                         the_bc_level(n-1),the_bc_level(n  ), &
                                         temp_comp,dm+temp_comp,1,fill_crse_input=.false.)
       enddo

    end if

    call destroy(bpt)

  end subroutine makeTfromRhoH

  subroutine makeTfromRhoH_2d(state,lo,hi,ng,tempbar)

    use variables, only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)
    
    ! Local variables
    integer :: i, j
    
    do_diag = .false.

    do j = lo(2), hi(2)
       do i = lo(1), hi(1)

          ! (rho, H) --> T, p
          
          den_eos(1)  = state(i,j,rho_comp)
          temp_eos(1) = tempbar(j)
          xn_eos(1,:) = state(i,j,spec_comp:spec_comp+nspec-1)/den_eos(1)
          
          h_eos(1) = state(i,j,rhoh_comp) / state(i,j,rho_comp)
          
          call eos(eos_input_rh, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)
          
          state(i,j,temp_comp) = temp_eos(1)
          
       enddo
    enddo
    
  end subroutine makeTfromRhoH_2d

  subroutine makeTfromRhoH_3d(state,lo,hi,ng,tempbar)

    use variables,      only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)

    ! Local variables
    integer :: i, j, k

    do_diag = .false.
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, H) --> T, p
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar(k)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             h_eos(1) = state(i,j,k,rhoh_comp) / state(i,j,k,rho_comp)
             
             call eos(eos_input_rh, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             state(i,j,k,temp_comp) = temp_eos(1)
             
          enddo
       enddo
    enddo

  end subroutine makeTfromRhoH_3d

  subroutine makeTfromRhoH_3d_sphr(state,lo,hi,ng,tempbar,dx)

    use variables,      only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)
    real(kind=dp_t)   , intent(in   ) :: dx(:)

    ! Local variables
    integer :: i, j, k
    real(kind=dp_t), allocatable :: tempbar_cart(:,:,:,:)

    allocate(tempbar_cart(lo(1):hi(1),lo(2):hi(2),lo(3):hi(3),1))
    call put_1d_array_on_cart_3d_sphr(.false.,.false.,tempbar,tempbar_cart,lo,hi,dx,0,0)

    do_diag = .false.
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, H) --> T, p
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar_cart(i,j,k,1)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             h_eos(1) = state(i,j,k,rhoh_comp) / state(i,j,k,rho_comp)
             
             call eos(eos_input_rh, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             state(i,j,k,temp_comp) = temp_eos(1)
             
          enddo
       enddo
    enddo

    deallocate(tempbar_cart)

  end subroutine makeTfromRhoH_3d_sphr

  subroutine makeTfromRhoP(s,p0,tempbar,mla,the_bc_level,dx)

    use variables,             only: temp_comp
    use bl_prof_module
    use ml_restriction_module, only: ml_cc_restriction_c
    use multifab_physbc_module
    use multifab_fill_ghost_module
    use geometry, only: dm, nlevs, spherical

    type(multifab)    , intent(inout) :: s(:)
    real (kind = dp_t), intent(in   ) :: p0(:,0:)
    real (kind = dp_t), intent(in   ) :: tempbar(:,0:)
    type(ml_layout)   , intent(in   ) :: mla
    type(bc_level)    , intent(in   ) :: the_bc_level(:)
    real(kind=dp_t)   , intent(in   ) :: dx(:,:)

    ! local
    integer                  :: i,ng,n
    integer                  :: lo(dm),hi(dm)
    real(kind=dp_t), pointer :: snp(:,:,:,:)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "makeTfromRhoP")

    ng = s(1)%ng

    do n=1,nlevs

       do i=1,s(n)%nboxes
          if (multifab_remote(s(n),i)) cycle
          snp => dataptr(s(n),i)
          lo = lwb(get_box(s(n),i))
          hi = upb(get_box(s(n),i))
          select case (dm)
          case (2)
             call makeTfromRhoP_2d(snp(:,:,1,:),lo,hi,ng,p0(n,:),tempbar(n,:))
          case (3)
             if (spherical .eq. 1) then
                call makeTfromRhoP_3d_sphr(snp(:,:,:,:),lo,hi,ng,p0(1,:),tempbar(1,:), &
                                           dx(n,:))
             else
                call makeTfromRhoP_3d(snp(:,:,:,:),lo,hi,ng,p0(n,:),tempbar(n,:))
             end if
          end select
       end do

    end do

    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary_c(s(nlevs),temp_comp,1)

       ! fill non-periodic domain boundary ghost cells
       call multifab_physbc(s(nlevs),temp_comp,dm+temp_comp,1,the_bc_level(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the finer grids are done first
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n data covering it
          call ml_cc_restriction_c(s(n-1),temp_comp,s(n),temp_comp,mla%mba%rr(n-1,:),1)

          ! fill level n ghost cells using interpolation from level n-1 data
          ! note that multifab_fill_boundary and multifab_physbc are called for
          ! both levels n-1 and n
          call multifab_fill_ghost_cells(s(n),s(n-1),ng,mla%mba%rr(n-1,:), &
                                         the_bc_level(n-1),the_bc_level(n  ), &
                                         temp_comp,dm+temp_comp,1,fill_crse_input=.false.)
       enddo

    end if

    call destroy(bpt)

  end subroutine makeTfromRhoP

  subroutine makeTfromRhoP_2d(state,lo,hi,ng,p0,tempbar)

    use variables,     only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  p0(0:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)
    
    ! Local variables
    integer :: i, j
    
    do_diag = .false.

    do j = lo(2), hi(2)
       do i = lo(1), hi(1)
          
          ! (rho, p) --> T
          
          den_eos(1)  = state(i,j,rho_comp)
          temp_eos(1) = tempbar(j)
          xn_eos(1,:) = state(i,j,spec_comp:spec_comp+nspec-1)/den_eos(1)
          
          p_eos(1) = p0(j)
          
          call eos(eos_input_rp, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)
          
          state(i,j,temp_comp) = temp_eos(1)
          
       enddo
    enddo
    
  end subroutine makeTfromRhoP_2d

  subroutine makeTfromRhoP_3d(state,lo,hi,ng,p0,tempbar)

    use variables,      only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  p0(0:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)

    ! Local variables
    integer :: i, j, k

    do_diag = .false.

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, p) --> T
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar(k)
             p_eos(1) = p0(k)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             
             call eos(eos_input_rp, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             state(i,j,k,temp_comp) = temp_eos(1)
             
          enddo
       enddo
    enddo
    
  end subroutine makeTfromRhoP_3d

  subroutine makeTfromRhoP_3d_sphr(state,lo,hi,ng,p0,tempbar,dx)

    use variables,      only: rho_comp, spec_comp, rhoh_comp, temp_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng
    real (kind = dp_t), intent(inout) ::  state(lo(1)-ng:,lo(2)-ng:,lo(3)-ng:,:)
    real (kind = dp_t), intent(in   ) ::  p0(0:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)
    real(kind=dp_t)   , intent(in   ) :: dx(:)

    ! Local variables
    integer :: i, j, k
    real(kind=dp_t), allocatable :: p0_cart(:,:,:,:)
    real(kind=dp_t), allocatable :: tempbar_cart(:,:,:,:)

    allocate(tempbar_cart(lo(1):hi(1),lo(2):hi(2),lo(3):hi(3),1))
    call put_1d_array_on_cart_3d_sphr(.false.,.false.,tempbar,tempbar_cart,lo,hi,dx,0,0)

    allocate(p0_cart(lo(1):hi(1),lo(2):hi(2),lo(3):hi(3),1))
    call put_1d_array_on_cart_3d_sphr(.false.,.false.,p0,p0_cart,lo,hi,dx,0,0)

    do_diag = .false.

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, p) --> T
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar_cart(i,j,k,1)
             p_eos(1) = p0_cart(i,j,k,1)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             
             call eos(eos_input_rp, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             state(i,j,k,temp_comp) = temp_eos(1)
             
          enddo
       enddo
    enddo
    
    deallocate(tempbar_cart)
    deallocate(p0_cart)

  end subroutine makeTfromRhoP_3d_sphr

  subroutine makePfromRhoH(s,p,tempbar,mla,the_bc_level,dx)

    use variables,             only: foextrap_comp
    use bl_prof_module
    use ml_restriction_module, only: ml_cc_restriction_c
    use multifab_physbc_module
    use multifab_fill_ghost_module
    use geometry, only: dm, nlevs, spherical

    type(multifab)    , intent(in   ) :: s(:)
    type(multifab)    , intent(inout) :: p(:)
    real (kind = dp_t), intent(in   ) :: tempbar(:,0:)
    type(ml_layout)   , intent(inout) :: mla
    type(bc_level)    , intent(in   ) :: the_bc_level(:)
    real(kind=dp_t)   , intent(in   ) :: dx(:,:)

    ! local
    integer                  :: i,ng_s,ng_p,n
    integer                  :: lo(dm),hi(dm)
    real(kind=dp_t), pointer :: snp(:,:,:,:)
    real(kind=dp_t), pointer :: pnp(:,:,:,:)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "makePfromRhoH")

    ng_s = s(1)%ng
    ng_p = p(1)%ng

    do n=1,nlevs

       do i=1,s(n)%nboxes
          if (multifab_remote(s(n),i)) cycle
          snp => dataptr(s(n),i)
          pnp => dataptr(p(n),i)
          lo = lwb(get_box(s(n),i))
          hi = upb(get_box(s(n),i))
          select case (dm)
          case (2)
             call makePfromRhoH_2d(snp(:,:,1,:), pnp(:,:,1,1), lo, hi, ng_s, ng_p, &
                                   tempbar(n,:))
          case (3)
             if (spherical .eq. 1) then
                call makePfromRhoH_3d_sphr(snp(:,:,:,:), pnp(:,:,:,1), lo, hi, ng_s, ng_p, &
                                           tempbar(1,:), dx(n,:))
             else
                call makePfromRhoH_3d(snp(:,:,:,:), pnp(:,:,:,1), lo, hi, ng_s, ng_p, &
                                      tempbar(n,:))
             end if
          end select
       end do

    end do

    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary_c(p(nlevs),1,1)

       ! fill non-periodic domain boundary ghost cells
       call multifab_physbc(p(nlevs),1,foextrap_comp,1,the_bc_level(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the finer grids are done first
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n data covering it
          call ml_cc_restriction_c(p(n-1),1,p(n),1,mla%mba%rr(n-1,:),1)

          ! fill level n ghost cells using interpolation from level n-1 data
          ! note that multifab_fill_boundary and multifab_physbc are called for
          ! both levels n-1 and n
          call multifab_fill_ghost_cells(p(n),p(n-1),ng_p,mla%mba%rr(n-1,:), &
                                         the_bc_level(n-1),the_bc_level(n),1, &
                                         foextrap_comp,1,fill_crse_input=.false.)
       enddo

    end if

    call destroy(bpt)

  end subroutine makePfromRhoH

  subroutine makePfromRhoH_2d(state,p,lo,hi,ng_s,ng_p,tempbar)

    use variables,     only: rho_comp, spec_comp, rhoh_comp
    use eos_module

    integer, intent(in) :: lo(:), hi(:), ng_s, ng_p
    real (kind = dp_t), intent(in   ) :: state(lo(1)-ng_s:,lo(2)-ng_s:,:)
    real (kind = dp_t), intent(inout) ::     p(lo(1)-ng_p:,lo(2)-ng_p:)
    real (kind = dp_t), intent(in   ) ::  tempbar(0:)
    
    ! Local variables
    integer :: i, j
    
    do_diag = .false.

    do j = lo(2), hi(2)
       do i = lo(1), hi(1)

          ! (rho, H) --> T, p
          
          den_eos(1)  = state(i,j,rho_comp)
          temp_eos(1) = tempbar(j)
          xn_eos(1,:) = state(i,j,spec_comp:spec_comp+nspec-1)/den_eos(1)

          h_eos(1) = state(i,j,rhoh_comp) / state(i,j,rho_comp)

          call eos(eos_input_rh, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)

          p(i,j) = p_eos(1)

       enddo
    enddo

  end subroutine makePfromRhoH_2d

  subroutine makePfromRhoH_3d(state,p,lo,hi,ng_s,ng_p,tempbar)

    use variables,      only: rho_comp, spec_comp, rhoh_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng_s, ng_p
    real (kind = dp_t), intent(in   ) :: state(lo(1)-ng_s:,lo(2)-ng_s:,lo(3)-ng_s:,:)
    real (kind = dp_t), intent(inout) ::     p(lo(1)-ng_p:,lo(2)-ng_p:,lo(3)-ng_p:)
    real (kind = dp_t), intent(in   ) :: tempbar(0:)

    ! Local variables
    integer :: i, j, k

    do_diag = .false.
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, H) --> T, p
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar(k)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             h_eos(1) = state(i,j,k,rhoh_comp) / state(i,j,k,rho_comp)
             
             call eos(eos_input_rh, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             p(i,j,k) = p_eos(1)
             
          enddo
       enddo
    enddo

  end subroutine makePfromRhoH_3d

  subroutine makePfromRhoH_3d_sphr(state,p,lo,hi,ng_s,ng_p,tempbar,dx)

    use variables,      only: rho_comp, spec_comp, rhoh_comp
    use eos_module
    use fill_3d_module

    integer, intent(in) :: lo(:), hi(:), ng_s, ng_p
    real (kind = dp_t), intent(in   ) :: state(lo(1)-ng_s:,lo(2)-ng_s:,lo(3)-ng_s:,:)
    real (kind = dp_t), intent(inout) ::     p(lo(1)-ng_p:,lo(2)-ng_p:,lo(3)-ng_p:)
    real (kind = dp_t), intent(in   ) :: tempbar(0:)
    real(kind=dp_t)   , intent(in   ) :: dx(:)

    ! Local variables
    integer :: i, j, k
    real(kind=dp_t), allocatable :: tempbar_cart(:,:,:,:)

    allocate(tempbar_cart(lo(1):hi(1),lo(2):hi(2),lo(3):hi(3),1))
    call put_1d_array_on_cart_3d_sphr(.false.,.false.,tempbar,tempbar_cart,lo,hi,dx,0,0)

    do_diag = .false.
    
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)
             
             ! (rho, H) --> T, p
             
             den_eos(1)  = state(i,j,k,rho_comp)
             temp_eos(1) = tempbar_cart(i,j,k,1)
             xn_eos(1,:) = state(i,j,k,spec_comp:spec_comp+nspec-1)/den_eos(1)
             h_eos(1) = state(i,j,k,rhoh_comp) / state(i,j,k,rho_comp)
             
             call eos(eos_input_rh, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             p(i,j,k) = p_eos(1)
             
          enddo
       enddo
    enddo

    deallocate(tempbar_cart)

  end subroutine makePfromRhoH_3d_sphr

  subroutine makeTHfromRhoP(s,p0,bc,mla,dx)

    use multifab_module
    use ml_layout_module
    use define_bc_module
    use ml_restriction_module
    use multifab_fill_ghost_module
    use variables, only: rhoh_comp, temp_comp
    use multifab_physbc_module
    use geometry, only: dm, nlevs, spherical

    type(multifab) , intent(inout) :: s(:)
    real(kind=dp_t), intent(in   ) :: p0(:,0:)
    type(bc_level) , intent(in   ) :: bc(:)
    type(ml_layout), intent(inout) :: mla
    real(kind=dp_t), intent(in   ) :: dx(:,:)
    
    ! local
    real(kind=dp_t), pointer :: sop(:,:,:,:)
    integer                  :: i,n,ng_s
    integer                  :: lo(dm),hi(dm)

    type(bl_prof_timer), save :: bpt

    call build(bpt, "makeTHfromRhoP")

    ng_s = s(1)%ng

    do n=1,nlevs
       do i = 1, s(n)%nboxes
          if ( multifab_remote(s(n),i) ) cycle
          sop => dataptr(s(n),i)
          lo =  lwb(get_box(s(n),i))
          hi =  upb(get_box(s(n),i))
          select case (dm)
          case (2)
             call makeTHfromRhoP_2d(sop(:,:,1,:), ng_s, lo, hi, p0(n,:))
          case (3)
             if (spherical .eq. 1) then
                call makeTHfromRhoP_3d_sphr(sop(:,:,:,:), ng_s, lo, hi, p0(1,:), dx(n,:))
             else
                call makeTHfromRhoP_3d(sop(:,:,:,:), ng_s, lo, hi, p0(n,:))
             end if
          end select
       end do
    enddo

    if (nlevs .eq. 1) then

       ! fill ghost cells for two adjacent grids at the same level
       ! this includes periodic domain boundary ghost cells
       call multifab_fill_boundary_c(s(nlevs),rhoh_comp,1)
       call multifab_fill_boundary_c(s(nlevs),temp_comp,1)

       ! fill non-periodic domain boundary ghost cells
       call multifab_physbc(s(nlevs),rhoh_comp,dm+rhoh_comp,1,bc(nlevs))
       call multifab_physbc(s(nlevs),temp_comp,dm+temp_comp,1,bc(nlevs))

    else

       ! the loop over nlevs must count backwards to make sure the finer grids are done first
       do n=nlevs,2,-1

          ! set level n-1 data to be the average of the level n data covering it
          call ml_cc_restriction_c(s(n-1),rhoh_comp,s(n),rhoh_comp,mla%mba%rr(n-1,:))
          call ml_cc_restriction_c(s(n-1),temp_comp,s(n),temp_comp,mla%mba%rr(n-1,:))

          ! fill level n ghost cells using interpolation from level n-1 data
          ! note that multifab_fill_boundary and multifab_physbc are called for
          ! both levels n-1 and n
          call multifab_fill_ghost_cells(s(n),s(n-1),ng_s,mla%mba%rr(n-1,:), &
                                         bc(n-1),bc(n),1,dm+rhoh_comp,1, &
                                         fill_crse_input=.false.)
          call multifab_fill_ghost_cells(s(n),s(n-1),ng_s,mla%mba%rr(n-1,:), &
                                         bc(n-1),bc(n),1,dm+temp_comp,1, &
                                         fill_crse_input=.false.)

       enddo

    end if

    call destroy(bpt)

  end subroutine makeTHfromRhoP

  subroutine makeTHfromRhoP_2d(s,ng_s,lo,hi,p0)

    use eos_module
    use network
    use variables

    integer           , intent(in   ) :: lo(:),hi(:),ng_s
    real (kind = dp_t), intent(inout) :: s(lo(1)-ng_s:,lo(2)-ng_s:,:)  
    real(kind=dp_t)   , intent(in   ) :: p0(0:)

    ! local
    integer    :: i,j

    do j=lo(2),hi(2)
       do i=lo(1),hi(1)

          den_eos(1) = s(i,j,rho_comp)
          xn_eos(1,:) = s(i,j,spec_comp:spec_comp+nspec-1)/s(i,j,rho_comp)
          temp_eos(1) = s(i,j,temp_comp)
          p_eos(1) = p0(j)

          call eos(eos_input_rp, den_eos, temp_eos, &
                   npts, nspec, &
                   xn_eos, &
                   p_eos, h_eos, e_eos, &
                   cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                   dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                   dpdX_eos, dhdX_eos, &
                   gam1_eos, cs_eos, s_eos, &
                   dsdt_eos, dsdr_eos, &
                   do_diag)

          s(i,j,rhoh_comp) = den_eos(1)*h_eos(1)
          s(i,j,temp_comp) = temp_eos(1)

       end do
    end do

  end subroutine makeTHfromRhoP_2d
  
  subroutine makeTHfromRhoP_3d(s,ng_s,lo,hi,p0)

    use eos_module
    use network
    use variables

    integer           , intent(in   ) :: lo(:),hi(:),ng_s
    real (kind = dp_t), intent(inout) :: s(lo(1)-ng_s:,lo(2)-ng_s:,lo(3)-ng_s:,:)  
    real(kind=dp_t)   , intent(in   ) :: p0(0:)

    ! local
    integer    :: i,j,k

    do k=lo(3),hi(3)
       do j=lo(2),hi(2)
          do i=lo(1),hi(1)
             
             den_eos(1) = s(i,j,k,rho_comp)
             xn_eos(1,:) = s(i,j,k,spec_comp:spec_comp+nspec-1)/s(i,j,K,rho_comp)
             temp_eos(1) = s(i,j,k,temp_comp)
             p_eos(1) = p0(k)
             
             call eos(eos_input_rp, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             s(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1)
             s(i,j,k,temp_comp) = temp_eos(1)
             
          end do
       end do
    end do

  end subroutine makeTHfromRhoP_3d

  subroutine makeTHfromRhoP_3d_sphr(s,ng_s,lo,hi,p0,dx)

    use eos_module
    use network
    use variables
    use fill_3d_module

    integer           , intent(in   ) :: lo(:),hi(:),ng_s
    real (kind = dp_t), intent(inout) :: s(lo(1)-ng_s:,lo(2)-ng_s:,lo(3)-ng_s:,:)
    real(kind=dp_t)   , intent(in   ) :: p0(0:)
    real(kind=dp_t)   , intent(in   ) :: dx(:)

    ! local
    integer    :: i,j,k
    real(kind=dp_t), allocatable :: p0_cart(:,:,:,:)

    allocate(p0_cart(lo(1):hi(1),lo(2):hi(2),lo(3):hi(3),1))
    call put_1d_array_on_cart_3d_sphr(.false.,.false.,p0,p0_cart,lo,hi,dx,0,0)

    do k=lo(3),hi(3)
       do j=lo(2),hi(2)
          do i=lo(1),hi(1)
             
             den_eos(1) = s(i,j,k,rho_comp)
             xn_eos(1,:) = s(i,j,k,spec_comp:spec_comp+nspec-1)/s(i,j,K,rho_comp)
             temp_eos(1) = s(i,j,k,temp_comp)
             p_eos(1) = p0_cart(i,j,k,1)
             
             call eos(eos_input_rp, den_eos, temp_eos, &
                      npts, nspec, &
                      xn_eos, &
                      p_eos, h_eos, e_eos, &
                      cv_eos, cp_eos, xne_eos, eta_eos, pele_eos, &
                      dpdt_eos, dpdr_eos, dedt_eos, dedr_eos, &
                      dpdX_eos, dhdX_eos, &
                      gam1_eos, cs_eos, s_eos, &
                      dsdt_eos, dsdr_eos, &
                      do_diag)
             
             s(i,j,k,rhoh_comp) = den_eos(1)*h_eos(1)
             s(i,j,k,temp_comp) = temp_eos(1)
             
          end do
       end do
    end do

    deallocate(p0_cart)

  end subroutine makeTHfromRhoP_3d_sphr

end module rhoh_vs_t_module
