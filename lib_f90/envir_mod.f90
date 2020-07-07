MODULE envir_mod
!+
!     Helpfile location etc.
!-
USE precision_mod
!
   IMPLICIT NONE
   PUBLIC
   SAVE
!
   CHARACTER(LEN=9), PARAMETER :: OS_LINUX     = 'Linux    '
   CHARACTER(LEN=9), PARAMETER :: OS_LINUX_WSL = 'Linux_WSL'
   CHARACTER(LEN=9), PARAMETER :: OS_WINDOWS   = 'Windows  '
   CHARACTER(LEN=9), PARAMETER :: OS_CYGWIN32  = 'cygwin   '
   CHARACTER(LEN=9), PARAMETER :: OS_CYGWIN64  = 'cygwin64 '
   CHARACTER(LEN=9), PARAMETER :: OS_MACOSX    = 'darwin18 '
!
   CHARACTER(LEN=PREC_STRING) :: home_dir
   CHARACTER(LEN=PREC_STRING) :: appl_dir
   CHARACTER(LEN=PREC_STRING) :: share_dir
   CHARACTER(LEN=PREC_STRING) :: mac_dir
   CHARACTER(LEN=PREC_STRING) :: man_dir
   CHARACTER(LEN=PREC_STRING) :: tmp_dir
   CHARACTER(LEN=PREC_STRING) :: umac_dir
   CHARACTER(LEN=PREC_STRING) :: start_dir
   CHARACTER(LEN=PREC_STRING) :: start_line
   CHARACTER(LEN=PREC_STRING) :: current_dir
   CHARACTER(LEN= 256) :: operating
   CHARACTER(LEN= 256) :: operat_top
   CHARACTER(LEN= 256) :: user_profile
   CHARACTER(LEN= 256) :: term_scheme_file
   CHARACTER(LEN= 256) :: inst_file
   CHARACTER(LEN= 256) :: process_name
   CHARACTER(LEN= 256) :: parent_name
   CHARACTER(LEN= 80 ) :: deffile
   CHARACTER(LEN= 80 ) :: hlpfile
   CHARACTER(LEN= 80 ) :: manfile
   CHARACTER(LEN= 80 ) :: hlpdir
   CHARACTER(LEN= 80 ) :: colorfile
   CHARACTER(LEN= 80 ) :: nullfile
   CHARACTER(LEN= 80 ) :: user_name
   INTEGER             :: home_dir_l
   INTEGER             :: appl_dir_l
   INTEGER             :: share_dir_l
   INTEGER             :: term_scheme_file_l
   INTEGER             :: deffile_l
   INTEGER             :: hlpfile_l
   INTEGER             :: hlp_dir_l
   INTEGER             :: colorfile_l
   INTEGER             :: mac_dir_l
   INTEGER             :: tmp_dir_l
   INTEGER             :: umac_dir_l
   INTEGER             :: start_dir_l
   INTEGER             :: start_line_l
   INTEGER             :: current_dir_l
   INTEGER             :: user_name_l
   INTEGER             :: lines
   INTEGER             :: last_update = 0 ! Laste date of system update
   INTEGER             :: PID             ! Process ID of discus_suite
   INTEGER             :: PPID            ! Parent Process ID of discus_suite
   LOGICAL             :: term_scheme_exists = .FALSE.
   LOGICAL             :: envir_done         = .FALSE.
!
END MODULE envir_mod
