      SUBROUTINE TCARD8 (IQ,IRET)
C_Titl  TCARD8  Data input routine for  KRC system
C_Vars
      INCLUDE 'krcc8m.f'      ! has IMPLICIT NONE
      INCLUDE 'latc8m.f'
      INCLUDE 'dayc8m.f'
      INCLUDE 'filcom.inc'
      INCLUDE 'units.inc'
C_Args
      INTEGER*4 IQ              !in.    1 = read full set and optional changes
C                                   or start from disk
C                               2 = read change cards
      INTEGER*4 IRET            !out. status.  1 = normal start
C                       2 = restarted from disk record
C                       3 = continue from current conditions
C                       4 = Switch to "one-point" mode
C                       5 = END of data  OR error reading internal buffer
C_Desc  Reads all the  kinds of text input to KRC
C  If an I/O (read) error occurs, will print an error message and STOP
C_Calls  CLIMTAU  PORB08  PORBIT  SEASALB  SEASTAU  TDISK8  TPRINT8
C_Hist  85sep22  Hugh_H_Kieffer  First version was ~ 1971
C 87nov22  HK  Put in report if any input item reset
C 93mar93  ECisneros ported to unix
C 97jan30  HK  Changed name of  PORB call
C 98sep04  HK  Relax some constraints on  IB  &  N1
C 99dec07  HK  Add 'continue from memory' option
C 2006mar22  HK If I/O error on read of full card set, prints all current values.
C 2008oct02  HK  Replace  ID22(1) and (2) with  KVALB and  KVTAU
C 2008nov13  HK  Add  T-dependent conductivity parameters
C 2009feb24  HK  Briefly try using titcom.inc and block data for parameter titles
C 2009may10  HK  Add 1. to start date
C 2010jan12  HK  Use  IMPLICIT NONE
C 2010feb17  HK  Add T-dependent specific heat 
C  User can then look to see where zeros start as indication of error location.
C 2010jan23  HK  Fix error that allowed one-point mode to exit without limit check
C 2010apr21  HK  Add option for reading debug control integers
C 2011jul16  HK  Fix so  IC=0 does not generate error message for each case
C 2011jul31  HK  Add print of debug flags if they are read
C 2010feb26  HK  -Wall yields 'initialization string truncated to match variable'
C         at  SPEC_HEAT in DATA statement
C 2012mar27  HK  Incorporate  CLIMTAU
C 2012oct31 HK Minor format changes. Increment NRUN upon new file
C 2013jan29 HK@ASU Remove ability of switch to keyboard input. Eliminate error loop
C 2013jul24 HK Begin use of Version2 PORB system
C 2014jan21 HK If asked to restart, first call TDISK to close any open output file
C 2014feb25 HK Set most variables to *4. Untabify and justify
C_End6789012345678901234567890123456789012345678901234567890123456789012_4567890

      INTEGER*4 LNBLNK          ! function
      REAL*4 SEASALB,SEASTAU,CLIMTAU ! functions
      REAL*4 Q4,QF              ! temporary 
      REAL*8 Q8,XREAD           ! temporary 
      CHARACTER TEXT*74
      CHARACTER RBUF*80         ! internal file buffer
      CHARACTER*8 WHAT          ! distinguish what was expected to read 
      INTEGER*4 NFDR,NIDR,NLDR
      PARAMETER(NFDR = 64)      ! # of  REAL input variables
      PARAMETER(NIDR = 20)      ! # of  INTEGER input variables
      PARAMETER(NLDR = 20)      ! # of  LOGICAL input variables
      CHARACTER*8 TITF(NFDR) 
      CHARACTER*6 TITI(NIDR) 
      CHARACTER*6 TITL(NLDR) 

      INTEGER*4 KOUNT           ! number of changes cards read for this call

      INTEGER*4 I,IG,IIIN,ILEN,IREAD,JERR,KEEP,NEW,KDB
      
      DATA TITF /'ALBEDO','EMISS','INERTIA','COND2','DENS2','PERIOD'     !6
     & ,'SPEC_HEAT','DENSITY','CABR','AMW','ABRPHA','PTOTAL','FANON'     !7
     & ,'TATM','TDEEP','SpHeat2','TAUD','DUSTA','TAURAT','TWILI'         !7
     & ,'ARC2','ARC3','SLOPE','SLOAZI','TFROST','CFROST','AFROST'        !7
     & ,'FEMIS','AF1','AF2','FROEXT','spare','RLAY','FLAY','CONVF'       !8
     & ,'DEPTH','DRSET','DDT','GGT','DTMAX','DJUL','DELJUL','SolarDec'   !8
     & ,'DAU','L_S','SOLCON','GRAV','Atm_Cp','ConUp0','ConUp1','ConUp2'  !8
     & ,'ConUp3','ConLo0','ConLo1','ConLo2','ConLo3','SpHUp0','SpHUp1'   !7
     & ,'SpHUp2','SpHUp3','SpHLo0','SpHLo1','SpHLo2','SpHLo3'/ !6  total 64

      DATA TITI /'N1','N2','N3','N4','N5','N24','IB','IC'
     & ,'NRSET','NMHA','NRUN','JDISK','IDOWN','I1','I15','KPREF'
     & ,'K4OUT','JBARE','NMOD','IDISK2'/

      DATA TITL /'LP1','LP2','LP3','LP4','LP5','LP6'
     & ,'LPGLOB','LVFA','LVFT','LKofT','LPORB','LKEY','LSC','LNOTIF'
     & ,'LOCAL','LD16','LPTAVE','Prt.78','Prt.79','L_ONE'/

      IF (IDB2.GE.5) WRITE(IOSP,*) 'TCARD-A',IQ
C
      IRET=1                    ! normal return is a new case
      IF (J5.GT.1 .AND. J5.EQ.IDOWN) IRET=3 ! continue after changes
      KOUNT=0                   ! Number of change cards read
      JERR=0                    ! in case of IO error
D       WRITE(*,*)'TCARD entry  IQ,J5=',IQ,J5 !< dbug
D       WRITE(IOSP,*)'TCARD entry  IQ,J5=',IQ,J5 !< dbug
      GO TO (100,160), IQ
C
C initiate commons from input file or from disk saved record  (IQ = 1)
 100  NFD=NFDR                  ! transfer sizes into common
      NID=NIDR
      NLD=NLDR
      KDB=0
      IDB1=0
      IDB2=0
      IDB3=0
      IDB4=0
      IDB5=0
      IDB6=0
      READ (IOIN,*) KOLD,KEEP,KDB ! get: 0=input card set,  >0 = disk record
      IF (KDB.NE.0) THEN        ! Read and print debug flags
        READ (IOIN,*) IDB1,IDB2,IDB3,IDB4,IDB5,IDB6
        WRITE(*,*)   'IDB1:6=',IDB1,IDB2,IDB3,IDB4,IDB5,IDB6
        WRITE(IOSP,*)'IDB1:6=',IDB1,IDB2,IDB3,IDB4,IDB5,IDB6
      ENDIF
      IF (KOLD.NE.0) THEN
        IRET=2
        WRITE (IOPM,*)' OLD DATA FILE?'
        CALL TDISK8 (1,1)         ! open old file to read starting conditions
        CALL TDISK8 (3,KOLD)      ! read starting record; will override  KRCCOM
        IF (KEEP.EQ.0) THEN
          CALL TDISK8 (4,0)       ! close 'starting' file
        ELSE
          JDISK=J5       ! prepare to start saving to file after first new season
        ENDIF
      ELSE                      !  READ parameter cards
        READ (IOIN,'(A)'        ,END=430) KITLE
        READ (IOIN,'(/8F10.2)'  ,ERR=431,END=430) (FD(I),I=1,NFD)
        READ (IOIN,'(/8I10)'    ,ERR=432,END=430) (ID(I),I=1,NID)
        READ (IOIN,'(/10L7)'    ,ERR=433,END=430) (LD(I),I=1,NLD)
        PRINT *, 'TCARD:notice N4,MAXN4=',n4,MAXN4
        READ (IOIN,'(/(10F7.2))',ERR=434,END=430) (ALAT(I),I=1,N4)
        READ (IOIN,'(/(10F7.2))',ERR=435,END=430) (ELEV(I),I=1,N4)
      ENDIF
        
C  GET orbital parameters if needed
      IF (IDB1.GE.1) PRINT *,'Before PORB0'
      IF (LPORB) CALL PORB08
      IF (IDB1.GE.1) PRINT *,'AFTER PORB0'

C  READ a set of parameter change cards  (IQ = 2)

 160  READ (IOIN,'(A80)',ERR=436,END=430) RBUF ! read into character buffer
      KOUNT=KOUNT+1
      READ (RBUF,*,ERR=437,END=430) IG
      WRITE(*,*)'IG=',IG, '  RBUF=',RBUF
      IF (IG.LT.1) GOTO 370     ! no more changes
      IF (IG.LT.11) THEN        ! read a single parameter
        READ (RBUF,*,ERR=438,END=430) IG,IREAD,XREAD,TEXT
        ILEN = LNBLNK(TEXT)
        IF (.NOT. LONE .AND. KOUNT.EQ.1) THEN
          CALL TPRINT8 (8)       ! print page heading
          WRITE (IOSP,166)
 166      FORMAT ('--------- TYPE LOC VALUE -------- Parameter changes')
        ENDIF
 167    FORMAT (' Changed>>',2I4,G12.4,1X,A,2x,A)
        IF (IG.GT.3) WRITE (IOSP,167) IG,IREAD,XREAD,TEXT(1:ILEN)
      ENDIF
      GO TO (210,220,230,240,250,260,270,280,290,300,310,320,330), IG
C             1   2   3   4   5   6   7   8   9   10  11  12  13
C IG=Type     Meaning                                     Valid Index
C
C    0   End of Current Changes                              any
C    1   Real Parameter                                     1:NFDR
C    2   Integer Parameter                                  1:NIDR
C    3   Logical Parameter                                  1:NLDR
C    4   New Latitude Card(s) Follow                         any
C    5   New Elevation Card(s) Follow                        any
C    6   New Orbital Parm Cards Follow (LPORB Must be True)  any
C    7   Text becomes new Title                              any
C    8   Text becomes new disk or season-variation file name
C          if index=22, read variable ALBEDO
C          if index=23, read variable TAUD
C          if index=24, read climate opacity file
C    9   Complete new set of input follows                   any
C   10   Text becomes new One-Point input file name          any
C   11   This is a set of parameters for "one-point" model   none
C           For this type, 9 values must appear in a rigid format
C   12   Set of 2*4 coefficents for T-dep. conductivity.  List-directed IO
C   13   Set of 2*4 coefficents for T-dep. specific heat. List-directed IO 
C For 12 and 13, 8 white-space-separated coefficients must follow after 
C the type on the same line, with no interveneing index or text 

 210  IF (IREAD.LT.1 .OR. IREAD.GT.NFDR) GOTO 295
      FD(IREAD)=XREAD           !  IG=1: change  REAL parm
      WRITE (IOSP,167)IG,IREAD,XREAD,TEXT(1:ILEN),TITF(IREAD)
      GO TO 160

 220  IF (IREAD.LT.1 .OR. IREAD.GT.NIDR) GOTO 295
      ID(IREAD)=IDNINT(XREAD)     !  IG=2: change  INTEGER parm
C     IF (IREAD.EQ.12) NCASE=0 ! JDISK: 2009mar reason lost
      WRITE (IOSP,167)IG,IREAD,XREAD,TEXT(1:ILEN),TITI(IREAD)
      GO TO 160

 230  IF (IREAD.LT.1 .OR. IREAD.GT.NLDR) GOTO 295
      LD(IREAD)=XREAD.GT.0.D0     !  IG=3: change  LOGICAL parm
      WRITE (IOSP,167)IG,IREAD,XREAD,TEXT(1:ILEN),TITL(IREAD)
      GO TO 160

 240  READ (IIIN,'(10F7.2)',END=430) (ALAT(I),I=1,N4) !  IG=4: read latitudes
      GO TO 160

 250  READ (IIIN,'(10F7.2)',END=430) (ELEV(I),I=1,N4) !  IG=5: read elevations
      GO TO 160

 260  CALL PORB08                !  IG=6: read  PORB data lines
      GO TO 160

 270  READ (TEXT,'(A)',END=160) KITLE !  IG=7: change  TITLE
      GO TO 160

 280  IF (IREAD.EQ.22) THEN     ! IG=8 Read file name
        FVALB=TEXT              ! move file name into common
        I=SEASALB(-999.)        ! read data file
        KVALB=0                 ! set flag off
        IF (I.GT.1) KVALB=1     ! set variable albedo flag
      ELSEIF (IREAD.EQ.23) THEN 
        FVTAU=TEXT              ! move file name into common
        I=SEASTAU(-999.)        ! read data file
        KVTAU=0                 ! set flag off
        IF (I.GT.1) KVTAU=1     ! set variable tau flag
      ELSEIF (IREAD.EQ.24) THEN 
        FVTAU=TEXT              ! move file name into common
        QF=CLIMTAU(-999.,0.,Q4) ! read data file
        KVTAU=0                 ! set flag off
        IF (QF.EQ.0) KVTAU=2    ! set variable Climate flag
      ELSE
        CALL TDISK8 (4,0)         ! Default: new disk file name, close current
        FDISK = TEXT            ! move new file name into common
        NRUN=NRUN+1             ! increment run count
        WRITE (IOSP,*)NRUN,'=Run. New Disk file name= ',FDISK(1:ILEN)
      ENDIF
      WRITE(*,*)'TCARD_280',IREAD, I, KVALB,KVTAU
      GOTO 160

 295  WRITE(IOERR,*)'Invalid change index: ',RBUF ! 2nd value out of range for the type
      GOTO 160

 290  CALL TDISK8 (4,0)          ! must close disk file if one is open
      GOTO 100                  ! read complete new input set

 300  FINPUT=TEXT(1:ILEN)       ! 10. name of one-point input file
      IRET=4                    ! flag for switch to new input file
C       write(*,*)'TCARD setting IRET=4'
      GOTO 370

 310  XREAD=123.456D0            ! one-point model
      WHAT='1-Point'
      READ (RBUF,313,ERR=417,END=418) XREAD,ALAT(1),HOURO,ELEV(1) 
     &    ,ALB,SKRC,TAUD,SLOPE,SLOAZI,TITONE
C                  ls   lat hour Elev  Alb Iner Opac Slop Azim
 313  FORMAT(2X,F6.1,F6.1,F6.2,F5.1,F5.2,F7.1,F5.2,F5.1,F5.0,A20)
      CALL PORBIT (2,Q8,XREAD,SDEC,DAU) ! Q8 will be the MJD for Ls=XREAD
      DJUL=Q8-(N5-1)*DELJUL     ! starting date
      GOTO 390                  ! skip limit checks that one-point file cannot change
      
 320  WHAT='8-Cond.'
!     write(IOSP,*)' CCK Was',CCKU,CCKL
      READ (RBUF,*,ERR=417,END=418) IG,CCKU,CCKL !ConUp0:ConLo3
      write(IOSP,*)' CCK Now',CCKU,CCKL
      GO TO 160 

 330  WHAT='8-SpHt.'
!     write(IOSP,*)' CCK Was',CCPU,CCPL
      READ (RBUF,*,ERR=417,END=418) IG,CCPU,CCPL !SphUp0:SphLo3
      write(IOSP,*)' CCK Now',CCPU,CCPL
      GO TO 160
C
C quit if there was no interactive input
C
 370  IF (IQ.EQ.2 .AND. KOUNT.EQ.1) GOTO 430
C
C  NORMAL return -  Check input parameters.  Bound array dimensions
C
      N1PIB = N1                ! set lowest layer used in calculations
      IF (IB.GE.1) N1PIB=N1+1   !   :condition for constant  T_bottom
      IF (N1.LT.2   .OR. N1PIB.GT.MAXN1P) THEN
        NEW = MAXN1/2           ! ensure within dimen
        WRITE (IOERR,388) 'N1',N1,NEW
 388    FORMAT (/1X,A,' invalid. Input and reset = ',2I6)
        N1 = NEW
        N1PIB = N1              ! must reset 
        IF (IB.GE.1) N1PIB=N1+1 !
      ENDIF
      IF (IC2.LT.3 ) THEN       ! may not change first physical layer
        NEW=999      
        WRITE (IOERR,388) 'IC',IC2,NEW
        IC2 = NEW
      ENDIF
      IF (N2.LT.32 .OR. N2.GT.MAXN2) THEN
        NEW = MAXN2/2           ! ensure within dimen
        WRITE (IOERR,388) 'N2',N2,NEW
        N2 = NEW
      ENDIF
      IF (N3.LT.1 .OR. N3.GT.MAXN3-1) THEN ! 1 for j3+1 in  TDAY
        NEW = MAXN3/2        
        WRITE (IOERR,388) 'N3',N3,NEW
        N3 = NEW
      ENDIF
      IF (N4.LT.1  .OR. N4.GT.MAXN4) THEN
        NEW = MAXN4/2           ! ensure within dimen.
        WRITE (IOERR,388) 'N4',N4,NEW
        WRITE (IOERR,*) '^ This may cause Latitude read failure.'
        N4 = NEW
      ENDIF
      IF (N24.LT.2  .OR. N24.GT.MAXNH) THEN
        NEW = 24                ! ensure within dimen.
        WRITE (IOERR,388) 'N24',N24,NEW
        N24 = NEW
      ENDIF
      NMOD = MAX(NMOD,1)        ! ensure positive modulo
      IF (DRSET.LT.0. .OR. DRSET.GT.0.) THEN ! ensure reasonable
 389    FORMAT (/1X,A,' invalid. Input and reset = ',2g12.5)
        Q8=0.
        WRITE (IOERR,389) 'DRSET',DRSET,Q8
        DRSET=Q8
      ENDIF

 390  IF (TAUD.LT.0.) THEN      ! ensure physically valid
        Q8=0.
        WRITE (IOERR,389) 'TAUD',TAUD,Q8
        TAUD=Q8
      ENDIF
      GOTO 9

 417  WRITE(IOERR,*)'TCARD: Error reading internal buffer for ',WHAT
      IRET=5
      GOTO 9
 418  WRITE(IOERR,*)'TCARD: EOF reading internal buffer for ',WHAT
      IRET=5
      GOTO 9
C
C no more input data
C
 438  JERR=JERR+1
 437  JERR=JERR+1
 436  JERR=JERR+1
 435  JERR=JERR+1
 434  JERR=JERR+1  
 433  JERR=JERR+1
 432  JERR=JERR+1
 431  JERR=JERR+1
      WRITE (IOSP,*),'TCARD: IO error: at ',430+JERR
      N4=MAX(N4,1)
      CALL TPRINT8 (2)
      STOP

 430  IRET=5
      WRITE (IOSP,'(//5X,A)') 'END OF DATA ON INPUT UNIT'
      
 9    CONTINUE                  ! only exit from this routine
      IF (IDB1.NE.0) WRITE(IOSP,*)'TCARD Exit: IRET=',IRET,NFD,ID(1) !< dbug
      RETURN          
      END