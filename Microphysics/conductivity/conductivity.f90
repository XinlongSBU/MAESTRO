module conductivity_module
  ! the general interface to thermal conductivities

  use bl_types

  implicit none

  logical, save :: initialized = .false.

contains

  ! do any conductivity initialization (e.g. table reading, ...)

  subroutine conductivity_init()

    use actual_conductivity_module, only : actual_conductivity_init

    implicit none

    call actual_conductivity_init()

    initialized = .true.

  end subroutine conductivity_init


  ! a generic wrapper that calls the EOS and then the conductivity

  subroutine conducteos(input, state)

    use actual_conductivity_module
    use eos_type_module, only : eos_t
    use eos_module

    implicit none

    integer         , intent(in   ) :: input
    type (eos_t)    , intent(inout) :: state

    ! call the EOS, passing through the arguments we called conducteos with
    call eos(input, state)

    call actual_conductivity(state)

  end subroutine conducteos

end module conductivity_module
