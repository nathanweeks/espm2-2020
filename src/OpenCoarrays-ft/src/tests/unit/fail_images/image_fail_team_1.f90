program image_fail_team_1
  use, intrinsic :: iso_fortran_env, only : team_type, STAT_FAILED_IMAGE
  implicit none

  integer :: initial_team_size, odd_even_team_size, team_num, stat
  type(team_type) :: odd_even_team, initial_team_minus_failed_images, odd_even_team_minus_failed_images, new_index_team
   
  initial_team_size = num_images()
  if (initial_team_size < 6) error stop "I need at least 6 images to function"

  team_num = mod(this_image(), 2) + 1
  form team (team_num, odd_even_team)
 
  change team (odd_even_team)
    odd_even_team_size = num_images()
    if (this_image() == num_images()) fail image
    form team (1, odd_even_team_minus_failed_images, stat=stat)
    if (stat /= STAT_FAILED_IMAGE) error stop "Expected FORM TEAM (STAT == STAT_FAILED_IMAGE)."
    if (size(failed_images()) /= 1) error stop "Expected size(failed_images()) == 1"
    change team (odd_even_team_minus_failed_images, stat=stat)
      if (stat == STAT_FAILED_IMAGE) error stop "Expected CHANGE TEAM (STAT /= STAT_FAILED_IMAGE)."
      if (num_images() /= odd_even_team_size - 1) error stop "Expected num_images() == odd_even_team_size - 1"
    end team
  end team(stat=stat)
  if (stat /= STAT_FAILED_IMAGE) error stop "Expected END TEAM (STAT == STAT_FAILED_IMAGE)."

  sync all(STAT=stat)

  if (stat /= STAT_FAILED_IMAGE) error stop "Expected sync all (STAT == STAT_FAILED_IMAGE)."
  if (size(failed_images()) /= 2) error stop "Expected size(failed_images()) == 2"

  form team (1, initial_team_minus_failed_images, stat=stat)
  if (stat /= STAT_FAILED_IMAGE) error stop "Expected FORM TEAM (STAT == STAT_FAILED_IMAGE)."

  change team (initial_team_minus_failed_images)
    if (num_images() /= initial_team_size - 2) error stop "Expected num_images() == initial_team_size - 2"
    if (this_image() == 2) FAIL IMAGE
    form team(1, new_index_team, new_index=this_image(), stat=stat)
    if (stat /= STAT_FAILED_IMAGE) error stop "Expected stat == STAT_FAILED_IMAGE"
    change team (new_index_team)
      if (num_images() /= initial_team_size - 3) error stop "Expected num_images() == initial_team_size - 3"
    end team
    if (this_image() == 3) fail image
    change team (new_index_team, stat=stat)
       if (stat /= STAT_FAILED_IMAGE) error stop "Expected CHANGE TEAM (STAT == STAT_FAILED_IMAGE)."
    end team(stat=stat)
    if (stat /= STAT_FAILED_IMAGE) error stop "Expected END TEAM (STAT == STAT_FAILED_IMAGE)."
    !if (failed_images(TODO: INITIAL TEAM...)...
  end team(stat=stat)

  if (stat /= STAT_FAILED_IMAGE) error stop "Expected END TEAM (STAT == STAT_FAILED_IMAGE)."

  if (this_image() == 1) write (*,*) "Test passed."
end program
