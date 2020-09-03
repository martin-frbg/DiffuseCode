MODULE four_strucf_mod
!
CONTAINS
!*****7*****************************************************************
      SUBROUTINE four_strucf (iscat, lform) 
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
REAL(KIND=PREC_DP)        ::        xincu, xincv , xincw
REAL(KIND=PREC_DP)        ::        oincu, oincv , oincw
INTEGER (KIND=PREC_INT_LARGE)   :: h, i, ii, j, k, iarg, iarg0, iincu, iincv, iincw
INTEGER (KIND=PREC_INT_LARGE)   ::                              jincu, jincv, jincw
INTEGER (KIND=PREC_INT_LARGE), PARAMETER :: shift = -6
!
INTEGER :: IAND, ISHFT 
!
INTEGER                              :: tid       ! Id of this thread
INTEGER                              :: nthreads  ! Number of threadsa available from OMP
COMPLEX(KIND=PREC_DP), DIMENSION(:,:), ALLOCATABLE :: tcsfp     ! Partial structure factor from parallel OMP
!
tcsf = cmplx (0.0d0, 0.0d0)
IF(par_omp_use) THEN
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
ENDIF

!  Allocate, initialize tcsfp
!  PRINT *, 'nthreads=',nthreads,'MAXQXY: ', MAXQXY,'NAT ',nxat
   ALLOCATE (tcsfp (1:MAXQXY,0:nthreads-1))
   tcsfp = cmplx(0.0d0, 0.0d0, KIND=KIND(0.0D0))

!$OMP PARALLEL PRIVATE(tid,k,xincu,xincv,xincw,iincu,iincv,iincw,iarg,iarg0,ii,j,i,h)
!$OMP DO

!------ zero fourier array                                              
!                                                                       
!tcsf = CMPLX(0.0D0, 0.0D0, KIND=KIND(0.0D0)) 
!                                                                       
!------ Loop over all atoms in 'xat'                                    
!                                                                       
DO k = 1, nxat 
   tid = OMP_GET_THREAD_NUM()
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
            ii             = ii + 1 
            tcsfp(ii, tid) = tcsfp(ii, tid) + cex (IAND  (ISHFT(iarg, shift), MASK) )
            iarg           = iarg + iincw
         ENDDO 
      ENDDO 
   ENDDO 
ENDDO 
!$OMP END DO NOWAIT
!$OMP END PARALLEL
!
tcsf = SUM(tcsfp, DIM=2)
DEALLOCATE(tcsfp)
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
END SUBROUTINE four_strucf                    
!
END MODULE four_strucf_mod
