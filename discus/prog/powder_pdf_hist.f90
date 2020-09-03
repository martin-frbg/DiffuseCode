MODULE powder_pdf_hist_mod
!
! Common histogram building for POWDER and PDF
!
USE precision_mod
INTEGER                       :: nexp = 20000
REAL(KIND=PREC_DP), PARAMETER :: gauss_step = 0.0005d0
REAL(KIND=PREC_DP), DIMENSION(:), ALLOCATABLE :: expo
!
CONTAINS
!
!*******************************************************************************
!
SUBROUTINE pow_pdf_hist
!
USE crystal_mod
USE debye_mod
USE diffuse_mod
USE discus_plot_mod
USE discus_plot_init_mod
USE molecule_mod
USE powder_mod
USE discus_save_mod
USE save_menu, ONLY: save_internal, save_store_setting, save_restore_setting, save_default_setting, save_struc, save_show
USE surface_func_mod
USE prop_para_func
USE read_internal_mod
!
USE errlist_mod
USE lib_errlist_func
USE precision_mod
USE trig_degree_mod
USE wink_mod
!
IMPLICIT NONE
!
CHARACTER(LEN=PREC_STRING) :: line
CHARACTER(LEN=PREC_STRING) :: origstruc       ! Structure prior to powder calculation
INTEGER :: length
INTEGER :: i
LOGICAL                 :: do_mol      ! Molecules with Biso /= 0.0
INTEGER                 :: powder_nmol ! Number of look up dimensions molecules
REAL   , DIMENSION(1:3) :: u
REAL(KIND=PREC_DP), DIMENSION(3) :: com  ! Center of mass of crystal
!
!IF (rlambda.ne.0.0) THEN
!
!   IF (pow_qmax.le.pow_qmin.or.pow_deltaq.le.0.0) THEN 
!      ier_num = - 108 
!      ier_typ = ER_APPL 
!      RETURN 
!   ENDIF 
!
!        Calculate hkl limits 
!
!   pow_ds_max = (pow_qmax+pow_deltaq + pow_qmax_buf)/REAL(zpi)
!   pow_ds_min = pow_qmin/REAL(zpi)
!   IF(pow_qmax*rlambda/2./zpi > 1.0) THEN
!      ier_num = -108
!      ier_typ = ER_APPL
!      ier_msg(1) = 'Qmax is too large for current wave length'
!      ier_msg(2) = 'Qmax*lambda/(4pi) is greater than one!'
!      ier_msg(3) = 'Reduce Qmax or the wave length'
!      RETURN
!   ENDIF
!
!   pow_hkl_max (1) = cr_a0 (1) * pow_ds_max 
!   pow_hkl_max (2) = cr_a0 (2) * pow_ds_max 
!   pow_hkl_max (3) = cr_a0 (3) * pow_ds_max 
!
!  If the user wants to calculate a periodic PDF from an extended
!  group of atoms via the Debye mode, We:
!  - store the original structure
!  - cut the rest into a sphere with radius pow_period/pow_period_cut (cut=0.8)
!  - calculate the PDF
!  - divide the PDF by the sphere shape function
!  - restore the original structure
   IF(pow_lperiod) THEN      ! Make the PDF periodic
      IF(pow_period > 0.0) THEN    ! Limit is positive
         CALL save_store_setting             ! Backup user "save" setting
         CALL save_default_setting           ! Default to full saving
         line       = 'ignore, all'          ! Ignore all properties
         length     = 11
         CALL property_select(line, length, sav_sel_prop)
         line       = 'ignore, all'          ! Ignore all properties for global as well
         length     = 11
         CALL property_select(line, length,  cr_sel_prop)
!
         origstruc   = 'internal.powderback.stru' ! internal user files always start with 'internal'
         CALL save_internal(origstruc)       !     thus this file name is unique
!
         com = 0.0D0                         ! Calculate center of mass
         DO i=1, cr_natoms
            com = com + cr_pos(:,i)
         ENDDO
         com = com / cr_natoms
!         WRITE(line,1000) pow_period/pow_period_cut/2.0, com
!11000 FORMAT('sphere ',F12.4,',centx:',G15.6E3,'centy:',G15.6E3,'centz:',G15.6E3) 
!write(*,'(a)') line
         length = 72
         CALL boundary (line, length)
!
      ELSE
         ier_num = -168
         ier_typ = ER_APPL 
         RETURN
      ENDIF
   ENDIF
!
   u(:) = 0.0
!
   CALL plot_ini_trans (1.0,                          &
        pl_tran_g, pl_tran_gi, pl_tran_f, pl_tran_fi, &
        cr_gten, cr_rten, cr_eps)

   CALL powder_trans_atoms_tocart (u)
!
!     u is the body diagonal of the cartesian box around the crystal
!     calculate its length and use the length to allocate the histogram size
!
!
!     Any molecules with b-value /= zero ?
!
   do_mol      = .false.
   powder_nmol = 0
   search_mol: DO i=1, mole_num_type
      IF(mole_biso(i) > 0.0 .OR. mole_clin(i)>0.0 .OR. mole_cqua(i)>0.0) THEN
         do_mol   = .true.
         powder_nmol = mole_num_type + mole_num_type*(mole_num_type+1)/2
         EXIT search_mol
      ENDIF
   ENDDO search_mol
   IF(do_mol) THEN
!
      CALL powder_debye_hist_cart_mole (u, cr_nscat, do_mol, powder_nmol)
   ELSE
      CALL powder_debye_hist_cart      (u, cr_nscat)
   ENDIF
!           CALL alloc_debye (       1,      1,   MAXDQXY, MASK )
   CALL powder_trans_atoms_fromcart 
!
!ELSE
!   ier_num = -99
!   ier_typ = ER_APPL
!ENDIF
!
IF(pow_lperiod) THEN
   CALL errlist_save                   ! Keep error status 

   CALL save_restore_setting
   CALL no_error
   CALL readstru_internal(origstruc)   ! Read  core file
   CALL errlist_restore                ! Restore error status
ENDIF
!
END SUBROUTINE pow_pdf_hist
!
!*****7*****************************************************************
!
SUBROUTINE powder_debye_hist_cart (udist, cr_nscat_temp)
!-                                                                      
!     Calculate the powder pattern by using the Debye Formula according 
!     to Giacovacco                                                     
!     Histogram Version                                                 
!+                                                                      
USE discus_config_mod 
USE discus_allocate_appl_mod
USE crystal_mod 
USE debye_mod 
USE diffuse_mod 
USE fourier_sup
USE metric_mod
USE output_mod 
USE phases_mod
USE phases_set_mod
USE pdf_mod
USE powder_mod 
USE powder_tables_mod 
USE wink_mod
!$ USE omp_lib
!                                                                       
USE parallel_mod
USE prompt_mod 
USE precision_mod 
USE trig_degree_mod
use times_mod
USE support_mod
IMPLICIT none 
!                                                                       
REAL,    INTENT(IN)  :: udist(3)
INTEGER, INTENT(IN)  :: cr_nscat_temp
!                                                                       
INTEGER, DIMENSION(0:cr_nscat_temp) :: natom ! (0:MAXSCAT) 
INTEGER ibin 
INTEGER j, k, l 
INTEGER i, iscat, jscat 
INTEGER                :: n_hist
INTEGER                :: n_srch         ! Actual MAXHIST 
INTEGER                :: n_qxy   = 1
INTEGER                :: n_nscat = 1
INTEGER                :: n_natom = 1
INTEGER                :: n_pha   = 1
REAL                   :: distance
REAL (PREC_DP) :: xstart, xdelta   ! start/step in dstar for sinthea/lambda table
REAL ss, st
REAL                   :: shift
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: partial
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: histogram
INTEGER, DIMENSION(:,:  ), ALLOCATABLE :: look
INTEGER, DIMENSION(:,:  ), ALLOCATABLE :: is_look
REAL u (3), v (3) 
!
REAL(KIND=PREC_DP) :: deltar    = 0.0D0
REAL(KIND=PREC_SP) :: qbroad    = 0.0E0
REAL(KIND=PREC_SP) :: cquad_a   = 0.0E0
REAL(KIND=PREC_SP) :: clin_a    = 0.0E0
INTEGER            :: nmol_type = 0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: cquad_m  = 0.0D0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: clin_m   = 0.0D0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: bval_mol = 0.0D0
INTEGER            :: nlook_mol = 0
!                                                                       
INTEGER :: i0

INTEGER :: IAND 
!VARIABLES for OpenMP
INTEGER                              :: tid       ! Id of this thread
INTEGER                              :: nthreads  ! Number of threadsa available from OMP
INTEGER, DIMENSION(:,:), ALLOCATABLE :: natom_p   ! Number of atoms (0:cr_nscat_temp, 0:nthreads)
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: histogram_p
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: partial_p
!
!REAL, EXTERNAL :: seknds 
!                                                                       
n_qxy   = 1
n_nscat = 1
n_natom = 1
ier_num = 0 
!                                                                       
!------ preset some values                                              
!                                                                       
num (1) = 1021 
num (2) = 1 
DO i = 1, 3 
   u (i) = 0.0 
   v (i) = 0.0 
   xm (i) = 0.0 
   uin (i) = 0.0 
   vin (i) = 0.0 
ENDDO 
!
u (1) = 1.00 
xm (1) = pow_qmin / REAL(zpi)
ss = (pow_qmax+pow_qmax_buf) / REAL(zpi) 
st = (pow_qmax - pow_deltaq) / REAL(zpi )
uin (1) = pow_deltaq / REAL(zpi )
num (1) = nint ( (ss - xm (1) ) / uin (1) ) + 1 
!
!    Allocate arrays
!
n_qxy    = num (1) * num (2) + 1
distance = sqrt(udist(1)**2+udist(2)**2+udist(3)**2)
n_hist   = nint(distance/pow_del_hist) + 2
!     n_qxy   = MAX(n_qxy,num(1) * num(2),MAXQXY,MAXDQXY)
n_nscat = MAX(n_nscat,cr_nscat,DIF_MAXSCAT)
n_natom = MAX(n_natom,cr_natoms,DIF_MAXAT)
IF (num (1) * num (2) > MAXQXY  .OR.          &
    num (1) * num (2) > MAXDQXY .OR.          &
    cr_nscat>DIF_MAXSCAT              ) THEN
   CALL alloc_diffuse (n_qxy,  n_nscat,  n_natom )
ENDIF
CALL alloc_debye  (cr_nscat, n_hist, n_qxy, MASK )
!
CALL alloc_powder (n_qxy, n_nscat          )
!
IF(n_qxy > PHA_MAXPTS .OR. cr_nscat> PHA_MAXSCAT) THEN 
   n_pha   = PHA_MAXPHA
   n_qxy   = MAX(PHA_MAXPTS,  n_qxy)
   n_nscat = MAX(PHA_MAXSCAT, cr_nscat)
   CALL alloc_phases(n_pha, n_qxy, n_nscat)
ENDIF
!                                                                       
!     prepare lookuptable for atom types
!                                                                       
ALLOCATE(look     (1:cr_nscat,1:cr_nscat))
look  = 0
nlook = 0 
DO i = 1, cr_nscat 
   DO j = i, cr_nscat 
      nlook = nlook + 1 
      look (i, j) = nlook 
      look (j, i) = nlook 
   ENDDO 
ENDDO 
!
ALLOCATE(is_look  (1:2,1:nlook))
ALLOCATE(partial  (1:num(1)*num(2),1:nlook,0:0))
!ALLOCATE(histogram(0:n_hist       ,1:nlook,0:0))
k=0
DO i = 1, cr_nscat 
   DO j = i, cr_nscat
      k = k + 1 
      is_look(1,k) = i      ! Compile inverse lookup table
      is_look(2,k) = j
   ENDDO 
ENDDO 
!                                                                       
!------ zero some arrays                                                
!                                                                       
partial(:,:,:)   = 0.0D0
rsf(:)           = 0.0D0
!histogram(:,:,:) = 0
!natom            = 0 
!                                                                       
!------ preset some tables, calculate average structure                 
!                                                                       
pow_npkt = n_qxy    ! set actual number of powder data points
CALL powder_sinet 
!
xstart = pow_qmin  /zpi
xdelta = pow_deltaq/zpi
CALL powder_stltab(n_qxy, xstart  ,xdelta    )   ! Really only needed for <f^2> and <f>^2 for F(Q) and S(Q)
!
IF (ier_num /= 0) THEN
   DEALLOCATE(look   )
   DEALLOCATE(partial)
   RETURN
ENDIF
CALL four_formtab
!
WRITE (output_io, * ) ' Starting histogram' 
ss = seknds (0.0) 
!     Jump into OpenMP to obtain number of threads
tid      = 0    ! Default if not compiled with OpenMP
nthreads = 1    ! Default if not compiled with OpenMP
IF(par_omp_use) THEN
!$OMP PARALLEL PRIVATE(tid)
!$   tid = OMP_GET_THREAD_NUM()
!$   IF (tid == 0) THEN
!$      IF(par_omp_maxthreads == -1) THEN
!$         nthreads = OMP_GET_NUM_THREADS()
!$      ELSE
!$         nthreads = MAX(1,MIN(par_omp_maxthreads, OMP_GET_NUM_THREADS()))
!$      ENDIF
!$   END IF
!$OMP END PARALLEL
ENDIF
!
ALLOCATE(natom_p(    0:cr_nscat_temp,        0:nthreads-1))
ALLOCATE(partial_p  (1:num(1)*num(2),1:nlook,0:nthreads-1))
ALLOCATE(histogram_p(0:n_hist       ,1:nlook,0:nthreads-1))
ALLOCATE(histogram(  0:n_hist       ,1:nlook,0:0         ))
histogram   = 0.0D0
histogram_p = 0.0D0
partial_p   = 0.0D0
natom_p     = 0
!                                                                       
!     loop over all atoms                                               
!                                                                       
!-----Optimization notes
!     Omitting the error checks saves about 1/4 time
!     Replaced NINT by INT( + shift) this cuts the time in half!!!!
!     Omitting the SQRT only saves a little, as do the local variables
!     The if(iscat) does not cause much compute time
shift = 0.5*pow_del_hist   ! Shift in blen position to avoid NINT function
!$OMP PARALLEL PRIVATE(tid, jscat, iscat, ibin, u)
!$OMP DO SCHEDULE(DYNAMIC, cr_natoms/32)
! !$OMP DO SCHEDULE(GUIDED, cr_natoms/16)
! ! !$OMP DO SCHEDULE(STATIC)
main_loop: DO j = 1, cr_natoms ! - 1
!$ tid = OMP_GET_THREAD_NUM()
   jscat = cr_iscat(j) 
   IF(jscat > 0) THEN 
      u(1) = cr_pos(1, j) 
      u(2) = cr_pos(2, j) 
      u(3) = cr_pos(3, j) 
!                                                                       
!     --- get info on relative amount of atoms                          
!                                                                       
      natom_p(jscat,tid) = natom_p(jscat,tid) + 1 
!                                                                       
!------ --- loop over all different atom types                          
!                                                                       
      DO l = j + 1, cr_natoms 
         iscat = cr_iscat(l) 
         IF(iscat > 0) THEN 
            ibin =   INT((SQRT((cr_pos(1, l) - u(1))*(cr_pos(1, l) - u(1)) + &
                               (cr_pos(2, l) - u(2))*(cr_pos(2, l) - u(2)) + &
                               (cr_pos(3, l) - u(3))*(cr_pos(3, l) - u(3))   &
                              )                                              &
                          +shift)/ pow_del_hist)
            histogram_p(ibin, look(jscat, iscat), tid) = &
            histogram_p(ibin, look(jscat, iscat), tid) + 1
!            IF(ier_ctrlc) EXIT main_loop ! Does not influence timing
         ENDIF 
      ENDDO 
   ENDIF 
ENDDO  main_loop
!$OMP END DO NOWAIT
!$OMP END PARALLEL
IF(ier_ctrlc .OR. ier_num/=0) THEN         ! Does not influence timing
   ier_num = -14
   ier_typ = ER_COMM
   DEALLOCATE(look   )
   DEALLOCATE(partial)
   DEALLOCATE(histogram)
   DEALLOCATE(histogram_p)
   DEALLOCATE(natom_p)
   RETURN
ENDIF
!IF(nthreads>0) THEN
   natom  (:  )     = SUM(natom_p, DIM=2)
   histogram(:,:,0) = SUM(histogram_p,DIM=3)
!ENDIF
!
pow_nreal = 0
DO j=1,cr_nscat         ! Add real atom numbers
   pow_nreal = pow_nreal + NINT(natom(j)*cr_occ(j))
ENDDO
!
n_srch = MAXHIST               ! Find longest occupied entry in histogram
srch: DO l=MAXHIST, 1, -1
   DO j=1,nlook
      IF(histogram(l,j,0) >0) THEN
         n_srch = l             ! Limit convolution / Fourier range
         EXIT srch
      ENDIF
   ENDDO
ENDDO  srch
!
i= 0
DO j=1,nlook
   i = MAX(i, INT(histogram(0,j,0)))
ENDDO
IF(i > 0) THEN    ! Entries in histogram(0,*) exist, flag Error
   ier_num = -123
   ier_typ = ER_APPL
   DEALLOCATE(look   )
   DEALLOCATE(partial)
   DEALLOCATE(histogram)
   DEALLOCATE(histogram_p)
   DEALLOCATE(natom_p)
   RETURN
ENDIF
!
!
deb_conv = .FALSE.
qbroad  = pdf_qalp
cquad_a = pdf_cquad_a
clin_a  = pdf_clin_a
!
IF(qbroad > 0.0 .OR. cquad_a>0.0 .OR. clin_a>0.0) deb_conv = .TRUE.
!
IF(deb_conv) THEN
   cquad_m(:) = 0.0D0
   clin_m(:)  = 0.0D0
   nmol_type = 0
   bval_mol(:) = 0
   deltar = DBLE(pow_del_hist)
   CALL pow_pdf_convtherm(n_hist, nlook, nlook_mol, n_srch, histogram, is_look, &
              deltar, qbroad, cquad_a, clin_a, cquad_m, clin_m, nmol_type,      &
              bval_mol )
ENDIF
!
!     --- Calculate the Fourier                                         
!                                                                       
i0 = 0
qwert: DO i = 1, nlook 
   !$OMP PARALLEL PRIVATE(tid)
   !$OMP DO SCHEDULE(DYNAMIC, 1)
   DO j = 1, n_srch 
      !$ tid = OMP_GET_THREAD_NUM()
      IF (histogram (j, i,0) >  0) THEN 
         DO k = 1, num (1) * num (2) 
            partial_p(k, i,tid) = partial_p(k, i,tid) + histogram (j, i,0)                                   &
               * sinetab(IAND(int((j * pow_del_hist) * (xm(1) + (k - 1) * uin(1)) * I2PI, PREC_INT_LARGE ) , MASK))  &
               / (zpi * DBLE((j * pow_del_hist) * (xm(1) + (k - 1) * uin(1))))
         ENDDO 
      ENDIF 
   ENDDO 
  !$OMP END DO NOWAIT
  !$OMP END PARALLEL
ENDDO  qwert
!IF(nthreads>0) THEN
partial(:,:,0)     = SUM(partial_p, DIM=3)
!                                                                       
!------ Multiply the partial structure factors with form factors,add    
!     to total sum                                                      
!                                                                       
IF(.NOT.deb_conv .AND. ldbw) THEN
   DO i = 1, cr_nscat 
      DO j = i, cr_nscat 
         DO k = 1, num (1) * num (2) 
            rsf (k) = rsf (k) + 2.0D0 * partial (k, look (i, j),0 ) * ( &
               DBLE(cfact (powder_istl (k), i) ) * DBLE(cfact (powder_istl (k), j) ) + &
              aimag(cfact (powder_istl (k), i) ) * aimag (cfact (powder_istl (k), j) ) )            
         ENDDO 
      ENDDO 
   ENDDO 
!                                                                       
!                                                                       
!     add the f**2 weighted by relative amount to intensity             
!     store <f**2> and <f>**2
!                                                                       
   DO iscat = 1, cr_nscat 
      DO i = 1, num (1) * num (2) 
         rsf (i) = rsf (i) + DBLE (cfact      (powder_istl (i), iscat) * &
                            conjg (cfact      (powder_istl (i), iscat) ) ) * natom (iscat)
      ENDDO 
!
   ENDDO 
ELSE
   DO i = 1, cr_nscat 
      DO j = i, cr_nscat 
         DO k = 1, num (1) * num (2) 
            rsf(k) = rsf(k) + 2.0D0 * partial(k, look(i, j),0 ) * ( &
               DBLE(cfact_pure (powder_istl(k), i)) * DBLE( cfact_pure(powder_istl(k), j)) + &
              AIMAG(cfact_pure (powder_istl(k), i)) * AIMAG(cfact_pure(powder_istl(k), j)) )            
         ENDDO 
      ENDDO 
   ENDDO 
!
!     add the f**2 weighted by relative amount to intensity             
!     store <f**2> and <f>**2
!
   DO iscat = 1, cr_nscat 
      DO i = 1, num (1) * num (2) 
         rsf(i) = rsf(i) + DBLE(cfact_pure(powder_istl(i), iscat) * &
                          CONJG(cfact_pure(powder_istl(i), iscat))) * natom(iscat)
      ENDDO 
!
   ENDDO 
ENDIF
!
DEALLOCATE(look   )
DEALLOCATE(partial)
DEALLOCATE(histogram)
DEALLOCATE(histogram_p)
DEALLOCATE(natom_p)
DEALLOCATE(partial_p)
!
ss = seknds (ss) 
WRITE (output_io, 4000) ss 
!                                                                       
 4000 FORMAT     (/,' Elapsed time H  : ',G13.6,' sec') 
!
END SUBROUTINE powder_debye_hist_cart         
!
!*****7*****************************************************************
!
SUBROUTINE powder_debye_hist_cart_mole(udist, cr_nscat_temp, &
                 do_mol, powder_nmol)
!-                                                                      
!     Calculate the powder pattern by using the Debye Formula according 
!     to Giacovacco                                                     
!     Histogram Version                                                 
!+                                                                      
USE discus_config_mod 
USE discus_allocate_appl_mod
USE crystal_mod 
USE debye_mod 
USE diffuse_mod 
USE fourier_sup
USE metric_mod
USE molecule_mod
USE output_mod 
USE pdf_mod
USE powder_mod 
USE powder_tables_mod 
USE wink_mod
!$ USE omp_lib
!                                                                       
USE parallel_mod
USE prompt_mod 
USE precision_mod 
USE trig_degree_mod
USE support_mod
IMPLICIT none 
!                                                                       
REAL,    INTENT(IN)  :: udist(3)
INTEGER, INTENT(IN)  :: cr_nscat_temp
LOGICAL, INTENT(IN)  :: do_mol      ! Molecules with Biso /= 0.0
INTEGER, INTENT(IN)  :: powder_nmol ! Number of look up dimensions molecules
!                                                                       
INTEGER, DIMENSION(0:cr_nscat_temp) :: natom ! (0:MAXSCAT) 
INTEGER ibin 
INTEGER j, k, l , il
INTEGER i, iscat, jscat 
INTEGER(KIND=PREC_INT_LARGE) :: iarg, iadd 
INTEGER                :: n_hist
INTEGER                :: n_srch         ! Actual MAXHIST 
INTEGER                :: n_qxy   = 1
INTEGER                :: n_nscat = 1
INTEGER                :: n_natom = 1
INTEGER                :: nmol_type = 0
INTEGER                :: nlook_mol   ! Number of look up dimensions molecules
INTEGER                :: islook      ! Actual molecule look up number
INTEGER, DIMENSION(:,:), ALLOCATABLE :: is_look          ! Inverse lookup for atoms
INTEGER, DIMENSION(:,:), ALLOCATABLE :: powder_look_mol
REAL   , DIMENSION(:)  , ALLOCATABLE :: powder_bvalue_mole
REAL   , DIMENSION(:)  , ALLOCATABLE :: powder_clin_mole
REAL   , DIMENSION(:)  , ALLOCATABLE :: powder_cqua_mole
REAL   , DIMENSION(:,:), ALLOCATABLE :: pow_dw
REAL   , DIMENSION(:,:,:), ALLOCATABLE :: partial
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: histogram
INTEGER, DIMENSION(:,:  ), ALLOCATABLE :: look
REAL(KIND=PREC_DP) :: deltar    = 0.0D0
REAL(KIND=PREC_SP) :: qbroad    = 0.0E0
REAL(KIND=PREC_SP) :: cquad_a   = 0.0E0
REAL(KIND=PREC_SP) :: clin_a    = 0.0E0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: cquad_m  = 0.0D0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: clin_m   = 0.0D0
REAL(KIND=PREC_SP), DIMENSION(0:0) :: bval_mol = 0.0D0
REAL                   :: distance
REAL (PREC_DP) :: xstart, xdelta   ! start/step in dstar for sinthea/lambda table
REAL ss, st
REAL                   :: shift
REAL u (3), v (3) 
REAL (KIND=PREC_DP) :: arg 
!                                                                       
INTEGER IAND 
!VARIABLES for OpenMP
INTEGER                              :: tid       ! Id of this thread
INTEGER                              :: nthreads  ! Number of threadsa available from OMP
INTEGER, DIMENSION(:,:), ALLOCATABLE :: natom_p   ! Number of atoms (0:cr_nscat_temp, 0:nthreads)
REAL(KIND=PREC_DP), DIMENSION(:,:,:,:), ALLOCATABLE :: histogram_p
REAL(KIND=PREC_DP), DIMENSION(:,:,:,:), ALLOCATABLE :: partial_p
!     REAL sind 
!REAL seknds 
!                                                                       
n_qxy   = 1
n_nscat = 1
n_natom = 1
ier_num = 0 
!                                                                       
!------ preset some values                                              
!                                                                       
num(1) = 1021 
num(2) = 1 
!------ Reset arrays
u     = 0.0 
v     = 0.0 
xm    = 0.0 
uin   = 0.0 
vin   = 0.0 
!
!IF (pow_axis.eq.POW_AXIS_DSTAR) THEN 
!   CONTINUE 
!ELSEIF (pow_axis.eq.POW_AXIS_Q) THEN 
   u (1) = 1.00 
   xm (1) = pow_qmin / REAL(zpi) 
   ss = pow_qmax / REAL(zpi) 
   st = (pow_qmax - pow_deltaq) / REAL(zpi) 
   uin (1) = pow_deltaq / REAL(zpi) 
   num (1) = nint ( (ss - xm (1) ) / uin (1) ) + 1 
!ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
!   u (1) = 1.00 
!   xm (1) = 2 * sind (0.5 * pow_tthmin) / rlambda 
!   ss = 2 * sind (0.5 *  pow_tthmax                 ) / rlambda 
!   st = 2 * sind (0.5 * (pow_tthmax - pow_deltatth) ) / rlambda 
!   uin (1) = (ss - st) / 2. 
!   num (1) = nint ( (ss - xm (1) ) / uin (1) ) + 1 
!ENDIF 
!
!     Lay out look_up table for molecule entries
!
IF(ALLOCATED(powder_look_mol)) DEALLOCATE(powder_look_mol)
ALLOCATE(powder_look_mol(0:mole_num_type,0:mole_num_type))
IF(ALLOCATED(powder_bvalue_mole)) DEALLOCATE(powder_bvalue_mole)
ALLOCATE(powder_bvalue_mole(0:powder_nmol))
IF(ALLOCATED(powder_clin_mole)) DEALLOCATE(powder_clin_mole)
ALLOCATE(powder_clin_mole(0:powder_nmol))
IF(ALLOCATED(powder_cqua_mole)) DEALLOCATE(powder_cqua_mole)
ALLOCATE(powder_cqua_mole(0:powder_nmol))
powder_look_mol    = 0
powder_bvalue_mole = 0.0
powder_clin_mole   = 0.0
powder_cqua_mole   = 0.0
nlook_mol          = 0
IF(powder_nmol>0) THEN    ! Non-zero molecular bvalues
   DO i=1,mole_num_type   ! First part biso for single molecule
      powder_look_mol(0,i) = i
      powder_look_mol(i,0) = i
      powder_bvalue_mole(i) = mole_biso(i)
   ENDDO
   nlook_mol = mole_num_type
   DO i=1,mole_num_type   !Second part biso for two molecules
      DO j = i,mole_num_type
         nlook_mol            = nlook_mol + 1
         powder_look_mol(i,j) = nlook_mol
         powder_look_mol(j,i) = nlook_mol
         powder_bvalue_mole(nlook_mol) = mole_biso(i) + mole_biso(j)
         powder_clin_mole(nlook_mol)   = mole_biso(i) + mole_biso(j)
         powder_cqua_mole(nlook_mol)   = mole_biso(i) + mole_biso(j)
      ENDDO
   ENDDO
ENDIF
!
!    Allocate arrays
!
n_qxy    = num (1) * num (2) + 1
distance = sqrt(udist(1)**2+udist(2)**2+udist(3)**2)
n_hist   = nint(distance/pow_del_hist) + 2
n_qxy   = MAX(n_qxy,num(1) * num(2),MAXQXY,MAXDQXY)
n_nscat = MAX(n_nscat,cr_nscat,DIF_MAXSCAT)
n_natom = MAX(n_natom,cr_natoms,DIF_MAXAT)
IF (num (1) * num (2) .gt. MAXQXY  .OR.          &
    num (1) * num (2) .gt. MAXDQXY .OR.          &
    cr_nscat>DIF_MAXSCAT              ) THEN
   CALL alloc_diffuse (n_qxy,  n_nscat,  n_natom )
ENDIF
CALL alloc_debye  (cr_nscat, n_hist, n_qxy, MASK )
!
CALL alloc_powder (n_qxy, n_nscat          )
IF(ALLOCATED(pow_dw)) DEALLOCATE(pow_dw)
ALLOCATE(pow_dw(0:CFPKT, 0:nlook_mol))
pow_dw = 1.0
IF(do_mol) THEN   ! If necessary calc Debye Waller terms for molecules
  CALL powder_dwmoltab (nlook_mol, pow_dw, powder_bvalue_mole)
ENDIF
!                                                                       
!     prepare loopuptable for atom types
!                                                                       
ALLOCATE(look     (1:cr_nscat,1:cr_nscat))
look  = 0
nlook = 0 
DO i = 1, cr_nscat 
   DO j = i, cr_nscat 
      nlook = nlook + 1 
      look (i, j) = nlook 
      look (j, i) = nlook 
   ENDDO 
ENDDO 
ALLOCATE(is_look  (1:2,1:nlook))
k=0
DO i = 1, cr_nscat 
   DO j = i, cr_nscat
      k = k + 1 
      is_look(1,k) = i      ! Compile inverse lookup table
      is_look(2,k) = j
   ENDDO 
ENDDO 
!do i=1, cr_nscat
!write(*,*) 'LOOK ', i,(look(i,j),j=1, cr_nscat)
!enddo
!write(*,*) ' nlook ', nlook
!do i=1, nlook
!write(*,*) is_look(:,i)
!enddo
!
!                                                                       
!------ preset some tables, calculate average structure                 
!                                                                       
pow_npkt = n_qxy    ! set actual number of powder data points
CALL powder_sinet 
!IF(pow_axis == POW_AXIS_Q ) THEN
   xstart = pow_qmin  /zpi
   xdelta = pow_deltaq/zpi
   CALL powder_stltab(n_qxy, xstart  ,xdelta    )   ! Really only needed for <f^2> and <f>^2 for F(Q) and S(Q)
!ELSEIF (pow_axis.eq.POW_AXIS_TTH) THEN 
!   CALL powder_stltab(n_qxy, xm(1)   ,uin(1)    )   ! Really only needed for <f^2> and <f>^2 for F(Q) and S(Q)
!ENDIF
IF (ier_num.ne.0) RETURN 
CALL four_formtab
!
WRITE (output_io, * ) ' Starting histogram'
ss = seknds (0.0) 
!     Jump into OpenMP to obtain number of threads
tid      = 0    ! Default if not compiled with OpenMP
nthreads = 1    ! Default if not compiled with OpenMP
IF(par_omp_use) THEN
!$OMP PARALLEL PRIVATE(tid)
!$   tid = OMP_GET_THREAD_NUM()
!$   IF (tid == 0) THEN
!$      IF(par_omp_maxthreads == -1) THEN
!$         nthreads = OMP_GET_NUM_THREADS()
!$      ELSE
!$         nthreads = MAX(1,MIN(par_omp_maxthreads, OMP_GET_NUM_THREADS()))
!$      ENDIF
!$   END IF
!$OMP END PARALLEL
ENDIF
!
!ALLOCATE(partial  (1:num(1)*num(2),1:nlook,0:nlook_mol))
!ALLOCATE(histogram(0:n_hist       ,1:nlook,0:nlook_mol))

ALLOCATE(natom_p(    0:cr_nscat_temp,        0:nthreads-1            ))
ALLOCATE(partial    (1:num(1)*num(2),1:nlook,0:nlook_mol             ))
ALLOCATE(partial_p  (1:num(1)*num(2),1:nlook,0:nlook_mol,0:nthreads-1))
ALLOCATE(histogram_p(0:n_hist       ,1:nlook,0:nlook_mol,0:nthreads-1))
ALLOCATE(histogram(  0:n_hist       ,1:nlook,0:nlook_mol             ))
histogram   = 0.0D0
histogram_p = 0.0D0
partial_p   = 0.0D0
natom_p     = 0
!
!------ zero some arrays                                                
!                                                                       
partial   = 0.0D0
rsf       = 0.0D0
histogram = 0.0D0
natom     = 0 
!                                                                       
!     loop over all atoms                                               
!                                                                       
!-----Optimization notes
!     Omitting the error checks saves about 1/4 time
!     Replaced NINT by INT( + shift) this cuts the time in half!!!!
!     Omitting the SQRT only saves a little, as do the local variables
!     The if(iscat) do not cause much compute time

shift = 0.5*pow_del_hist   ! Shift in blen position to avoid NINT function
!$OMP PARALLEL PRIVATE(tid, jscat, iscat, ibin, u)
!$OMP DO SCHEDULE(DYNAMIC, cr_natoms/32)
DO j = 1, cr_natoms - 1
   !$ tid = OMP_GET_THREAD_NUM()
   jscat = cr_iscat(j) 
   IF (jscat.gt.0) THEN 
      u(1) = cr_pos(1,j) 
      u(2) = cr_pos(2,j) 
      u(3) = cr_pos(3,j) 
!                                                                       
!     --- get info on relative amount of atoms                          
!                                                                       
      natom_p (jscat, tid) = natom_p (jscat, tid) + 1 
!                                                                       
!------ --- loop over all different atom types                          
!                                                                       
      DO l = j + 1, cr_natoms 
         iscat = cr_iscat (l) 
         IF (iscat.gt.0) THEN 
           IF(cr_mole(j )==cr_mole(l)) THEN
              islook = 0   ! Atoms are within the same molecule
           ELSE
              islook = powder_look_mol(mole_type(cr_mole(j)),mole_type(cr_mole(l)))
           ENDIF
!if(j==1 .and. l==2) then
!write(*,*) 'Atom 1 ', jscat,cr_pos(:,j), cr_mole(j)
!write(*,*) 'Atom 2 ', iscat,cr_pos(:,l), cr_mole(l)
!write(*,*) 'islook', islook, look(jscat, iscat)
!endif
           v(1) = cr_pos(1, l) - u(1) 
           v(2) = cr_pos(2, l) - u(2) 
           v(3) = cr_pos(3, l) - u(3) 

!              ibin = nint (sqrt (v (1) **2 + v (2) **2 + v (3) **2)/ pow_del_hist)
            ibin =   int((sqrt (v (1) **2 + v (2) **2 + v (3) **2)+shift)/ pow_del_hist)
            histogram_p(ibin, look(jscat, iscat), islook, tid ) = &
            histogram_p(ibin, look(jscat, iscat), islook, tid ) + 1.0D0
!           IF(ier_ctrlc) THEN
!              ier_num = -14
!              ier_typ = ER_COMM
!              RETURN
!           ENDIF
!           IF(ier_num/=0) RETURN      ! An error occured or CTRL-C
         ENDIF 
      ENDDO 
   ENDIF 
ENDDO 
!$OMP END DO NOWAIT
!$OMP END PARALLEL
IF(ier_ctrlc .OR. ier_num/=0) THEN         ! Does not influence timing
   ier_num = -14
   ier_typ = ER_COMM
   DEALLOCATE(look   )
   DEALLOCATE(partial)
   DEALLOCATE(histogram)
   DEALLOCATE(histogram_p)
   DEALLOCATE(natom_p)
   RETURN
ENDIF
!IF(nthreads>0) THEN
   natom  (:  )     = SUM(natom_p, DIM=2)
   histogram(:,:,:) = SUM(histogram_p,DIM=4)
!ENDIF
!open(78,file='hist.mole',status='unknown')
!do i=1, Ubound(histogram,1)
!  write(78,*) i, histogram(i,:,:)
!enddo
!close(78)
!
!     Check for entries in histogram (0,*,*) ==> atoms at distance ZERO
!
i= 0
DO j=1,nlook
   i = MAX(DBLE(i), histogram(0,j,0))
ENDDO
IF(i > 0) THEN    ! Entries in histogram(0,*) exist, flag Error
   ier_num = -123
   ier_typ = ER_APPL
   DEALLOCATE(look)
   DEALLOCATE(partial)
   DEALLOCATE(histogram)
   RETURN
ENDIF
!
n_srch = MAXHIST               ! Find longest occupied entry in histogram
srch: DO l=MAXHIST, 1, -1
   DO j=1,nlook
      DO k=1,nlook_mol
         IF(histogram(l,j,k) >0.0D0) THEN
            n_srch = l             ! Limit convolution / Fourier range
            EXIT srch
         ENDIF
      ENDDO
   ENDDO
ENDDO  srch
!
deb_conv = .FALSE.

qbroad  = pdf_qalp
cquad_a = pdf_cquad_a
clin_a  = pdf_clin_a
IF(qbroad > 0.0 .OR. cquad_a>0.0 .OR. clin_a>0.0) deb_conv = .TRUE.
IF(deb_conv) THEN
   cquad_m(:) = 0.0D0
   clin_m(:)  = 0.0D0
   nmol_type = 0
   bval_mol(:) = 0
   deltar = DBLE(pow_del_hist)
!write(*,*) ' WITH CONVOLUTION ', qbroad, cquad_a, clin_a
   CALL pow_pdf_convtherm(n_hist, nlook, nlook_mol, n_srch, histogram, is_look, &
              deltar, qbroad, cquad_a, clin_a, cquad_m, clin_m, nmol_type,      &
              bval_mol )
ENDIF
!                                                                       
!     --- Calculate the Fourier                                         
!                                                                       
DO i = 1, nlook 
   !$OMP PARALLEL PRIVATE(tid)
   !$OMP DO SCHEDULE(DYNAMIC, 1)
   DO j = 1, MAXHIST 
      !$ tid = OMP_GET_THREAD_NUM()
      DO il=0,nlook_mol
         IF (histogram (j, i,il) .gt.0.0D0) THEN 
            DO k = 1, num (1) * num (2) 
               arg  = zpi *DBLE((j * pow_del_hist) * (xm (1) + (k - 1) * uin (1) ) )
               iarg = INT( (j * pow_del_hist) * (xm (1) + (k - 1) * uin (1) ) * I2PI )
               iadd = IAND (iarg, MASK) 
               partial_p(k,i,il, tid) = partial_p(k,i,il, tid) + REAL(DBLE(histogram(j,i,il)) * sinetab(iadd)/arg)
!AAA!          partial(k,i,il) = partial(k,i,il) + REAL(DBLE(histogram(j,i,il)) * sinetab(iadd)    )
            ENDDO 
         ENDIF 
      ENDDO 
   ENDDO 
   !$OMP END DO NOWAIT
   !$OMP END PARALLEL
ENDDO 
partial(:,:,:)     = SUM(partial_p, DIM=4)
!
!                                                                       
!------ Multiply the partial structure factors with form factors,add    
!     to total sum                                                      
!                                                                       
      DO i = 1, cr_nscat 
         DO j = i, cr_nscat 
            DO k = 1, num (1) * num (2) 
               DO il=0,powder_nmol
                  rsf(k) = rsf (k) + 2.0D0 * partial (k, look (i, j),il ) *       &
                           (DBLE(cfact(powder_istl(k),i)) * DBLE (cfact(powder_istl(k),j)) +  &
                           aimag(cfact(powder_istl(k),i)) * aimag(cfact(powder_istl(k),j)))*  &
                           pow_dw(powder_istl(k),il)
               ENDDO 
            ENDDO 
         ENDDO 
      ENDDO 
!                                                                       
!                                                                       
!     add the f**2 weighted by relative amount to intensity             
!                                                                       
      DO iscat = 1, cr_nscat 
         DO i = 1, num (1) * num (2) 
            rsf(i) = rsf(i) + DBLE(cfact(powder_istl(i),iscat) * &
                             conjg(cfact(powder_istl(i),iscat))) * natom(iscat)
         ENDDO 
      ENDDO 
!
      DEALLOCATE(look)
      DEALLOCATE(partial)
      DEALLOCATE(histogram)
      ss = seknds (ss) 
      WRITE (output_io, 4000) ss 
!                                                                       
 4000 FORMAT     (/,' Elapsed time    : ',G13.6,' sec') 
END SUBROUTINE powder_debye_hist_cart_mole
!
!*******************************************************************************
!
SUBROUTINE pow_pdf_convtherm(nhist, nlook, nlook_mol, nsrch, histogram,   &
           is_look, &
           deltar, qbroad, cquad_a, clin_a, cquad_m, clin_m, nmol_type,   &
           bval_mol )
!
! Perform the convolution with the atomic ADP's, 
! Correct for Corrlin and / or Corrquad  and Qbroad
! The latter should be phased out and instead a convolution of the
! diffraction pattern by an appropriate profile function be performed
!
!
USE crystal_mod
!
USE errlist_mod
USE wink_mod
USE precision_mod
!
IMPLICIT NONE
!
INTEGER                        , INTENT(IN) :: nhist     ! Histogram length
INTEGER                        , INTENT(IN) :: nlook     ! No of atoms tpye lookup entries
INTEGER                        , INTENT(IN) :: nlook_mol ! No of molecule lookup entries
INTEGER                        , INTENT(INOUT) :: nsrch     ! Actual occupied Histogram length
REAL(KIND=PREC_DP), DIMENSION(0:nhist, 1:nlook, 0:nlook_mol), INTENT(INOUT) :: histogram
INTEGER,DIMENSION(1:2, 1:nlook), INTENT(IN) :: is_look
REAL(KIND=PREC_DP)             , INTENT(IN) :: deltar    ! Real space step width
REAL(KIND=PREC_SP)             , INTENT(IN) :: qbroad    ! Resolution broadening
REAL(KIND=PREC_SP)             , INTENT(IN) :: cquad_a   ! Quadratic correlation term for atoms
REAL(KIND=PREC_SP)             , INTENT(IN) :: clin_a    ! Linear    correlation term for atoms
REAL(KIND=PREC_SP), DIMENSION(0:nlook_mol), INTENT(IN) :: cquad_m   ! Linear correlation term for molecules
REAL(KIND=PREC_SP), DIMENSION(0:nlook_mol), INTENT(IN) :: clin_m    ! Linear correlation term for molecules
INTEGER                        , INTENT(IN) :: nmol_type ! No of molecule types
REAL(KIND=PREC_SP), DIMENSION(0:nmol_type), INTENT(IN) :: bval_mol  ! No of molecule types
!INTEGER                              , INTENT(IN) :: nexp ! Number of points in exponent curve
!REAL(KIND=PREC_DP), DIMENSION(0:nexp), INTENT(IN) :: expo ! Preset value in Gaussian function
!REAL(KIND=PREC_DP)                   , INTENT(IN) :: gauss_step  ! step width in Gaussian lookup
!
INTEGER            :: il            ! Lookup dummy
INTEGER            :: im            ! molecule dummy
INTEGER            :: is, js        ! Scattering types
INTEGER            :: ibin          !loop index bins
INTEGER            :: ib, ie        ! Begin, end of Gaussion profile
INTEGER            :: igaus         ! number of point in Gaussian
INTEGER            :: jgaus         ! loop limit    for Gaussian 
INTEGER            :: ig            ! loop variable for Gaussian 
REAL(KIND=PREC_DP), DIMENSION(:,:,:), ALLOCATABLE :: corr  ! Temporary, Corrected histogram 
REAL(KIND=PREC_DP) :: fac
REAL(KIND=PREC_DP) :: sqrt_zpi
REAL(KIND=PREC_DP) :: dist          ! Real space distance at bin position
REAL(KIND=PREC_DP) :: dist2         ! Real space distance^2 at bin position
REAL(KIND=PREC_DP) :: sigma         ! Gaussian sigma
REAL(KIND=PREC_DP) :: gnorm         ! Gaussian normalizer 
REAL(KIND=PREC_DP) :: factor        ! Gaussian lookup factor
REAL(KIND=PREC_DP) :: fac4          ! Gaussian terms
REAL(PREC_DP), DIMENSION(:), ALLOCATABLE :: gauss   ! Gaussian curve
!
IF(.NOT. ALLOCATED(expo)) THEN     ! need to set up exponential lookup table
   CALL expo_set
ENDIF
fac         = 1.0D0/(2.0D0 * zpi**2)
sqrt_zpi    = 1.0D0/SQRT(zpi)
ALLOCATE(corr(0:nhist, 1:nlook, 0:nlook_mol))
ALLOCATE(gauss(-nhist:nhist))
corr(:,:,:) = 0.0D0
gauss(:)    = 0.0D0
im = 0
!
loop_look: DO il= 1,nlook    ! Loop over all atom pairs
   is = is_look(1,il)
   js = is_look(2,il)
   bins: DO ibin=1, nsrch    ! Loop over all occupied points in histogram
      zero: IF(histogram(ibin, il, im)>0) THEN   ! Only if pairs are present at this distance
         dist  = ibin*deltar
         dist2 = dist*dist
         sigma = MAX(0.0D0,fac * (cr_dw(is)+cr_dw(js) + bval_mol(im))   &
                           - cquad_a/dist2 - cquad_m(im)                &
                           - clin_a /dist  - clin_m (im))
         sigma = SQRT(sigma + qbroad**2*dist2)
         igaus = 1 + INT(5.0*sigma/deltar + 0.5D0)    !no of points in Gaussian
         narrow: IF(sigma==0.0D0 .OR. igaus<2) THEN           ! Narrow peak
            corr(ibin,il,im) = corr(ibin,il,im) + histogram(ibin,il,im)
         ELSE narrow                                  ! Perform convolution
            ib    = MAX(1, ibin-igaus+1)                 ! Start point
            ie    = MIN(nhist, ibin+igaus-1)             ! Final point
            gnorm = sqrt_zpi/sigma
            factor= deltar/gauss_step/sigma
            fac4  = deltar/dist
            jgaus = MIN(igaus, INT(nexp/factor), UBOUND(gauss,1))
            DO ig = -jgaus, jgaus
               gauss(ig) = gnorm*(1+ig*fac4)*expo(ABS(INT(ABS(ig)*factor)))
            ENDDO
            DO ig=ib,ie
                corr(ig  ,il,im) = corr(ig  ,il,im) + histogram(ibin,il,im) * &
                                   gauss(ig-ibin)
            ENDDO
         ENDIF narrow 
      ENDIF zero
   ENDDO bins
ENDDO loop_look
!
DO ibin=0,nhist
   DO il= 1,nlook
      DO im=0,nlook_mol
         histogram(ibin, il, im) = corr(ibin, il, im)*deltar
      ENDDO
   ENDDO
ENDDO
srch: DO ibin=nhist,nsrch, -1
   DO il= 1,nlook
      DO im=0,nlook_mol
         IF(histogram(ibin,il, im) > 0.0) THEN
            nsrch = ibin
            EXIT srch
        ENDif
      ENDDO
   ENDDO
ENDDO srch
!rite(*,*) ' DELTAR ', deltar, gauss_step
!
DEALLOCATE(corr)
DEALLOCATE(gauss)
!
END SUBROUTINE pow_pdf_convtherm
!
!*****7*****************************************************************
!
SUBROUTINE powder_trans_atoms_tocart (uvw_out)
!-                                                                      
!     transforms atom coordinates into a cartesian space                
!     Warning, only the fractional coordinates are transformed,         
!     the unit cell and space group information is not touched.         
!+                                                                      
      USE discus_config_mod 
      USE crystal_mod 
      USE discus_plot_mod 
      USE trans_sup_mod
      IMPLICIT none 
!                                                                       
      REAL ,DIMENSION(1:3), INTENT(OUT) :: uvw_out !(3)
!
      INTEGER              ::  i
      LOGICAL, PARAMETER   :: lscreen = .false. 
      REAL, DIMENSION(1:4) :: uvw
      REAL             :: xmin
      REAL             :: xmax
      REAL             :: ymin
      REAL             :: ymax
      REAL             :: zmin
      REAL             :: zmax
!                                                                       
      xmin = 0.0
      xmax = 0.0
      ymin = 0.0
      ymax = 0.0
      zmin = 0.0
      zmax = 0.0
      uvw(4) = 1.0
!         
      DO i = 1, cr_natoms 
         uvw (1) = cr_pos (1, i) 
         uvw (2) = cr_pos (2, i) 
         uvw (3) = cr_pos (3, i) 
         CALL tran_ca (uvw, pl_tran_f, lscreen) 
         cr_pos (1, i) = uvw (1) 
         cr_pos (2, i) = uvw (2) 
         cr_pos (3, i) = uvw (3) 
         xmin = MIN(xmin,uvw(1))
         xmax = MAX(xmax,uvw(1))
         ymin = MIN(ymin,uvw(2))
         ymax = MAX(ymax,uvw(2))
         zmin = MIN(zmin,uvw(3))
         zmax = MAX(zmax,uvw(3))
      ENDDO
      uvw_out (1) = ABS(xmax-xmin)
      uvw_out (2) = ABS(ymax-ymin)
      uvw_out (3) = ABS(zmax-zmin) 
!                                                                       
END SUBROUTINE powder_trans_atoms_tocart      
!
!*****7*****************************************************************
!
SUBROUTINE powder_trans_atoms_fromcart 
!-                                                                      
!     transforms atom coordinates from a cartesian space back           
!     to the original coordinates                                       
!     Warning, only the fractional coordinates are transformed,         
!     the unit cell and space group information is not touched.         
!+                                                                      
      USE discus_config_mod 
      USE crystal_mod 
      USE discus_plot_mod 
      USE trans_sup_mod
      IMPLICIT none 
!                                                                       
      INTEGER              :: i 
      LOGICAL, PARAMETER   :: lscreen = .false.
!                                                                       
      REAL, DIMENSION(1:4) ::  uvw !(4) 
!                                                                       
!                                                                       
      uvw(4) = 1.0
      DO i = 1, cr_natoms 
         uvw (1) = cr_pos (1, i) 
         uvw (2) = cr_pos (2, i) 
         uvw (3) = cr_pos (3, i) 
         CALL tran_ca (uvw, pl_tran_fi, lscreen) 
         cr_pos (1, i) = uvw (1) 
         cr_pos (2, i) = uvw (2) 
         cr_pos (3, i) = uvw (3) 
      ENDDO 
!                                                                       
END SUBROUTINE powder_trans_atoms_fromcart    
!
!*****7*****************************************************************
!
SUBROUTINE powder_dwmoltab (nlook_mol, pow_dw, powder_bvalue_mole)
!+                                                                      
!     This routine sets up the complex formfactor lookup table          
!     for all atom types. The range in sin(theta)/lambda is             
!     0 -> 2 in steps of 0.001. These values can be changed             
!     in the 'diffuse_mod.f90' file.                                        
!-                                                                      
      USE discus_config_mod 
      USE crystal_mod 
      USE diffuse_mod 
!                                                                       
      USE prompt_mod 
      IMPLICIT none 
!
      INTEGER,                                 INTENT(IN)  :: nlook_mol
      REAL   , DIMENSION(0:CFPKT,0:nlook_mol), INTENT(OUT) :: pow_dw
      REAL   , DIMENSION(0:nlook_mol)        , INTENT(IN ) :: powder_bvalue_mole
!                                                                       
      REAL    :: q2
      INTEGER :: iq, iscat 
!
!      IF (four_log) THEN 
         WRITE (output_io, 1000) 
!      ENDIF 
!                                                                       
      DO iscat = 0, nlook_mol 
         DO iq = 0, CFPKT 
            q2 = (REAL(iq) * REAL(CFINC)) **2 
!
            IF (powder_bvalue_mole(iscat)>0.0) THEN 
               pow_dw (iq, iscat) = exp ( - powder_bvalue_mole ( iscat ) * q2) 
            ELSE 
               pow_dw (iq, iscat) = 1.0
            ENDIF 
!
         ENDDO 
      ENDDO 
!                                                                       
 1000 FORMAT     (' Computing Molecular DW lookup table ...') 
END SUBROUTINE powder_dwmoltab                   
!
!*******************************************************************************
!
SUBROUTINE expo_set
!
USE precision_mod
!
IMPLICIT NONE
!
INTEGER            :: i
REAL(KIND=PREC_DP) :: factor
!
ALLOCATE(expo(0:nexp))
!
factor = -0.50D0*gauss_step**2
!
DO i=0, nexp
   expo(i) = EXP(factor*DBLE(i*i))
ENDDO
!
END SUBROUTINE expo_set
!
!*******************************************************************************
!
END MODULE powder_pdf_hist_mod
