program monte_carlo_pi
  use iso_fortran_env, only : team_type, STAT_FAILED_IMAGE
  implicit none
  integer, parameter :: NFAIL=2, NSAMPLES=10**6
  integer :: sample, status, n_copy, n = 0
  type(team_type) :: team_active_images
  logical :: fail
  double precision :: x, y
  ! gfortran 9.x doesn't support NUM_IMAGES([TEAM])
  integer :: num_images_initial_team, image_index_in_active_team
  
  call random_init(repeatable=.true., image_distinct=.true.)
  
  do sample = 1, NSAMPLES
    call random_number(x); call random_number(y)
    if (hypot(x, y) <= 1) n = n + 1
  end do

  num_images_initial_team = num_images()
  n_copy = n
  
  do
    form team(1, team_active_images, stat=status)
    change team (team_active_images, stat=status)
      ! FORM TEAM NEW_INDEX= specifier not used; image index in team_active_images is processor-dependent
      image_index_in_active_team = this_image()
      if (num_images_initial_team - num_images() < NFAIL .and. this_image() == num_images()) fail image
      call co_sum(n, result_image = 1, stat=status)
    end team (stat=status)
    if (status /= STAT_FAILED_IMAGE) exit
    ! else value of n is undefined; restore from copy
    n = n_copy
  end do
  
  if (image_index_in_active_team == 1) then
    write(*,*) (4.0d0 * n / NSAMPLES) / (num_images() - size(failed_images()))
  end if
end program monte_carlo_pi
