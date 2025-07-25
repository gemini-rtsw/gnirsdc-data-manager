       COMMENT *

This file is used to generate DSP code for the Gen III = ARC-22 
	250 MHz timing boards to operate one quadrant of an 
	Aladdin III infrared array with one 8-channel ARC-46 video
	board.
	MODIFIED L BOUCHER SO WE DON'T RUN LAST_8INROWS WFM CLOCK
   *

   PAGE    132     ; Printronix page width - 132 columns

; Include the boot and header files so addressing is easy
	INCLUDE	"timboot.asm"

	ORG	P:,P:

CC	EQU	ARC22+ARC32+ARC46+CONT_RD

; Put number of words of application in P: for loading application from EEPROM
	DC	TIMBOOT_X_MEMORY-@LCV(L)-1

; Define CLOCK as a macro to produce in-line code to reduce execution time
CLOCK	MACRO
	JCLR	#SSFHF,X:HDR,*		; Don't overfill the WRSS FIFO
	REP	Y:(R0)+			; Repeat
	MOVEP	Y:(R0)+,Y:WRSS		; Write the waveform to the FIFO
	ENDM

; Continuously reset and read array, checking for commands every four rows
CONT_RST
	MOVE	#FRAME_RESET,R0
	CLOCK
	MOVE	#FRAME_RESET,R0
	CLOCK
	MOVE	#FRAME_RESET,R0
	CLOCK
	MOVE	#FRAME_RESET,R0
	CLOCK
	DO	#128,L_RESET
	MOVE	#CLOCK_ROW_1,R0
	CLOCK
	JSR	<CLK_COL
	MOVE	#CLOCK_ROW_2,R0
	CLOCK
	JSR	<CLK_COL
	MOVE	#CLOCK_ROW_3,R0
	CLOCK
	JSR	<CLK_COL
	MOVE	#CLOCK_ROW_4,R0
	CLOCK
	JSR	<CLK_COL
	MOVE	#(CLK2+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR),X0
	MOVE	X0,Y:WRSS
	
	MOVE	#COM_BUF,R3
	JSR	<GET_RCV		; Look for a new command every 4 rows
	JCC	<NO_COM			; If none, then stay here
	ENDDO
	JMP	<PRC_RCV
NO_COM	NOP
L_RESET
	JMP	<CONT_RST

; Simple clocking routine for resetting and clearing
CLK_COL	DO	#32,L_CLOCK
	MOVE	#CLOCK_COLUMN,R0
	CLOCK
L_CLOCK
	RTS

;  ************************  Readout subroutines  ********************
; Normal readout of the whole array

NORMAL_READOUT
;	;MOVE	#FRAME_RESET,R0
;	;CLOCK
;	JCLR	#ST_CDS,X:STATUS,*+3
;	JSR	<READOUT		; Read the array
;	JSR	<WAIT_TO_FINISH_CLOCKING
;	MOVE	#L_EXP1,R7		; Return address at end of exposure
;	JMP	<EXPOSE			; Delay for specified exposure time
;L_EXP1
;	JSR	<READOUT
;	JMP	<DONE_READOUT


RESET_ARRAY
	MOVE	#FRAME_RESET,R0
	JSR <CLOCK
	MOVE	#FRAME_RESET,R0
	JSR <CLOCK
	MOVE	#FRAME_RESET,R0
	JSR <CLOCK
	MOVE	#FRAME_RESET,R0
	JSR <CLOCK
	RTS

; Now start reading out the image with the frame initialization clocks first
READOUT	
	JSR	<PCI_READ_IMAGE
	MOVE	#FRAME_INIT,R0
	CLOCK
	DO	#128,L_READOUT
	MOVE	#CLOCK_ROW_1,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_ROW_2,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_ROW_3,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_ROW_4,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	JSR	<WAIT_TO_FINISH_CLOCKING
	NOP
L_READOUT

        MOVE	#CLOCK_ROW_1,R0
        CLOCK
        JSR	<CLK_COL_AND_READ

	MOVE	#FRAME_INIT,R0                 ;deselect last row by initializing 
	CLOCK

        JSR	<WAIT_TO_FINISH_CLOCKING
        NOP

	RTS


NO_READOUT	
;	JSR	<PCI_READ_IMAGE
	MOVE	#FRAME_INIT,R0
	CLOCK
	DO	#128,L_NO_READOUT
	MOVE	#CLOCK_ROW_1,R0
	CLOCK
	JSR	<CLK_COL_NO_READ
	MOVE	#CLOCK_ROW_2,R0
	CLOCK
	JSR	<CLK_COL_NO_READ
	MOVE	#CLOCK_ROW_3,R0
	CLOCK
	JSR	<CLK_COL_NO_READ
	MOVE	#CLOCK_ROW_4,R0
	CLOCK
	JSR	<CLK_COL_NO_READ
	JSR	<WAIT_TO_FINISH_CLOCKING
	NOP
L_NO_READOUT

        MOVE	#CLOCK_ROW_1,R0
        CLOCK
        JSR	<CLK_COL_NO_READ

	MOVE	#FRAME_INIT,R0                 ;deselect last row by initializing 
	CLOCK

        JSR	<WAIT_TO_FINISH_CLOCKING
        NOP

	RTS


; Row-by-row reset and readout, for high illumination levels
ROW_BY_ROW_RESET_READOUT
	JSR	<WAIT_TO_FINISH_CLOCKING
	BSET	#ST_RDC,X:<STATUS 	; Set status to reading out
	MOVE	#$020104,B		; Send header word to the FO transmitter
	JSR	<XMT_WRD
	MOVE	#'RDA',B
	JSR	<XMT_WRD
	MOVE	#1024,B			; Number of columns to read
	JSR	<XMT_WRD
	JSET	#ST_CDS,X:STATUS,RRR_CDS
	
; Read out the image in single read mode, row-by-row reset
	MOVE	#1024,B			; Number of rows to read
	JSR	<XMT_WRD
	MOVE	#FRAME_INIT,R0
	CLOCK
	DO	#128,L_RR_RESET_READOUT
	MOVE	#RESET_ROW_12,R0
	CLOCK
	JSR	<WAIT_TO_FINISH_CLOCKING
	MOVE	#L_RR12,R7
	JMP	<EXPOSE
L_RR12
	MOVE	#CLOCK_RR_ROW_1,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_RR_ROW_2,R0
	CLOCK
	JSR	<CLK_COL_AND_READ

	MOVE	#RESET_ROW_34,R0
	CLOCK
	JSR	<WAIT_TO_FINISH_CLOCKING
	MOVE	#L_RR34,R7
	JMP	<EXPOSE
L_RR34
	MOVE	#CLOCK_RR_ROW_3,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_RR_ROW_4,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	NOP
L_RR_RESET_READOUT

	JMP	<DONE_READOUT

; Read out the image in CDS mode, row-by-row reset
RRR_CDS	MOVE	#1024,B
	JSR	<XMT_WRD		; Number of rows to read
	MOVE	#FRAME_INIT,R0
	CLOCK
	DO	#128,CDS_RR_RESET_READOUT
	MOVE	#CLOCK_CDS_RESET_ROW_1,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_CDS_RESET_ROW_2,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	JSR	<WAIT_TO_FINISH_CLOCKING
	MOVE	#CDS_RR1,R7
	JMP	<EXPOSE
CDS_RR1
	MOVE	#CLOCK_RR_ROW_1,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_RR_ROW_2,R0
	CLOCK
	JSR	<CLK_COL_AND_READ

	MOVE	#CLOCK_CDS_RESET_ROW_3,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_CDS_RESET_ROW_4,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	JSR	<WAIT_TO_FINISH_CLOCKING
	MOVE	#CDS_RR3,R7
	JMP	<EXPOSE
CDS_RR3
	MOVE	#CLOCK_RR_ROW_3,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	MOVE	#CLOCK_RR_ROW_4,R0
	CLOCK
	JSR	<CLK_COL_AND_READ
	NOP
CDS_RR_RESET_READOUT

; This is code for continuous readout - check if more frames are needed
DONE_READOUT
	MOVE	Y:<N_FRAMES,A		; Are we in continuous readout mode?
	CMP	#1,A
	JLE	<RDA_END
	BCLR	#ST_RDC,X:<STATUS	; Set status to not reading out
	JSR	<WAIT_TO_FINISH_CLOCKING

; Check for a command once. Only the ABORT command should be issued.
	MOVE	#COM_BUF,R3
	JSR	<GET_RCV		; Was a command received?
	JCC	<NEXT_FRAME		; If no, get the next frame
	JMP	<PRC_RCV		; If yes, go process it

; Restore the controller to non-image data transfer and idling if necessary
RDA_END	MOVE	#CONT_RST,R0		; Process commands, don't idle, 
	MOVE	R0,X:<IDL_ADR		;    during the exposure
	BCLR	#ST_RDC,X:<STATUS	; Set status to not reading out
        JMP	<START


;  ********  End of readout routines  ****************

; Simple implementation
CONTRD	BSET	#TIM_BIT,X:TCSR0	; Enable the timer
	JMP	<START



CLK_COL_AND_READ

	DO	#32,L_CLOCK_COLUMN_AND_READ

	MOVE	#RD_COLS1,R0
        CLOCK

        DO    Y:<NDS,SAMPLE_A3
        MOVE  #SAMPLE_COL,R0                
        CLOCK
        NOP
SAMPLE_A3


	MOVE	#RD_COLS2,R0
        CLOCK


        DO    Y:<NDS,SAMPLE_A4
        MOVE  #SAMPLE_COL,R0  
        CLOCK
        NOP
SAMPLE_A4


	NOP

L_CLOCK_COLUMN_AND_READ

	CLOCK

	RTS


CLK_COL_NO_READ

	DO	#32,L_CLOCK_COLUMN_NO_READ

	MOVE	#RD_COLS1,R0
        CLOCK

	MOVE	#RD_COLS2,R0
        CLOCK

	NOP

L_CLOCK_COLUMN_NO_READ

	CLOCK

	RTS








; ******  Include many routines not directly needed for readout  *******
	INCLUDE "timIRmisc.asm"


TIMBOOT_X_MEMORY	EQU	@LCV(L)

;  ****************  Setup memory tables in X: space ********************

; Define the address in P: space where the table of constants begins

	IF	@SCP("DOWNLOAD","HOST")
	ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
	ENDIF

	IF	@SCP("DOWNLOAD","ROM")
	ORG     X:END_COMMAND_TABLE,P:
	ENDIF

; Application commands
	DC	'PON',POWER_ON
	DC	'POF',POWER_OFF
	DC	'SBL',SET_BIAS_VOLTAGES_L
	DC	'SBV',SET_BIAS_VOLTAGES
	DC	'SBH',SET_BIAS_VOLTAGES_H
	DC	'IDL',FINISH
	DC	'CLR',CLEAR    

; Exposure and readout control routines
	DC	'SET',SET_EXPOSURE_TIME
	DC	'RET',READ_EXPOSURE_TIME
	DC	'SEX',START_EXPOSURE
	DC	'SRL',START_RR_LINEAR
	DC	'SRE',START_RR_EXP
	DC	'PEX',PAUSE_EXPOSURE
	DC	'REX',RESUME_EXPOSURE
	DC	'AEX',ABORT_EXPOSURE
	DC	'ABR',ABORT_EXPOSURE
	DC	'CDS',CORRELATED_DOUBLE_SAMPLE
	DC	'RRR',SELECT_ROW_BY_ROW_RESET
	DC	'SFS',SET_NUMBER_OF_FOWLER_SAMPLES
	DC	'SDS',SET_NUMBER_OF_DIGITAL_SAMPLES
	DC	'SNC',SET_NUMBER_OF_CLOCKOUTS
	DC	'COA',CLOCKOUT_ARRAY_CMD
	DC	'RAR',RESET_ARRAY_CMD
	DC	'RRO',RESET_READOUT_CMD
	DC	'ROR',READOUT_ARRAY_CMD
	
; Support routines
	DC	'SBN',SET_BIAS_NUMBER
	DC	'SMX',SET_MUX
	DC	'CSW',CLR_SWS
	DC	'RCC',READ_CONTROLLER_CONFIGURATION 

; Continuous readout commands
	DC	'SNF',SET_NUMBER_OF_FRAMES
	DC	'FPB',SET_NUMBER_OF_FRAMES_PER_BUFFER

END_APPLICATON_COMMAND_TABLE	EQU	@LCV(L)

	IF	@SCP("DOWNLOAD","HOST")
NUM_COM			EQU	(@LCV(R)-COM_TBL_R)/2	; Number of boot + 
							;  application commands
EXPOSING		EQU	CHK_TIM			; Address if exposing
CONTINUE_READING	EQU	CONT_RD 		; Address if reading out
	ENDIF

	IF	@SCP("DOWNLOAD","ROM")
	ORG     Y:0,P:
	ENDIF

; Now let's go for the timing waveform tables
	IF	@SCP("DOWNLOAD","HOST")
        ORG     Y:0,Y:0
	ENDIF

GAIN	DC	END_APPLICATON_Y_MEMORY-@LCV(L)-1

NSR     DC      12288   ; 512 x6DS x4 for 4 Quadrants
NPR     DC      1024    ; 2048 = 2(CDS) x NFS=1 x 512
NSCLR	DC      0  		; Not used
NPCLR   DC      0    		; Not used 
DUMMY	DC	0,0		; Binning parameters (reserved)
TST_DAT	DC	0		; Temporary definition for test images
CONFIG	DC	CC		; Controller configuration
TRM_ADR	DC	0		; Test RAM memory error address
NFS		DC	1		; Number of Fowler samples
NDS		DC	1		; Number of Digital samples
NCO             DC      0              ; Number of clockouts

; Continuous readout parameters
N_FRAMES DC	1		; Total number of frames to read out
I_FRAME	DC	0		; Number of frames read out so far
IBUFFER	DC	0		; Number of frames read into the PCI buffer
N_FPB	DC	0		; Number of frames per PCI image buffer

; Include the waveform table for the designated IR array
	INCLUDE "WAVEFORM_FILE" ; Readout and clocking waveform file
   INCLUDE "CLOCK_ROW_RST.waveforms" ; 
   INCLUDE "CLOCK_GLOBAL_RST.waveforms" ; 
   INCLUDE "CLOCK_READOUT.waveforms" ; 

END_APPLICATON_Y_MEMORY	EQU	@LCV(L)

; End of program
	END

