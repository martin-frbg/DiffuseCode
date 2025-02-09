MODULE kuplot_load_shelx
!-
!  Contains routines to read a HDF5 file written by DISCUS
!+
!USE hdf5
!
USE kuplot_config
!
use lib_hdf5_read_mod
use lib_data_struc_h5
use hdf5_def_mod
USE precision_mod
!
IMPLICIT NONE
!
PRIVATE
PUBLIC shelx_read_kuplot
!PUBLIC hdf5_place_kuplot
!
!
CONTAINS
!
!*******************************************************************************
!
SUBROUTINE shelx_read_kuplot(infile, length, O_LAYER, O_TRANS, NOPTIONAL, opara, lopara,         &
                     lpresent, owerte, iz, ku_ndims,     &
                     ier_num, ier_typ, idims, ier_msg, ER_APPL, ER_IO, output_io)
!
use kuplot_global
!
USE ber_params_mod
use lib_data_struc_h5
use lib_load_mod
!
IMPLICIT NONE
!
CHARACTER(LEN=1024)                      , INTENT(INOUT) :: infile
INTEGER                                  , INTENT(IN) :: length
INTEGER                                  , INTENT(IN) :: O_LAYER
INTEGER                                  , INTENT(IN) :: O_TRANS
INTEGER                                  , INTENT(IN) :: NOPTIONAL
CHARACTER(LEN=*)   , DIMENSION(NOPTIONAL), INTENT(IN) :: opara
INTEGER            , DIMENSION(NOPTIONAL), INTENT(IN) :: lopara
LOGICAL            , DIMENSION(NOPTIONAL), INTENT(IN) :: lpresent
REAL(KIND=PREC_DP) , DIMENSION(NOPTIONAL), INTENT(IN) :: owerte
INTEGER                                  , INTENT(INOUT) :: iz     ! KUPLOT data set number
INTEGER, DIMENSION(  MAXKURVTOT)         , INTENT(INOUT) :: ku_ndims
!
INTEGER,                            INTENT(OUT)   :: ier_num
INTEGER,                            INTENT(OUT)   :: ier_typ
INTEGER,                            INTENT(IN )   :: idims
CHARACTER(LEN=*), DIMENSION(idims), INTENT(INOUT) :: ier_msg    ! Error message
INTEGER,                            INTENT(IN )   :: ER_APPL
INTEGER,                            INTENT(IN )   :: ER_IO
INTEGER, INTENT(IN)    :: output_io   ! KUPLOT array size
!
!
CHARACTER(LEN=14)   :: dataname    ! Dummy name for HDF5 datasets
!
integer               :: node_number = 0
integer               :: ndims = 0
integer               :: ik
integer, dimension(3) :: dims  = 1
logical               :: lout = .TRUE.
!
dataname = ' '
!
            call gen_load_hklf4(infile, node_number, lout)
            call dgl5_set_h5_is_ku(iz, node_number)
            call dgl5_set_ku_is_h5(node_number, iz)
            ku_ndims(iz) = 3
            ik = iz
            call dgl5_set_ku_is_h5(iz, node_number)
            call dgl5_set_h5_is_ku(node_number, iz)
!
            call data2kuplot(ik, infile  , lout  )
!
END SUBROUTINE shelx_read_kuplot
!
!*******************************************************************************
!
!
!*******************************************************************************
!
END MODULE kuplot_load_shelx
