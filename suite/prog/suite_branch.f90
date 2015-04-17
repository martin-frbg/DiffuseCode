SUBROUTINE suite_branch(zeile, length)
!
!  Specific DISCUS Version of a branch subroutine
!  Call KUPLOT via system
!
USE discus_setup_mod
USE discus_loop_mod
USE kuplot_setup_mod
USE kuplot_loop_mod
!
USE errlist_mod
USE prompt_mod
USE suite_init_mod
!
IMPLICIT NONE
!
CHARACTER (LEN=*), INTENT(IN) :: zeile
INTEGER          , INTENT(IN) :: length
!
CHARACTER(LEN= 7   ) :: br_pname_old,br_pname_cap_old
INTEGER              :: br_prompt_status_old
INTEGER              :: br_ier_sta_old
!
LOGICAL str_comp
!
br_pname_old         = pname         ! Store old prompt/error status
br_pname_cap_old     = pname_cap
br_prompt_status_old = prompt_status
br_ier_sta_old       = ier_sta
!
IF(str_comp(zeile, 'kuplot', 2, length, 6)) THEN
   IF(suite_kuplot_init) then
      pname     = 'kuplot'
      pname_cap = 'KUPLOT'
      prompt    = pname
      CALL suite_set_hlp ()
   ELSE
      CALL kuplot_setup   (lstandalone)
      suite_kuplot_init = .TRUE.
   ENDIF
   CALL kuplot_set_sub ()
   CALL kuplot_loop    ()
   pname      = br_pname_old
   pname_cap  = br_pname_cap_old
   prompt     = pname
   prompt_status = br_prompt_status_old
   ier_sta       = br_ier_sta_old
ELSEIF(str_comp(zeile, 'discus', 2, length, 6)) THEN
   IF(suite_discus_init) then
      pname     = 'discus'
      pname_cap = 'DISCUS'
      prompt    = pname
      CALL suite_set_hlp ()
   ELSE
      CALL discus_setup   (lstandalone)
      suite_discus_init = .TRUE.
   ENDIF
   CALL discus_set_sub ()
   CALL discus_loop    ()
   pname      = br_pname_old
   pname_cap  = br_pname_cap_old
   prompt     = pname
   prompt_status = br_prompt_status_old
   ier_sta       = br_ier_sta_old
ELSE
   ier_num = -7
   ier_typ = ER_COMM
ENDIF
!
IF(pname=='discus') THEN      ! Return to DISCUS branch
      CALL discus_set_sub ()
ELSEIF(pname=='kuplot') THEN  ! Return to KUPLOT branch
      CALL kuplot_set_sub ()
ENDIF
CALL suite_set_hlp () 
!
END SUBROUTINE suite_branch
