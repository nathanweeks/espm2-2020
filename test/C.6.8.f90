! Assumptions: even number of images >= 4
PROGRAM possibly_recoverable_simulation
  USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY:TEAM_TYPE, STAT_FAILED_IMAGE, ERROR_UNIT
  IMPLICIT NONE
  INTEGER, ALLOCATABLE :: failures (:) ! Indices of the failed images.
  INTEGER :: images_spare ! No. spare images. Not altered in main loop. 
  INTEGER :: images_used ! Max index of image in use
  INTEGER :: team_number ! 1 if in working team; 2 otherwise.  
  INTEGER :: local_index ! Index of the image in the team
  INTEGER :: status ! stat= value
  INTEGER :: i
  TYPE (TEAM_TYPE) :: simulation_team
  INTEGER :: done [*] ! 0: not done
                       ! 1: computation finished on the image
                       ! 2: read checkpoint on entering simulation_procedure
  ! Keep 1% spare images if we have a lot, just 1 if 11-199 images, 
  !                                                      0 if <=10.
! COMMENT: hard-coding 2 images for testing purposes
! images_spare = MAX(NUM_IMAGES()/100,MIN(NUM_IMAGES()-10,1))
  images_spare = 2
  images_used = NUM_IMAGES () - images_spare
  
  team_number = MERGE (1, 2, THIS_IMAGE()<=images_used)
  local_index = THIS_IMAGE() - (team_number-1)*images_used
  done = 0

  outer : DO
    ! Set up a simulation team of constant size.
    ! Team 2 is the set of spares, so does not participate.
    FORM TEAM (team_number, simulation_team, NEW_INDEX=local_index, &
               STAT=status)
! COMMENT: Fortran 2018 does requires the optional TEAM argument to NUM_IMAGES to refer to the current team or an ancestor
!          team; however, if a child team were permitted, then NUM_IMAGES(TEAM=simulation_team) could be used to efficiently
!          determine if the simulation_team has the required number of images to proceed (without the more expensive
!          synchronization implied by CHANGE TEAM for images in team_number == 1)
! COMMENT: FAILED_IMAGES(TEAM=GET_TEAM(PARENT_TEAM)) not supported (due to lack of PARENT_TEAM and GET_TEAM() in
!          GFortran/OpenCoarrays); save failures here to reference in simulation_procedure
    failures = failed_images()
    IF (team_number == 1) THEN
! COMMENT: (optimization) CHANGE TEAM needn't be called by team_number == 2.
      CHANGE TEAM (simulation_team, STAT=status)
! COMMENT: NUM_IMAGES() < images_used if image failure occurred before/during FORM TEAM; status == STAT_FAILED_IMAGE if image
!          failure detected in by CHANGE TEAM 
         IF (NUM_IMAGES() < images_used .OR. status == STAT_FAILED_IMAGE) GOTO 999
         iter : DO
           CALL simulation_procedure (done, status)
           ! The simulation_procedure:
           !  - sets up and performs some part of the simulation;
           !  - resets to the last checkpoint if requested (done == 2);
           !  - sets status from its internal synchronizations;
           !  - sets done to 1 when the simulation has completed.
           IF (status == STAT_FAILED_IMAGE) THEN
              done = 2 ! read checkpoint
              GO TO 999
           ELSE IF (done == 1) THEN
              EXIT iter
           END IF
           done = 0 ! normal iteration; don't read checkpoint on next entry to simulation_procedure
         END DO iter
999   END TEAM (STAT=status)
    ELSE ! team_number == 2
! COMMENT: images in team_number == 2 have a consistent (though not necessarily complete) knowledge of failed images, as the last
!          image control statement they have executed at this point is FORM TEAM
      CALL replace_failed_images(team_number, local_index)
    END IF

    SYNC ALL (STAT=status)

    IF (team_number == 2) THEN
! COMMENT: get done status from first non-failed image in team 1 (which are lower-numbered);
!          assumes at least one image in team team_number == 1 has not failed
      DO i = 1, NUM_IMAGES()
        done = done[i, STAT=status]
        IF (status /= STAT_FAILED_IMAGE) EXIT
      END DO
    END IF
    IF (done == 1) EXIT outer
  END DO outer
  write(*,'(*(g0))') '(done) team: ', team_number, '; image (team): ', local_index, &
                     '; image (initial_team):', THIS_IMAGE()
CONTAINS
  SUBROUTINE replace_failed_images(team_number, local_index)
    IMPLICIT NONE
    INTEGER, INTENT(INOUT) :: team_number, local_index

    INTEGER, ALLOCATABLE, SAVE :: old_failures(:) ! Previous failures.
    INTEGER, ALLOCATABLE, SAVE :: map(:) ! For each spare image k in use, 
               ! map(k) holds the index of the failed image it replaces.

    INTEGER, ALLOCATABLE :: failures(:), new_failures(:), new_failures_active(:), available_spares(:)
    INTEGER :: i ! Temporaries
    INTEGER, PARAMETER :: FAILED = -1, SPARE = 0

    IF (.NOT. ALLOCATED(old_failures)) ALLOCATE ( old_failures(0), map(images_used+1:NUM_IMAGES()), SOURCE=SPARE)

    failures = FAILED_IMAGES()
    new_failures = PACK(failures, MASK = [(ALL(old_failures /= failures(i)), i=1, SIZE(failures))])

    old_failures = failures

    ! mask newly-failed spares
    do i = 1, size(new_failures)
       if (new_failures(i) > images_used) then
          if (map(i) == SPARE) then
             map(i) = FAILED
             new_failures(i) = HUGE(0)
          end if
       end if
    end do

    new_failures_active = PACK(new_failures, MASK = new_failures < num_images())
    available_spares = FINDLOC(map, SPARE) + LBOUND(map, 1) - 1

    map(available_spares(:size(new_failures_active))) = new_failures_active

    if (map(this_image()) /= SPARE) then ! this spare image replaces a failed image
        team_number = 1
        local_index = map(this_image())
        deallocate(old_failures, map) ! no longer needed
    end if
  END SUBROUTINE

! done == .true. when no spare images remain
  subroutine simulation_procedure(done, status)
    implicit none
    integer, intent(inout) :: done
    integer, intent(out) :: status

    ! local_state is a counter that is incremented on each call to simulation_procedure
    integer, save :: remote_checkpoint[*] = -1, local_state = -1
    integer :: buddy

    buddy = this_image() + -1*(this_image()-1)/(num_images()/2)

    if (done == 2) then  ! read checkpoint
       if (local_state == -1) then ! newly-recruited spare image
          local_state = remote_checkpoint[buddy, stat=status]
          if (status == STAT_FAILED_IMAGE) ERROR STOP 'buddy failed; cannot recover checkpoint'
          ! buddy was also a spare in the previous iteration... recovery not possible
          if (local_state == -1) ERROR STOP 'no checkpoint exists on buddy'
       else ! assume state restored from local checkpoint
          ! save state to buddy image in case it is a newly-recruited spare
          ! (future optimization: check if this is the case before saving)
          local_state = local_state - 1
          remote_checkpoint[buddy, stat=status] = local_state
       end if
    else
       if (local_state /= -1) remote_checkpoint[buddy, stat=status] = local_state
    end if

    if (size(failures) < images_spare .and. local_state == size(failures) &
        .and. this_image() == num_images()-size(failures)) fail image

    ! some computation, advancing local state
    local_state = local_state + 1

    ! arbitrarily assuming done if no more spares exist
    if (local_state >= images_spare) done = 1

    ! set output status argument to verify that all images completed without failure
    sync all (stat=status)

  end subroutine simulation_procedure
END PROGRAM possibly_recoverable_simulation
