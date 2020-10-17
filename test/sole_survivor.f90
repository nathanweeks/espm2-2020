! OUTPUT
!     3 columns: time in seconds for FORM TEAM, CHANGE TEAM, END TEAM
program sole_survivor
   use, intrinsic :: iso_fortran_env, only: int64, real64, team_type
   implicit none

   type(team_type) :: active_images
   integer(kind=int64), allocatable :: t(:,:)
   integer(kind=int64) :: count_rate
   integer :: i, stat

   if (this_image() == 1) allocate(t(3,num_images()))

   sync all

   do i = 1, num_images()-1
      if (this_image() == 1) call system_clock(t(1,i))
      form team(1, active_images, stat = stat)
      if (this_image() == 1) call system_clock(t(2,i))
      change team(active_images, stat = stat)
        if (this_image() == 1) then
          call system_clock(t(3,i))
        else if (this_image() == num_images()) then
          fail image
        end if
      end team(stat=stat)
   end do

   call system_clock(t(1,ubound(t,2))) ! time last END TEAM
   call system_clock(count_rate = count_rate)

   ! 1st line: total time
   write(*,'(g0,1X,g0,1X,g0,1X,g0,1X,g0)') num_images(), 0, real(t(1,ubound(t,2)) - t(1,1),kind=real64)/count_rate, 0, 0
   write(*,'(g0,1X,g0,1X,g0,1X,g0,1X,g0)') (num_images(), &
                                            num_images() - i+1, &
                                            real(t(2,i)   - t(1,i), kind=real64)/count_rate, &
                                            real(t(3,i)   - t(2,i), kind=real64)/count_rate, &
                                            real(t(1,i+1) - t(3,i), kind=real64)/count_rate, &
                                            i = 1, num_images()-1)

end program sole_survivor
