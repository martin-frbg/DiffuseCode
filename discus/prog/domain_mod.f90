MODULE domain_mod
!
!
!     Variables for the cluster distributions
!
INTEGER             ::  clu_increment     = 200
INTEGER             ::  CLU_MAX_TYPE      =   1
!
INTEGER, PARAMETER  ::  CLU_IN_CLUSTER    = 0
INTEGER, PARAMETER  ::  CLU_IN_PSEUDO     = 1
!
INTEGER, PARAMETER  ::  CLU_CHAR_CUBE     = -1
INTEGER, PARAMETER  ::  CLU_CHAR_CYLINDER = -2
INTEGER, PARAMETER  ::  CLU_CHAR_SPHERE   = -3
INTEGER, PARAMETER  ::  CLU_CHAR_FUZZY    = -4
!
INTEGER, PARAMETER  ::  CLU_REMOVE_STRICT = 0
INTEGER, PARAMETER  ::  CLU_REMOVE_INITIAL= 1
INTEGER, PARAMETER  ::  CLU_REMOVE_TRUST  = 2
INTEGER, PARAMETER  ::  CLU_REMOVE_NONE   = 3
!
CHARACTER(LEN=200)                    ::  clu_infile = ' '
CHARACTER(LEN=200), DIMENSION(:),     ALLOCATABLE  ::  clu_content   ! (CLU_MAX_TYPE)
CHARACTER(LEN=  4), DIMENSION(:),     ALLOCATABLE  ::  clu_name      ! (CLU_MAX_TYPE)
!
INTEGER,            DIMENSION(:)    , ALLOCATABLE  ::  clu_character ! (CLU_MAX_TYPE)
REAL   ,            DIMENSION(:)    , ALLOCATABLE  ::  clu_fuzzy  ! (CLU_MAX_TYPE)
REAL   ,            DIMENSION(:,:,:), ALLOCATABLE  ::  clu_orient ! (CLU_MAX_TYPE,3,4)
REAL   ,            DIMENSION(:,:,:), ALLOCATABLE  ::  clu_shape  ! (CLU_MAX_TYPE,3,4)
REAL   ,            DIMENSION(:,:  ), ALLOCATABLE  ::  clu_sigma  ! (CLU_MAX_TYPE,3  )
INTEGER,            DIMENSION(:,:)  , ALLOCATABLE  ::  clu_mole_tab  ! (CLU_MAX_TYPE)
INTEGER                               ::  clu_index = 0
INTEGER                               ::  clu_mode  = CLU_IN_PSEUDO
INTEGER                               ::  clu_number  = 0               ! Total cluster type numbers
INTEGER                               ::  clu_current = 0               ! Current cluster type
!
LOGICAL                               ::  clu_surface = .FALSE.
LOGICAL                               ::  clu_infile_internal = .false. ! Is infile an internal file ?
INTEGER                               ::  clu_iatom = 0
!
INTEGER                               ::  clu_remove_mode = CLU_REMOVE_STRICT   ! Remove initial atoms or include prev domains
INTEGER                               ::  clu_remove_end  = 1  ! Initial last atom to remove
REAL                                  ::  clu_remove_dist = 0.0! Initial removal distance
!
INTEGER                               ::  clu_size_of! Bytes allocated for DOMAIN
!
END MODULE domain_mod
