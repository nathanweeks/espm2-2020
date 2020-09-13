program teams_new_index
  !! author: Nathan Weeks
  !!
  !! Test FORM TEAM NEW_INDEX= specifier
  use iso_fortran_env, only : team_type
  use oc_assertions_interface, only : assert
  implicit none

  integer :: new_index
  type(team_type) :: team

  new_index = merge(num_images(), this_image()-1, this_image() == 1)

  form team (1, team, new_index=new_index)
  change team(team)
    call assert( this_image() == new_index, "this_image() /= new_index" )
  end team

  sync all

  if (this_image() == 1) print *,"Test passed."

end program
