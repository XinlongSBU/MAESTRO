module react_base_module
  ! 
  ! This is React Base from paper III.
  ! 
  use bl_types

  implicit none
  
  private

  public :: react_base
  
contains
  
  subroutine react_base(nlevs,rhoh0_in,rho_omegadotbar,rho_Hextbar,halfdt_in,rhoh0_out)

    use geometry, only: r_start_coord, r_end_coord, numdisjointchunks
    use network, only: nspec
    use eos_module, only: ebin
    use variables, only: rho_comp, spec_comp, rhoh_comp
    use bl_prof_module
    use restrict_base_module
     
    integer        , intent(in   ) :: nlevs
    real(kind=dp_t), intent(in   ) :: rhoh0_in(:,0:)
    real(kind=dp_t), intent(in   ) :: rho_omegadotbar(:,0:,:)
    real(kind=dp_t), intent(in   ) :: rho_Hextbar(:,0:)
    real(kind=dp_t), intent(in   ) :: halfdt_in
    real(kind=dp_t), intent(  out) :: rhoh0_out(:,0:)
    
    integer :: n,r,comp,i

    type(bl_prof_timer), save :: bpt

    call build(bpt, "react_base")
    
    do n=1,nlevs
       do i=1,numdisjointchunks(n)
          do r=r_start_coord(n,i),r_end_coord(n,i)
             
             ! update enthalpy
             rhoh0_out(n,r) = rhoh0_in(n,r)
             do comp = spec_comp,spec_comp+nspec-1
                rhoh0_out(n,r) = rhoh0_out(n,r) &
                     -halfdt_in*rho_omegadotbar(n,r,comp-spec_comp+1)*ebin(comp-spec_comp+1)
             end do
             rhoh0_out(n,r) = rhoh0_out(n,r) + halfdt_in * rho_Hextbar(n,r)
             
          end do
       end do
    enddo ! end loop over levels

    call restrict_base(nlevs,rhoh0_out,.true.)
    call fill_ghost_base(nlevs,rhoh0_out,.true.)

    call destroy(bpt)

  end subroutine react_base

end module react_base_module
