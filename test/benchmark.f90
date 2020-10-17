! OUTPUT
!     3 columns: time in seconds for FORM TEAM, CHANGE TEAM, END TEAM
program benchmark
   use, intrinsic :: iso_fortran_env, only: int64, real64, team_type
   implicit none

   type(team_type) :: active_images
   integer(kind=int64), allocatable :: t(:,:,:)
   integer(kind=int64) :: count_rate
   integer :: i, image, j, stat
   integer, parameter :: NREP = 1000

   allocate(t(3,NREP+1,2))

   sync all

! Benchmark 1: FORM TEAM / CHANGE TEAM / END TEAM (MPI_BARRIER synchronization)

   do i = 1, NREP
      call system_clock(t(1,i,1))
      form team(1, active_images)
      call system_clock(t(2,i,1))
      change team(active_images)
        call system_clock(t(3,i,1))
      end team
   end do

   call system_clock(t(1,ubound(t,2),1)) ! time last END TEAM

   sync all

! Benchmark 1: FORM TEAM / CHANGE TEAM / END TEAM (MPI_COMM_AGREE synchronization)

   do i = 1, NREP
      call system_clock(t(1,i,2))
      form team(1, active_images, stat = stat)
      call system_clock(t(2,i,2))
      change team(active_images, stat = stat)
        call system_clock(t(3,i,2))
      end team(stat=stat)
   end do

   call system_clock(t(1,ubound(t,2),2)) ! time last END TEAM
   call system_clock(count_rate = count_rate)

   image = this_image()

   write(*,'(g0,1X,g0,1X,g0,1X,g0,1X,g0,1X,g0)') ((image, j, i, real(t(2,i,j)   - t(1,i,j), kind=real64)/count_rate, &
                                                                real(t(3,i,j)   - t(2,i,j), kind=real64)/count_rate, &
                                                                real(t(1,i+1,j) - t(3,i,j), kind=real64)/count_rate, &
                                                                i = 1, ubound(t,2)-1), j=1,2)

end program benchmark
