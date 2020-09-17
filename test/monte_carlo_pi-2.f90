program monte_carlo_pi
  use iso_fortran_env, only : STAT_FAILED_IMAGE
  implicit none
  integer, parameter :: NFAIL=2, NSAMPLES=10**6
  integer :: i, status, n_i, n[*], active_images = 1
  double precision :: x, y
  
  call random_init(repeatable=.true., image_distinct=.true.)
  
  n = 0

  do i = 1, NSAMPLES
    call random_number(x); call random_number(y)
    if (hypot(x, y) <= 1) n = n + 1
  end do

  ! simulate failure in last NFAIL images
  if (num_images() - this_image() < NFAIL) fail image

  if (this_image() == 1) then
    do i = 2, num_images()
       sync images(i, stat=status)
       n_i = n[i, stat=status]
       if (status /= STAT_FAILED_IMAGE) then
          n = n + n_i
          active_images = active_images + 1
       end if
    end do
    write(*,*) (4.0d0 * n / NSAMPLES) / active_images
  else
     sync images(1)
  end if
end program monte_carlo_pi
