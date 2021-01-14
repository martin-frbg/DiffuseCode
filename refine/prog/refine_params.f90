MODULE refine_params_mod
!
!  Variables related to the refined parameters 
!
IMPLICIT NONE
!
INTEGER                                        :: REF_MAXPARAM    = 0 ! maximum number of parameters
INTEGER                                        :: REF_MAXPARAM_FIX= 0 ! maximum number of fixed parameters
INTEGER                                        :: refine_par_n    = 0 ! number of parameters
INTEGER                                        :: refine_fix_n    = 0 ! number of fixed parameters
LOGICAL                                        :: refine_autoconstr =.TRUE. ! Do automatic constraints
LOGICAL          , DIMENSION(0:3)              :: refine_fwhm       = .FALSE. ! u,v,w, are refined=TRUE or fixed=FALSE
INTEGER          , DIMENSION(3)                :: refine_fwhm_ind = HUGE(0) ! u,v,w, are at these locations in _p/ _f
CHARACTER(LEN=16), DIMENSION(:)  , ALLOCATABLE :: refine_params       ! parameter names
CHARACTER(LEN=16), DIMENSION(:)  , ALLOCATABLE :: refine_fixed        ! parameter names, fixed values
REAL             , DIMENSION(:,:), ALLOCATABLE :: refine_range        ! allowed parameter range
REAL             , DIMENSION(:)  , ALLOCATABLE :: refine_p            ! Current parameter value
REAL             , DIMENSION(:)  , ALLOCATABLE :: refine_f            ! Current fixed parameter value
REAL             , DIMENSION(:)  , ALLOCATABLE :: refine_dp           ! Current parameter sigma
REAL             , DIMENSION(:,:), ALLOCATABLE :: refine_cl           ! Correlation matrix
REAL             , DIMENSION(:,:), ALLOCATABLE :: refine_alpha        ! temporary Correlation matrix
REAL             , DIMENSION(:  ), ALLOCATABLE :: refine_beta         ! temporary parameter shift
REAL             , DIMENSION(:)  , ALLOCATABLE :: refine_shift        ! P*shift gives shift to calc derivative
INTEGER          , DIMENSION(:)  , ALLOCATABLE :: refine_nderiv       ! Number of p+n*DELTA to calc derivative
INTEGER          , DIMENSION(:)  , ALLOCATABLE :: refine_kderiv       ! KUPLOT data set that has derivative
!
END MODULE refine_params_mod
