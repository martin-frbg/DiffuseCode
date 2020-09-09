MODULE four_strucf_mod
!
CONTAINS
!
!*****7*****************************************************************
!
SUBROUTINE four_strucf (iscat, lform) 
!
!+
!  Interface to four_strucf_serial((iscat, lform)
!           and four_strucf_omp((iscat, lform)
!-
USE parallel_mod
!
IMPLICIT NONE
!
INTEGER, INTENT(IN) :: iscat 
LOGICAL, INTENT(IN) :: lform 
!
IF(par_omp_use) THEN
   CALL four_strucf_omp(iscat, lform)
ELSE
   CALL four_strucf_serial(iscat, lform)
ENDIF
END SUBROUTINE four_strucf
!
!*******************************************************************************
!
SUBROUTINE four_strucf_omp(iscat, lform) 
!+                                                                      
!     Here the complex structure factor of 'nxat' identical atoms       
!     from array 'xat' is computed.                                     
!
!     The phase "iarg0" is calculated via integer math as offset from 
!     phase = 0 at hkl=0.
!-                                                                      
USE omp_lib
USE discus_config_mod 
USE diffuse_mod 
!
USE parallel_mod
USE precision_mod
!
IMPLICIT none 
!                                                                       
INTEGER, INTENT(IN) :: iscat 
LOGICAL, INTENT(IN) :: lform 
!                                                                       
REAL(KIND=PREC_DP)           , DIMENSION(nxat) ::        xincu, xincv , xincw
REAL(KIND=PREC_DP)           , DIMENSION(nxat) ::        oincu, oincv , oincw
INTEGER (KIND=PREC_INT_LARGE), DIMENSION(nxat) ::               iincu, iincv, iincw
INTEGER (KIND=PREC_INT_LARGE), DIMENSION(nxat) ::               jincu, jincv, jincw
INTEGER (KIND=PREC_INT_LARGE)   :: h, i, j, k
INTEGER (KIND=PREC_INT_LARGE), PARAMETER :: SHIFT = -6
INTEGER :: ii
INTEGER :: num23
!
INTEGER :: IAND, ISHFT 
!
INTEGER                              :: tid       ! Id of this thread
INTEGER                              :: nthreads  ! Number of threadsa available from OMP
 COMPLEX(KIND=PREC_DP), DIMENSION(:  ), ALLOCATABLE :: tcsfp     ! Partial structure factor from parallel OMP
!
!------ zero fourier array                                              
!                                                                       
!tcsf = CMPLX(0.0D0, 0.0D0, KIND=KIND(0.0D0)) 
tcsf = cmplx (0.0d0, 0.0d0)
nthreads = 1
tid = 0
!     Jump into OpenMP to obtain number of threads
!$OMP PARALLEL PRIVATE(tid)
   tid = OMP_GET_THREAD_NUM()
   IF (tid == 0) THEN
      IF(par_omp_maxthreads == -1) THEN
         nthreads = OMP_GET_NUM_THREADS()
      ELSE
         nthreads = MAX(1,MIN(par_omp_maxthreads, OMP_GET_NUM_THREADS()))
      ENDIF
   END IF
!$OMP END PARALLEL
!  Allocate, initialize tcsfp
IF(ALLOCATED(tcsfp)) DEALLOCATE(tcsfp)
ALLOCATE (tcsfp (0:MAXQXY-1)) !,0:nthreads-1))
tcsfp = cmplx(0.0d0, 0.0d0, KIND=KIND(0.0D0))
!
!$OMP PARALLEL
!$OMP DO SCHEDULE(STATIC)
DO k = 1, nxat 
   xincu(k) = uin(1)        * xat(k, 1) + uin(2)         * xat(k, 2) + uin(3)         * xat(k, 3)
   xincv(k) = vin(1)        * xat(k, 1) + vin(2)         * xat(k, 2) + vin(3)         * xat(k, 3)
   xincw(k) = win(1)        * xat(k, 1) + win(2)         * xat(k, 2) + win(3)         * xat(k, 3)
   oincu(k) = off_shift(1,1)* xat(k, 1) + off_shift(2,1) * xat(k, 2) + off_shift(3,1) * xat(k, 3)
   oincv(k) = off_shift(1,2)* xat(k, 1) + off_shift(2,2) * xat(k, 2) + off_shift(3,2) * xat(k, 3)
   oincw(k) = off_shift(1,3)* xat(k, 1) + off_shift(2,3) * xat(k, 2) + off_shift(3,3) * xat(k, 3)
!                                                                       
   iincu(k) = nint (64 * I2PI * (xincu(k) - int (xincu(k)) + 0.0d0) ) 
   iincv(k) = nint (64 * I2PI * (xincv(k) - int (xincv(k)) + 0.0d0) ) 
   iincw(k) = nint (64 * I2PI * (xincw(k) - int (xincw(k)) + 0.0d0) ) 
   jincu(k) = nint (64 * I2PI * (oincu(k) - int (oincu(k)) + 0.0d0) ) 
   jincv(k) = nint (64 * I2PI * (oincv(k) - int (oincv(k)) + 0.0d0) ) 
   jincw(k) = nint (64 * I2PI * (oincw(k) - int (oincw(k)) + 0.0d0) ) 
ENDDO
!$OMP END DO NOWAIT
!$OMP END PARALLEL
!                                                                       
!------ Loop over all atoms in 'xat'                                    
!                                                                       
num23 = num(2)*num(3)
!
!$OMP PARALLEL PRIVATE(j, i, h)
!$OMP DO SCHEDULE(STATIC)
DO ii = 0,num(1)*num(2)*num(3)-1
   j =          ii   / num23
   i = MOD(     ii   /num(3) , num(2))
   h = MOD(     ii           , num(3))
   DO k = 1, nxat 
      tcsfp(ii) = tcsfp(ii) + cex (IAND  (ISHFT(     &
              ((lmn(1)+j)*iincu(k) + (lmn(2)+i)*iincv(k) + (lmn(3)+h)*iincw(k) + &
                lmn(4)   *jincu(k) +  lmn(5)   *jincv(k) +  lmn(6)   *jincw(k))  &
                                                    , SHIFT), MASK) )
   ENDDO
ENDDO 
!$OMP END DO NOWAIT
!$OMP END PARALLEL
!
!------ Now we multiply with formfactor                                 
!                                                                       
IF (lform) then 
   DO  i = 1, num (1) * num (2) * num(3)
!  FORALL( i = 1: num (1) * num (2) * num(3))   !!! DO Loops seem to be faster!
      tcsf (i) = tcsfp(i-1) * cfact (istl (i), iscat) 
!  END FORALL
   END DO
ELSE
   DO ii = 1, num(1)*num(2)*num(3)
      tcsf(ii) = tcsfp(ii-1)
   ENDDO
ENDIF 
DEALLOCATE(tcsfp)
!                                                                       
END SUBROUTINE four_strucf_omp
!
!*****7*****************************************************************
!
SUBROUTINE four_strucf_serial (iscat, lform) 
!+                                                                      
!     Here the complex structure factor of 'nxat' identical atoms       
!     from array 'xat' is computed.                                     
!
!     The phase "iarg0" is calculated via integer math as offset from 
!     phase = 0 at hkl=0.
!-                                                                      
USE discus_config_mod 
USE diffuse_mod 
USE precision_mod
!
IMPLICIT none 
!                                                                       
INTEGER, INTENT(IN) :: iscat 
LOGICAL, INTENT(IN) :: lform 
!                                                                       
REAL(KIND=PREC_DP)        ::        xincu, xincv , xincw
REAL(KIND=PREC_DP)        ::        oincu, oincv , oincw
INTEGER (KIND=PREC_INT_LARGE)   :: h, i, ii, j, k, iarg, iarg0, iincu, iincv, iincw
INTEGER (KIND=PREC_INT_LARGE)   ::                              jincu, jincv, jincw
INTEGER (KIND=PREC_INT_LARGE), PARAMETER :: shift = -6
!
INTEGER :: IAND, ISHFT 
!
!------ zero fourier array                                              
!                                                                       
tcsf = CMPLX(0.0D0, 0.0D0, KIND=KIND(0.0D0)) 
!                                                                       
!------ Loop over all atoms in 'xat'                                    
!                                                                       
DO k = 1, nxat 
!        xarg0 = xm (1)        * xat(k, 1) + xm (2)         * xat(k, 2) + xm (3)         * xat(k, 3)
   xincu = uin(1)        * xat(k, 1) + uin(2)         * xat(k, 2) + uin(3)         * xat(k, 3)
   xincv = vin(1)        * xat(k, 1) + vin(2)         * xat(k, 2) + vin(3)         * xat(k, 3)
   xincw = win(1)        * xat(k, 1) + win(2)         * xat(k, 2) + win(3)         * xat(k, 3)
   oincu = off_shift(1,1)* xat(k, 1) + off_shift(2,1) * xat(k, 2) + off_shift(3,1) * xat(k, 3)
   oincv = off_shift(1,2)* xat(k, 1) + off_shift(2,2) * xat(k, 2) + off_shift(3,2) * xat(k, 3)
   oincw = off_shift(1,3)* xat(k, 1) + off_shift(2,3) * xat(k, 2) + off_shift(3,3) * xat(k, 3)
!                                                                       
!        iarg0 = nint (64 * I2PI * (xarg0 - int (xarg0) + 0.0d0) ) 
   iincu = nint (64 * I2PI * (xincu - int (xincu) + 0.0d0) ) 
   iincv = nint (64 * I2PI * (xincv - int (xincv) + 0.0d0) ) 
   iincw = nint (64 * I2PI * (xincw - int (xincw) + 0.0d0) ) 
   jincu = nint (64 * I2PI * (oincu - int (oincu) + 0.0d0) ) 
   jincv = nint (64 * I2PI * (oincv - int (oincv) + 0.0d0) ) 
   jincw = nint (64 * I2PI * (oincw - int (oincw) + 0.0d0) ) 
   iarg0 =  lmn(1)*iincu + lmn(2)*iincv + lmn(3)*iincw + &
            lmn(4)*jincu + lmn(5)*jincv + lmn(6)*jincw
   iarg = iarg0 
!                                                                       
!------ - Loop over all points in Q. 'iadd' is the address of the       
!------ - complex exponent table. 'IADD' divides out the 64 and         
!------ - ISHFT acts as MOD so that the argument stays in the table     
!------ - boundaries.                                                   
!                 iadd      = ISHFT (iarg, - 6) 
!                 iadd      = IAND  (iadd, MASK) 
!                 tcsf (ii) = tcsf (ii) + cex (iadd, MASK) )
!                 iarg      = iarg + iincw
!                                                                       
   ii = 0 
!                                                                       
   DO j = 0, num (1) - 1
      DO i = 0, num (2) - 1
         iarg = iarg0 + iincu*j + iincv*i 
         DO h = 1, num (3) 
            ii       = ii + 1 
            tcsf(ii) = tcsf (ii) + cex (IAND  (ISHFT(iarg, shift), MASK) )
            iarg     = iarg + iincw
         ENDDO 
      ENDDO 
   ENDDO 
ENDDO 
!
!------ Now we multiply with formfactor                                 
!                                                                       
IF (lform) then 
   DO  i = 1, num (1) * num (2) * num(3)
!  FORALL( i = 1: num (1) * num (2) * num(3))   !!! DO Loops seem to be faster!
      tcsf (i) = tcsf (i) * cfact (istl (i), iscat) 
!  END FORALL
   END DO
ENDIF 
!                                                                       
END SUBROUTINE four_strucf_serial
!
END MODULE four_strucf_mod
