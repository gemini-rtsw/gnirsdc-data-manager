; Miscellaneous IR array control routines, common to all detector types

POWER_OFF
	JSR	<CLEAR_SWITCHES_AND_DACS ; Clear switches and DACs
	BSET	#LVEN,X:HDR 		; Turn off low +/- 6.5, +/- 16.5 supplies
	BSET	#HVEN,X:HDR 		; Turn off high +36 supply
	JMP	<FINISH

; Start power-on cycle
POWER_ON
	JSR	<CLEAR_SWITCHES_AND_DACS ; Clear all analog switches
	JSR	<PON			; Turn on the power control board
	JCLR	#PWROK,X:HDR,PWR_ERR	; Test if the power turned on properly
	MOVE	#CONT_RST,R0		; Put controller in continuous readout
	MOVE	R0,X:<IDL_ADR		;   state
	JMP	<FINISH

; The power failed to turn on because of an error on the power control board
PWR_ERR	BSET	#LVEN,X:HDR		; Turn off the low voltage emable line
	BSET	#HVEN,X:HDR		; Turn off the high voltage emable line
	JMP	<ERROR

; Now ramp up the low voltages (+/- 6.5V, 16.5V) and delay them to turn on
PON	BSET	#CDAC,X:<LATCH		; Disable clearing of DACs
	MOVEP	X:LATCH,Y:WRLATCH	; Write it to the hardware

; Write all the bias voltages to the DACs
SET_BIASES
	BSET	#3,X:PCRD		; Turn the serial clock on
	BCLR	#1,X:<LATCH		; Separate updates of clock driver
	MOVEP	#$002000,Y:WRSS		; Set clock driver switches low
	MOVEP	#$003000,Y:WRSS
	BCLR	#LVEN,X:HDR		; LVEN = Low => Turn on +/- 6.5V, 
	BSET	#HVEN,X:HDR
	MOVE	#>40,A			; Delay for the power to turn on
	JSR	<MILLISEC_DELAY
	
; Write the values to the clock driver and DC bias supplies
	MOVE	#BIASES,R0		; Turn on the power before writing to
	JSR	<SET_DAC		;  the DACs since the MAX829 DAcs need
	MOVE	#CLOCKS,R0		;  power to be written to
	JSR	<SET_DAC
	JSR	<PAL_DLY

	BSET	#ENCK,X:<LATCH		; Enable the output switches
	MOVEP	X:LATCH,Y:WRLATCH
	BCLR	#3,X:PCRD		; Turn the serial clock off
	RTS

SET_BIAS_VOLTAGES
	JSR	<SET_BIASES
	JMP	<FINISH

CLR_SWS	JSR	<CLEAR_SWITCHES_AND_DACS
	JMP	<FINISH

CLEAR_SWITCHES_AND_DACS
	BCLR	#CDAC,X:<LATCH		; Clear all the DACs
	BCLR	#ENCK,X:<LATCH		; Disable all the output switches
	MOVEP	X:LATCH,Y:WRLATCH	; Write it to the hardware
	BSET	#3,X:PCRD	; Turn the serial clock on
	MOVE	#$0C3000,A	; Value of integrate speed and gain switches
	CLR	B
	MOVE	#$100000,X0	; Increment over board numbers for DAC writes
	MOVE	#$001000,X1	; Increment over board numbers for WRSS writes
	DO	#15,L_VIDEO	; Fifteen video processor boards maximum
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	ADD	X0,A
	MOVE	B,Y:WRSS
	JSR	<PAL_DLY	; Delay for the serial data transmission
	ADD	X1,B
L_VIDEO	
	BCLR	#3,X:PCRD		; Turn the serial clock off
	RTS

; Fast clear of the array, executed as a command
CLEAR	MOVE	#FRAME_RESET,R0
	CLOCK
	JMP     <FINISH

; Start the exposure timer and monitor its progress
EXPOSE	
	MOVEP	#0,X:TLR0		; Load 0 into counter timer
	MOVE	#0,X0
	MOVE	X0,X:<ELAPSED_TIME	; Set elapsed exposure time to zero
	MOVE	X:<EXPOSURE_TIME,B
	TST	B			; Special test for zero exposure time
	JEQ	<END_EXP		; Don't even start an exposure
	SUB	#1,B			; Timer counts from X:TCPR0+1 to zero
	BSET	#TIM_BIT,X:TCSR0	; Enable the timer #0
	MOVE	B,X:TCPR0
CHK_RCV	
	JCLR    #EF,X:HDR,CHK_TIM	; Simple test for fast execution
	MOVE	#COM_BUF,R3		; The beginning of the command buffer
	JSR	<GET_RCV		; Check for an incoming command
	JCS	<PRC_RCV		; If command is received, go check it
CHK_TIM	
	JCLR	#TCF,X:TCSR0,CHK_RCV	; Wait for timer to equal compare value
END_EXP	
	BCLR	#TIM_BIT,X:TCSR0	; Disable the timer
	JMP	(R7)			; This contains the return address

;  *****************  Start the exposure  *****************
;START_EXPOSURE
;	MOVE	#TST_RCV,R0		; Process commands, don't idle, 
;	MOVE	R0,X:<IDL_ADR		;    during the exposure
START_EXPOSURE
	JSR	<INIT_PCI_IMAGE_ADDRESS
	MOVE	#TST_RCV,R0		; Process commands, don't idle, 
	MOVE	R0,X:<IDL_ADR		;    during the exposure
	NOP
	JSR	<RESET_ARRAY		; Clear out the FPA
	NOP
	DO	Y:<NFS,RD1_END		; Fowler sampling
	JSR	<READOUT			; Read out the FPA
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
RD1_END
	MOVE	#L_SEX1,R7		; Return address at end of exposure
	JSR	<WAIT_TO_FINISH_CLOCKING
	JMP	<EXPOSE			; Delay for specified exposure time
L_SEX1
	DO	Y:<NFS,RD2_END		; Fowler sampling
	JSR	<READOUT			; Go read out the FPA
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
RD2_END
	MOVE	#CONT_RST,R0		; Continuously read array in idle mode
	MOVE	R0,X:<IDL_ADR
	NOP
	JMP	<START



; Test for continuous readout
	MOVE	Y:<N_FRAMES,A
	CMP	#1,A
	JLE	<INIT_PCI_BOARD
	
INIT_FRAME_COUNT
	JSR	<WAIT_TO_FINISH_CLOCKING	
	MOVE	#$020102,B		; Initialize the PCI frame counter
	JSR	<XMT_WRD
	MOVE	#'IFC',B
	JSR	<XMT_WRD
	MOVE	#0,X0
	MOVE	X0,Y:<I_FRAME		; Initialize the frame number
	JMP	<INIT_PCI_BOARD
	
; Start up the next frame of the coaddition series
NEXT_FRAME
	MOVE	Y:<I_FRAME,A		; Get the # of frames coadded so far
	ADD	#1,A
	MOVE	Y:<N_FRAMES,X0		; See if we've coadded enough frames
	MOVE	A1,Y:<I_FRAME		; Increment the coaddition frame counter
	CMP	X0,A
	JGE	<RDA_END		; End of coaddition sequence

	MOVE	Y:<IBUFFER,A		; Get the position in the buffer
	ADD	#1,A
	MOVE	Y:<N_FPB,X0
	MOVE	A1,Y:<IBUFFER
	CMP	X0,A
	JLT	<SEX_1			; Test if the frame buffer is full

INIT_PCI_BOARD
	MOVE	#0,X0
	MOVE	X0,Y:<IBUFFER		; IBUFFER counts from 0 to N_FPB
	MOVE	#$020102,B
	JSR	<XMT_WRD
	MOVE	#'IIA',B		; Initialize the PCI image address
	JSR	<XMT_WRD

; Start the exposure
SEX_1	JSET	#TST_IMG,X:STATUS,SYNTHETIC_IMAGE
	MOVE	#$0c1000,A		; Reset video processor FIFOs
	JSR	<WR_BIAS
	JSET	#ST_RRR,X:STATUS,ROW_BY_ROW_RESET_READOUT
	JMP	<NORMAL_READOUT


; ********************* Initialize PCI image address ***********************
INIT_PCI_IMAGE_ADDRESS
	MOVE	#$020102,B		; Initialize the PCI image address
	JSR	<XMT_WRD
	MOVE	#'IIA',B
	JSR	<XMT_WRD
	RTS

	
; Set the desired exposure time
SET_EXPOSURE_TIME
	MOVE	X:(R3)+,Y0
	MOVE	Y0,X:EXPOSURE_TIME
	JCLR	#TIM_BIT,X:TCSR0,FINISH	; Return if exposure not occurring
	MOVE	Y0,X:TCPR0		; Update timer if exposure in progress
	JMP	<FINISH

; Read the time remaining until the exposure ends
READ_EXPOSURE_TIME
	JSET	#TIM_BIT,X:TCSR0,RD_TIM	; Read DSP timer if its running
	MOVE	X:<ELAPSED_TIME,Y1
	JMP	<FINISH1
RD_TIM	MOVE	X:TCR0,Y1		; Read elapsed exposure time
	JMP	<FINISH1

; Pause the exposure - close the shutter and stop the timer
PAUSE_EXPOSURE
	MOVEP	X:TCR0,X:ELAPSED_TIME	; Save the elapsed exposure time
	BCLR    #TIM_BIT,X:TCSR0	; Disable the DSP exposure timer
	JMP	<FINISH

; Resume the exposure - open the shutter if needed and restart the timer
RESUME_EXPOSURE
	MOVEP	X:ELAPSED_TIME,X:TLR0	; Restore elapsed exposure time
	BSET	#TIM_BIT,X:TCSR0	; Re-enable the DSP exposure timer
L_RES	JMP	<FINISH

; Special ending after abort command to send a 'DON' to the host computer
; Abort exposure - close the shutter, stop the timer and resume idle mode
ABORT_EXPOSURE
	BCLR    #TIM_BIT,X:TCSR0	; Disable the DSP exposure timer
	MOVE	#CONT_RST,R0
	MOVE	R0,X:<IDL_ADR
	JSR	<WAIT_TO_FINISH_CLOCKING
	BCLR	#ST_RDC,X:<STATUS	; Set status to not reading out
	DO      #4000,*+3		; Wait 40 microsec for the fiber
	NOP				;  optic to clear out 
	JMP	<FINISH

; Short delay for the array to settle down after a global reset
MILLISEC_DELAY
	TST	A
	JNE	<DLY_IT
	RTS
DLY_IT	MOVEP	#0,X:TLR0		; Load 0 into counter timer
	BSET	#TIM_BIT,X:TCSR0	; Enable the timer #0
	MOVE	A,X:TCPR0		; Desired elapsed time
CNT_DWN	JCLR	#TCF,X:TCSR0,CNT_DWN	; Wait here for timer to count down
	BCLR	#TIM_BIT,X:TCSR0
	RTS
	
; Generate a synthetic image by simply incrementing the pixel counts
SYNTHETIC_IMAGE
	JSR	<PCI_READ_IMAGE
	CLR	A
	DO      Y:<NPR,LPR_TST      	; Loop over each line readout
	DO      Y:<NSR,LSR_TST		; Loop over number of pixels per line
	REP	#20			; #20 => 1.0 microsec per pixel
	NOP
	ADD	#1,A			; Pixel data = Pixel data + 1
	NOP
	MOVE	A,B
	JSR	<XMT_PIX		; Transmit the pixel data
	NOP
LSR_TST	
	NOP
LPR_TST	
        RTS

; Transmit the 16-bit pixel datum in B1 to the host computer
XMT_PIX	ASL	#16,B,B
	NOP
	MOVE	B2,X1
	ASL	#8,B,B
	NOP
	MOVE	B2,X0
	NOP
	MOVEP	X1,Y:WRFO
	MOVEP	X0,Y:WRFO
	RTS

; Write a number to an analog board over the serial link
WR_BIAS	BSET	#3,X:PCRD	; Turn on the serial clock
	JSR	<PAL_DLY
	JSR	<XMIT_A_WORD	; Transmit it to TIM-A-STD
	JSR	<PAL_DLY
	BCLR	#3,X:PCRD	; Turn off the serial clock
	JSR	<PAL_DLY
	RTS

; Alert the PCI interface board that images are coming soon
;   Image size = 512columns x 512 x # of Fowler samples x 2 if CDS

PCI_READ_IMAGE
	MOVE	#$020104,B		; Send header word to the FO transmitter
	JSR	<XMT_WRD
	MOVE	#'RDA',B
	JSR	<XMT_WRD
	MOVE	#'NSR',B			; Number of columns to read 512 for 1Q
	JSR	<XMT_WRD
	MOVE	#'NPR',B 		; 512 x 2FS x2 (because we always do CDS)
	JSR	<XMT_WRD		; Number of rows to read
	RTS

; Wait for the clocking to be complete before proceeding
WAIT_TO_FINISH_CLOCKING
	JSET	#SSFEF,X:PDRD,*		; Wait for the SS FIFO to be empty	
	RTS

; This MOVEP instruction executes in 30 nanosec, 20 nanosec for the MOVEP,
;   and 10 nanosec for the wait state that is required for SRAM writes and 
;   FIFO setup times. It looks reliable, so will be used for now.

; Core subroutine for clocking
CLOCK
	JCLR	#SSFHF,X:HDR,*		; Only write to FIFO if < half full
	NOP
	JCLR	#SSFHF,X:HDR,CLOCK	; Guard against metastability
	MOVE    Y:(R0)+,X0      	; # of waveform entries 
	DO      X0,CLK1                 ; Repeat X0 times
	MOVEP	Y:(R0)+,Y:WRSS		; 30 nsec Write the waveform to the SS 	
CLK1
	NOP
	RTS                     	; Return from subroutine

; Delay for serial writes to the PALs and DACs by 8 microsec
PAL_DLY	DO	#800,DLY	 ; Wait 8 usec for serial data transmission
	NOP
DLY	NOP
	RTS

; Read DAC values from a table, and write them to the DACs
SET_DAC	DO      Y:(R0)+,L_DAC		; Repeat Y:(R0)+ times
	MOVE	Y:(R0)+,A		; Read the table entry
	JSR	<XMIT_A_WORD		; Transmit it to TIM-A-STD
	NOP
	JSR	<PAL_DLY
	JSR	<PAL_DLY
	NOP
L_DAC	RTS

; Let the host computer read the controller configuration
READ_CONTROLLER_CONFIGURATION
	MOVE	Y:<CONFIG,Y1		; Just transmit the configuration
	JMP	<FINISH1

; Set a particular DAC numbers, for setting DC bias voltages, clock driver  
;   voltages and video processor offset
;
; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
;
;				#BOARD is from 0 to 15
;				#DAC number
;				#voltage is from 0 to 4095

SET_BIAS_NUMBER			; Set bias number
	BSET	#3,X:PCRD	; Turn on the serial clock
	MOVE	X:(R3)+,A	; First argument is board number, 0 to 15
	REP	#20
	LSL	A
	NOP
	MOVE	A,X1		; Save the board number
	MOVE	X:(R3)+,A	; Second argument is DAC number
	NOP
	MOVE	A1,Y:0		; Save the DAC number for a little while
	MOVE	X:(R3)+,B	; Third argument is 'VID' or 'CLK' string
	CMP	#'VID',B
	JEQ	<ERR_SBN	; Video board offsets aren't supported
	CMP	#'CLK',B
	JNE	<ERR_SBN

; For ARC32 do some trickiness to set the chip select and address bits
	MOVE	A1,B
	REP	#14
	LSL	A
	MOVE	#$0E0000,X0
	AND	X0,A
	MOVE	#>7,X0
	AND	X0,B		; Get 3 least significant bits of clock #
	CMP	#0,B
	JNE	<CLK_1
	BSET	#8,A
	JMP	<BD_SET
CLK_1	CMP	#1,B
	JNE	<CLK_2
	BSET	#9,A
	JMP	<BD_SET
CLK_2	CMP	#2,B
	JNE	<CLK_3
	BSET	#10,A
	JMP	<BD_SET
CLK_3	CMP	#3,B
	JNE	<CLK_4
	BSET	#11,A
	JMP	<BD_SET
CLK_4	CMP	#4,B
	JNE	<CLK_5
	BSET	#13,A
	JMP	<BD_SET
CLK_5	CMP	#5,B
	JNE	<CLK_6
	BSET	#14,A
	JMP	<BD_SET
CLK_6	CMP	#6,B
	JNE	<CLK_7
	BSET	#15,A
	JMP	<BD_SET
CLK_7	CMP	#7,B
	JNE	<BD_SET
	BSET	#16,A

BD_SET	OR	X1,A		; Add on the board number
	NOP
	MOVE	A,X0
	MOVE	X:(R3)+,A	; Fourth argument is voltage value, 0 to $fff
	REP	#4
	LSR	A		; Convert 12 bits to 8 bits for ARC32
	MOVE	#>$FF,Y0	; Mask off just 8 bits
	AND	Y0,A
	OR	X0,A
	NOP
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY	; Wait for the number to be sent
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<FINISH
ERR_SBN	MOVE	X:(R3)+,A	; Read and discard the fourth argument
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<ERROR

; Specify the MUX value to be output on the clock driver board
; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
;				#clock_driver_board from 0 to 15
;				#MUX1, #MUX2 from 0 to 23

SET_MUX	BSET	#3,X:PCRD	; Turn on the serial clock
	MOVE	X:(R3)+,A	; Clock driver board number
	REP	#20
	LSL	A
	MOVE	#$001000,X0	; Bits to select MUX on ARC32 board
	OR	X0,A
	NOP
	MOVE	A1,X1		; Move here for later use
	
; Get the first MUX number
	MOVE	X:(R3)+,A	; Get the first MUX number
	TST	A
	JLT	<ERR_SM1
	MOVE	#>24,X0		; Check for argument less than 32
	CMP	X0,A
	JGE	<ERR_SM1
	MOVE	A,B
	MOVE	#>7,X0
	AND	X0,B
	MOVE	#>$18,X0
	AND	X0,A
	JNE	<SMX_1		; Test for 0 <= MUX number <= 7
	BSET	#3,B1
	JMP	<SMX_A
SMX_1	MOVE	#>$08,X0
	CMP	X0,A		; Test for 8 <= MUX number <= 15
	JNE	<SMX_2
	BSET	#4,B1
	JMP	<SMX_A
SMX_2	MOVE	#>$10,X0
	CMP	X0,A		; Test for 16 <= MUX number <= 23
	JNE	<ERR_SM1
	BSET	#5,B1
SMX_A	OR	X1,B1		; Add prefix to MUX numbers
	NOP
	MOVE	B1,Y1

; Add on the second MUX number
	MOVE	X:(R3)+,A	; Get the next MUX number
	TST	A
	JLT	<ERR_SM2
	MOVE	#>24,X0		; Check for argument less than 32
	CMP	X0,A
	JGE	<ERR_SM2
	REP	#6
	LSL	A
	NOP
	MOVE	A,B
	MOVE	#$1C0,X0
	AND	X0,B
	MOVE	#>$600,X0
	AND	X0,A
	JNE	<SMX_3		; Test for 0 <= MUX number <= 7
	BSET	#9,B1
	JMP	<SMX_B
SMX_3	MOVE	#>$200,X0
	CMP	X0,A		; Test for 8 <= MUX number <= 15
	JNE	<SMX_4
	BSET	#10,B1
	JMP	<SMX_B
SMX_4	MOVE	#>$400,X0
	CMP	X0,A		; Test for 16 <= MUX number <= 23
	JNE	<ERR_SM2
	BSET	#11,B1
SMX_B	ADD	Y1,B		; Add prefix to MUX numbers
	NOP
	MOVE	B1,A
	AND	#$F01FFF,A	; Just to be sure
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY	; Delay for all this to happen
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<FINISH
ERR_SM1	MOVE	X:(R3)+,A	; Throw off the last argument
ERR_SM2	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<ERROR


CORRELATED_DOUBLE_SAMPLE
	MOVE	X:(R3)+,X0		; Get the command argument
	JSET	#0,X0,CDS_SET
	BCLR	#ST_CDS,X:STATUS  
	JMP	<FINISH
CDS_SET	BSET	#ST_CDS,X:STATUS
	JMP	<FINISH
	
SELECT_ROW_BY_ROW_RESET
	MOVE	X:(R3)+,X0		; Get the command argument
	JSET	#0,X0,RR_SET
	BCLR	#ST_RRR,X:STATUS  
	JMP	<FINISH
RR_SET	BSET	#ST_RRR,X:STATUS
	JMP	<FINISH

;******************************************************************************
; Set number of Fowler samples per frame
SET_NUMBER_OF_FOWLER_SAMPLES
	MOVE	X:(R3)+,X0
	MOVE	X0,Y:<NFS		; Number of Fowler samples
	JMP	<FINISH

;******************************************************************************
; Set the number of RESET frame. 
;SET_NUMBER_OF_RESET
;	MOVE	X:(R3)+,X0
;	MOVE	X0,Y:<NRESET
;	JMP	<FINISH


; Continuous readout commands
SET_NUMBER_OF_FRAMES			; Number of frames to obtain
	MOVE	X:(R3)+,X0		;   in an exposure sequence
	MOVE	X0,Y:<N_FRAMES
	JMP	<FINISH	

SET_NUMBER_OF_FRAMES_PER_BUFFER		; Number of frames in each image
	MOVE	X:(R3)+,X0		;   buffer in the host computer
	MOVE	X0,Y:<N_FPB		;   system memory
	JMP	<FINISH
