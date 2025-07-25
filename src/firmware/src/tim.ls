Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 1



1                                 COMMENT *
2      
3                          This file is used to generate DSP code for the Gen III = ARC-22
4                                  250 MHz timing boards to operate one quadrant of an
5                                  Aladdin III infrared array with one 8-channel ARC-46 video
6                                  board.
7      
8                          ----------- Revision History
9                                  MODIFIED L BOUCHER SO WE DON'T RUN LAST_8INROWS WFM CLOCK
10                                 2025 March - Revision by Shane Jacobson to add pon/poff subroutines
11     
12                                 *
13     
14                                   PAGE    132                               ; Printronix page width - 132 columns
15     
16                         ; Include the boot and header files so addressing is easy
17                                   INCLUDE "timboot.asm"
18                         ;  This file is used to generate boot DSP code for the Gen III 250 MHz fiber
19                         ;       optic timing board = ARC22 using a DSP56303 as its main processor.
20     
21                         ; Various addressing control registers
22        FFFFFB           BCR       EQU     $FFFFFB                           ; Bus Control Register
23        FFFFF9           AAR0      EQU     $FFFFF9                           ; Address Attribute Register, channel 0
24        FFFFF8           AAR1      EQU     $FFFFF8                           ; Address Attribute Register, channel 1
25        FFFFF7           AAR2      EQU     $FFFFF7                           ; Address Attribute Register, channel 2
26        FFFFF6           AAR3      EQU     $FFFFF6                           ; Address Attribute Register, channel 3
27        FFFFFD           PCTL      EQU     $FFFFFD                           ; PLL control register
28        FFFFFE           IPRP      EQU     $FFFFFE                           ; Interrupt Priority register - Peripheral
29        FFFFFF           IPRC      EQU     $FFFFFF                           ; Interrupt Priority register - Core
30     
31                         ; Port E is the Synchronous Communications Interface (SCI) port
32        FFFF9F           PCRE      EQU     $FFFF9F                           ; Port Control Register
33        FFFF9E           PRRE      EQU     $FFFF9E                           ; Port Direction Register
34        FFFF9D           PDRE      EQU     $FFFF9D                           ; Port Data Register
35        FFFF9C           SCR       EQU     $FFFF9C                           ; SCI Control Register
36        FFFF9B           SCCR      EQU     $FFFF9B                           ; SCI Clock Control Register
37     
38        FFFF9A           SRXH      EQU     $FFFF9A                           ; SCI Receive Data Register, High byte
39        FFFF99           SRXM      EQU     $FFFF99                           ; SCI Receive Data Register, Middle byte
40        FFFF98           SRXL      EQU     $FFFF98                           ; SCI Receive Data Register, Low byte
41     
42        FFFF97           STXH      EQU     $FFFF97                           ; SCI Transmit Data register, High byte
43        FFFF96           STXM      EQU     $FFFF96                           ; SCI Transmit Data register, Middle byte
44        FFFF95           STXL      EQU     $FFFF95                           ; SCI Transmit Data register, Low byte
45     
46        FFFF94           STXA      EQU     $FFFF94                           ; SCI Transmit Address Register
47        FFFF93           SSR       EQU     $FFFF93                           ; SCI Status Register
48     
49        000009           SCITE     EQU     9                                 ; X:SCR bit set to enable the SCI transmitter
50        000008           SCIRE     EQU     8                                 ; X:SCR bit set to enable the SCI receiver
51        000000           TRNE      EQU     0                                 ; This is set in X:SSR when the transmitter
52                                                                             ;  shift and data registers are both empty
53        000001           TDRE      EQU     1                                 ; This is set in X:SSR when the transmitter
54                                                                             ;  data register is empty
55        000002           RDRF      EQU     2                                 ; X:SSR bit set when receiver register is full
56        00000F           SELSCI    EQU     15                                ; 1 for SCI to backplane, 0 to front connector
57     
58     
59                         ; ESSI Flags
60        000006           TDE       EQU     6                                 ; Set when transmitter data register is empty
61        000007           RDF       EQU     7                                 ; Set when receiver is full of data
62        000010           TE        EQU     16                                ; Transmitter enable
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 2



63     
64                         ; Phase Locked Loop initialization
65        050003           PLL_INIT  EQU     $050003                           ; PLL = 25 MHz x 2 = 100 MHz
66     
67                         ; Port B general purpose I/O
68        FFFFC4           HPCR      EQU     $FFFFC4                           ; Control register (bits 1-6 cleared for GPIO)
69        FFFFC9           HDR       EQU     $FFFFC9                           ; Data register
70        FFFFC8           HDDR      EQU     $FFFFC8                           ; Data Direction Register bits (=1 for output)
71     
72                         ; Port C is Enhanced Synchronous Serial Port 0 = ESSI0
73        FFFFBF           PCRC      EQU     $FFFFBF                           ; Port C Control Register
74        FFFFBE           PRRC      EQU     $FFFFBE                           ; Port C Data direction Register
75        FFFFBD           PDRC      EQU     $FFFFBD                           ; Port C GPIO Data Register
76        FFFFBC           TX00      EQU     $FFFFBC                           ; Transmit Data Register #0
77        FFFFB8           RX0       EQU     $FFFFB8                           ; Receive data register
78        FFFFB7           SSISR0    EQU     $FFFFB7                           ; Status Register
79        FFFFB6           CRB0      EQU     $FFFFB6                           ; Control Register B
80        FFFFB5           CRA0      EQU     $FFFFB5                           ; Control Register A
81     
82                         ; Port D is Enhanced Synchronous Serial Port 1 = ESSI1
83        FFFFAF           PCRD      EQU     $FFFFAF                           ; Port D Control Register
84        FFFFAE           PRRD      EQU     $FFFFAE                           ; Port D Data direction Register
85        FFFFAD           PDRD      EQU     $FFFFAD                           ; Port D GPIO Data Register
86        FFFFAC           TX10      EQU     $FFFFAC                           ; Transmit Data Register 0
87        FFFFA7           SSISR1    EQU     $FFFFA7                           ; Status Register
88        FFFFA6           CRB1      EQU     $FFFFA6                           ; Control Register B
89        FFFFA5           CRA1      EQU     $FFFFA5                           ; Control Register A
90     
91                         ; Timer module addresses
92        FFFF8F           TCSR0     EQU     $FFFF8F                           ; Timer control and status register
93        FFFF8E           TLR0      EQU     $FFFF8E                           ; Timer load register = 0
94        FFFF8D           TCPR0     EQU     $FFFF8D                           ; Timer compare register = exposure time
95        FFFF8C           TCR0      EQU     $FFFF8C                           ; Timer count register = elapsed time
96        FFFF83           TPLR      EQU     $FFFF83                           ; Timer prescaler load register => milliseconds
97        FFFF82           TPCR      EQU     $FFFF82                           ; Timer prescaler count register
98        000000           TIM_BIT   EQU     0                                 ; Set to enable the timer
99        000009           TRM       EQU     9                                 ; Set to enable the timer preloading
100       000015           TCF       EQU     21                                ; Set when timer counter = compare register
101    
102                        ; Board specific addresses and constants
103       FFFFF1           RDFO      EQU     $FFFFF1                           ; Read incoming fiber optic data byte
104       FFFFF2           WRFO      EQU     $FFFFF2                           ; Write fiber optic data replies
105       FFFFF3           WRSS      EQU     $FFFFF3                           ; Write switch state
106       FFFFF5           WRLATCH   EQU     $FFFFF5                           ; Write to a latch
107       010000           RDAD      EQU     $010000                           ; Read A/D values into the DSP
108       000009           EF        EQU     9                                 ; Serial receiver empty flag
109    
110                        ; DSP port A bit equates
111       000000           PWROK     EQU     0                                 ; Power control board says power is OK
112       000001           LED1      EQU     1                                 ; Control one of two LEDs
113       000002           LVEN      EQU     2                                 ; Low voltage power enable
114       000003           HVEN      EQU     3                                 ; High voltage power enable
115       00000E           SSFHF     EQU     14                                ; Switch state FIFO half full flag
116       00000A           EXT_IN0   EQU     10                                ; External digital I/O to the timing board
117       00000B           EXT_IN1   EQU     11
118       00000C           EXT_OUT0  EQU     12
119       00000D           EXT_OUT1  EQU     13
120    
121                        ; Port D equate
122       000001           SSFEF     EQU     1                                 ; Switch state FIFO empty flag
123    
124                        ; Other equates
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 3



125       000002           WRENA     EQU     2                                 ; Enable writing to the EEPROM
126    
127                        ; Latch U25 bit equates
128       000000           CDAC      EQU     0                                 ; Clear the analog board DACs
129       000002           ENCK      EQU     2                                 ; Enable the clock outputs
130       000004           SHUTTER   EQU     4                                 ; Control the shutter
131       000005           TIM_U_RST EQU     5                                 ; Reset the utility board
132    
133                        ; Software status bits, defined at X:<STATUS = X:0
134       000000           ST_RCV    EQU     0                                 ; Set to indicate word is from SCI = utility board
135       000002           IDLMODE   EQU     2                                 ; Set if need to idle after readout
136       000003           ST_SHUT   EQU     3                                 ; Set to indicate shutter is closed, clear for open
137       000004           ST_RDC    EQU     4                                 ; Set if executing 'RDC' command - reading out
138       000005           SPLIT_S   EQU     5                                 ; Set if split serial
139       000006           SPLIT_P   EQU     6                                 ; Set if split parallel
140       000007           MPP       EQU     7                                 ; Set if parallels are in MPP mode
141       000008           NOT_CLR   EQU     8                                 ; Set if not to clear CCD before exposure
142       00000A           TST_IMG   EQU     10                                ; Set if controller is to generate a test image
143       00000B           SHUT      EQU     11                                ; Set if opening shutter at beginning of exposure
144       00000C           ST_DITH   EQU     12                                ; Set if to dither during exposure
145       00000D           ST_SYNC   EQU     13                                ; Set if starting exposure on SYNC = high signal
146       00000E           ST_CNRD   EQU     14                                ; Set if in continous readout mode
147       00000F           ST_DIRTY  EQU     15                                ; Set if waveform tables need to be updated
148       000010           ST_SA     EQU     16                                ; Set if in subarray readout mode
149       000011           ST_CDS    EQU     17                                ; Set for correlated double sample readout
150       000012           ST_RRR    EQU     18                                ; Set if row-by-row reset while reading out and expos
ing
151    
152                        ; Address for the table containing the incoming SCI words
153       000400           SCI_TABLE EQU     $400
154    
155    
156                        ; Specify controller configuration bits of the X:STATUS word
157                        ;   to describe the software capabilities of this application file
158                        ; The bit is set (=1) if the capability is supported by the controller
159    
160    
161                                COMMENT *
162    
163                        BIT #'s         FUNCTION
164                        2,1,0           Video Processor
165                                                000     ARC41, CCD Rev. 3
166                                                001     CCD Gen I
167                                                010     ARC42, dual readout CCD
168                                                011     ARC44, 4-readout IR coadder
169                                                100     ARC45. dual readout CCD
170                                                101     ARC46 = 8-channel IR
171                                                110     ARC48 = 8 channel CCD
172                                                111     ARC47 = 4-channel CCD
173    
174                        4,3             Timing Board
175                                                00      ARC20, Rev. 4, Gen II
176                                                01      Gen I
177                                                10      ARC22, Gen III, 250 MHz
178    
179                        6,5             Utility Board
180                                                00      No utility board
181                                                01      ARC50
182    
183                        7               Shutter
184                                                0       No shutter support
185                                                1       Yes shutter support
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 4



186    
187                        9,8             Temperature readout
188                                                00      No temperature readout
189                                                01      Polynomial Diode calibration
190                                                10      Linear temperature sensor calibration
191    
192                        10              Subarray readout
193                                                0       Not supported
194                                                1       Yes supported
195    
196                        11              Binning
197                                                0       Not supported
198                                                1       Yes supported
199    
200                        12              Split-Serial readout
201                                                0       Not supported
202                                                1       Yes supported
203    
204                        13              Split-Parallel readout
205                                                0       Not supported
206                                                1       Yes supported
207    
208                        14              MPP = Inverted parallel clocks
209                                                0       Not supported
210                                                1       Yes supported
211    
212                        16,15           Clock Driver Board
213                                                00      ARC30 or ARC31
214                                                01      ARC32, CCD and IR
215                                                11      No clock driver board (Gen I)
216    
217                        19,18,17                Special implementations
218                                                000     Somewhere else
219                                                001     Mount Laguna Observatory
220                                                010     NGST Aladdin
221                                                xxx     Other
222                                *
223    
224                        CCDVIDREV3B
225       000000                     EQU     $000000                           ; CCD Video Processor Rev. 3
226       000000           ARC41     EQU     $000000
227       000001           VIDGENI   EQU     $000001                           ; CCD Video Processor Gen I
228       000002           IRREV4    EQU     $000002                           ; IR Video Processor Rev. 4
229       000002           ARC42     EQU     $000002
230       000003           COADDER   EQU     $000003                           ; IR Coadder
231       000003           ARC44     EQU     $000003
232       000004           CCDVIDREV5 EQU    $000004                           ; Differential input CCD video Rev. 5
233       000004           ARC45     EQU     $000004
234       000005           ARC46     EQU     $000005                           ; 8-channel IR video board
235       000006           ARC48     EQU     $000006                           ; 8-channel CCD video board
236       000007           ARC47     EQU     $000007                           ; 4-channel CCD video board
237       000000           TIMREV4   EQU     $000000                           ; Timing Revision 4 = 50 MHz
238       000000           ARC20     EQU     $000000
239       000008           TIMGENI   EQU     $000008                           ; Timing Gen I = 40 MHz
240       000010           TIMREV5   EQU     $000010                           ; Timing Revision 5 = 250 MHz
241       000010           ARC22     EQU     $000010
242       008000           ARC32     EQU     $008000                           ; CCD & IR clock driver board
243       000020           UTILREV3  EQU     $000020                           ; Utility Rev. 3 supported
244       000020           ARC50     EQU     $000020
245       000080           SHUTTER_CC EQU    $000080                           ; Shutter supported
246       000100           TEMP_POLY EQU     $000100                           ; Polynomial calibration
247                        TEMP_LINEAR
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 5



248       000200                     EQU     $000200                           ; Linear calibration
249       000400           SUBARRAY  EQU     $000400                           ; Subarray readout supported
250       000800           BINNING   EQU     $000800                           ; Binning supported
251                        SPLIT_SERIAL
252       001000                     EQU     $001000                           ; Split serial supported
253                        SPLIT_PARALLEL
254       002000                     EQU     $002000                           ; Split parallel supported
255       004000           MPP_CC    EQU     $004000                           ; Inverted clocks supported
256       018000           CLKDRVGENI EQU    $018000                           ; No clock driver board - Gen I
257       020000           MLO       EQU     $020000                           ; Set if Mount Laguna Observatory
258       040000           NGST      EQU     $040000                           ; NGST Aladdin implementation
259       100000           CONT_RD   EQU     $100000                           ; Continuous readout implemented
260    
261                        ; Special address for two words for the DSP to bootstrap code from the EEPROM
262                                  IF      @SCP("HOST","ROM")
269                                  ENDIF
270    
271                                  IF      @SCP("HOST","HOST")
272       P:000000 P:000000                   ORG     P:0,P:0
273       P:000000 P:000000 0C0190            JMP     <INIT
274       P:000001 P:000001 000000            NOP
275                                           ENDIF
276    
277                                 ;  This ISR receives serial words a byte at a time over the asynchronous
278                                 ;    serial link (SCI) and squashes them into a single 24-bit word
279       P:000002 P:000002 602400  SCI_RCV   MOVE              R0,X:<SAVE_R0           ; Save R0
280       P:000003 P:000003 052139            MOVEC             SR,X:<SAVE_SR           ; Save Status Register
281       P:000004 P:000004 60A700            MOVE              X:<SCI_R0,R0            ; Restore R0 = pointer to SCI receive regist
er
282       P:000005 P:000005 542300            MOVE              A1,X:<SAVE_A1           ; Save A1
283       P:000006 P:000006 452200            MOVE              X1,X:<SAVE_X1           ; Save X1
284       P:000007 P:000007 54A600            MOVE              X:<SCI_A1,A1            ; Get SRX value of accumulator contents
285       P:000008 P:000008 45E000            MOVE              X:(R0),X1               ; Get the SCI byte
286       P:000009 P:000009 0AD041            BCLR    #1,R0                             ; Test for the address being $FFF6 = last by
te
287       P:00000A P:00000A 000000            NOP
288       P:00000B P:00000B 000000            NOP
289       P:00000C P:00000C 000000            NOP
290       P:00000D P:00000D 205862            OR      X1,A      (R0)+                   ; Add the byte into the 24-bit word
291       P:00000E P:00000E 0E0013            JCC     <MID_BYT                          ; Not the last byte => only restore register
s
292       P:00000F P:00000F 545C00  END_BYT   MOVE              A1,X:(R4)+              ; Put the 24-bit word into the SCI buffer
293       P:000010 P:000010 60F400            MOVE              #SRXL,R0                ; Re-establish first address of SCI interfac
e
                            FFFF98
294       P:000012 P:000012 2C0000            MOVE              #0,A1                   ; For zeroing out SCI_A1
295       P:000013 P:000013 602700  MID_BYT   MOVE              R0,X:<SCI_R0            ; Save the SCI receiver address
296       P:000014 P:000014 542600            MOVE              A1,X:<SCI_A1            ; Save A1 for next interrupt
297       P:000015 P:000015 05A139            MOVEC             X:<SAVE_SR,SR           ; Restore Status Register
298       P:000016 P:000016 54A300            MOVE              X:<SAVE_A1,A1           ; Restore A1
299       P:000017 P:000017 45A200            MOVE              X:<SAVE_X1,X1           ; Restore X1
300       P:000018 P:000018 60A400            MOVE              X:<SAVE_R0,R0           ; Restore R0
301       P:000019 P:000019 000004            RTI                                       ; Return from interrupt service
302    
303                                 ; Clear error condition and interrupt on SCI receiver
304       P:00001A P:00001A 077013  CLR_ERR   MOVEP             X:SSR,X:RCV_ERR         ; Read SCI status register
                            000025
305       P:00001C P:00001C 077018            MOVEP             X:SRXL,X:RCV_ERR        ; This clears any error
                            000025
306       P:00001E P:00001E 000004            RTI
307    
308       P:00001F P:00001F                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 6



309       P:000030 P:000030                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
310       P:000040 P:000040                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
311    
312                                 ; Tune the table so the following instruction is at P:$50 exactly.
313       P:000050 P:000050 0D0002            JSR     SCI_RCV                           ; SCI receive data interrupt
314       P:000051 P:000051 000000            NOP
315       P:000052 P:000052 0D001A            JSR     CLR_ERR                           ; SCI receive error interrupt
316       P:000053 P:000053 000000            NOP
317    
318                                 ; *******************  Command Processing  ******************
319    
320                                 ; Read the header and check it for self-consistency
321       P:000054 P:000054 609F00  START     MOVE              X:<IDL_ADR,R0
322       P:000055 P:000055 018FA0            JSET    #TIM_BIT,X:TCSR0,EXPOSING         ; If exposing go check the timer
                            0004AA
323       P:000057 P:000057 0A00A4            JSET    #ST_RDC,X:<STATUS,CONTINUE_READING
                            100000
324       P:000059 P:000059 0AE080            JMP     (R0)
325    
326       P:00005A P:00005A 330700  TST_RCV   MOVE              #<COM_BUF,R3
327       P:00005B P:00005B 0D00A5            JSR     <GET_RCV
328       P:00005C P:00005C 0E005B            JCC     *-1
329    
330                                 ; Check the header and read all the remaining words in the command
331       P:00005D P:00005D 0C00FF  PRC_RCV   JMP     <CHK_HDR                          ; Update HEADER and NWORDS
332       P:00005E P:00005E 578600  PR_RCV    MOVE              X:<NWORDS,B             ; Read this many words total in the command
333       P:00005F P:00005F 000000            NOP
334       P:000060 P:000060 01418C            SUB     #1,B                              ; We've already read the header
335       P:000061 P:000061 000000            NOP
336       P:000062 P:000062 06CF00            DO      B,RD_COM
                            00006A
337       P:000064 P:000064 205B00            MOVE              (R3)+                   ; Increment past what's been read already
338       P:000065 P:000065 0B0080  GET_WRD   JSCLR   #ST_RCV,X:STATUS,CHK_FO
                            0000A9
339       P:000067 P:000067 0B00A0            JSSET   #ST_RCV,X:STATUS,CHK_SCI
                            0000D5
340       P:000069 P:000069 0E0065            JCC     <GET_WRD
341       P:00006A P:00006A 000000            NOP
342       P:00006B P:00006B 330700  RD_COM    MOVE              #<COM_BUF,R3            ; Restore R3 = beginning of the command
343    
344                                 ; Is this command for the timing board?
345       P:00006C P:00006C 448500            MOVE              X:<HEADER,X0
346       P:00006D P:00006D 579B00            MOVE              X:<DMASK,B
347       P:00006E P:00006E 459A4E            AND     X0,B      X:<TIM_DRB,X1           ; Extract destination byte
348       P:00006F P:00006F 20006D            CMP     X1,B                              ; Does header = timing board number?
349       P:000070 P:000070 0EA080            JEQ     <COMMAND                          ; Yes, process it here
350       P:000071 P:000071 0E909D            JLT     <FO_XMT                           ; Send it to fiber optic transmitter
351    
352                                 ; Transmit the command to the utility board over the SCI port
353       P:000072 P:000072 060600            DO      X:<NWORDS,DON_XMT                 ; Transmit NWORDS
                            00007E
354       P:000074 P:000074 60F400            MOVE              #STXL,R0                ; SCI first byte address
                            FFFF95
355       P:000076 P:000076 44DB00            MOVE              X:(R3)+,X0              ; Get the 24-bit word to transmit
356       P:000077 P:000077 060380            DO      #3,SCI_SPT
                            00007D
357       P:000079 P:000079 019381            JCLR    #TDRE,X:SSR,*                     ; Continue ONLY if SCI XMT is empty
                            000079
358       P:00007B P:00007B 445800            MOVE              X0,X:(R0)+              ; Write to SCI, byte pointer + 1
359       P:00007C P:00007C 000000            NOP                                       ; Delay for the status flag to be set
360       P:00007D P:00007D 000000            NOP
361                                 SCI_SPT
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 7



362       P:00007E P:00007E 000000            NOP
363                                 DON_XMT
364       P:00007F P:00007F 0C0054            JMP     <START
365    
366                                 ; Process the receiver entry - is it in the command table ?
367       P:000080 P:000080 0203DF  COMMAND   MOVE              X:(R3+1),B              ; Get the command
368       P:000081 P:000081 205B00            MOVE              (R3)+
369       P:000082 P:000082 205B00            MOVE              (R3)+                   ; Point R3 to the first argument
370       P:000083 P:000083 302800            MOVE              #<COM_TBL,R0            ; Get the command table starting address
371       P:000084 P:000084 062680            DO      #NUM_COM,END_COM                  ; Loop over the command table
                            00008B
372       P:000086 P:000086 47D800            MOVE              X:(R0)+,Y1              ; Get the command table entry
373       P:000087 P:000087 62E07D            CMP     Y1,B      X:(R0),R2               ; Does receiver = table entries address?
374       P:000088 P:000088 0E208B            JNE     <NOT_COM                          ; No, keep looping
375       P:000089 P:000089 00008C            ENDDO                                     ; Restore the DO loop system registers
376       P:00008A P:00008A 0AE280            JMP     (R2)                              ; Jump execution to the command
377       P:00008B P:00008B 205800  NOT_COM   MOVE              (R0)+                   ; Increment the register past the table addr
ess
378                                 END_COM
379       P:00008C P:00008C 0C008D            JMP     <ERROR                            ; The command is not in the table
380    
381                                 ; It's not in the command table - send an error message
382       P:00008D P:00008D 479D00  ERROR     MOVE              X:<ERR,Y1               ; Send the message - there was an error
383       P:00008E P:00008E 0C0090            JMP     <FINISH1                          ; This protects against unknown commands
384    
385                                 ; Send a reply packet - header and reply
386       P:00008F P:00008F 479800  FINISH    MOVE              X:<DONE,Y1              ; Send 'DON' as the reply
387       P:000090 P:000090 578500  FINISH1   MOVE              X:<HEADER,B             ; Get header of incoming command
388       P:000091 P:000091 469C00            MOVE              X:<SMASK,Y0             ; This was the source byte, and is to
389       P:000092 P:000092 330700            MOVE              #<COM_BUF,R3            ;     become the destination byte
390       P:000093 P:000093 46935E            AND     Y0,B      X:<TWO,Y0
391       P:000094 P:000094 0C1ED1            LSR     #8,B                              ; Shift right eight bytes, add it to the
392       P:000095 P:000095 460600            MOVE              Y0,X:<NWORDS            ;     header, and put 2 as the number
393       P:000096 P:000096 469958            ADD     Y0,B      X:<SBRD,Y0              ;     of words in the string
394       P:000097 P:000097 200058            ADD     Y0,B                              ; Add source board's header, set Y1 for abov
e
395       P:000098 P:000098 000000            NOP
396       P:000099 P:000099 575B00            MOVE              B,X:(R3)+               ; Put the new header on the transmitter stac
k
397       P:00009A P:00009A 475B00            MOVE              Y1,X:(R3)+              ; Put the argument on the transmitter stack
398       P:00009B P:00009B 570500            MOVE              B,X:<HEADER
399       P:00009C P:00009C 0C006B            JMP     <RD_COM                           ; Decide where to send the reply, and do it
400    
401                                 ; Transmit words to the host computer over the fiber optics link
402       P:00009D P:00009D 63F400  FO_XMT    MOVE              #COM_BUF,R3
                            000007
403       P:00009F P:00009F 060600            DO      X:<NWORDS,DON_FFO                 ; Transmit all the words in the command
                            0000A3
404       P:0000A1 P:0000A1 57DB00            MOVE              X:(R3)+,B
405       P:0000A2 P:0000A2 0D00EB            JSR     <XMT_WRD
406       P:0000A3 P:0000A3 000000            NOP
407       P:0000A4 P:0000A4 0C0054  DON_FFO   JMP     <START
408    
409                                 ; Check for commands from the fiber optic FIFO and the utility board (SCI)
410       P:0000A5 P:0000A5 0D00A9  GET_RCV   JSR     <CHK_FO                           ; Check for fiber optic command from FIFO
411       P:0000A6 P:0000A6 0E80A8            JCS     <RCV_RTS                          ; If there's a command, check the header
412       P:0000A7 P:0000A7 0D00D5            JSR     <CHK_SCI                          ; Check for an SCI command
413       P:0000A8 P:0000A8 00000C  RCV_RTS   RTS
414    
415                                 ; Because of FIFO metastability require that EF be stable for two tests
416       P:0000A9 P:0000A9 0A8989  CHK_FO    JCLR    #EF,X:HDR,TST2                    ; EF = Low,  Low  => CLR SR, return
                            0000AC
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 8



417       P:0000AB P:0000AB 0C00AF            JMP     <TST3                             ;      High, Low  => try again
418       P:0000AC P:0000AC 0A8989  TST2      JCLR    #EF,X:HDR,CLR_CC                  ;      Low,  High => try again
                            0000D1
419       P:0000AE P:0000AE 0C00A9            JMP     <CHK_FO                           ;      High, High => read FIFO
420       P:0000AF P:0000AF 0A8989  TST3      JCLR    #EF,X:HDR,CHK_FO
                            0000A9
421    
422       P:0000B1 P:0000B1 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
423       P:0000B3 P:0000B3 000000            NOP
424       P:0000B4 P:0000B4 000000            NOP
425       P:0000B5 P:0000B5 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
426       P:0000B7 P:0000B7 2B0000            MOVE              #0,B2
427       P:0000B8 P:0000B8 0140CE            AND     #$FF,B
                            0000FF
428       P:0000BA P:0000BA 0140CD            CMP     #>$AC,B                           ; It must be $AC to be a valid word
                            0000AC
429       P:0000BC P:0000BC 0E20D1            JNE     <CLR_CC
430       P:0000BD P:0000BD 4EF000            MOVE                          Y:RDFO,Y0   ; Read the MS byte
                            FFFFF1
431       P:0000BF P:0000BF 0C1951            INSERT  #$008010,Y0,B
                            008010
432       P:0000C1 P:0000C1 4EF000            MOVE                          Y:RDFO,Y0   ; Read the middle byte
                            FFFFF1
433       P:0000C3 P:0000C3 0C1951            INSERT  #$008008,Y0,B
                            008008
434       P:0000C5 P:0000C5 4EF000            MOVE                          Y:RDFO,Y0   ; Read the LS byte
                            FFFFF1
435       P:0000C7 P:0000C7 0C1951            INSERT  #$008000,Y0,B
                            008000
436       P:0000C9 P:0000C9 000000            NOP
437       P:0000CA P:0000CA 516300            MOVE              B0,X:(R3)               ; Put the word into COM_BUF
438       P:0000CB P:0000CB 0A0000            BCLR    #ST_RCV,X:<STATUS                 ; Its a command from the host computer
439       P:0000CC P:0000CC 000000  SET_CC    NOP
440       P:0000CD P:0000CD 0AF960            BSET    #0,SR                             ; Valid word => SR carry bit = 1
441       P:0000CE P:0000CE 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
442       P:0000D0 P:0000D0 00000C            RTS
443       P:0000D1 P:0000D1 0AF940  CLR_CC    BCLR    #0,SR                             ; Not valid word => SR carry bit = 0
444       P:0000D2 P:0000D2 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
445       P:0000D4 P:0000D4 00000C            RTS
446    
447                                 ; Test the SCI (= synchronous communications interface) for new words
448       P:0000D5 P:0000D5 44F000  CHK_SCI   MOVE              X:(SCI_TABLE+33),X0
                            000421
449       P:0000D7 P:0000D7 228E00            MOVE              R4,A
450       P:0000D8 P:0000D8 209000            MOVE              X0,R0
451       P:0000D9 P:0000D9 200045            CMP     X0,A
452       P:0000DA P:0000DA 0EA0D1            JEQ     <CLR_CC                           ; There is no new SCI word
453       P:0000DB P:0000DB 44D800            MOVE              X:(R0)+,X0
454       P:0000DC P:0000DC 446300            MOVE              X0,X:(R3)
455       P:0000DD P:0000DD 220E00            MOVE              R0,A
456       P:0000DE P:0000DE 0140C5            CMP     #(SCI_TABLE+32),A                 ; Wrap it around the circular
                            000420
457       P:0000E0 P:0000E0 0EA0E4            JEQ     <INIT_PROCESSED_SCI               ;   buffer boundary
458       P:0000E1 P:0000E1 547000            MOVE              A1,X:(SCI_TABLE+33)
                            000421
459       P:0000E3 P:0000E3 0C00E9            JMP     <SCI_END
460                                 INIT_PROCESSED_SCI
461       P:0000E4 P:0000E4 56F400            MOVE              #SCI_TABLE,A
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 9



                            000400
462       P:0000E6 P:0000E6 000000            NOP
463       P:0000E7 P:0000E7 567000            MOVE              A,X:(SCI_TABLE+33)
                            000421
464       P:0000E9 P:0000E9 0A0020  SCI_END   BSET    #ST_RCV,X:<STATUS                 ; Its a utility board (SCI) word
465       P:0000EA P:0000EA 0C00CC            JMP     <SET_CC
466    
467                                 ; Transmit the word in B1 to the host computer over the fiber optic data link
468                                 XMT_WRD
469       P:0000EB P:0000EB 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
470       P:0000ED P:0000ED 60F400            MOVE              #FO_HDR+1,R0
                            000002
471       P:0000EF P:0000EF 060380            DO      #3,XMT_WRD1
                            0000F3
472       P:0000F1 P:0000F1 0C1D91            ASL     #8,B,B
473       P:0000F2 P:0000F2 000000            NOP
474       P:0000F3 P:0000F3 535800            MOVE              B2,X:(R0)+
475                                 XMT_WRD1
476       P:0000F4 P:0000F4 60F400            MOVE              #FO_HDR,R0
                            000001
477       P:0000F6 P:0000F6 61F400            MOVE              #WRFO,R1
                            FFFFF2
478       P:0000F8 P:0000F8 060480            DO      #4,XMT_WRD2
                            0000FB
479       P:0000FA P:0000FA 46D800            MOVE              X:(R0)+,Y0              ; Should be MOVEP  X:(R0)+,Y:WRFO
480       P:0000FB P:0000FB 4E6100            MOVE                          Y0,Y:(R1)
481                                 XMT_WRD2
482       P:0000FC P:0000FC 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
483       P:0000FE P:0000FE 00000C            RTS
484    
485                                 ; Check the command or reply header in X:(R3) for self-consistency
486       P:0000FF P:0000FF 46E300  CHK_HDR   MOVE              X:(R3),Y0
487       P:000100 P:000100 579600            MOVE              X:<MASK1,B              ; Test for S.LE.3 and D.LE.3 and N.LE.7
488       P:000101 P:000101 20005E            AND     Y0,B
489       P:000102 P:000102 0E208D            JNE     <ERROR                            ; Test failed
490       P:000103 P:000103 579700            MOVE              X:<MASK2,B              ; Test for either S.NE.0 or D.NE.0
491       P:000104 P:000104 20005E            AND     Y0,B
492       P:000105 P:000105 0EA08D            JEQ     <ERROR                            ; Test failed
493       P:000106 P:000106 579500            MOVE              X:<SEVEN,B
494       P:000107 P:000107 20005E            AND     Y0,B                              ; Extract NWORDS, must be > 0
495       P:000108 P:000108 0EA08D            JEQ     <ERROR
496       P:000109 P:000109 44E300            MOVE              X:(R3),X0
497       P:00010A P:00010A 440500            MOVE              X0,X:<HEADER            ; Its a correct header
498       P:00010B P:00010B 550600            MOVE              B1,X:<NWORDS            ; Number of words in the command
499       P:00010C P:00010C 0C005E            JMP     <PR_RCV
500    
501                                 ;  *****************  Boot Commands  *******************
502    
503                                 ; Test Data Link - simply return value received after 'TDL'
504       P:00010D P:00010D 47DB00  TDL       MOVE              X:(R3)+,Y1              ; Get the data value
505       P:00010E P:00010E 0C0090            JMP     <FINISH1                          ; Return from executing TDL command
506    
507                                 ; Read DSP or EEPROM memory ('RDM' address): read memory, reply with value
508       P:00010F P:00010F 47DB00  RDMEM     MOVE              X:(R3)+,Y1
509       P:000110 P:000110 20EF00            MOVE              Y1,B
510       P:000111 P:000111 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
511       P:000113 P:000113 21B000            MOVE              B1,R0                   ; Need the address in an address register
512       P:000114 P:000114 20EF00            MOVE              Y1,B
513       P:000115 P:000115 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 10



514       P:000116 P:000116 0ACF14            JCLR    #20,B,RDX                         ; Test address bit for Program memory
                            00011A
515       P:000118 P:000118 07E087            MOVE              P:(R0),Y1               ; Read from Program Memory
516       P:000119 P:000119 0C0090            JMP     <FINISH1                          ; Send out a header with the value
517       P:00011A P:00011A 0ACF15  RDX       JCLR    #21,B,RDY                         ; Test address bit for X: memory
                            00011E
518       P:00011C P:00011C 47E000            MOVE              X:(R0),Y1               ; Write to X data memory
519       P:00011D P:00011D 0C0090            JMP     <FINISH1                          ; Send out a header with the value
520       P:00011E P:00011E 0ACF16  RDY       JCLR    #22,B,RDR                         ; Test address bit for Y: memory
                            000122
521       P:000120 P:000120 4FE000            MOVE                          Y:(R0),Y1   ; Read from Y data memory
522       P:000121 P:000121 0C0090            JMP     <FINISH1                          ; Send out a header with the value
523       P:000122 P:000122 0ACF17  RDR       JCLR    #23,B,ERROR                       ; Test address bit for read from EEPROM memo
ry
                            00008D
524       P:000124 P:000124 479400            MOVE              X:<THREE,Y1             ; Convert to word address to a byte address
525       P:000125 P:000125 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
526       P:000126 P:000126 2000B8            MPY     Y0,Y1,B                           ; Multiply
527       P:000127 P:000127 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
528       P:000128 P:000128 213000            MOVE              B0,R0                   ; Need to address memory
529       P:000129 P:000129 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
530       P:00012A P:00012A 0D0178            JSR     <RD_WORD                          ; Read word from EEPROM
531       P:00012B P:00012B 21A700            MOVE              B1,Y1                   ; FINISH1 transmits Y1 as its reply
532       P:00012C P:00012C 0C0090            JMP     <FINISH1
533    
534                                 ; Program WRMEM ('WRM' address datum): write to memory, reply 'DON'.
535       P:00012D P:00012D 47DB00  WRMEM     MOVE              X:(R3)+,Y1              ; Get the address to be written to
536       P:00012E P:00012E 20EF00            MOVE              Y1,B
537       P:00012F P:00012F 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
538       P:000131 P:000131 21B000            MOVE              B1,R0                   ; Need the address in an address register
539       P:000132 P:000132 20EF00            MOVE              Y1,B
540       P:000133 P:000133 46DB00            MOVE              X:(R3)+,Y0              ; Get datum into Y0 so MOVE works easily
541       P:000134 P:000134 0ACF14            JCLR    #20,B,WRX                         ; Test address bit for Program memory
                            000138
542       P:000136 P:000136 076086            MOVE              Y0,P:(R0)               ; Write to Program memory
543       P:000137 P:000137 0C008F            JMP     <FINISH
544       P:000138 P:000138 0ACF15  WRX       JCLR    #21,B,WRY                         ; Test address bit for X: memory
                            00013C
545       P:00013A P:00013A 466000            MOVE              Y0,X:(R0)               ; Write to X: memory
546       P:00013B P:00013B 0C008F            JMP     <FINISH
547       P:00013C P:00013C 0ACF16  WRY       JCLR    #22,B,WRR                         ; Test address bit for Y: memory
                            000140
548       P:00013E P:00013E 4E6000            MOVE                          Y0,Y:(R0)   ; Write to Y: memory
549       P:00013F P:00013F 0C008F            JMP     <FINISH
550       P:000140 P:000140 0ACF17  WRR       JCLR    #23,B,ERROR                       ; Test address bit for write to EEPROM
                            00008D
551       P:000142 P:000142 013D02            BCLR    #WRENA,X:PDRC                     ; WR_ENA* = 0 to enable EEPROM writing
552       P:000143 P:000143 460E00            MOVE              Y0,X:<SV_A1             ; Save the datum to be written
553       P:000144 P:000144 479400            MOVE              X:<THREE,Y1             ; Convert word address to a byte address
554       P:000145 P:000145 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
555       P:000146 P:000146 2000B8            MPY     Y1,Y0,B                           ; Multiply
556       P:000147 P:000147 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
557       P:000148 P:000148 213000            MOVE              B0,R0                   ; Need to address memory
558       P:000149 P:000149 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
559       P:00014A P:00014A 558E00            MOVE              X:<SV_A1,B1             ; Get the datum to be written
560       P:00014B P:00014B 060380            DO      #3,L1WRR                          ; Loop over three bytes of the word
                            000154
561       P:00014D P:00014D 07588D            MOVE              B1,P:(R0)+              ; Write each EEPROM byte
562       P:00014E P:00014E 0C1C91            ASR     #8,B,B
563       P:00014F P:00014F 469E00            MOVE              X:<C100K,Y0             ; Move right one byte, enter delay = 1 msec
564       P:000150 P:000150 06C600            DO      Y0,L2WRR                          ; Delay by 12 milliseconds for EEPROM write
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 11



                            000153
565       P:000152 P:000152 060CA0            REP     #12                               ; Assume 100 MHz DSP56303
566       P:000153 P:000153 000000            NOP
567                                 L2WRR
568       P:000154 P:000154 000000            NOP                                       ; DO loop nesting restriction
569                                 L1WRR
570       P:000155 P:000155 013D22            BSET    #WRENA,X:PDRC                     ; WR_ENA* = 1 to disable EEPROM writing
571       P:000156 P:000156 0C008F            JMP     <FINISH
572    
573                                 ; Load application code from P: memory into its proper locations
574       P:000157 P:000157 47DB00  LDAPPL    MOVE              X:(R3)+,Y1              ; Application number, not used yet
575       P:000158 P:000158 0D015A            JSR     <LOAD_APPLICATION
576       P:000159 P:000159 0C008F            JMP     <FINISH
577    
578                                 LOAD_APPLICATION
579       P:00015A P:00015A 60F400            MOVE              #$8000,R0               ; Starting EEPROM address
                            008000
580       P:00015C P:00015C 0D0178            JSR     <RD_WORD                          ; Number of words in boot code
581       P:00015D P:00015D 21A600            MOVE              B1,Y0
582       P:00015E P:00015E 479400            MOVE              X:<THREE,Y1
583       P:00015F P:00015F 2000B8            MPY     Y0,Y1,B
584       P:000160 P:000160 20002A            ASR     B
585       P:000161 P:000161 213000            MOVE              B0,R0                   ; EEPROM address of start of P: application
586       P:000162 P:000162 0AD06F            BSET    #15,R0                            ; To access EEPROM
587       P:000163 P:000163 0D0178            JSR     <RD_WORD                          ; Read number of words in application P:
588       P:000164 P:000164 61F400            MOVE              #(X_BOOT_START+1),R1    ; End of boot P: code that needs keeping
                            00022B
589       P:000166 P:000166 06CD00            DO      B1,RD_APPL_P
                            000169
590       P:000168 P:000168 0D0178            JSR     <RD_WORD
591       P:000169 P:000169 07598D            MOVE              B1,P:(R1)+
592                                 RD_APPL_P
593       P:00016A P:00016A 0D0178            JSR     <RD_WORD                          ; Read number of words in application X:
594       P:00016B P:00016B 61F400            MOVE              #END_COMMAND_TABLE,R1
                            000036
595       P:00016D P:00016D 06CD00            DO      B1,RD_APPL_X
                            000170
596       P:00016F P:00016F 0D0178            JSR     <RD_WORD
597       P:000170 P:000170 555900            MOVE              B1,X:(R1)+
598                                 RD_APPL_X
599       P:000171 P:000171 0D0178            JSR     <RD_WORD                          ; Read number of words in application Y:
600       P:000172 P:000172 310100            MOVE              #1,R1                   ; There is no Y: memory in the boot code
601       P:000173 P:000173 06CD00            DO      B1,RD_APPL_Y
                            000176
602       P:000175 P:000175 0D0178            JSR     <RD_WORD
603       P:000176 P:000176 5D5900            MOVE                          B1,Y:(R1)+
604                                 RD_APPL_Y
605       P:000177 P:000177 00000C            RTS
606    
607                                 ; Read one word from EEPROM location R0 into accumulator B1
608       P:000178 P:000178 060380  RD_WORD   DO      #3,L_RDBYTE
                            00017B
609       P:00017A P:00017A 07D88B            MOVE              P:(R0)+,B2
610       P:00017B P:00017B 0C1C91            ASR     #8,B,B
611                                 L_RDBYTE
612       P:00017C P:00017C 00000C            RTS
613    
614                                 ; Come to here on a 'STP' command so 'DON' can be sent
615                                 STOP_IDLE_CLOCKING
616       P:00017D P:00017D 305A00            MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
617       P:00017E P:00017E 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
618       P:00017F P:00017F 0A0002            BCLR    #IDLMODE,X:<STATUS                ; Don't idle after readout
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 12



619       P:000180 P:000180 0C008F            JMP     <FINISH
620    
621                                 ; Routines executed after the DSP boots and initializes
622       P:000181 P:000181 305A00  STARTUP   MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
623       P:000182 P:000182 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
624       P:000183 P:000183 44F400            MOVE              #50000,X0               ; Delay by 500 milliseconds
                            00C350
625       P:000185 P:000185 06C400            DO      X0,L_DELAY
                            000188
626       P:000187 P:000187 06E8A3            REP     #1000
627       P:000188 P:000188 000000            NOP
628                                 L_DELAY
629       P:000189 P:000189 57F400            MOVE              #$020002,B              ; Normal reply after booting is 'SYR'
                            020002
630       P:00018B P:00018B 0D00EB            JSR     <XMT_WRD
631       P:00018C P:00018C 57F400            MOVE              #'SYR',B
                            535952
632       P:00018E P:00018E 0D00EB            JSR     <XMT_WRD
633    
634       P:00018F P:00018F 0C0054            JMP     <START                            ; Start normal command processing
635    
636                                 ; *******************  DSP  INITIALIZATION  CODE  **********************
637                                 ; This code initializes the DSP right after booting, and is overwritten
638                                 ;   by application code
639       P:000190 P:000190 08F4BD  INIT      MOVEP             #PLL_INIT,X:PCTL        ; Initialize PLL to 100 MHz
                            050003
640       P:000192 P:000192 000000            NOP
641    
642                                 ; Set operation mode register OMR to normal expanded
643       P:000193 P:000193 0500BA            MOVEC             #$0000,OMR              ; Operating Mode Register = Normal Expanded
644       P:000194 P:000194 0500BB            MOVEC             #0,SP                   ; Reset the Stack Pointer SP
645    
646                                 ; Program the AA = address attribute pins
647       P:000195 P:000195 08F4B9            MOVEP             #$FFFC21,X:AAR0         ; Y = $FFF000 to $FFFFFF asserts commands
                            FFFC21
648       P:000197 P:000197 08F4B8            MOVEP             #$008909,X:AAR1         ; P = $008000 to $00FFFF accesses the EEPROM
                            008909
649       P:000199 P:000199 08F4B7            MOVEP             #$010C11,X:AAR2         ; X = $010000 to $010FFF reads A/D values
                            010C11
650       P:00019B P:00019B 08F4B6            MOVEP             #$080621,X:AAR3         ; Y = $080000 to $0BFFFF R/W from SRAM
                            080621
651    
652       P:00019D P:00019D 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Enable clearing of DACs
653       P:00019E P:00019E 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable clock and DAC output switches
654       P:00019F P:00019F 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Execute these two operations
                            00000F
655    
656                                 ; Program the DRAM memory access and addressing
657       P:0001A1 P:0001A1 08F4BB            MOVEP             #$028FE1,X:BCR          ; Bus Control Register
                            028FE1
658    
659                                 ; Program the Host port B for parallel I/O
660       P:0001A3 P:0001A3 08F484            MOVEP             #>1,X:HPCR              ; All pins enabled as GPIO
                            000001
661       P:0001A5 P:0001A5 08F489            MOVEP             #$810C,X:HDR
                            00810C
662       P:0001A7 P:0001A7 08F488            MOVEP             #$B10E,X:HDDR           ; Data Direction Register
                            00B10E
663                                                                                     ;  (1 for Output, 0 for Input)
664    
665                                 ; Port B conversion from software bits to schematic labels
666                                 ;       PB0 = PWROK             PB08 = PRSFIFO*
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 13



667                                 ;       PB1 = LED1              PB09 = EF*
668                                 ;       PB2 = LVEN              PB10 = EXT-IN0
669                                 ;       PB3 = HVEN              PB11 = EXT-IN1
670                                 ;       PB4 = STATUS0           PB12 = EXT-OUT0
671                                 ;       PB5 = STATUS1           PB13 = EXT-OUT1
672                                 ;       PB6 = STATUS2           PB14 = SSFHF*
673                                 ;       PB7 = STATUS3           PB15 = SELSCI
674    
675                                 ; Program the serial port ESSI0 = Port C for serial communication with
676                                 ;   the utility board
677       P:0001A9 P:0001A9 07F43F            MOVEP             #>0,X:PCRC              ; Software reset of ESSI0
                            000000
678       P:0001AB P:0001AB 07F435            MOVEP             #$180809,X:CRA0         ; Divide 100 MHz by 20 to get 5.0 MHz
                            180809
679                                                                                     ; DC[4:0] = 0 for non-network operation
680                                                                                     ; WL0-WL2 = 3 for 24-bit data words
681                                                                                     ; SSC1 = 0 for SC1 not used
682       P:0001AD P:0001AD 07F436            MOVEP             #$020020,X:CRB0         ; SCKD = 1 for internally generated clock
                            020020
683                                                                                     ; SCD2 = 0 so frame sync SC2 is an output
684                                                                                     ; SHFD = 0 for MSB shifted first
685                                                                                     ; FSL = 0, frame sync length not used
686                                                                                     ; CKP = 0 for rising clock edge transitions
687                                                                                     ; SYN = 0 for asynchronous
688                                                                                     ; TE0 = 1 to enable transmitter #0
689                                                                                     ; MOD = 0 for normal, non-networked mode
690                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
691                                                                                     ; RE = 1 to enable receiver
692       P:0001AF P:0001AF 07F43F            MOVEP             #%111001,X:PCRC         ; Control Register (0 for GPIO, 1 for ESSI)
                            000039
693       P:0001B1 P:0001B1 07F43E            MOVEP             #%000110,X:PRRC         ; Data Direction Register (0 for In, 1 for O
ut)
                            000006
694       P:0001B3 P:0001B3 07F43D            MOVEP             #%000100,X:PDRC         ; Data Register - WR_ENA* = 1
                            000004
695    
696                                 ; Port C version = Analog boards
697                                 ;       MOVEP   #$000809,X:CRA0 ; Divide 100 MHz by 20 to get 5.0 MHz
698                                 ;       MOVEP   #$000030,X:CRB0 ; SCKD = 1 for internally generated clock
699                                 ;       MOVEP   #%100000,X:PCRC ; Control Register (0 for GPIO, 1 for ESSI)
700                                 ;       MOVEP   #%000100,X:PRRC ; Data Direction Register (0 for In, 1 for Out)
701                                 ;       MOVEP   #%000000,X:PDRC ; Data Register: 'not used' = 0 outputs
702    
703       P:0001B5 P:0001B5 07F43C            MOVEP             #0,X:TX00               ; Initialize the transmitter to zero
                            000000
704       P:0001B7 P:0001B7 000000            NOP
705       P:0001B8 P:0001B8 000000            NOP
706       P:0001B9 P:0001B9 013630            BSET    #TE,X:CRB0                        ; Enable the SSI transmitter
707    
708                                 ; Conversion from software bits to schematic labels for Port C
709                                 ;       PC0 = SC00 = UTL-T-SCK
710                                 ;       PC1 = SC01 = 2_XMT = SYNC on prototype
711                                 ;       PC2 = SC02 = WR_ENA*
712                                 ;       PC3 = SCK0 = TIM-U-SCK
713                                 ;       PC4 = SRD0 = UTL-T-STD
714                                 ;       PC5 = STD0 = TIM-U-STD
715    
716                                 ; Program the serial port ESSI1 = Port D for serial transmission to
717                                 ;   the analog boards and two parallel I/O input pins
718       P:0001BA P:0001BA 07F42F            MOVEP             #>0,X:PCRD              ; Software reset of ESSI0
                            000000
719       P:0001BC P:0001BC 07F425            MOVEP             #$000809,X:CRA1         ; Divide 100 MHz by 20 to get 5.0 MHz
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 14



                            000809
720                                                                                     ; DC[4:0] = 0
721                                                                                     ; WL[2:0] = ALC = 0 for 8-bit data words
722                                                                                     ; SSC1 = 0 for SC1 not used
723       P:0001BE P:0001BE 07F426            MOVEP             #$000030,X:CRB1         ; SCKD = 1 for internally generated clock
                            000030
724                                                                                     ; SCD2 = 1 so frame sync SC2 is an output
725                                                                                     ; SHFD = 0 for MSB shifted first
726                                                                                     ; CKP = 0 for rising clock edge transitions
727                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
728                                                                                     ; MOD = 0 so its not networked mode
729       P:0001C0 P:0001C0 07F42F            MOVEP             #%100000,X:PCRD         ; Control Register (0 for GPIO, 1 for ESSI)
                            000020
730                                                                                     ; PD3 = SCK1, PD5 = STD1 for ESSI
731       P:0001C2 P:0001C2 07F42E            MOVEP             #%000100,X:PRRD         ; Data Direction Register (0 for In, 1 for O
ut)
                            000004
732       P:0001C4 P:0001C4 07F42D            MOVEP             #%000100,X:PDRD         ; Data Register: 'not used' = 0 outputs
                            000004
733       P:0001C6 P:0001C6 07F42C            MOVEP             #0,X:TX10               ; Initialize the transmitter to zero
                            000000
734       P:0001C8 P:0001C8 000000            NOP
735       P:0001C9 P:0001C9 000000            NOP
736       P:0001CA P:0001CA 012630            BSET    #TE,X:CRB1                        ; Enable the SSI transmitter
737    
738                                 ; Conversion from software bits to schematic labels for Port D
739                                 ; PD0 = SC10 = 2_XMT_? input
740                                 ; PD1 = SC11 = SSFEF* input
741                                 ; PD2 = SC12 = PWR_EN
742                                 ; PD3 = SCK1 = TIM-A-SCK
743                                 ; PD4 = SRD1 = PWRRST
744                                 ; PD5 = STD1 = TIM-A-STD
745    
746                                 ; Program the SCI port to communicate with the utility board
747       P:0001CB P:0001CB 07F41C            MOVEP             #$0B04,X:SCR            ; SCI programming: 11-bit asynchronous
                            000B04
748                                                                                     ;   protocol (1 start, 8 data, 1 even parity
,
749                                                                                     ;   1 stop); LSB before MSB; enable receiver
750                                                                                     ;   and its interrupts; transmitter interrup
ts
751                                                                                     ;   disabled.
752       P:0001CD P:0001CD 07F41B            MOVEP             #$0003,X:SCCR           ; SCI clock: utility board data rate =
                            000003
753                                                                                     ;   (390,625 kbits/sec); internal clock.
754       P:0001CF P:0001CF 07F41F            MOVEP             #%011,X:PCRE            ; Port Control Register = RXD, TXD enabled
                            000003
755       P:0001D1 P:0001D1 07F41E            MOVEP             #%000,X:PRRE            ; Port Direction Register (0 = Input)
                            000000
756    
757                                 ;       PE0 = RXD
758                                 ;       PE1 = TXD
759                                 ;       PE2 = SCLK
760    
761                                 ; Program one of the three timers as an exposure timer
762       P:0001D3 P:0001D3 07F403            MOVEP             #$C34F,X:TPLR           ; Prescaler to generate millisecond timer,
                            00C34F
763                                                                                     ;  counting from the system clock / 2 = 50 M
Hz
764       P:0001D5 P:0001D5 07F40F            MOVEP             #$208200,X:TCSR0        ; Clear timer complete bit and enable presca
ler
                            208200
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 15



765       P:0001D7 P:0001D7 07F40E            MOVEP             #0,X:TLR0               ; Timer load register
                            000000
766    
767                                 ; Enable interrupts for the SCI port only
768       P:0001D9 P:0001D9 08F4BF            MOVEP             #$000000,X:IPRC         ; No interrupts allowed
                            000000
769       P:0001DB P:0001DB 08F4BE            MOVEP             #>$80,X:IPRP            ; Enable SCI interrupt only, IPR = 1
                            000080
770       P:0001DD P:0001DD 00FCB8            ANDI    #$FC,MR                           ; Unmask all interrupt levels
771    
772                                 ; Initialize the fiber optic serial receiver circuitry
773       P:0001DE P:0001DE 061480            DO      #20,L_FO_INIT
                            0001E3
774       P:0001E0 P:0001E0 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
775       P:0001E2 P:0001E2 0605A0            REP     #5
776       P:0001E3 P:0001E3 000000            NOP
777                                 L_FO_INIT
778    
779                                 ; Pulse PRSFIFO* low to revive the CMDRST* instruction and reset the FIFO
780       P:0001E4 P:0001E4 44F400            MOVE              #1000000,X0             ; Delay by 10 milliseconds
                            0F4240
781       P:0001E6 P:0001E6 06C400            DO      X0,*+3
                            0001E8
782       P:0001E8 P:0001E8 000000            NOP
783       P:0001E9 P:0001E9 0A8908            BCLR    #8,X:HDR
784       P:0001EA P:0001EA 0614A0            REP     #20
785       P:0001EB P:0001EB 000000            NOP
786       P:0001EC P:0001EC 0A8928            BSET    #8,X:HDR
787    
788                                 ; Reset the utility board
789       P:0001ED P:0001ED 0A0F05            BCLR    #5,X:<LATCH
790       P:0001EE P:0001EE 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
791       P:0001F0 P:0001F0 06C8A0            REP     #200                              ; Delay by RESET* low time
792       P:0001F1 P:0001F1 000000            NOP
793       P:0001F2 P:0001F2 0A0F25            BSET    #5,X:<LATCH
794       P:0001F3 P:0001F3 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
795       P:0001F5 P:0001F5 56F400            MOVE              #200000,A               ; Delay 2 msec for utility boot
                            030D40
796       P:0001F7 P:0001F7 06CE00            DO      A,*+3
                            0001F9
797       P:0001F9 P:0001F9 000000            NOP
798    
799                                 ; Put all the analog switch inputs to low so they draw minimum current
800       P:0001FA P:0001FA 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
801       P:0001FB P:0001FB 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
802       P:0001FD P:0001FD 20001B            CLR     B
803       P:0001FE P:0001FE 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
804       P:0001FF P:0001FF 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
805       P:000201 P:000201 060F80            DO      #15,L_ANALOG                      ; Fifteen video processor boards maximum
                            000209
806       P:000203 P:000203 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
807       P:000204 P:000204 200040            ADD     X0,A
808       P:000205 P:000205 5F7000            MOVE                          B,Y:WRSS    ; This is for the fast analog switches
                            FFFFF3
809       P:000207 P:000207 0620A3            REP     #800                              ; Delay for the serial data transmission
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 16



810       P:000208 P:000208 000000            NOP
811       P:000209 P:000209 200068            ADD     X1,B                              ; Increment the video and clock driver numbe
rs
812                                 L_ANALOG
813       P:00020A P:00020A 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
814       P:00020B P:00020B 0C0223            JMP     <SKIP
815    
816                                 ; Transmit contents of accumulator A1 over the synchronous serial transmitter
817                                 XMIT_A_WORD
818       P:00020C P:00020C 07F42C            MOVEP             #0,X:TX10               ; This helps, don't know why
                            000000
819       P:00020E P:00020E 547000            MOVE              A1,X:SV_A1
                            00000E
820       P:000210 P:000210 000000            NOP
821       P:000211 P:000211 01A786            JCLR    #TDE,X:SSISR1,*                   ; Start bit
                            000211
822       P:000213 P:000213 07F42C            MOVEP             #$010000,X:TX10
                            010000
823       P:000215 P:000215 060380            DO      #3,L_X
                            00021B
824       P:000217 P:000217 01A786            JCLR    #TDE,X:SSISR1,*                   ; Three data bytes
                            000217
825       P:000219 P:000219 04CCCC            MOVEP             A1,X:TX10
826       P:00021A P:00021A 0C1E90            LSL     #8,A
827       P:00021B P:00021B 000000            NOP
828                                 L_X
829       P:00021C P:00021C 01A786            JCLR    #TDE,X:SSISR1,*                   ; Zeroes to bring transmitter low
                            00021C
830       P:00021E P:00021E 07F42C            MOVEP             #0,X:TX10
                            000000
831       P:000220 P:000220 54F000            MOVE              X:SV_A1,A1
                            00000E
832       P:000222 P:000222 00000C            RTS
833    
834                                 SKIP
835    
836                                 ; Set up the circular SCI buffer, 32 words in size
837       P:000223 P:000223 64F400            MOVE              #SCI_TABLE,R4
                            000400
838       P:000225 P:000225 051FA4            MOVE              #31,M4
839       P:000226 P:000226 647000            MOVE              R4,X:(SCI_TABLE+33)
                            000421
840    
841                                           IF      @SCP("HOST","ROM")
849                                           ENDIF
850    
851       P:000228 P:000228 44F400            MOVE              #>$AC,X0
                            0000AC
852       P:00022A P:00022A 440100            MOVE              X0,X:<FO_HDR
853    
854       P:00022B P:00022B 0C0181            JMP     <STARTUP
855    
856                                 ;  ****************  X: Memory tables  ********************
857    
858                                 ; Define the address in P: space where the table of constants begins
859    
860                                  X_BOOT_START
861       00022A                              EQU     @LCV(L)-2
862    
863                                           IF      @SCP("HOST","ROM")
865                                           ENDIF
866                                           IF      @SCP("HOST","HOST")
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 17



867       X:000000 X:000000                   ORG     X:0,X:0
868                                           ENDIF
869    
870                                 ; Special storage area - initialization constants and scratch space
871       X:000000 X:000000         STATUS    DC      4                                 ; Controller status bits
872    
873       000001                    FO_HDR    EQU     STATUS+1                          ; Fiber optic write bytes
874       000005                    HEADER    EQU     FO_HDR+4                          ; Command header
875       000006                    NWORDS    EQU     HEADER+1                          ; Number of words in the command
876       000007                    COM_BUF   EQU     NWORDS+1                          ; Command buffer
877       00000E                    SV_A1     EQU     COM_BUF+7                         ; Save accumulator A1
878    
879                                           IF      @SCP("HOST","ROM")
884                                           ENDIF
885    
886                                           IF      @SCP("HOST","HOST")
887       X:00000F X:00000F                   ORG     X:$F,X:$F
888                                           ENDIF
889    
890                                 ; Parameter table in P: space to be copied into X: space during
891                                 ;   initialization, and is copied from ROM by the DSP boot
892       X:00000F X:00000F         LATCH     DC      $3A                               ; Starting value in latch chip U25
893                                  EXPOSURE_TIME
894       X:000010 X:000010                   DC      0                                 ; Exposure time in milliseconds
895                                  ELAPSED_TIME
896       X:000011 X:000011                   DC      0                                 ; Time elapsed so far in the exposure
897       X:000012 X:000012         ONE       DC      1                                 ; One
898       X:000013 X:000013         TWO       DC      2                                 ; Two
899       X:000014 X:000014         THREE     DC      3                                 ; Three
900       X:000015 X:000015         SEVEN     DC      7                                 ; Seven
901       X:000016 X:000016         MASK1     DC      $FCFCF8                           ; Mask for checking header
902       X:000017 X:000017         MASK2     DC      $030300                           ; Mask for checking header
903       X:000018 X:000018         DONE      DC      'DON'                             ; Standard reply
904       X:000019 X:000019         SBRD      DC      $020000                           ; Source Identification number
905       X:00001A X:00001A         TIM_DRB   DC      $000200                           ; Destination = timing board number
906       X:00001B X:00001B         DMASK     DC      $00FF00                           ; Mask to get destination board number
907       X:00001C X:00001C         SMASK     DC      $FF0000                           ; Mask to get source board number
908       X:00001D X:00001D         ERR       DC      'ERR'                             ; An error occurred
909       X:00001E X:00001E         C100K     DC      100000                            ; Delay for WRROM = 1 millisec
910       X:00001F X:00001F         IDL_ADR   DC      TST_RCV                           ; Address of idling routine
911       X:000020 X:000020         EXP_ADR   DC      0                                 ; Jump to this address during exposures
912    
913                                 ; Places for saving register values
914       X:000021 X:000021         SAVE_SR   DC      0                                 ; Status Register
915       X:000022 X:000022         SAVE_X1   DC      0
916       X:000023 X:000023         SAVE_A1   DC      0
917       X:000024 X:000024         SAVE_R0   DC      0
918       X:000025 X:000025         RCV_ERR   DC      0
919       X:000026 X:000026         SCI_A1    DC      0                                 ; Contents of accumulator A1 in RCV ISR
920       X:000027 X:000027         SCI_R0    DC      SRXL
921    
922                                 ; Command table
923       000028                    COM_TBL_R EQU     @LCV(R)
924       X:000028 X:000028         COM_TBL   DC      'TDL',TDL                         ; Test Data Link
925       X:00002A X:00002A                   DC      'RDM',RDMEM                       ; Read from DSP or EEPROM memory
926       X:00002C X:00002C                   DC      'WRM',WRMEM                       ; Write to DSP memory
927       X:00002E X:00002E                   DC      'LDA',LDAPPL                      ; Load application from EEPROM to DSP
928       X:000030 X:000030                   DC      'STP',STOP_IDLE_CLOCKING
929       X:000032 X:000032                   DC      'DON',START                       ; Nothing special
930       X:000034 X:000034                   DC      'ERR',START                       ; Nothing special
931    
932                                  END_COMMAND_TABLE
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timboot.asm  Page 18



933       000036                              EQU     @LCV(R)
934    
935                                 ; The table at SCI_TABLE is for words received from the utility board, written by
936                                 ;   the interrupt service routine SCI_RCV. Note that it is 32 words long,
937                                 ;   hard coded, and the 33rd location contains the pointer to words that have
938                                 ;   been processed by moving them from the SCI_TABLE to the COM_BUF.
939    
940                                           IF      @SCP("HOST","ROM")
942                                           ENDIF
943    
944       000036                    END_ADR   EQU     @LCV(L)                           ; End address of P: code written to ROM
945    
946       P:00022C P:00022C                   ORG     P:,P:
947    
948       108015                    CC        EQU     ARC22+ARC32+ARC46+CONT_RD
949    
950                                 ; Put number of words of application in P: for loading application from EEPROM
951       P:00022C P:00022C                   DC      TIMBOOT_X_MEMORY-@LCV(L)-1
952    
953                                 ; Define CLOCK as a macro to produce in-line code to reduce execution time
954                                 CLOCK     MACRO
955  m                                        JCLR    #SSFHF,X:HDR,*                    ; Don't overfill the WRSS FIFO
956  m                                        REP     Y:(R0)+                           ; Repeat
957  m                                        MOVEP   Y:(R0)+,Y:WRSS                    ; Write the waveform to the FIFO
958  m                                        ENDM
959    
960                                 ; Continuously reset and read array, checking for commands every four rows
961                                 CONT_RST
962       P:00022D P:00022D 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
963                                           CLOCK
967       P:000233 P:000233 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
968                                           CLOCK
972       P:000239 P:000239 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
973                                           CLOCK
977       P:00023F P:00023F 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
978                                           CLOCK
982       P:000245 P:000245 068080            DO      #128,L_RESET
                            00026C
983       P:000247 P:000247 60F400            MOVE              #CLOCK_ROW_1,R0
                            0001F7
984                                           CLOCK
988       P:00024D P:00024D 0D026E            JSR     <CLK_COL
989       P:00024E P:00024E 60F400            MOVE              #CLOCK_ROW_2,R0
                            0001FD
990                                           CLOCK
994       P:000254 P:000254 0D026E            JSR     <CLK_COL
995       P:000255 P:000255 60F400            MOVE              #CLOCK_ROW_3,R0
                            000203
996                                           CLOCK
1000      P:00025B P:00025B 0D026E            JSR     <CLK_COL
1001      P:00025C P:00025C 60F400            MOVE              #CLOCK_ROW_4,R0
                            000209
1002                                          CLOCK
1006      P:000262 P:000262 0D026E            JSR     <CLK_COL
1007      P:000263 P:000263 44F400            MOVE              #(CLK2+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR),X0
                            00207F
1008      P:000265 P:000265 4C7000            MOVE                          X0,Y:WRSS
                            FFFFF3
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 19



1009   
1010      P:000267 P:000267 330700            MOVE              #COM_BUF,R3
1011      P:000268 P:000268 0D00A5            JSR     <GET_RCV                          ; Look for a new command every 4 rows
1012      P:000269 P:000269 0E026C            JCC     <NO_COM                           ; If none, then stay here
1013      P:00026A P:00026A 00008C            ENDDO
1014      P:00026B P:00026B 0C005D            JMP     <PRC_RCV
1015      P:00026C P:00026C 000000  NO_COM    NOP
1016                                L_RESET
1017      P:00026D P:00026D 0C022D            JMP     <CONT_RST
1018   
1019                                ; Simple clocking routine for resetting and clearing
1020      P:00026E P:00026E 062080  CLK_COL   DO      #32,L_CLOCK
                            000275
1021      P:000270 P:000270 60F400            MOVE              #CLOCK_COLUMN,R0
                            00020F
1022                                          CLOCK
1026                                L_CLOCK
1027      P:000276 P:000276 00000C            RTS
1028   
1029                                ;  ************************  Readout subroutines  ********************
1030                                ; Normal readout of the whole array
1031   
1032                                NORMAL_READOUT
1033                                ;       ;MOVE   #FRAME_RESET,R0
1034                                ;       ;CLOCK
1035                                ;       JCLR    #ST_CDS,X:STATUS,*+3
1036                                ;       JSR     <READOUT                ; Read the array
1037                                ;       JSR     <WAIT_TO_FINISH_CLOCKING
1038                                ;       MOVE    #L_EXP1,R7              ; Return address at end of exposure
1039                                ;       JMP     <EXPOSE                 ; Delay for specified exposure time
1040                                ;L_EXP1
1041                                ;       JSR     <READOUT
1042                                ;       JMP     <DONE_READOUT
1043   
1044   
1045                                RESET_ARRAY
1046      P:000277 P:000277 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
1047      P:000279 P:000279 0D0566            JSR     <CLOCK
1048      P:00027A P:00027A 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
1049      P:00027C P:00027C 0D0566            JSR     <CLOCK
1050      P:00027D P:00027D 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
1051      P:00027F P:00027F 0D0566            JSR     <CLOCK
1052      P:000280 P:000280 60F400            MOVE              #FRAME_RESET,R0
                            0001DB
1053      P:000282 P:000282 0D0566            JSR     <CLOCK
1054      P:000283 P:000283 00000C            RTS
1055   
1056                                ; Now start reading out the image with the frame initialization clocks first
1057                                READOUT
1058      P:000284 P:000284 0D0557            JSR     <PCI_READ_IMAGE
1059      P:000285 P:000285 60F400            MOVE              #FRAME_INIT,R0
                            0001F0
1060                                          CLOCK
1064      P:00028B P:00028B 068080            DO      #128,L_READOUT
                            0002AA
1065      P:00028D P:00028D 60F400            MOVE              #CLOCK_ROW_1,R0
                            0001F7
1066                                          CLOCK
1070      P:000293 P:000293 0D0397            JSR     <CLK_COL_AND_READ
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 20



1071      P:000294 P:000294 60F400            MOVE              #CLOCK_ROW_2,R0
                            0001FD
1072                                          CLOCK
1076      P:00029A P:00029A 0D0397            JSR     <CLK_COL_AND_READ
1077      P:00029B P:00029B 60F400            MOVE              #CLOCK_ROW_3,R0
                            000203
1078                                          CLOCK
1082      P:0002A1 P:0002A1 0D0397            JSR     <CLK_COL_AND_READ
1083      P:0002A2 P:0002A2 60F400            MOVE              #CLOCK_ROW_4,R0
                            000209
1084                                          CLOCK
1088      P:0002A8 P:0002A8 0D0397            JSR     <CLK_COL_AND_READ
1089      P:0002A9 P:0002A9 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1090      P:0002AA P:0002AA 000000            NOP
1091                                L_READOUT
1092   
1093      P:0002AB P:0002AB 60F400            MOVE              #CLOCK_ROW_1,R0
                            0001F7
1094                                          CLOCK
1098      P:0002B1 P:0002B1 0D0397            JSR     <CLK_COL_AND_READ
1099   
1100      P:0002B2 P:0002B2 60F400            MOVE              #FRAME_INIT,R0          ;deselect last row by initializing
                            0001F0
1101                                          CLOCK
1105   
1106      P:0002B8 P:0002B8 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1107      P:0002B9 P:0002B9 000000            NOP
1108   
1109      P:0002BA P:0002BA 00000C            RTS
1110   
1111   
1112                                NO_READOUT
1113                                ;       JSR     <PCI_READ_IMAGE
1114      P:0002BB P:0002BB 60F400            MOVE              #FRAME_INIT,R0
                            0001F0
1115                                          CLOCK
1119      P:0002C1 P:0002C1 068080            DO      #128,L_NO_READOUT
                            0002E0
1120      P:0002C3 P:0002C3 60F400            MOVE              #CLOCK_ROW_1,R0
                            0001F7
1121                                          CLOCK
1125      P:0002C9 P:0002C9 0D03BD            JSR     <CLK_COL_NO_READ
1126      P:0002CA P:0002CA 60F400            MOVE              #CLOCK_ROW_2,R0
                            0001FD
1127                                          CLOCK
1131      P:0002D0 P:0002D0 0D03BD            JSR     <CLK_COL_NO_READ
1132      P:0002D1 P:0002D1 60F400            MOVE              #CLOCK_ROW_3,R0
                            000203
1133                                          CLOCK
1137      P:0002D7 P:0002D7 0D03BD            JSR     <CLK_COL_NO_READ
1138      P:0002D8 P:0002D8 60F400            MOVE              #CLOCK_ROW_4,R0
                            000209
1139                                          CLOCK
1143      P:0002DE P:0002DE 0D03BD            JSR     <CLK_COL_NO_READ
1144      P:0002DF P:0002DF 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1145      P:0002E0 P:0002E0 000000            NOP
1146                                L_NO_READOUT
1147   
1148      P:0002E1 P:0002E1 60F400            MOVE              #CLOCK_ROW_1,R0
                            0001F7
1149                                          CLOCK
1153      P:0002E7 P:0002E7 0D03BD            JSR     <CLK_COL_NO_READ
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 21



1154   
1155      P:0002E8 P:0002E8 60F400            MOVE              #FRAME_INIT,R0          ;deselect last row by initializing
                            0001F0
1156                                          CLOCK
1160   
1161      P:0002EE P:0002EE 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1162      P:0002EF P:0002EF 000000            NOP
1163   
1164      P:0002F0 P:0002F0 00000C            RTS
1165   
1166   
1167                                ; Row-by-row reset and readout, for high illumination levels
1168                                ROW_BY_ROW_RESET_READOUT
1169      P:0002F1 P:0002F1 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1170      P:0002F2 P:0002F2 0A0024            BSET    #ST_RDC,X:<STATUS                 ; Set status to reading out
1171      P:0002F3 P:0002F3 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1172      P:0002F5 P:0002F5 0D00EB            JSR     <XMT_WRD
1173      P:0002F6 P:0002F6 57F400            MOVE              #'RDA',B
                            524441
1174      P:0002F8 P:0002F8 0D00EB            JSR     <XMT_WRD
1175      P:0002F9 P:0002F9 57F400            MOVE              #1024,B                 ; Number of columns to read
                            000400
1176      P:0002FB P:0002FB 0D00EB            JSR     <XMT_WRD
1177      P:0002FC P:0002FC 0A00B1            JSET    #ST_CDS,X:STATUS,RRR_CDS
                            00033B
1178   
1179                                ; Read out the image in single read mode, row-by-row reset
1180      P:0002FE P:0002FE 57F400            MOVE              #1024,B                 ; Number of rows to read
                            000400
1181      P:000300 P:000300 0D00EB            JSR     <XMT_WRD
1182      P:000301 P:000301 60F400            MOVE              #FRAME_INIT,R0
                            0001F0
1183                                          CLOCK
1187      P:000307 P:000307 068080            DO      #128,L_RR_RESET_READOUT
                            000339
1188      P:000309 P:000309 60F400            MOVE              #RESET_ROW_12,R0
                            0001CD
1189                                          CLOCK
1193      P:00030F P:00030F 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1194      P:000310 P:000310 67F400            MOVE              #L_RR12,R7
                            000313
1195      P:000312 P:000312 0C049A            JMP     <EXPOSE
1196                                L_RR12
1197      P:000313 P:000313 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            00016D
1198                                          CLOCK
1202      P:000319 P:000319 0D0397            JSR     <CLK_COL_AND_READ
1203      P:00031A P:00031A 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000173
1204                                          CLOCK
1208      P:000320 P:000320 0D0397            JSR     <CLK_COL_AND_READ
1209   
1210      P:000321 P:000321 60F400            MOVE              #RESET_ROW_34,R0
                            0001D4
1211                                          CLOCK
1215      P:000327 P:000327 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1216      P:000328 P:000328 67F400            MOVE              #L_RR34,R7
                            00032B
1217      P:00032A P:00032A 0C049A            JMP     <EXPOSE
1218                                L_RR34
1219      P:00032B P:00032B 60F400            MOVE              #CLOCK_RR_ROW_3,R0
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 22



                            000179
1220                                          CLOCK
1224      P:000331 P:000331 0D0397            JSR     <CLK_COL_AND_READ
1225      P:000332 P:000332 60F400            MOVE              #CLOCK_RR_ROW_4,R0
                            00017F
1226                                          CLOCK
1230      P:000338 P:000338 0D0397            JSR     <CLK_COL_AND_READ
1231      P:000339 P:000339 000000            NOP
1232                                L_RR_RESET_READOUT
1233   
1234      P:00033A P:00033A 0C0387            JMP     <DONE_READOUT
1235   
1236                                ; Read out the image in CDS mode, row-by-row reset
1237      P:00033B P:00033B 57F400  RRR_CDS   MOVE              #1024,B
                            000400
1238      P:00033D P:00033D 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1239      P:00033E P:00033E 60F400            MOVE              #FRAME_INIT,R0
                            0001F0
1240                                          CLOCK
1244      P:000344 P:000344 068080            DO      #128,CDS_RR_RESET_READOUT
                            000386
1245      P:000346 P:000346 60F400            MOVE              #CLOCK_CDS_RESET_ROW_1,R0
                            0001A9
1246                                          CLOCK
1250      P:00034C P:00034C 0D0397            JSR     <CLK_COL_AND_READ
1251      P:00034D P:00034D 60F400            MOVE              #CLOCK_CDS_RESET_ROW_2,R0
                            0001B2
1252                                          CLOCK
1256      P:000353 P:000353 0D0397            JSR     <CLK_COL_AND_READ
1257      P:000354 P:000354 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1258      P:000355 P:000355 67F400            MOVE              #CDS_RR1,R7
                            000358
1259      P:000357 P:000357 0C049A            JMP     <EXPOSE
1260                                CDS_RR1
1261      P:000358 P:000358 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            00016D
1262                                          CLOCK
1266      P:00035E P:00035E 0D0397            JSR     <CLK_COL_AND_READ
1267      P:00035F P:00035F 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000173
1268                                          CLOCK
1272      P:000365 P:000365 0D0397            JSR     <CLK_COL_AND_READ
1273   
1274      P:000366 P:000366 60F400            MOVE              #CLOCK_CDS_RESET_ROW_3,R0
                            0001BB
1275                                          CLOCK
1279      P:00036C P:00036C 0D0397            JSR     <CLK_COL_AND_READ
1280      P:00036D P:00036D 60F400            MOVE              #CLOCK_CDS_RESET_ROW_4,R0
                            0001C4
1281                                          CLOCK
1285      P:000373 P:000373 0D0397            JSR     <CLK_COL_AND_READ
1286      P:000374 P:000374 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1287      P:000375 P:000375 67F400            MOVE              #CDS_RR3,R7
                            000378
1288      P:000377 P:000377 0C049A            JMP     <EXPOSE
1289                                CDS_RR3
1290      P:000378 P:000378 60F400            MOVE              #CLOCK_RR_ROW_3,R0
                            000179
1291                                          CLOCK
1295      P:00037E P:00037E 0D0397            JSR     <CLK_COL_AND_READ
1296      P:00037F P:00037F 60F400            MOVE              #CLOCK_RR_ROW_4,R0
                            00017F
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 23



1297                                          CLOCK
1301      P:000385 P:000385 0D0397            JSR     <CLK_COL_AND_READ
1302      P:000386 P:000386 000000            NOP
1303                                CDS_RR_RESET_READOUT
1304   
1305                                ; This is code for continuous readout - check if more frames are needed
1306                                DONE_READOUT
1307      P:000387 P:000387 5E8D00            MOVE                          Y:<N_FRAMES,A ; Are we in continuous readout mode?
1308      P:000388 P:000388 014185            CMP     #1,A
1309      P:000389 P:000389 0EF390            JLE     <RDA_END
1310      P:00038A P:00038A 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1311      P:00038B P:00038B 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1312   
1313                                ; Check for a command once. Only the ABORT command should be issued.
1314      P:00038C P:00038C 330700            MOVE              #COM_BUF,R3
1315      P:00038D P:00038D 0D00A5            JSR     <GET_RCV                          ; Was a command received?
1316      P:00038E P:00038E 0E04E7            JCC     <NEXT_FRAME                       ; If no, get the next frame
1317      P:00038F P:00038F 0C005D            JMP     <PRC_RCV                          ; If yes, go process it
1318   
1319                                ; Restore the controller to non-image data transfer and idling if necessary
1320      P:000390 P:000390 60F400  RDA_END   MOVE              #CONT_RST,R0            ; Process commands, don't idle,
                            00022D
1321      P:000392 P:000392 601F00            MOVE              R0,X:<IDL_ADR           ;    during the exposure
1322      P:000393 P:000393 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1323      P:000394 P:000394 0C0054            JMP     <START
1324   
1325   
1326                                ;  ********  End of readout routines  ****************
1327   
1328                                ; Simple implementation
1329      P:000395 P:000395 010F20  CONTRD    BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer
1330      P:000396 P:000396 0C0054            JMP     <START
1331   
1332   
1333   
1334                                CLK_COL_AND_READ
1335   
1336      P:000397 P:000397 062080            DO      #32,L_CLOCK_COLUMN_AND_READ
                            0003B7
1337   
1338      P:000399 P:000399 60F400            MOVE              #RD_COLS1,R0
                            000251
1339                                          CLOCK
1343   
1344      P:00039F P:00039F 060B40            DO      Y:<NDS,SAMPLE_A3
                            0003A7
1345      P:0003A1 P:0003A1 60F400            MOVE              #SAMPLE_COL,R0
                            000257
1346                                          CLOCK
1350      P:0003A7 P:0003A7 000000            NOP
1351                                SAMPLE_A3
1352   
1353   
1354      P:0003A8 P:0003A8 60F400            MOVE              #RD_COLS2,R0
                            000254
1355                                          CLOCK
1359   
1360   
1361      P:0003AE P:0003AE 060B40            DO      Y:<NDS,SAMPLE_A4
                            0003B6
1362      P:0003B0 P:0003B0 60F400            MOVE              #SAMPLE_COL,R0
                            000257
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 24



1363                                          CLOCK
1367      P:0003B6 P:0003B6 000000            NOP
1368                                SAMPLE_A4
1369   
1370   
1371      P:0003B7 P:0003B7 000000            NOP
1372   
1373                                L_CLOCK_COLUMN_AND_READ
1374   
1375                                          CLOCK
1379   
1380      P:0003BC P:0003BC 00000C            RTS
1381   
1382   
1383                                CLK_COL_NO_READ
1384   
1385      P:0003BD P:0003BD 062080            DO      #32,L_CLOCK_COLUMN_NO_READ
                            0003CB
1386   
1387      P:0003BF P:0003BF 60F400            MOVE              #RD_COLS1,R0
                            000251
1388                                          CLOCK
1392   
1393      P:0003C5 P:0003C5 60F400            MOVE              #RD_COLS2,R0
                            000254
1394                                          CLOCK
1398   
1399      P:0003CB P:0003CB 000000            NOP
1400   
1401                                L_CLOCK_COLUMN_NO_READ
1402   
1403                                          CLOCK
1407   
1408      P:0003D0 P:0003D0 00000C            RTS
1409   
1410   
1411   
1412   
1413   
1414   
1415   
1416   
1417                                ; ******  Include many routines not directly needed for readout  *******
1418                                          INCLUDE "timIRmisc.asm"
1419                                ; Miscellaneous IR array control routines, common to all detector types
1420   
1421                                ; original POWER_OFF sequence
1422                                ;POWER_OFF
1423                                ;       JSR     <CLEAR_SWITCHES_AND_DACS ; Clear switches and DACs
1424                                ;       BSET    #LVEN,X:HDR             ; Turn off low +/- 6.5, +/- 16.5 supplies
1425                                ;       BSET    #HVEN,X:HDR             ; Turn off high +36 supply
1426                                ;       JMP     <FINISH
1427   
1428                                ; new POWER_OFF sequence - only powers down clocks and takes biases to zero
1429                                POWER_OFF
1430      P:0003D1 P:0003D1 0D043C            JSR     <SET_BIASES_Z
1431      P:0003D2 P:0003D2 0C008F            JMP     <FINISH
1432   
1433                                ; Start power-on cycle
1434                                POWER_ON
1435      P:0003D3 P:0003D3 0D047E            JSR     <CLEAR_SWITCHES_AND_DACS          ; Clear all analog switches
1436      P:0003D4 P:0003D4 0D03F4            JSR     <PON                              ; Turn on the power control board
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 25



1437      P:0003D5 P:0003D5 0A8980            JCLR    #PWROK,X:HDR,PWR_ERR              ; Test if the power turned on properly
                            0003F1
1438   
1439      P:0003D7 P:0003D7 0D043C            JSR     <SET_BIASES_Z                     ; Zero the analog bias voltages
1440      P:0003D8 P:0003D8 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1441      P:0003DA P:0003DA 06C400            DO      X0,*+3
                            0003DC
1442      P:0003DC P:0003DC 000000            NOP
1443      P:0003DD P:0003DD 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1444      P:0003DF P:0003DF 06C400            DO      X0,*+3
                            0003E1
1445      P:0003E1 P:0003E1 000000            NOP
1446      P:0003E2 P:0003E2 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1447      P:0003E4 P:0003E4 06C400            DO      X0,*+3
                            0003E6
1448      P:0003E6 P:0003E6 000000            NOP
1449      P:0003E7 P:0003E7 0D040E            JSR     <SET_BIASES
1450      P:0003E8 P:0003E8 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1451      P:0003EA P:0003EA 06C400            DO      X0,*+3
                            0003EC
1452      P:0003EC P:0003EC 000000            NOP
1453      P:0003ED P:0003ED 60F400            MOVE              #CONT_RST,R0            ; Put controller in continuous readout
                            00022D
1454      P:0003EF P:0003EF 601F00            MOVE              R0,X:<IDL_ADR           ;   state
1455      P:0003F0 P:0003F0 0C008F            JMP     <FINISH
1456   
1457                                ; The power failed to turn on because of an error on the power control board
1458      P:0003F1 P:0003F1 0A8922  PWR_ERR   BSET    #LVEN,X:HDR                       ; Turn off the low voltage emable line
1459      P:0003F2 P:0003F2 0A8923            BSET    #HVEN,X:HDR                       ; Turn off the high voltage emable line
1460      P:0003F3 P:0003F3 0C008D            JMP     <ERROR
1461   
1462                                ; Now ramp up the low voltages (+/- 6.5V, 16.5V) and delay them to turn on
1463      P:0003F4 P:0003F4 0A0F20  PON       BSET    #CDAC,X:<LATCH                    ; Disable clearing of DACs
1464      P:0003F5 P:0003F5 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1465   
1466                                ; Write all the bias voltages to the DACs
1467                                SET_BIASES_L
1468      P:0003F7 P:0003F7 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1469      P:0003F8 P:0003F8 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1470      P:0003F9 P:0003F9 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1471      P:0003FB P:0003FB 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1472      P:0003FD P:0003FD 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1473      P:0003FE P:0003FE 0A8923            BSET    #HVEN,X:HDR
1474      P:0003FF P:0003FF 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1475      P:000401 P:000401 0D052A            JSR     <MILLISEC_DELAY
1476   
1477                                ; Write the values to the clock driver and DC bias supplies
1478      P:000402 P:000402 60F400            MOVE              #BIASES_L,R0            ; Turn on the power before writing to
                            00009B
1479      P:000404 P:000404 0D0576            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1480      P:000405 P:000405 60F400            MOVE              #CLOCKS,R0              ;  power to be written to
                            000011
1481      P:000407 P:000407 0D0576            JSR     <SET_DAC
1482      P:000408 P:000408 0D0571            JSR     <PAL_DLY
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 26



1483   
1484      P:000409 P:000409 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1485      P:00040A P:00040A 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
1486      P:00040C P:00040C 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1487      P:00040D P:00040D 00000C            RTS
1488   
1489                                ; Write all the bias voltages to the DACs
1490                                SET_BIASES
1491      P:00040E P:00040E 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1492      P:00040F P:00040F 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1493      P:000410 P:000410 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1494      P:000412 P:000412 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1495      P:000414 P:000414 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1496      P:000415 P:000415 0A8923            BSET    #HVEN,X:HDR
1497      P:000416 P:000416 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1498      P:000418 P:000418 0D052A            JSR     <MILLISEC_DELAY
1499   
1500                                ; Write the values to the clock driver and DC bias supplies
1501      P:000419 P:000419 60F400            MOVE              #BIASES,R0              ; Turn on the power before writing to
                            000127
1502      P:00041B P:00041B 0D0576            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1503      P:00041C P:00041C 60F400            MOVE              #CLOCKS,R0              ;  power to be written to
                            000011
1504      P:00041E P:00041E 0D0576            JSR     <SET_DAC
1505      P:00041F P:00041F 0D0571            JSR     <PAL_DLY
1506   
1507      P:000420 P:000420 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1508      P:000421 P:000421 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
1509      P:000423 P:000423 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1510      P:000424 P:000424 00000C            RTS
1511   
1512                                ; Write all the bias voltages to the DACs
1513                                SET_BIASES_H
1514      P:000425 P:000425 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1515      P:000426 P:000426 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1516      P:000427 P:000427 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1517      P:000429 P:000429 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1518      P:00042B P:00042B 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1519      P:00042C P:00042C 0A8923            BSET    #HVEN,X:HDR
1520      P:00042D P:00042D 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1521      P:00042F P:00042F 0D052A            JSR     <MILLISEC_DELAY
1522   
1523                                ; Write the values to the clock driver and DC bias supplies
1524      P:000430 P:000430 60F400            MOVE              #BIASES_H,R0            ; Turn on the power before writing to
                            0000E1
1525      P:000432 P:000432 0D0576            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1526      P:000433 P:000433 60F400            MOVE              #CLOCKS,R0              ;  power to be written to
                            000011
1527      P:000435 P:000435 0D0576            JSR     <SET_DAC
1528      P:000436 P:000436 0D0571            JSR     <PAL_DLY
1529   
1530      P:000437 P:000437 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1531      P:000438 P:000438 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 27



1532      P:00043A P:00043A 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1533      P:00043B P:00043B 00000C            RTS
1534   
1535                                ; Write all the bias voltages to the DACs
1536                                SET_BIASES_Z
1537      P:00043C P:00043C 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1538      P:00043D P:00043D 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1539      P:00043E P:00043E 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1540      P:000440 P:000440 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1541      P:000442 P:000442 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1542      P:000443 P:000443 0A8923            BSET    #HVEN,X:HDR
1543      P:000444 P:000444 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1544      P:000446 P:000446 0D052A            JSR     <MILLISEC_DELAY
1545   
1546                                ; Write the values to the clock driver and DC bias supplies
1547      P:000447 P:000447 60F400            MOVE              #BIASES_Z,R0            ; Turn on the power before writing to
                            000075
1548      P:000449 P:000449 0D0576            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1549      P:00044A P:00044A 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1550      P:00044C P:00044C 06C400            DO      X0,*+3
                            00044E
1551      P:00044E P:00044E 000000            NOP
1552      P:00044F P:00044F 60F400            MOVE              #CLOCKS_Z,R0            ;  power to be written to
                            000043
1553      P:000451 P:000451 0D0576            JSR     <SET_DAC
1554      P:000452 P:000452 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1555      P:000454 P:000454 06C400            DO      X0,*+3
                            000456
1556      P:000456 P:000456 000000            NOP
1557      P:000457 P:000457 0D0571            JSR     <PAL_DLY
1558      P:000458 P:000458 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1559      P:00045A P:00045A 06C400            DO      X0,*+3
                            00045C
1560      P:00045C P:00045C 000000            NOP
1561   
1562      P:00045D P:00045D 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1563      P:00045E P:00045E 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
1564      P:000460 P:000460 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1565      P:000462 P:000462 06C400            DO      X0,*+3
                            000464
1566      P:000464 P:000464 000000            NOP
1567   
1568      P:000465 P:000465 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1569      P:000466 P:000466 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1570      P:000468 P:000468 06C400            DO      X0,*+3
                            00046A
1571      P:00046A P:00046A 000000            NOP
1572      P:00046B P:00046B 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1573      P:00046D P:00046D 06C400            DO      X0,*+3
                            00046F
1574      P:00046F P:00046F 000000            NOP
1575   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 28



1576   
1577      P:000470 P:000470 00000C            RTS
1578   
1579                                SET_BIAS_VOLTAGES_L
1580      P:000471 P:000471 0D03F7            JSR     <SET_BIASES_L
1581      P:000472 P:000472 0C008F            JMP     <FINISH
1582   
1583                                SET_BIAS_VOLTAGES
1584      P:000473 P:000473 44F400            MOVE              #6800000,X0             ; Wait 15 msec.
                            67C280
1585      P:000475 P:000475 06C400            DO      X0,*+3
                            000477
1586      P:000477 P:000477 000000            NOP
1587      P:000478 P:000478 0D040E            JSR     <SET_BIASES
1588      P:000479 P:000479 0C008F            JMP     <FINISH
1589   
1590                                SET_BIAS_VOLTAGES_H
1591      P:00047A P:00047A 0D0425            JSR     <SET_BIASES_H
1592      P:00047B P:00047B 0C008F            JMP     <FINISH
1593   
1594      P:00047C P:00047C 0D047E  CLR_SWS   JSR     <CLEAR_SWITCHES_AND_DACS
1595      P:00047D P:00047D 0C008F            JMP     <FINISH
1596   
1597                                CLEAR_SWITCHES_AND_DACS
1598      P:00047E P:00047E 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Clear all the DACs
1599      P:00047F P:00047F 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable all the output switches
1600      P:000480 P:000480 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1601      P:000482 P:000482 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1602      P:000483 P:000483 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
1603      P:000485 P:000485 20001B            CLR     B
1604      P:000486 P:000486 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
1605      P:000487 P:000487 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
1606      P:000489 P:000489 060F80            DO      #15,L_VIDEO                       ; Fifteen video processor boards maximum
                            000490
1607      P:00048B P:00048B 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1608      P:00048C P:00048C 200040            ADD     X0,A
1609      P:00048D P:00048D 5F7000            MOVE                          B,Y:WRSS
                            FFFFF3
1610      P:00048F P:00048F 0D0571            JSR     <PAL_DLY                          ; Delay for the serial data transmission
1611      P:000490 P:000490 200068            ADD     X1,B
1612                                L_VIDEO
1613      P:000491 P:000491 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1614      P:000492 P:000492 00000C            RTS
1615   
1616                                ; Fast clear of the array, executed as a command
1617      P:000493 P:000493 60F400  CLEAR     MOVE              #FRAME_RESET,R0
                            0001DB
1618                                          CLOCK
1622      P:000499 P:000499 0C008F            JMP     <FINISH
1623   
1624                                ; Start the exposure timer and monitor its progress
1625                                EXPOSE
1626      P:00049A P:00049A 07F40E            MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1627      P:00049C P:00049C 240000            MOVE              #0,X0
1628      P:00049D P:00049D 441100            MOVE              X0,X:<ELAPSED_TIME      ; Set elapsed exposure time to zero
1629      P:00049E P:00049E 579000            MOVE              X:<EXPOSURE_TIME,B
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 29



1630      P:00049F P:00049F 20000B            TST     B                                 ; Special test for zero exposure time
1631      P:0004A0 P:0004A0 0EA4AC            JEQ     <END_EXP                          ; Don't even start an exposure
1632      P:0004A1 P:0004A1 01418C            SUB     #1,B                              ; Timer counts from X:TCPR0+1 to zero
1633      P:0004A2 P:0004A2 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1634      P:0004A3 P:0004A3 577000            MOVE              B,X:TCPR0
                            FFFF8D
1635                                CHK_RCV
1636      P:0004A5 P:0004A5 0A8989            JCLR    #EF,X:HDR,CHK_TIM                 ; Simple test for fast execution
                            0004AA
1637      P:0004A7 P:0004A7 330700            MOVE              #COM_BUF,R3             ; The beginning of the command buffer
1638      P:0004A8 P:0004A8 0D00A5            JSR     <GET_RCV                          ; Check for an incoming command
1639      P:0004A9 P:0004A9 0E805D            JCS     <PRC_RCV                          ; If command is received, go check it
1640                                CHK_TIM
1641      P:0004AA P:0004AA 018F95            JCLR    #TCF,X:TCSR0,CHK_RCV              ; Wait for timer to equal compare value
                            0004A5
1642                                END_EXP
1643      P:0004AC P:0004AC 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the timer
1644      P:0004AD P:0004AD 0AE780            JMP     (R7)                              ; This contains the return address
1645   
1646                                ;  *****************  Start the exposure  *****************
1647   
1648                                START_EXPOSURE
1649      P:0004AE P:0004AE 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
1650   
1651      P:0004AF P:0004AF 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
1652   
1653      P:0004B0 P:0004B0 060A40            DO      Y:<NFS,RD1_END                    ; Fowler sampling
                            0004B4
1654      P:0004B2 P:0004B2 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
1655      P:0004B3 P:0004B3 0D0284            JSR     <READOUT                          ; Read out the FPA
1656      P:0004B4 P:0004B4 000000            NOP
1657   
1658                                RD1_END
1659   
1660   
1661   
1662   
1663      P:0004B5 P:0004B5 67F400            MOVE              #L_SEX1,R7              ; Return address at end of exposure
                            0004B8
1664      P:0004B7 P:0004B7 0C049A            JMP     <EXPOSE                           ; Delay for specified exposure time
1665                                L_SEX1
1666   
1667   
1668   
1669   
1670   
1671      P:0004B8 P:0004B8 060A40            DO      Y:<NFS,RD2_END                    ; Fowler sampling
                            0004BC
1672      P:0004BA P:0004BA 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
1673      P:0004BB P:0004BB 0D0284            JSR     <READOUT                          ; Read out the FPA
1674      P:0004BC P:0004BC 000000            NOP
1675                                RD2_END
1676   
1677      P:0004BD P:0004BD 000000            NOP
1678      P:0004BE P:0004BE 0C0054            JMP     <START
1679   
1680   
1681   
1682                                ; ***************** Start Read up the Ramp linear *****************
1683   
1684                                START_RR_LINEAR
1685      P:0004BF P:0004BF 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 30



1686      P:0004C0 P:0004C0 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
1687   
1688   
1689      P:0004C1 P:0004C1 200013            CLR     A
1690      P:0004C2 P:0004C2 5E8A00            MOVE                          Y:<NFS,A
1691      P:0004C3 P:0004C3 014184            SUB     #1,A                              ; subtract one readout from the loop and do 
the readout at the end
1692      P:0004C4 P:0004C4 000000            NOP
1693   
1694      P:0004C5 P:0004C5 06CE00            DO      A,RRL_END                         ; number of samples
                            0004CB
1695      P:0004C7 P:0004C7 0D0284            JSR     <READOUT                          ; Read out the FPA
1696   
1697   
1698      P:0004C8 P:0004C8 67F400            MOVE              #L_SEX2,R7              ; Return address at end of exposure
                            0004CB
1699      P:0004CA P:0004CA 0C049A            JMP     <EXPOSE                           ; Delay for specified exposure time
1700                                L_SEX2
1701   
1702   
1703      P:0004CB P:0004CB 000000            NOP
1704                                RRL_END
1705   
1706      P:0004CC P:0004CC 0D0284            JSR     <READOUT                          ; final readout after all exposures
1707   
1708      P:0004CD P:0004CD 0C0054            JMP     <START
1709   
1710   
1711   
1712   
1713                                ; ***************** Start Read up the Ramp exponential *****************
1714   
1715   
1716   
1717   
1718                                START_RR_EXP
1719      P:0004CE P:0004CE 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
1720      P:0004CF P:0004CF 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
1721   
1722   
1723      P:0004D0 P:0004D0 200013            CLR     A
1724      P:0004D1 P:0004D1 5E8A00            MOVE                          Y:<NFS,A
1725      P:0004D2 P:0004D2 014184            SUB     #1,A                              ; subtract one readout from the loop and do 
the readout at the end
1726      P:0004D3 P:0004D3 000000            NOP
1727   
1728      P:0004D4 P:0004D4 06CE00            DO      A,RRE_END                         ; read up the ramp exponential
                            0004DA
1729   
1730      P:0004D6 P:0004D6 0D0284            JSR     <READOUT                          ; Read out the FPA
1731   
1732   
1733      P:0004D7 P:0004D7 67F400            MOVE              #L_SEX3,R7              ; Return address at end of exposure
                            0004DA
1734      P:0004D9 P:0004D9 0C049A            JMP     <EXPOSE                           ; Delay for specified exposure time
1735                                L_SEX3
1736   
1737   
1738      P:0004DA P:0004DA 000000            NOP
1739                                RRE_END
1740   
1741      P:0004DB P:0004DB 0D0284            JSR     <READOUT                          ; final readout after all exposures
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 31



1742   
1743      P:0004DC P:0004DC 0C0054            JMP     <START
1744   
1745   
1746   
1747   
1748                                ; Test for continuous readout
1749                                ;       MOVE    Y:<N_FRAMES,A
1750                                ;       CMP     #1,A
1751                                ;       JLE     <INIT_PCI_BOARD
1752   
1753                                INIT_FRAME_COUNT
1754      P:0004DD P:0004DD 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1755      P:0004DE P:0004DE 57F400            MOVE              #$020102,B              ; Initialize the PCI frame counter
                            020102
1756      P:0004E0 P:0004E0 0D00EB            JSR     <XMT_WRD
1757      P:0004E1 P:0004E1 57F400            MOVE              #'IFC',B
                            494643
1758      P:0004E3 P:0004E3 0D00EB            JSR     <XMT_WRD
1759      P:0004E4 P:0004E4 240000            MOVE              #0,X0
1760      P:0004E5 P:0004E5 4C0E00            MOVE                          X0,Y:<I_FRAME ; Initialize the frame number
1761      P:0004E6 P:0004E6 0C04F3            JMP     <INIT_PCI_BOARD
1762   
1763                                ; Start up the next frame of the coaddition series
1764                                NEXT_FRAME
1765      P:0004E7 P:0004E7 5E8E00            MOVE                          Y:<I_FRAME,A ; Get the # of frames coadded so far
1766      P:0004E8 P:0004E8 014180            ADD     #1,A
1767      P:0004E9 P:0004E9 4C8D00            MOVE                          Y:<N_FRAMES,X0 ; See if we've coadded enough frames
1768      P:0004EA P:0004EA 5C0E00            MOVE                          A1,Y:<I_FRAME ; Increment the coaddition frame counter
1769      P:0004EB P:0004EB 200045            CMP     X0,A
1770      P:0004EC P:0004EC 0E1390            JGE     <RDA_END                          ; End of coaddition sequence
1771   
1772      P:0004ED P:0004ED 5E8F00            MOVE                          Y:<IBUFFER,A ; Get the position in the buffer
1773      P:0004EE P:0004EE 014180            ADD     #1,A
1774      P:0004EF P:0004EF 4C9000            MOVE                          Y:<N_FPB,X0
1775      P:0004F0 P:0004F0 5C0F00            MOVE                          A1,Y:<IBUFFER
1776      P:0004F1 P:0004F1 200045            CMP     X0,A
1777      P:0004F2 P:0004F2 0E94FB            JLT     <SEX_1                            ; Test if the frame buffer is full
1778   
1779                                INIT_PCI_BOARD
1780      P:0004F3 P:0004F3 240000            MOVE              #0,X0
1781      P:0004F4 P:0004F4 4C0F00            MOVE                          X0,Y:<IBUFFER ; IBUFFER counts from 0 to N_FPB
1782      P:0004F5 P:0004F5 57F400            MOVE              #$020102,B
                            020102
1783      P:0004F7 P:0004F7 0D00EB            JSR     <XMT_WRD
1784      P:0004F8 P:0004F8 57F400            MOVE              #'IIA',B                ; Initialize the PCI image address
                            494941
1785      P:0004FA P:0004FA 0D00EB            JSR     <XMT_WRD
1786   
1787                                ; Start the exposure
1788      P:0004FB P:0004FB 0A00AA  SEX_1     JSET    #TST_IMG,X:STATUS,SYNTHETIC_IMAGE
                            000536
1789      P:0004FD P:0004FD 56F400            MOVE              #$0c1000,A              ; Reset video processor FIFOs
                            0C1000
1790      P:0004FF P:0004FF 0D0550            JSR     <WR_BIAS
1791      P:000500 P:000500 0A00B2            JSET    #ST_RRR,X:STATUS,ROW_BY_ROW_RESET_READOUT
                            0002F1
1792      P:000502 P:000502 0C0277            JMP     <NORMAL_READOUT
1793   
1794   
1795                                ; ********************* Initialize PCI image address ***********************
1796                                INIT_PCI_IMAGE_ADDRESS
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 32



1797      P:000503 P:000503 57F400            MOVE              #$020102,B              ; Initialize the PCI image address
                            020102
1798      P:000505 P:000505 0D00EB            JSR     <XMT_WRD
1799      P:000506 P:000506 57F400            MOVE              #'IIA',B
                            494941
1800      P:000508 P:000508 0D00EB            JSR     <XMT_WRD
1801      P:000509 P:000509 00000C            RTS
1802   
1803   
1804                                ; Set the desired exposure time
1805                                SET_EXPOSURE_TIME
1806      P:00050A P:00050A 46DB00            MOVE              X:(R3)+,Y0
1807      P:00050B P:00050B 461000            MOVE              Y0,X:EXPOSURE_TIME
1808      P:00050C P:00050C 018F80            JCLR    #TIM_BIT,X:TCSR0,FINISH           ; Return if exposure not occurring
                            00008F
1809      P:00050E P:00050E 467000            MOVE              Y0,X:TCPR0              ; Update timer if exposure in progress
                            FFFF8D
1810      P:000510 P:000510 0C008F            JMP     <FINISH
1811   
1812                                ; Read the time remaining until the exposure ends
1813                                READ_EXPOSURE_TIME
1814      P:000511 P:000511 018FA0            JSET    #TIM_BIT,X:TCSR0,RD_TIM           ; Read DSP timer if its running
                            000515
1815      P:000513 P:000513 479100            MOVE              X:<ELAPSED_TIME,Y1
1816      P:000514 P:000514 0C0090            JMP     <FINISH1
1817      P:000515 P:000515 47F000  RD_TIM    MOVE              X:TCR0,Y1               ; Read elapsed exposure time
                            FFFF8C
1818      P:000517 P:000517 0C0090            JMP     <FINISH1
1819   
1820                                ; Pause the exposure - close the shutter and stop the timer
1821                                PAUSE_EXPOSURE
1822      P:000518 P:000518 07700C            MOVEP             X:TCR0,X:ELAPSED_TIME   ; Save the elapsed exposure time
                            000011
1823      P:00051A P:00051A 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1824      P:00051B P:00051B 0C008F            JMP     <FINISH
1825   
1826                                ; Resume the exposure - open the shutter if needed and restart the timer
1827                                RESUME_EXPOSURE
1828      P:00051C P:00051C 07F00E            MOVEP             X:ELAPSED_TIME,X:TLR0   ; Restore elapsed exposure time
                            000011
1829      P:00051E P:00051E 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Re-enable the DSP exposure timer
1830      P:00051F P:00051F 0C008F  L_RES     JMP     <FINISH
1831   
1832                                ; Special ending after abort command to send a 'DON' to the host computer
1833                                ; Abort exposure - close the shutter, stop the timer and resume idle mode
1834                                ABORT_EXPOSURE
1835      P:000520 P:000520 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1836      P:000521 P:000521 60F400            MOVE              #CONT_RST,R0
                            00022D
1837      P:000523 P:000523 601F00            MOVE              R0,X:<IDL_ADR
1838      P:000524 P:000524 0D0563            JSR     <WAIT_TO_FINISH_CLOCKING
1839      P:000525 P:000525 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1840      P:000526 P:000526 06A08F            DO      #4000,*+3                         ; Wait 40 microsec for the fiber
                            000528
1841      P:000528 P:000528 000000            NOP                                       ;  optic to clear out
1842      P:000529 P:000529 0C008F            JMP     <FINISH
1843   
1844                                ; Short delay for the array to settle down after a global reset
1845                                MILLISEC_DELAY
1846      P:00052A P:00052A 200003            TST     A
1847      P:00052B P:00052B 0E252D            JNE     <DLY_IT
1848      P:00052C P:00052C 00000C            RTS
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 33



1849      P:00052D P:00052D 07F40E  DLY_IT    MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1850      P:00052F P:00052F 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1851      P:000530 P:000530 567000            MOVE              A,X:TCPR0               ; Desired elapsed time
                            FFFF8D
1852      P:000532 P:000532 018F95  CNT_DWN   JCLR    #TCF,X:TCSR0,CNT_DWN              ; Wait here for timer to count down
                            000532
1853      P:000534 P:000534 010F00            BCLR    #TIM_BIT,X:TCSR0
1854      P:000535 P:000535 00000C            RTS
1855   
1856                                ; Generate a synthetic image by simply incrementing the pixel counts
1857                                SYNTHETIC_IMAGE
1858      P:000536 P:000536 0D0557            JSR     <PCI_READ_IMAGE
1859                                                                                    ;CLR    A
1860                                ;       DO      Y:<NPR,LPR_TST          ; Loop over each line readout
1861      P:000537 P:000537 060182            DO      #513,LPR_TST                      ; Loop over each line readout
                            000542
1862      P:000539 P:000539 060140            DO      Y:<NSR,LSR_TST                    ; Loop over number of pixels per line
                            000540
1863      P:00053B P:00053B 0614A0            REP     #20                               ; #20 => 1.0 microsec per pixel
1864      P:00053C P:00053C 000000            NOP
1865                                ;       ADD     #1,A                    ; Pixel data = Pixel data + 1
1866      P:00053D P:00053D 000000            NOP
1867      P:00053E P:00053E 21CF00            MOVE              A,B
1868      P:00053F P:00053F 0D0546            JSR     <XMT_PIX                          ; Transmit the pixel data
1869      P:000540 P:000540 000000            NOP
1870                                LSR_TST
1871      P:000541 P:000541 014180            ADD     #1,A                              ; Pixel data = Pixel data + 1
1872      P:000542 P:000542 000000            NOP
1873                                LPR_TST
1874      P:000543 P:000543 0140C0            ADD     #10000,A
                            002710
1875      P:000545 P:000545 00000C            RTS
1876   
1877                                ; Transmit the 16-bit pixel datum in B1 to the host computer
1878      P:000546 P:000546 0C1DA1  XMT_PIX   ASL     #16,B,B
1879      P:000547 P:000547 000000            NOP
1880      P:000548 P:000548 216500            MOVE              B2,X1
1881      P:000549 P:000549 0C1D91            ASL     #8,B,B
1882      P:00054A P:00054A 000000            NOP
1883      P:00054B P:00054B 216400            MOVE              B2,X0
1884      P:00054C P:00054C 000000            NOP
1885      P:00054D P:00054D 09C532            MOVEP             X1,Y:WRFO
1886      P:00054E P:00054E 09C432            MOVEP             X0,Y:WRFO
1887      P:00054F P:00054F 00000C            RTS
1888   
1889                                ; Write a number to an analog board over the serial link
1890      P:000550 P:000550 012F23  WR_BIAS   BSET    #3,X:PCRD                         ; Turn on the serial clock
1891      P:000551 P:000551 0D0571            JSR     <PAL_DLY
1892      P:000552 P:000552 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1893      P:000553 P:000553 0D0571            JSR     <PAL_DLY
1894      P:000554 P:000554 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1895      P:000555 P:000555 0D0571            JSR     <PAL_DLY
1896      P:000556 P:000556 00000C            RTS
1897   
1898                                ; Alert the PCI interface board that images are coming soon
1899                                ;   Image size = 512columns x 512 x # of Fowler samples x 2 if CDS
1900   
1901                                PCI_READ_IMAGE
1902      P:000557 P:000557 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1903      P:000559 P:000559 0D00EB            JSR     <XMT_WRD
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 34



1904      P:00055A P:00055A 57F400            MOVE              #'RDA',B
                            524441
1905      P:00055C P:00055C 0D00EB            JSR     <XMT_WRD
1906      P:00055D P:00055D 5F8100            MOVE                          Y:<NSR,B    ; Number of columns to read
1907      P:00055E P:00055E 0D00EB            JSR     <XMT_WRD
1908                                ;       MOVE    Y:<NPR,B
1909      P:00055F P:00055F 57F400            MOVE              #513,B
                            000201
1910      P:000561 P:000561 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1911      P:000562 P:000562 00000C            RTS
1912   
1913                                ; Wait for the clocking to be complete before proceeding
1914                                WAIT_TO_FINISH_CLOCKING
1915      P:000563 P:000563 01ADA1            JSET    #SSFEF,X:PDRD,*                   ; Wait for the SS FIFO to be empty
                            000563
1916      P:000565 P:000565 00000C            RTS
1917   
1918                                ; This MOVEP instruction executes in 30 nanosec, 20 nanosec for the MOVEP,
1919                                ;   and 10 nanosec for the wait state that is required for SRAM writes and
1920                                ;   FIFO setup times. It looks reliable, so will be used for now.
1921   
1922                                ; Core subroutine for clocking
1923                                CLOCK
1924      P:000566 P:000566 0A898E            JCLR    #SSFHF,X:HDR,*                    ; Only write to FIFO if < half full
                            000566
1925      P:000568 P:000568 000000            NOP
1926      P:000569 P:000569 0A898E            JCLR    #SSFHF,X:HDR,CLOCK                ; Guard against metastability
                            000566
1927      P:00056B P:00056B 4CD800            MOVE                          Y:(R0)+,X0  ; # of waveform entries
1928      P:00056C P:00056C 06C400            DO      X0,CLK1                           ; Repeat X0 times
                            00056E
1929      P:00056E P:00056E 09D8F3            MOVEP             Y:(R0)+,Y:WRSS          ; 30 nsec Write the waveform to the SS
1930                                CLK1
1931      P:00056F P:00056F 000000            NOP
1932      P:000570 P:000570 00000C            RTS                                       ; Return from subroutine
1933   
1934                                ; Delay for serial writes to the PALs and DACs by 8 microsec
1935      P:000571 P:000571 062083  PAL_DLY   DO      #800,DLY                          ; Wait 8 usec for serial data transmission
                            000573
1936      P:000573 P:000573 000000            NOP
1937      P:000574 P:000574 000000  DLY       NOP
1938      P:000575 P:000575 00000C            RTS
1939   
1940                                ; Read DAC values from a table, and write them to the DACs
1941      P:000576 P:000576 065840  SET_DAC   DO      Y:(R0)+,L_DAC                     ; Repeat Y:(R0)+ times
                            00057D
1942      P:000578 P:000578 5ED800            MOVE                          Y:(R0)+,A   ; Read the table entry
1943      P:000579 P:000579 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1944      P:00057A P:00057A 000000            NOP
1945      P:00057B P:00057B 0D0571            JSR     <PAL_DLY
1946      P:00057C P:00057C 0D0571            JSR     <PAL_DLY
1947      P:00057D P:00057D 000000            NOP
1948      P:00057E P:00057E 00000C  L_DAC     RTS
1949   
1950                                ; Let the host computer read the controller configuration
1951                                READ_CONTROLLER_CONFIGURATION
1952      P:00057F P:00057F 4F8800            MOVE                          Y:<CONFIG,Y1 ; Just transmit the configuration
1953      P:000580 P:000580 0C0090            JMP     <FINISH1
1954   
1955                                ; Set a particular DAC numbers, for setting DC bias voltages, clock driver
1956                                ;   voltages and video processor offset
1957                                ;
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 35



1958                                ; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
1959                                ;
1960                                ;                               #BOARD is from 0 to 15
1961                                ;                               #DAC number
1962                                ;                               #voltage is from 0 to 4095
1963   
1964                                SET_BIAS_NUMBER                                     ; Set bias number
1965      P:000581 P:000581 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1966      P:000582 P:000582 56DB00            MOVE              X:(R3)+,A               ; First argument is board number, 0 to 15
1967      P:000583 P:000583 0614A0            REP     #20
1968      P:000584 P:000584 200033            LSL     A
1969      P:000585 P:000585 000000            NOP
1970      P:000586 P:000586 21C500            MOVE              A,X1                    ; Save the board number
1971      P:000587 P:000587 56DB00            MOVE              X:(R3)+,A               ; Second argument is DAC number
1972      P:000588 P:000588 000000            NOP
1973      P:000589 P:000589 5C0000            MOVE                          A1,Y:0      ; Save the DAC number for a little while
1974      P:00058A P:00058A 57DB00            MOVE              X:(R3)+,B               ; Third argument is 'VID' or 'CLK' string
1975      P:00058B P:00058B 0140CD            CMP     #'VID',B
                            564944
1976      P:00058D P:00058D 0EA5C7            JEQ     <ERR_SBN                          ; Video board offsets aren't supported
1977      P:00058E P:00058E 0140CD            CMP     #'CLK',B
                            434C4B
1978      P:000590 P:000590 0E25C7            JNE     <ERR_SBN
1979   
1980                                ; For ARC32 do some trickiness to set the chip select and address bits
1981      P:000591 P:000591 218F00            MOVE              A1,B
1982      P:000592 P:000592 060EA0            REP     #14
1983      P:000593 P:000593 200033            LSL     A
1984      P:000594 P:000594 240E00            MOVE              #$0E0000,X0
1985      P:000595 P:000595 200046            AND     X0,A
1986      P:000596 P:000596 44F400            MOVE              #>7,X0
                            000007
1987      P:000598 P:000598 20004E            AND     X0,B                              ; Get 3 least significant bits of clock #
1988      P:000599 P:000599 01408D            CMP     #0,B
1989      P:00059A P:00059A 0E259D            JNE     <CLK_1
1990      P:00059B P:00059B 0ACE68            BSET    #8,A
1991      P:00059C P:00059C 0C05B8            JMP     <BD_SET
1992      P:00059D P:00059D 01418D  CLK_1     CMP     #1,B
1993      P:00059E P:00059E 0E25A1            JNE     <CLK_2
1994      P:00059F P:00059F 0ACE69            BSET    #9,A
1995      P:0005A0 P:0005A0 0C05B8            JMP     <BD_SET
1996      P:0005A1 P:0005A1 01428D  CLK_2     CMP     #2,B
1997      P:0005A2 P:0005A2 0E25A5            JNE     <CLK_3
1998      P:0005A3 P:0005A3 0ACE6A            BSET    #10,A
1999      P:0005A4 P:0005A4 0C05B8            JMP     <BD_SET
2000      P:0005A5 P:0005A5 01438D  CLK_3     CMP     #3,B
2001      P:0005A6 P:0005A6 0E25A9            JNE     <CLK_4
2002      P:0005A7 P:0005A7 0ACE6B            BSET    #11,A
2003      P:0005A8 P:0005A8 0C05B8            JMP     <BD_SET
2004      P:0005A9 P:0005A9 01448D  CLK_4     CMP     #4,B
2005      P:0005AA P:0005AA 0E25AD            JNE     <CLK_5
2006      P:0005AB P:0005AB 0ACE6D            BSET    #13,A
2007      P:0005AC P:0005AC 0C05B8            JMP     <BD_SET
2008      P:0005AD P:0005AD 01458D  CLK_5     CMP     #5,B
2009      P:0005AE P:0005AE 0E25B1            JNE     <CLK_6
2010      P:0005AF P:0005AF 0ACE6E            BSET    #14,A
2011      P:0005B0 P:0005B0 0C05B8            JMP     <BD_SET
2012      P:0005B1 P:0005B1 01468D  CLK_6     CMP     #6,B
2013      P:0005B2 P:0005B2 0E25B5            JNE     <CLK_7
2014      P:0005B3 P:0005B3 0ACE6F            BSET    #15,A
2015      P:0005B4 P:0005B4 0C05B8            JMP     <BD_SET
2016      P:0005B5 P:0005B5 01478D  CLK_7     CMP     #7,B
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 36



2017      P:0005B6 P:0005B6 0E25B8            JNE     <BD_SET
2018      P:0005B7 P:0005B7 0ACE70            BSET    #16,A
2019   
2020      P:0005B8 P:0005B8 200062  BD_SET    OR      X1,A                              ; Add on the board number
2021      P:0005B9 P:0005B9 000000            NOP
2022      P:0005BA P:0005BA 21C400            MOVE              A,X0
2023      P:0005BB P:0005BB 56DB00            MOVE              X:(R3)+,A               ; Fourth argument is voltage value, 0 to $ff
f
2024      P:0005BC P:0005BC 0604A0            REP     #4
2025      P:0005BD P:0005BD 200023            LSR     A                                 ; Convert 12 bits to 8 bits for ARC32
2026      P:0005BE P:0005BE 46F400            MOVE              #>$FF,Y0                ; Mask off just 8 bits
                            0000FF
2027      P:0005C0 P:0005C0 200056            AND     Y0,A
2028      P:0005C1 P:0005C1 200042            OR      X0,A
2029      P:0005C2 P:0005C2 000000            NOP
2030      P:0005C3 P:0005C3 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
2031      P:0005C4 P:0005C4 0D0571            JSR     <PAL_DLY                          ; Wait for the number to be sent
2032      P:0005C5 P:0005C5 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
2033      P:0005C6 P:0005C6 0C008F            JMP     <FINISH
2034      P:0005C7 P:0005C7 56DB00  ERR_SBN   MOVE              X:(R3)+,A               ; Read and discard the fourth argument
2035      P:0005C8 P:0005C8 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
2036      P:0005C9 P:0005C9 0C008D            JMP     <ERROR
2037   
2038                                ; Specify the MUX value to be output on the clock driver board
2039                                ; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
2040                                ;                               #clock_driver_board from 0 to 15
2041                                ;                               #MUX1, #MUX2 from 0 to 23
2042   
2043      P:0005CA P:0005CA 012F23  SET_MUX   BSET    #3,X:PCRD                         ; Turn on the serial clock
2044      P:0005CB P:0005CB 56DB00            MOVE              X:(R3)+,A               ; Clock driver board number
2045      P:0005CC P:0005CC 0614A0            REP     #20
2046      P:0005CD P:0005CD 200033            LSL     A
2047      P:0005CE P:0005CE 44F400            MOVE              #$001000,X0             ; Bits to select MUX on ARC32 board
                            001000
2048      P:0005D0 P:0005D0 200042            OR      X0,A
2049      P:0005D1 P:0005D1 000000            NOP
2050      P:0005D2 P:0005D2 218500            MOVE              A1,X1                   ; Move here for later use
2051   
2052                                ; Get the first MUX number
2053      P:0005D3 P:0005D3 56DB00            MOVE              X:(R3)+,A               ; Get the first MUX number
2054      P:0005D4 P:0005D4 200003            TST     A
2055      P:0005D5 P:0005D5 0E961A            JLT     <ERR_SM1
2056      P:0005D6 P:0005D6 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
2057      P:0005D8 P:0005D8 200045            CMP     X0,A
2058      P:0005D9 P:0005D9 0E161A            JGE     <ERR_SM1
2059      P:0005DA P:0005DA 21CF00            MOVE              A,B
2060      P:0005DB P:0005DB 44F400            MOVE              #>7,X0
                            000007
2061      P:0005DD P:0005DD 20004E            AND     X0,B
2062      P:0005DE P:0005DE 44F400            MOVE              #>$18,X0
                            000018
2063      P:0005E0 P:0005E0 200046            AND     X0,A
2064      P:0005E1 P:0005E1 0E25E4            JNE     <SMX_1                            ; Test for 0 <= MUX number <= 7
2065      P:0005E2 P:0005E2 0ACD63            BSET    #3,B1
2066      P:0005E3 P:0005E3 0C05EF            JMP     <SMX_A
2067      P:0005E4 P:0005E4 44F400  SMX_1     MOVE              #>$08,X0
                            000008
2068      P:0005E6 P:0005E6 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
2069      P:0005E7 P:0005E7 0E25EA            JNE     <SMX_2
2070      P:0005E8 P:0005E8 0ACD64            BSET    #4,B1
2071      P:0005E9 P:0005E9 0C05EF            JMP     <SMX_A
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 37



2072      P:0005EA P:0005EA 44F400  SMX_2     MOVE              #>$10,X0
                            000010
2073      P:0005EC P:0005EC 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
2074      P:0005ED P:0005ED 0E261A            JNE     <ERR_SM1
2075      P:0005EE P:0005EE 0ACD65            BSET    #5,B1
2076      P:0005EF P:0005EF 20006A  SMX_A     OR      X1,B1                             ; Add prefix to MUX numbers
2077      P:0005F0 P:0005F0 000000            NOP
2078      P:0005F1 P:0005F1 21A700            MOVE              B1,Y1
2079   
2080                                ; Add on the second MUX number
2081      P:0005F2 P:0005F2 56DB00            MOVE              X:(R3)+,A               ; Get the next MUX number
2082      P:0005F3 P:0005F3 200003            TST     A
2083      P:0005F4 P:0005F4 0E961B            JLT     <ERR_SM2
2084      P:0005F5 P:0005F5 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
2085      P:0005F7 P:0005F7 200045            CMP     X0,A
2086      P:0005F8 P:0005F8 0E161B            JGE     <ERR_SM2
2087      P:0005F9 P:0005F9 0606A0            REP     #6
2088      P:0005FA P:0005FA 200033            LSL     A
2089      P:0005FB P:0005FB 000000            NOP
2090      P:0005FC P:0005FC 21CF00            MOVE              A,B
2091      P:0005FD P:0005FD 44F400            MOVE              #$1C0,X0
                            0001C0
2092      P:0005FF P:0005FF 20004E            AND     X0,B
2093      P:000600 P:000600 44F400            MOVE              #>$600,X0
                            000600
2094      P:000602 P:000602 200046            AND     X0,A
2095      P:000603 P:000603 0E2606            JNE     <SMX_3                            ; Test for 0 <= MUX number <= 7
2096      P:000604 P:000604 0ACD69            BSET    #9,B1
2097      P:000605 P:000605 0C0611            JMP     <SMX_B
2098      P:000606 P:000606 44F400  SMX_3     MOVE              #>$200,X0
                            000200
2099      P:000608 P:000608 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
2100      P:000609 P:000609 0E260C            JNE     <SMX_4
2101      P:00060A P:00060A 0ACD6A            BSET    #10,B1
2102      P:00060B P:00060B 0C0611            JMP     <SMX_B
2103      P:00060C P:00060C 44F400  SMX_4     MOVE              #>$400,X0
                            000400
2104      P:00060E P:00060E 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
2105      P:00060F P:00060F 0E261B            JNE     <ERR_SM2
2106      P:000610 P:000610 0ACD6B            BSET    #11,B1
2107      P:000611 P:000611 200078  SMX_B     ADD     Y1,B                              ; Add prefix to MUX numbers
2108      P:000612 P:000612 000000            NOP
2109      P:000613 P:000613 21AE00            MOVE              B1,A
2110      P:000614 P:000614 0140C6            AND     #$F01FFF,A                        ; Just to be sure
                            F01FFF
2111      P:000616 P:000616 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
2112      P:000617 P:000617 0D0571            JSR     <PAL_DLY                          ; Delay for all this to happen
2113      P:000618 P:000618 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
2114      P:000619 P:000619 0C008F            JMP     <FINISH
2115      P:00061A P:00061A 56DB00  ERR_SM1   MOVE              X:(R3)+,A               ; Throw off the last argument
2116      P:00061B P:00061B 012F03  ERR_SM2   BCLR    #3,X:PCRD                         ; Turn the serial clock off
2117      P:00061C P:00061C 0C008D            JMP     <ERROR
2118   
2119   
2120                                CORRELATED_DOUBLE_SAMPLE
2121      P:00061D P:00061D 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
2122      P:00061E P:00061E 0AC420            JSET    #0,X0,CDS_SET
                            000622
2123      P:000620 P:000620 0A0011            BCLR    #ST_CDS,X:STATUS
2124      P:000621 P:000621 0C008F            JMP     <FINISH
2125      P:000622 P:000622 0A0031  CDS_SET   BSET    #ST_CDS,X:STATUS
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 38



2126      P:000623 P:000623 0C008F            JMP     <FINISH
2127   
2128                                SELECT_ROW_BY_ROW_RESET
2129      P:000624 P:000624 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
2130      P:000625 P:000625 0AC420            JSET    #0,X0,RR_SET
                            000629
2131      P:000627 P:000627 0A0012            BCLR    #ST_RRR,X:STATUS
2132      P:000628 P:000628 0C008F            JMP     <FINISH
2133      P:000629 P:000629 0A0032  RR_SET    BSET    #ST_RRR,X:STATUS
2134      P:00062A P:00062A 0C008F            JMP     <FINISH
2135   
2136                                ;******************************************************************************
2137                                ; Set number of Fowler samples per frame
2138                                ;******************************************************************************
2139   
2140                                SET_NUMBER_OF_FOWLER_SAMPLES
2141      P:00062B P:00062B 44DB00            MOVE              X:(R3)+,X0
2142      P:00062C P:00062C 4C0A00            MOVE                          X0,Y:<NFS   ; Number of Fowler samples
2143      P:00062D P:00062D 0C008F            JMP     <FINISH
2144   
2145   
2146                                ;******************************************************************************
2147                                ; Set number of digital samples
2148                                ;******************************************************************************
2149   
2150   
2151   
2152                                SET_NUMBER_OF_DIGITAL_SAMPLES
2153      P:00062E P:00062E 44DB00            MOVE              X:(R3)+,X0
2154      P:00062F P:00062F 4C0B00            MOVE                          X0,Y:<NDS   ; Number of Digital samples
2155   
2156      P:000630 P:000630 200013            CLR     A
2157      P:000631 P:000631 000000            NOP
2158      P:000632 P:000632 060B40            DO      Y:<NDS,CALC_NSR
                            000636
2159      P:000634 P:000634 0140C0            ADD     #2048,A                           ; columns in 4 quadrants times NDS
                            000800
2160      P:000636 P:000636 000000            NOP
2161                                CALC_NSR
2162   
2163      P:000637 P:000637 5E0100            MOVE                          A,Y:<NSR    ; Number of columns
2164   
2165      P:000638 P:000638 0C008F            JMP     <FINISH
2166   
2167   
2168   
2169                                ;******************************************************************************
2170                                ; Set number of clockouts
2171                                ;******************************************************************************
2172   
2173   
2174                                SET_NUMBER_OF_CLOCKOUTS
2175      P:000639 P:000639 44DB00            MOVE              X:(R3)+,X0
2176      P:00063A P:00063A 4C0C00            MOVE                          X0,Y:<NCO   ; Number of Clockouts
2177      P:00063B P:00063B 0C008F            JMP     <FINISH
2178   
2179   
2180                                ;******************************************************************************
2181                                ; Reset the Array
2182                                ;******************************************************************************
2183   
2184                                CLOCKOUT_ARRAY_CMD
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  timIRmisc.asm  Page 39



2185   
2186      P:00063C P:00063C 060C40            DO      Y:<NCO,CLK_OUT_END
                            000640
2187                                ;        JSR    <RESET_ARRAY            ; Clear out the FPA
2188      P:00063E P:00063E 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
2189      P:00063F P:00063F 0D02BB            JSR     <NO_READOUT
2190      P:000640 P:000640 000000            NOP
2191                                CLK_OUT_END
2192   
2193      P:000641 P:000641 0C008F            JMP     <FINISH
2194   
2195   
2196                                RESET_ARRAY_CMD
2197   
2198      P:000642 P:000642 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
2199      P:000643 P:000643 0C008F            JMP     <FINISH
2200   
2201                                RESET_READOUT_CMD
2202      P:000644 P:000644 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
2203      P:000645 P:000645 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
2204      P:000646 P:000646 0D0284            JSR     <READOUT                          ; Read out the FPA
2205      P:000647 P:000647 0C008F            JMP     <FINISH
2206   
2207                                READOUT_ARRAY_CMD
2208      P:000648 P:000648 0D0503            JSR     <INIT_PCI_IMAGE_ADDRESS
2209      P:000649 P:000649 0D0284            JSR     <READOUT                          ; Read out the FPA
2210      P:00064A P:00064A 0C008F            JMP     <FINISH
2211   
2212                                ;******************************************************************************
2213                                ; Set the number of RESET frame.
2214                                ;SET_NUMBER_OF_RESET
2215                                ;       MOVE    X:(R3)+,X0
2216                                ;       MOVE    X0,Y:<NRESET
2217                                ;       JMP     <FINISH
2218   
2219   
2220                                ; Continuous readout commands
2221                                SET_NUMBER_OF_FRAMES                                ; Number of frames to obtain
2222      P:00064B P:00064B 44DB00            MOVE              X:(R3)+,X0              ;   in an exposure sequence
2223      P:00064C P:00064C 4C0D00            MOVE                          X0,Y:<N_FRAMES
2224      P:00064D P:00064D 0C008F            JMP     <FINISH
2225   
2226                                SET_NUMBER_OF_FRAMES_PER_BUFFER                     ; Number of frames in each image
2227      P:00064E P:00064E 44DB00            MOVE              X:(R3)+,X0              ;   buffer in the host computer
2228      P:00064F P:00064F 4C1000            MOVE                          X0,Y:<N_FPB ;   system memory
2229      P:000650 P:000650 0C008F            JMP     <FINISH
2230   
2231   
2232                                 TIMBOOT_X_MEMORY
2233      000651                              EQU     @LCV(L)
2234   
2235                                ;  ****************  Setup memory tables in X: space ********************
2236   
2237                                ; Define the address in P: space where the table of constants begins
2238   
2239                                          IF      @SCP("HOST","HOST")
2240      X:000036 X:000036                   ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
2241                                          ENDIF
2242   
2243                                          IF      @SCP("HOST","ROM")
2245                                          ENDIF
2246   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 40



2247                                ; Application commands
2248      X:000036 X:000036                   DC      'PON',POWER_ON
2249      X:000038 X:000038                   DC      'POF',POWER_OFF
2250      X:00003A X:00003A                   DC      'SBL',SET_BIAS_VOLTAGES_L
2251      X:00003C X:00003C                   DC      'SBV',SET_BIAS_VOLTAGES
2252      X:00003E X:00003E                   DC      'SBH',SET_BIAS_VOLTAGES_H
2253      X:000040 X:000040                   DC      'IDL',FINISH
2254      X:000042 X:000042                   DC      'CLR',CLEAR
2255   
2256                                ; Exposure and readout control routines
2257      X:000044 X:000044                   DC      'SET',SET_EXPOSURE_TIME
2258      X:000046 X:000046                   DC      'RET',READ_EXPOSURE_TIME
2259      X:000048 X:000048                   DC      'SEX',START_EXPOSURE
2260      X:00004A X:00004A                   DC      'SRL',START_RR_LINEAR
2261      X:00004C X:00004C                   DC      'SRE',START_RR_EXP
2262      X:00004E X:00004E                   DC      'PEX',PAUSE_EXPOSURE
2263      X:000050 X:000050                   DC      'REX',RESUME_EXPOSURE
2264      X:000052 X:000052                   DC      'AEX',ABORT_EXPOSURE
2265      X:000054 X:000054                   DC      'ABR',ABORT_EXPOSURE
2266      X:000056 X:000056                   DC      'CDS',CORRELATED_DOUBLE_SAMPLE
2267      X:000058 X:000058                   DC      'RRR',SELECT_ROW_BY_ROW_RESET
2268      X:00005A X:00005A                   DC      'SFS',SET_NUMBER_OF_FOWLER_SAMPLES
2269      X:00005C X:00005C                   DC      'SDS',SET_NUMBER_OF_DIGITAL_SAMPLES
2270      X:00005E X:00005E                   DC      'SNC',SET_NUMBER_OF_CLOCKOUTS
2271      X:000060 X:000060                   DC      'COA',CLOCKOUT_ARRAY_CMD
2272      X:000062 X:000062                   DC      'RAR',RESET_ARRAY_CMD
2273      X:000064 X:000064                   DC      'RRO',RESET_READOUT_CMD
2274      X:000066 X:000066                   DC      'ROR',READOUT_ARRAY_CMD
2275   
2276                                ; Support routines
2277      X:000068 X:000068                   DC      'SBN',SET_BIAS_NUMBER
2278      X:00006A X:00006A                   DC      'SMX',SET_MUX
2279      X:00006C X:00006C                   DC      'CSW',CLR_SWS
2280      X:00006E X:00006E                   DC      'RCC',READ_CONTROLLER_CONFIGURATION
2281   
2282                                ; Continuous readout commands
2283      X:000070 X:000070                   DC      'SNF',SET_NUMBER_OF_FRAMES
2284      X:000072 X:000072                   DC      'FPB',SET_NUMBER_OF_FRAMES_PER_BUFFER
2285   
2286                                 END_APPLICATON_COMMAND_TABLE
2287      000074                              EQU     @LCV(L)
2288   
2289                                          IF      @SCP("HOST","HOST")
2290      000026                    NUM_COM   EQU     (@LCV(R)-COM_TBL_R)/2             ; Number of boot +
2291                                                                                    ;  application commands
2292      0004AA                    EXPOSING  EQU     CHK_TIM                           ; Address if exposing
2293                                 CONTINUE_READING
2294      100000                              EQU     CONT_RD                           ; Address if reading out
2295                                          ENDIF
2296   
2297                                          IF      @SCP("HOST","ROM")
2299                                          ENDIF
2300   
2301                                ; Now let's go for the timing waveform tables
2302                                          IF      @SCP("HOST","HOST")
2303      Y:000000 Y:000000                   ORG     Y:0,Y:0
2304                                          ENDIF
2305   
2306      Y:000000 Y:000000         GAIN      DC      END_APPLICATON_Y_MEMORY-@LCV(L)-1
2307   
2308      Y:000001 Y:000001         NSR       DC      12288                             ; 512 x6DS x4 for 4 Quadrants
2309      Y:000002 Y:000002         NPR       DC      1024                              ; 2048 = 2(CDS) x NFS=1 x 512
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 41



2310      Y:000003 Y:000003         NSCLR     DC      0                                 ; Not used
2311      Y:000004 Y:000004         NPCLR     DC      0                                 ; Not used
2312      Y:000005 Y:000005         DUMMY     DC      0,0                               ; Binning parameters (reserved)
2313      Y:000007 Y:000007         TST_DAT   DC      0                                 ; Temporary definition for test images
2314      Y:000008 Y:000008         CONFIG    DC      CC                                ; Controller configuration
2315      Y:000009 Y:000009         TRM_ADR   DC      0                                 ; Test RAM memory error address
2316      Y:00000A Y:00000A         NFS       DC      1                                 ; Number of Fowler samples
2317      Y:00000B Y:00000B         NDS       DC      1                                 ; Number of Digital samples
2318      Y:00000C Y:00000C         NCO       DC      0                                 ; Number of clockouts
2319   
2320                                ; Continuous readout parameters
2321      Y:00000D Y:00000D         N_FRAMES  DC      1                                 ; Total number of frames to read out
2322      Y:00000E Y:00000E         I_FRAME   DC      0                                 ; Number of frames read out so far
2323      Y:00000F Y:00000F         IBUFFER   DC      0                                 ; Number of frames read into the PCI buffer
2324      Y:000010 Y:000010         N_FPB     DC      0                                 ; Number of frames per PCI image buffer
2325   
2326                                ; Include the waveform table for the designated IR array
2327                                          INCLUDE "AladdinIII.waveforms"            ; Readout and clocking waveform file
2328                                       COMMENT *
2329   
2330                                Waveform tables for Aladdin III IR array to be used with one ARC-46 =
2331                                        8-channel video processor boards and Gen III = ARC22 = 250 MHz
2332                                        timing board and ARC-32 clock driver board.
2333                                Modified Feb. 2009 for row-by-row reset for high flux observations
2334   
2335                                        *
2336   
2337      000001                    AD        EQU     $000001                           ; Bit to start A/D conversion
2338      000002                    XFER      EQU     $000002                           ; Bit to transfer A/D counts into the A/D FI
FO
2339      00F7C0                    SXMIT     EQU     $00F7C0                           ; Transmit 32 pixels = 4 Aladdin quadrants
2340   
2341                                ; Definitions of readout variables
2342      002000                    CLK2      EQU     $002000                           ; Clock driver board lower half
2343      003000                    CLK3      EQU     $003000                           ; Clock driver board upper half
2344      000000                    VIDEO     EQU     $000000                           ; Video processor board switches
2345   
2346                                ; Various delay parameters
2347      100000                    DLY0      EQU     $100000
2348      180000                    DLY1      EQU     $180000                           ; 1.0 microsec
2349      320000                    DLY2      EQU     $320000                           ; 2.0 microsec
2350      640000                    DLY4      EQU     $640000                           ; 4.0 microsec
2351      930000                    DLY6      EQU     $930000                           ; 6.0 microsec
2352   
2353      130000                    DLYA      EQU     $130000                           ; Pixel readout delay parameters
2354      040000                    DLYB      EQU     $040000
2355      C00000                    DLYG      EQU     $C00000
2356   
2357      0C0000                    XMT_DLY   EQU     $0C0000                           ; Delay per SXMIT for the fiber optic transm
itter
2358   
2359                                ; Voltages for operating the Aladdin III focal plane array. The clock driver
2360                                ;   needs to be jumpered for bipolar operation because of the output source
2361                                ;   load resistor driver, VSSOUT = +1.0
2362   
2363   
2364                                ; Voltages for operating the Aladdin III focal plane array ORIGINAL
2365                                ;CLK_HI         EQU     +0.0    ; Clock voltage low
2366                                ;CLK_LO         EQU     -5.0    ; Clock voltage low
2367                                ;VRW_LO         EQU     -4.0    ; VrowON low voltage
2368                                ;VRST_HI                EQU     -3.5    ; VrstG high voltage
2369                                ;VRST_LO                EQU     -5.8    ; VrstG low voltage
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 42



2370                                ;ZERO           EQU      0.0    ; Unused clock driver voltage
2371      000002                    ADREF     EQU     +2                                ; A/D converter voltage reference
2372      00000D                    Vmax      EQU     13                                ; Maximum clock driver voltage, clock board
2373      2.600000E+001             Vmax1     EQU     2.0*Vmax
2374      7.500000E+000             Vmax2     EQU     7.5                               ; 2 x Maximum clock driver voltage
2375      1.500000E+001             Vmax3     EQU     2.0*Vmax2
2376   
2377                                ; Voltages for operating the Aladdin III focal plane array TWEAKED BY LUC AS NASA IRTF
2378      -5.000000E-001            CLK_HI    EQU     -0.5                              ; Clock voltage high
2379      -5.800000E+000            CLK_LO    EQU     -5.8                              ; Clock voltage low
2380      -4.000000E+000            VRW_LO    EQU     -4.0                              ; VrowON low voltage
2381      -3.500000E+000            VRST_HI   EQU     -3.5                              ; VrstG high voltage
2382      -5.800000E+000            VRST_LO   EQU     -5.8                              ; VrstG low voltage
2383      0.000000E+000             ZERO      EQU     0.0                               ; Unused clock driver voltage
2384   
2385   
2386                                ; Define switch state bits for CLK2 = bottom of clock board
2387      000001                    SSYNC     EQU     1                                 ; Slow Sync             Pin #1
2388      000002                    S1        EQU     2                                 ; Slow phase 1          Pin #2
2389      000004                    S2        EQU     4                                 ; Slow phase 2          Pin #3
2390      000008                    SOE       EQU     8                                 ; Odd/Even row select   Pin #4
2391      000010                    RDES      EQU     $10                               ; Row deselect          Pin #5
2392      000020                    VRSTOFF   EQU     $20                               ; Global reset = VrstG  Pin #6
2393      000040                    VRSTR     EQU     $40                               ; Row reset bias        Pin #7
2394      000080                    VROWON    EQU     $80                               ; Bias to row enable    Pin #8
2395   
2396                                ; Define switch state bits for CLK3 = top of clock board
2397      000001                    FSYNC     EQU     1                                 ; Fast sync             Pin #13
2398      000002                    F1        EQU     2                                 ; Fast phase 1          Pin #14
2399      000004                    F2        EQU     4                                 ; Fast phase 2          Pin #15
2400   
2401                                ; Aladdin III DC bias voltage definition
2402                                ; Per Peter Onaka, "you shouldn't forward bias the InSb = VDDUC should always be more negative t
han VDET."
2403                                ; FIXME
2404      -2.800000E+000            VGGCL     EQU     -2.8                              ; -2.8 ; p16 Board2 Column Clamp Clock, was 
-3.1V but UIST sets it to 0V and IRTF defines it at -3.1V but never switches it
2405      -2.800000E+000            VDDCL     EQU     -2.8                              ; -3.5 ; -2.8 ; p17 Board2 Column Clamp Bias
    was -3.6V now as UIST
2406      -4.000000E+000            VDDUC     EQU     -4.0                              ; -4.0 ;-3.5 ; -4.0 ; p33 Board1 Negative Un
it Cell Bias set to same as VdetCom for warm testing else -4V
2407      -5.950000E+000            VNROW     EQU     -5.95                             ; -5.95 ; p31 Board2 Negative row supply
2408      -5.950000E+000            VNCOL     EQU     -5.95                             ; -5.95 ; p15 Board2 Negative column supply
2409      -1.200000E+000            VDDOUT    EQU     -1.2                              ; -1.6 ;-1.5 ; p17 Board1 Drain voltage for 
drivers     was -1.2 now as UIST
2410      -3.700000E+000            VDETCOM_L EQU     -3.7                              ; p32 Board1 Detector Common not for MUX sho
uld be same as VdduC for warm testing else -3.4V
2411      -3.450000E+000            VDETCOM   EQU     -3.45                             ;-3.45 ;-2.9 ;-3.4 ; p32 Board1 Detector Com
mon not for MUX should be same as VdduC for warm testing else -3.4V
2412      -3.700000E+000            VDETCOM_H EQU     -3.7                              ;-3.7 ;-3.2 ;-3.6 ; p32 Board1 Detector Comm
on not for MUX should be same as VdduC for warm testing else -3.4V
2413      -2.000000E+000            IREF      EQU     -2.0                              ;-1.6 ;-2.0 ; p16 Board1 Reference current f
or Iidle and Islew
2414      1.000000E-001             VSSOUT    EQU     +0.1                              ;+0.2 ;+4.9 ;+4.5 ; Source follower load vol
tage
2415      -7.000000E-001            VROWOFF   EQU     -0.7                              ;-0.7 ;0.5 ; p33 Board2 Applied to SF transi
stor gate M2 when row is not selected
2416   
2417                                ;V1             EQU -0.8                ; Voltages to test the video boards and firmware
2418                                ;V2             EQU     -0.9            ; Set in conjunction with offset and gain settings
2419                                ;V3             EQU     -1                      ; for testing of each video board with the jumpe
r connector
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 43



2420                                ;V4             EQU     -1.2
2421                                ;V5             EQU     -1.4
2422                                ;V6             EQU     -1.5
2423                                ;V7             EQU     +5.0
2424   
2425                                ; Video offset variable
2426                                ;OFFSET EQU     $760            ; for operation of the Aladdin III array -
2427                                                                                    ;   64k DN at -1.0 volts input => full well
2428                                                                                    ;    0k DN at -2.0 volts input => dark
2429                                                                                    ; Increase offset to lower image counts
2430   
2431      0007B0                    OFFSETB1  EQU     $7B0                              ; with slow int gain $760 gives 4kADU dark w
ith fast 8A0
2432      0007B0                    OFFSETB2  EQU     $7B0                              ; with fast int gain
2433      0007B0                    OFFSETB3  EQU     $7B0                              ; with fast int gain
2434      0007B0                    OFFSETB4  EQU     $7B0                              ; with fast int gain
2435   
2436      0007B0                    OFFSET0   EQU     OFFSETB1
2437      0007B0                    OFFSET1   EQU     OFFSETB1
2438      0007B0                    OFFSET2   EQU     OFFSETB1
2439      0007B0                    OFFSET3   EQU     OFFSETB1
2440      0007B0                    OFFSET4   EQU     OFFSETB1
2441      0007B0                    OFFSET5   EQU     OFFSETB1
2442      0007B0                    OFFSET6   EQU     OFFSETB1
2443      0007B0                    OFFSET7   EQU     OFFSETB1
2444   
2445      0007B0                    OFFSET8   EQU     OFFSETB2
2446      0007B0                    OFFSET9   EQU     OFFSETB2
2447      0007B0                    OFFSET10  EQU     OFFSETB2
2448      0007B0                    OFFSET11  EQU     OFFSETB2
2449      0007B0                    OFFSET12  EQU     OFFSETB2
2450      0007B0                    OFFSET13  EQU     OFFSETB2
2451      0007B0                    OFFSET14  EQU     OFFSETB2
2452      0007B0                    OFFSET15  EQU     OFFSETB2
2453   
2454      0007B0                    OFFSET16  EQU     OFFSETB3
2455      0007B0                    OFFSET17  EQU     OFFSETB3
2456      0007B0                    OFFSET18  EQU     OFFSETB3
2457      0007B0                    OFFSET19  EQU     OFFSETB3
2458      0007B0                    OFFSET20  EQU     OFFSETB3
2459      0007B0                    OFFSET21  EQU     OFFSETB3
2460      0007B0                    OFFSET22  EQU     OFFSETB3
2461      0007B0                    OFFSET23  EQU     OFFSETB3
2462   
2463      0007B0                    OFFSET24  EQU     OFFSETB4
2464      0007B0                    OFFSET25  EQU     OFFSETB4
2465      0007B0                    OFFSET26  EQU     OFFSETB4
2466      0007B0                    OFFSET27  EQU     OFFSETB4
2467      0007B0                    OFFSET28  EQU     OFFSETB4
2468      0007B0                    OFFSET29  EQU     OFFSETB4
2469      0007B0                    OFFSET30  EQU     OFFSETB4
2470      0007B0                    OFFSET31  EQU     OFFSETB4
2471   
2472                                ; Copy of the clocking bit definition for easy reference
2473                                ;       DC      CLK2+DELAY+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2474                                ;       DC      CLK3+DELAY+FSYNC+F1+F2
2475   
2476   
2477                                ; Define high and low values for each clock.  Most significant 16 bits determine
2478                                ; the clock board and DACs to write.  Least significant 8-bit value is constructed
2479                                ; by @CVI
2480   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 44



2481      Y:000011 Y:000011         CLOCKS    DC      END_CLOCKS-CLOCKS-1
2482      Y:000012 Y:000012                   DC      $2A0080                           ; DAC = unbuffered mode
2483      Y:000013 Y:000013                   DC      $200100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #1, SSYNC
2484      Y:000014 Y:000014                   DC      $200200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2485      Y:000015 Y:000015                   DC      $200400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #2, S1
2486      Y:000016 Y:000016                   DC      $200800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2487      Y:000017 Y:000017                   DC      $202000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #3, S2
2488      Y:000018 Y:000018                   DC      $204000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2489      Y:000019 Y:000019                   DC      $208000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #4, SOE
2490      Y:00001A Y:00001A                   DC      $210000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2491      Y:00001B Y:00001B                   DC      $220100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #5, RDES
2492      Y:00001C Y:00001C                   DC      $220200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2493      Y:00001D Y:00001D                   DC      $220400+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #6, VRSTOFF
2494      Y:00001E Y:00001E                   DC      $220800+@CVI(((VRST_LO+Vmax)/Vmax)*255) ;   = VrstG
2495      Y:00001F Y:00001F                   DC      $222000+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #7, VRSTR
2496      Y:000020 Y:000020                   DC      $224000+@CVI(((VRST_LO+Vmax)/Vmax)*255)
2497      Y:000021 Y:000021                   DC      $228000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #8, VROWON
2498      Y:000022 Y:000022                   DC      $230000+@CVI(((VRW_LO+Vmax)/Vmax)*255)
2499      Y:000023 Y:000023                   DC      $240100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #9, Unused
2500      Y:000024 Y:000024                   DC      $240200+@CVI(((ZERO+Vmax)/Vmax)*255)
2501      Y:000025 Y:000025                   DC      $240400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #10, Unused
2502      Y:000026 Y:000026                   DC      $240800+@CVI(((ZERO+Vmax)/Vmax)*255)
2503      Y:000027 Y:000027                   DC      $242000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #11, Unused
2504      Y:000028 Y:000028                   DC      $244000+@CVI(((ZERO+Vmax)/Vmax)*255)
2505      Y:000029 Y:000029                   DC      $248000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #12, Unused
2506      Y:00002A Y:00002A                   DC      $250000+@CVI(((ZERO+Vmax)/Vmax)*255)
2507   
2508                                ; Upper bank
2509      Y:00002B Y:00002B                   DC      $260100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #13, FSYNC
2510      Y:00002C Y:00002C                   DC      $260200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2511      Y:00002D Y:00002D                   DC      $260400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #14, F1
2512      Y:00002E Y:00002E                   DC      $260800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2513      Y:00002F Y:00002F                   DC      $262000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #15, F2
2514      Y:000030 Y:000030                   DC      $264000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2515      Y:000031 Y:000031                   DC      $268000+@CVI(((ZERO+Vmax)/Vmax)*255)
2516      Y:000032 Y:000032                   DC      $270000+@CVI(((ZERO+Vmax)/Vmax)*255)
2517      Y:000033 Y:000033                   DC      $280100+@CVI(((ZERO+Vmax)/Vmax)*255)
2518      Y:000034 Y:000034                   DC      $280200+@CVI(((ZERO+Vmax)/Vmax)*255)
2519      Y:000035 Y:000035                   DC      $280400+@CVI(((ZERO+Vmax)/Vmax)*255)
2520      Y:000036 Y:000036                   DC      $280800+@CVI(((ZERO+Vmax)/Vmax)*255)
2521      Y:000037 Y:000037                   DC      $282000+@CVI(((ZERO+Vmax)/Vmax)*255)
2522      Y:000038 Y:000038                   DC      $284000+@CVI(((ZERO+Vmax)/Vmax)*255)
2523      Y:000039 Y:000039                   DC      $288000+@CVI(((ZERO+Vmax)/Vmax)*255)
2524      Y:00003A Y:00003A                   DC      $290000+@CVI(((ZERO+Vmax)/Vmax)*255)
2525      Y:00003B Y:00003B                   DC      $2A0100+@CVI(((ZERO+Vmax)/Vmax)*255)
2526      Y:00003C Y:00003C                   DC      $2A0200+@CVI(((ZERO+Vmax)/Vmax)*255)
2527      Y:00003D Y:00003D                   DC      $2A0400+@CVI(((ZERO+Vmax)/Vmax)*255)
2528      Y:00003E Y:00003E                   DC      $2A0800+@CVI(((ZERO+Vmax)/Vmax)*255)
2529      Y:00003F Y:00003F                   DC      $2A2000+@CVI(((ZERO+Vmax)/Vmax)*255)
2530      Y:000040 Y:000040                   DC      $2A4000+@CVI(((ZERO+Vmax)/Vmax)*255)
2531      Y:000041 Y:000041                   DC      $2A8000+@CVI(((ZERO+Vmax)/Vmax)*255)
2532      Y:000042 Y:000042                   DC      $2B0000+@CVI(((ZERO+Vmax)/Vmax)*255)
2533                                END_CLOCKS
2534   
2535      Y:000043 Y:000043         CLOCKS_Z  DC      END_CLOCKS_Z-CLOCKS_Z-1
2536      Y:000044 Y:000044                   DC      $2A0080                           ; DAC = unbuffered mode
2537      Y:000045 Y:000045                   DC      $200100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #1, SSYNC
2538      Y:000046 Y:000046                   DC      $200200+@CVI(((ZERO+Vmax)/Vmax)*255)
2539      Y:000047 Y:000047                   DC      $200400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #2, S1
2540      Y:000048 Y:000048                   DC      $200800+@CVI(((ZERO+Vmax)/Vmax)*255)
2541      Y:000049 Y:000049                   DC      $202000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #3, S2
2542      Y:00004A Y:00004A                   DC      $204000+@CVI(((ZERO+Vmax)/Vmax)*255)
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 45



2543      Y:00004B Y:00004B                   DC      $208000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #4, SOE
2544      Y:00004C Y:00004C                   DC      $210000+@CVI(((ZERO+Vmax)/Vmax)*255)
2545      Y:00004D Y:00004D                   DC      $220100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #5, RDES
2546      Y:00004E Y:00004E                   DC      $220200+@CVI(((ZERO+Vmax)/Vmax)*255)
2547      Y:00004F Y:00004F                   DC      $220400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #6, VRSTOFF
2548      Y:000050 Y:000050                   DC      $220800+@CVI(((ZERO+Vmax)/Vmax)*255) ;   = VrstG
2549      Y:000051 Y:000051                   DC      $222000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #7, VRSTR
2550      Y:000052 Y:000052                   DC      $224000+@CVI(((ZERO+Vmax)/Vmax)*255)
2551      Y:000053 Y:000053                   DC      $228000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #8, VROWON
2552      Y:000054 Y:000054                   DC      $230000+@CVI(((ZERO+Vmax)/Vmax)*255)
2553      Y:000055 Y:000055                   DC      $240100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #9, Unused
2554      Y:000056 Y:000056                   DC      $240200+@CVI(((ZERO+Vmax)/Vmax)*255)
2555      Y:000057 Y:000057                   DC      $240400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #10, Unused
2556      Y:000058 Y:000058                   DC      $240800+@CVI(((ZERO+Vmax)/Vmax)*255)
2557      Y:000059 Y:000059                   DC      $242000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #11, Unused
2558      Y:00005A Y:00005A                   DC      $244000+@CVI(((ZERO+Vmax)/Vmax)*255)
2559      Y:00005B Y:00005B                   DC      $248000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #12, Unused
2560      Y:00005C Y:00005C                   DC      $250000+@CVI(((ZERO+Vmax)/Vmax)*255)
2561   
2562                                ; Upper bank
2563      Y:00005D Y:00005D                   DC      $260100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #13, FSYNC
2564      Y:00005E Y:00005E                   DC      $260200+@CVI(((ZERO+Vmax)/Vmax)*255)
2565      Y:00005F Y:00005F                   DC      $260400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #14, F1
2566      Y:000060 Y:000060                   DC      $260800+@CVI(((ZERO+Vmax)/Vmax)*255)
2567      Y:000061 Y:000061                   DC      $262000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #15, F2
2568      Y:000062 Y:000062                   DC      $264000+@CVI(((ZERO+Vmax)/Vmax)*255)
2569      Y:000063 Y:000063                   DC      $268000+@CVI(((ZERO+Vmax)/Vmax)*255)
2570      Y:000064 Y:000064                   DC      $270000+@CVI(((ZERO+Vmax)/Vmax)*255)
2571      Y:000065 Y:000065                   DC      $280100+@CVI(((ZERO+Vmax)/Vmax)*255)
2572      Y:000066 Y:000066                   DC      $280200+@CVI(((ZERO+Vmax)/Vmax)*255)
2573      Y:000067 Y:000067                   DC      $280400+@CVI(((ZERO+Vmax)/Vmax)*255)
2574      Y:000068 Y:000068                   DC      $280800+@CVI(((ZERO+Vmax)/Vmax)*255)
2575      Y:000069 Y:000069                   DC      $282000+@CVI(((ZERO+Vmax)/Vmax)*255)
2576      Y:00006A Y:00006A                   DC      $284000+@CVI(((ZERO+Vmax)/Vmax)*255)
2577      Y:00006B Y:00006B                   DC      $288000+@CVI(((ZERO+Vmax)/Vmax)*255)
2578      Y:00006C Y:00006C                   DC      $290000+@CVI(((ZERO+Vmax)/Vmax)*255)
2579      Y:00006D Y:00006D                   DC      $2A0100+@CVI(((ZERO+Vmax)/Vmax)*255)
2580      Y:00006E Y:00006E                   DC      $2A0200+@CVI(((ZERO+Vmax)/Vmax)*255)
2581      Y:00006F Y:00006F                   DC      $2A0400+@CVI(((ZERO+Vmax)/Vmax)*255)
2582      Y:000070 Y:000070                   DC      $2A0800+@CVI(((ZERO+Vmax)/Vmax)*255)
2583      Y:000071 Y:000071                   DC      $2A2000+@CVI(((ZERO+Vmax)/Vmax)*255)
2584      Y:000072 Y:000072                   DC      $2A4000+@CVI(((ZERO+Vmax)/Vmax)*255)
2585      Y:000073 Y:000073                   DC      $2A8000+@CVI(((ZERO+Vmax)/Vmax)*255)
2586      Y:000074 Y:000074                   DC      $2B0000+@CVI(((ZERO+Vmax)/Vmax)*255)
2587                                END_CLOCKS_Z
2588   
2589                                ; Video offset assignments
2590      Y:000075 Y:000075         BIASES_Z  DC      END_BIASES_Z-BIASES_Z-1
2591   
2592                                ; Integrator gain and a few other things
2593                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2594                                ;       DC      $0c3000                 ; Integrate 2, High gain
2595      Y:000076 Y:000076                   DC      $0c3000                           ; Integrate 2, High gain
2596      Y:000077 Y:000077                   DC      $1c3000                           ; Integrate 2, High gain
2597      Y:000078 Y:000078                   DC      $2c3000                           ; Integrate 2, High gain
2598      Y:000079 Y:000079                   DC      $3c3000                           ; Integrate 2, High gain
2599      Y:00007A Y:00007A                   DC      $0c1000                           ; Reset image data FIFOs
2600      Y:00007B Y:00007B                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2601      Y:00007C Y:00007C                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2602      Y:00007D Y:00007D                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2603      Y:00007E Y:00007E                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2604   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 46



2605                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2606                                ;       DC      $0e0000+OFFSET0         ; Output #0
2607                                ;       DC      $0e4000+OFFSET1         ; Output #1
2608                                ;       DC      $0e8000+OFFSET2         ; Output #2
2609                                ;       DC      $0ec000+OFFSET3         ; Output #3
2610                                ;       DC      $0f0000+OFFSET4         ; Output #4
2611                                ;       DC      $0f4000+OFFSET5         ; Output #5
2612                                ;       DC      $0f8000+OFFSET6         ; Output #6
2613                                ;       DC      $0fc000+OFFSET7         ; Output #7
2614   
2615                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2616                                ;       DC      $1e0000+OFFSET8         ; Output #0
2617                                ;       DC      $1e4000+OFFSET9         ; Output #1
2618                                ;       DC      $1e8000+OFFSET10        ; Output #2
2619                                ;       DC      $1ec000+OFFSET11        ; Output #3
2620                                ;       DC      $1f0000+OFFSET12        ; Output #4
2621                                ;       DC      $1f4000+OFFSET13        ; Output #5
2622                                ;       DC      $1f8000+OFFSET14        ; Output #6
2623                                ;       DC      $1fc000+OFFSET15        ; Output #7
2624   
2625                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2626                                ;       DC      $2e0000+OFFSET16        ; Output #0
2627                                ;       DC      $2e4000+OFFSET17        ; Output #1
2628                                ;       DC      $2e8000+OFFSET18        ; Output #2
2629                                ;       DC      $2ec000+OFFSET19        ; Output #3
2630                                ;       DC      $2f0000+OFFSET20        ; Output #4
2631                                ;       DC      $2f4000+OFFSET21        ; Output #5
2632                                ;       DC      $2f8000+OFFSET22        ; Output #6
2633                                ;       DC      $2fc000+OFFSET23        ; Output #7
2634   
2635                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2636                                ;       DC      $3e0000+OFFSET24                ; Output #0
2637                                ;       DC      $3e4000+OFFSET25                ; Output #1
2638                                ;       DC      $3e8000+OFFSET26                ; Output #2
2639                                ;       DC      $3ec000+OFFSET27                ; Output #3
2640                                ;       DC      $3f0000+OFFSET28                ; Output #4
2641                                ;       DC      $3f4000+OFFSET29                ; Output #5
2642                                ;       DC      $3f8000+OFFSET30                ; Output #6
2643                                ;       DC      $3fc000+OFFSET31                ; Output #7
2644   
2645   
2646                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2647                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2648                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2649      Y:00007F Y:00007F                   DC      $0c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; VDDOUT; Pin #17 VDDOUT ; BO1
2650      Y:000080 Y:000080                   DC      $0c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; VDDUC; Pin #33 VDDUC ; BO2
2651      Y:000081 Y:000081                   DC      $0cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; IREF; Pin #16 IREF ; BO3
2652      Y:000082 Y:000082                   DC      $0d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; VDETCOM_L; Pin #32 VDETCOM ; BO4
2653      Y:000083 Y:000083                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC ; BO5
2654      Y:000084 Y:000084                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC ; BO6
2655      Y:000085 Y:000085                   DC      $0dc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; VSSOUT; Pin #14 NC but provides output
 source follower source voltage = 5V ; BO7
2656   
2657                                ; Video board #2
2658      Y:000086 Y:000086                   DC      $1c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2659      Y:000087 Y:000087                   DC      $1c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2660      Y:000088 Y:000088                   DC      $1cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2661      Y:000089 Y:000089                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2662      Y:00008A Y:00008A                   DC      $1d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2663      Y:00008B Y:00008B                   DC      $1d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2664      Y:00008C Y:00008C                   DC      $1dc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output source 
follower source voltage = 5V
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 47



2665   
2666                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2667      Y:00008D Y:00008D                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2668      Y:00008E Y:00008E                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2669      Y:00008F Y:00008F                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2670      Y:000090 Y:000090                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2671      Y:000091 Y:000091                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2672      Y:000092 Y:000092                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2673      Y:000093 Y:000093                   DC      $2dc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output source 
follower source voltage = 5V
2674   
2675                                ; Video board #4
2676      Y:000094 Y:000094                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2677      Y:000095 Y:000095                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2678      Y:000096 Y:000096                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2679      Y:000097 Y:000097                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2680      Y:000098 Y:000098                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2681      Y:000099 Y:000099                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2682      Y:00009A Y:00009A                   DC      $3dc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output source 
follower source voltage = 5V
2683   
2684                                END_BIASES_Z
2685   
2686                                ; Video offset assignments
2687      Y:00009B Y:00009B         BIASES_L  DC      END_BIASES_L-BIASES_L-1
2688   
2689                                ; Integrator gain and a few other things
2690                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2691                                ;       DC      $0c3000                 ; Integrate 2, High gain
2692      Y:00009C Y:00009C                   DC      $0c3000                           ; Integrate 2, High gain
2693      Y:00009D Y:00009D                   DC      $1c3000                           ; Integrate 2, High gain
2694      Y:00009E Y:00009E                   DC      $2c3000                           ; Integrate 2, High gain
2695      Y:00009F Y:00009F                   DC      $3c3000                           ; Integrate 2, High gain
2696      Y:0000A0 Y:0000A0                   DC      $0c1000                           ; Reset image data FIFOs
2697      Y:0000A1 Y:0000A1                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2698      Y:0000A2 Y:0000A2                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2699      Y:0000A3 Y:0000A3                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2700      Y:0000A4 Y:0000A4                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2701   
2702                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2703      Y:0000A5 Y:0000A5                   DC      $0e0000+OFFSET0                   ; Output #0
2704      Y:0000A6 Y:0000A6                   DC      $0e4000+OFFSET1                   ; Output #1
2705      Y:0000A7 Y:0000A7                   DC      $0e8000+OFFSET2                   ; Output #2
2706      Y:0000A8 Y:0000A8                   DC      $0ec000+OFFSET3                   ; Output #3
2707      Y:0000A9 Y:0000A9                   DC      $0f0000+OFFSET4                   ; Output #4
2708      Y:0000AA Y:0000AA                   DC      $0f4000+OFFSET5                   ; Output #5
2709      Y:0000AB Y:0000AB                   DC      $0f8000+OFFSET6                   ; Output #6
2710      Y:0000AC Y:0000AC                   DC      $0fc000+OFFSET7                   ; Output #7
2711   
2712                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2713      Y:0000AD Y:0000AD                   DC      $1e0000+OFFSET8                   ; Output #0
2714      Y:0000AE Y:0000AE                   DC      $1e4000+OFFSET9                   ; Output #1
2715      Y:0000AF Y:0000AF                   DC      $1e8000+OFFSET10                  ; Output #2
2716      Y:0000B0 Y:0000B0                   DC      $1ec000+OFFSET11                  ; Output #3
2717      Y:0000B1 Y:0000B1                   DC      $1f0000+OFFSET12                  ; Output #4
2718      Y:0000B2 Y:0000B2                   DC      $1f4000+OFFSET13                  ; Output #5
2719      Y:0000B3 Y:0000B3                   DC      $1f8000+OFFSET14                  ; Output #6
2720      Y:0000B4 Y:0000B4                   DC      $1fc000+OFFSET15                  ; Output #7
2721   
2722                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2723      Y:0000B5 Y:0000B5                   DC      $2e0000+OFFSET16                  ; Output #0
2724      Y:0000B6 Y:0000B6                   DC      $2e4000+OFFSET17                  ; Output #1
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 48



2725      Y:0000B7 Y:0000B7                   DC      $2e8000+OFFSET18                  ; Output #2
2726      Y:0000B8 Y:0000B8                   DC      $2ec000+OFFSET19                  ; Output #3
2727      Y:0000B9 Y:0000B9                   DC      $2f0000+OFFSET20                  ; Output #4
2728      Y:0000BA Y:0000BA                   DC      $2f4000+OFFSET21                  ; Output #5
2729      Y:0000BB Y:0000BB                   DC      $2f8000+OFFSET22                  ; Output #6
2730      Y:0000BC Y:0000BC                   DC      $2fc000+OFFSET23                  ; Output #7
2731   
2732                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2733      Y:0000BD Y:0000BD                   DC      $3e0000+OFFSET24                  ; Output #0
2734      Y:0000BE Y:0000BE                   DC      $3e4000+OFFSET25                  ; Output #1
2735      Y:0000BF Y:0000BF                   DC      $3e8000+OFFSET26                  ; Output #2
2736      Y:0000C0 Y:0000C0                   DC      $3ec000+OFFSET27                  ; Output #3
2737      Y:0000C1 Y:0000C1                   DC      $3f0000+OFFSET28                  ; Output #4
2738      Y:0000C2 Y:0000C2                   DC      $3f4000+OFFSET29                  ; Output #5
2739      Y:0000C3 Y:0000C3                   DC      $3f8000+OFFSET30                  ; Output #6
2740      Y:0000C4 Y:0000C4                   DC      $3fc000+OFFSET31                  ; Output #7
2741   
2742   
2743                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2744                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2745                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2746      Y:0000C5 Y:0000C5                   DC      $0c4000+@CVI((VDDOUT+Vmax2)/Vmax3*4095) ; VDDOUT; Pin #17 VDDOUT ; BO1
2747      Y:0000C6 Y:0000C6                   DC      $0c8000+@CVI((VDDUC+Vmax2)/Vmax3*4095) ; VDDUC; Pin #33 VDDUC ; BO2
2748      Y:0000C7 Y:0000C7                   DC      $0cc000+@CVI((IREF+Vmax2)/Vmax3*4095) ; IREF; Pin #16 IREF ; BO3
2749      Y:0000C8 Y:0000C8                   DC      $0d0000+@CVI((VDETCOM_L+Vmax2)/Vmax3*4095) ; VDETCOM_L; Pin #32 VDETCOM ; BO4
2750      Y:0000C9 Y:0000C9                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC ; BO5
2751      Y:0000CA Y:0000CA                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC ; BO6
2752      Y:0000CB Y:0000CB                   DC      $0dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; VSSOUT; Pin #14 NC but provides outp
ut source follower source voltage = 5V ; BO7
2753   
2754                                ; Video board #2
2755      Y:0000CC Y:0000CC                   DC      $1c4000+@CVI((VDDCL+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2756      Y:0000CD Y:0000CD                   DC      $1c8000+@CVI((VROWOFF+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2757      Y:0000CE Y:0000CE                   DC      $1cc000+@CVI((VGGCL+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2758      Y:0000CF Y:0000CF                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2759      Y:0000D0 Y:0000D0                   DC      $1d4000+@CVI((VNCOL+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2760      Y:0000D1 Y:0000D1                   DC      $1d8000+@CVI((VNROW+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2761      Y:0000D2 Y:0000D2                   DC      $1dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2762   
2763                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2764      Y:0000D3 Y:0000D3                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2765      Y:0000D4 Y:0000D4                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2766      Y:0000D5 Y:0000D5                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2767      Y:0000D6 Y:0000D6                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2768      Y:0000D7 Y:0000D7                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2769      Y:0000D8 Y:0000D8                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2770      Y:0000D9 Y:0000D9                   DC      $2dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2771   
2772                                ; Video board #4
2773      Y:0000DA Y:0000DA                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2774      Y:0000DB Y:0000DB                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2775      Y:0000DC Y:0000DC                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2776      Y:0000DD Y:0000DD                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2777      Y:0000DE Y:0000DE                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2778      Y:0000DF Y:0000DF                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2779      Y:0000E0 Y:0000E0                   DC      $3dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2780   
2781                                END_BIASES_L
2782   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 49



2783                                ; Video offset assignments
2784      Y:0000E1 Y:0000E1         BIASES_H  DC      END_BIASES_H-BIASES_H-1
2785   
2786   
2787                                ; Integrator gain and a few other things
2788                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2789                                ;       DC      $0c3000                 ; Integrate 2, High gain
2790      Y:0000E2 Y:0000E2                   DC      $0c3000                           ; Integrate 2, High gain
2791      Y:0000E3 Y:0000E3                   DC      $1c3000                           ; Integrate 2, High gain
2792      Y:0000E4 Y:0000E4                   DC      $2c3000                           ; Integrate 2, High gain
2793      Y:0000E5 Y:0000E5                   DC      $3c3000                           ; Integrate 2, High gain
2794      Y:0000E6 Y:0000E6                   DC      $0c1000                           ; Reset image data FIFOs
2795      Y:0000E7 Y:0000E7                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2796      Y:0000E8 Y:0000E8                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2797      Y:0000E9 Y:0000E9                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2798      Y:0000EA Y:0000EA                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2799   
2800                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2801      Y:0000EB Y:0000EB                   DC      $0e0000+OFFSET0                   ; Output #0
2802      Y:0000EC Y:0000EC                   DC      $0e4000+OFFSET1                   ; Output #1
2803      Y:0000ED Y:0000ED                   DC      $0e8000+OFFSET2                   ; Output #2
2804      Y:0000EE Y:0000EE                   DC      $0ec000+OFFSET3                   ; Output #3
2805      Y:0000EF Y:0000EF                   DC      $0f0000+OFFSET4                   ; Output #4
2806      Y:0000F0 Y:0000F0                   DC      $0f4000+OFFSET5                   ; Output #5
2807      Y:0000F1 Y:0000F1                   DC      $0f8000+OFFSET6                   ; Output #6
2808      Y:0000F2 Y:0000F2                   DC      $0fc000+OFFSET7                   ; Output #7
2809   
2810                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2811      Y:0000F3 Y:0000F3                   DC      $1e0000+OFFSET8                   ; Output #0
2812      Y:0000F4 Y:0000F4                   DC      $1e4000+OFFSET9                   ; Output #1
2813      Y:0000F5 Y:0000F5                   DC      $1e8000+OFFSET10                  ; Output #2
2814      Y:0000F6 Y:0000F6                   DC      $1ec000+OFFSET11                  ; Output #3
2815      Y:0000F7 Y:0000F7                   DC      $1f0000+OFFSET12                  ; Output #4
2816      Y:0000F8 Y:0000F8                   DC      $1f4000+OFFSET13                  ; Output #5
2817      Y:0000F9 Y:0000F9                   DC      $1f8000+OFFSET14                  ; Output #6
2818      Y:0000FA Y:0000FA                   DC      $1fc000+OFFSET15                  ; Output #7
2819   
2820                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2821      Y:0000FB Y:0000FB                   DC      $2e0000+OFFSET16                  ; Output #0
2822      Y:0000FC Y:0000FC                   DC      $2e4000+OFFSET17                  ; Output #1
2823      Y:0000FD Y:0000FD                   DC      $2e8000+OFFSET18                  ; Output #2
2824      Y:0000FE Y:0000FE                   DC      $2ec000+OFFSET19                  ; Output #3
2825      Y:0000FF Y:0000FF                   DC      $2f0000+OFFSET20                  ; Output #4
2826      Y:000100 Y:000100                   DC      $2f4000+OFFSET21                  ; Output #5
2827      Y:000101 Y:000101                   DC      $2f8000+OFFSET22                  ; Output #6
2828      Y:000102 Y:000102                   DC      $2fc000+OFFSET23                  ; Output #7
2829   
2830                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2831      Y:000103 Y:000103                   DC      $3e0000+OFFSET24                  ; Output #0
2832      Y:000104 Y:000104                   DC      $3e4000+OFFSET25                  ; Output #1
2833      Y:000105 Y:000105                   DC      $3e8000+OFFSET26                  ; Output #2
2834      Y:000106 Y:000106                   DC      $3ec000+OFFSET27                  ; Output #3
2835      Y:000107 Y:000107                   DC      $3f0000+OFFSET28                  ; Output #4
2836      Y:000108 Y:000108                   DC      $3f4000+OFFSET29                  ; Output #5
2837      Y:000109 Y:000109                   DC      $3f8000+OFFSET30                  ; Output #6
2838      Y:00010A Y:00010A                   DC      $3fc000+OFFSET31                  ; Output #7
2839   
2840   
2841                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2842                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2843                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2844      Y:00010B Y:00010B                   DC      $0c4000+@CVI((VDDOUT+Vmax2)/Vmax3*4095) ; Pin #17 VDDOUT
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 50



2845      Y:00010C Y:00010C                   DC      $0c8000+@CVI((VDDUC+Vmax2)/Vmax3*4095) ; Pin #33 VDDUC
2846      Y:00010D Y:00010D                   DC      $0cc000+@CVI((IREF+Vmax2)/Vmax3*4095) ; Pin #16 IREF
2847      Y:00010E Y:00010E                   DC      $0d0000+@CVI((VDETCOM_H+Vmax2)/Vmax3*4095) ; Pin #32 VDETCOM
2848      Y:00010F Y:00010F                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2849      Y:000110 Y:000110                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2850      Y:000111 Y:000111                   DC      $0dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2851   
2852                                ; Video board #2
2853      Y:000112 Y:000112                   DC      $1c4000+@CVI((VDDCL+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2854      Y:000113 Y:000113                   DC      $1c8000+@CVI((VROWOFF+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2855      Y:000114 Y:000114                   DC      $1cc000+@CVI((VGGCL+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2856      Y:000115 Y:000115                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2857      Y:000116 Y:000116                   DC      $1d4000+@CVI((VNCOL+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2858      Y:000117 Y:000117                   DC      $1d8000+@CVI((VNROW+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2859      Y:000118 Y:000118                   DC      $1dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2860   
2861                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2862      Y:000119 Y:000119                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2863      Y:00011A Y:00011A                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2864      Y:00011B Y:00011B                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2865      Y:00011C Y:00011C                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2866      Y:00011D Y:00011D                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2867      Y:00011E Y:00011E                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2868      Y:00011F Y:00011F                   DC      $2dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2869   
2870                                ; Video board #4
2871      Y:000120 Y:000120                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2872      Y:000121 Y:000121                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2873      Y:000122 Y:000122                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2874      Y:000123 Y:000123                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2875      Y:000124 Y:000124                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2876      Y:000125 Y:000125                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2877      Y:000126 Y:000126                   DC      $3dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2878   
2879                                END_BIASES_H
2880   
2881   
2882                                ; Video offset assignments
2883      Y:000127 Y:000127         BIASES    DC      END_BIASES-BIASES-1
2884   
2885                                ; Integrator gain and a few other things
2886                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2887                                ;       DC      $0c3000                 ; Integrate 2, High gain
2888      Y:000128 Y:000128                   DC      $0c3000                           ; Integrate 2, High gain
2889      Y:000129 Y:000129                   DC      $1c3000                           ; Integrate 2, High gain
2890      Y:00012A Y:00012A                   DC      $2c3000                           ; Integrate 2, High gain
2891      Y:00012B Y:00012B                   DC      $3c3000                           ; Integrate 2, High gain
2892      Y:00012C Y:00012C                   DC      $0c1000                           ; Reset image data FIFOs
2893      Y:00012D Y:00012D                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2894      Y:00012E Y:00012E                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2895      Y:00012F Y:00012F                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2896      Y:000130 Y:000130                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2897   
2898                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2899      Y:000131 Y:000131                   DC      $0e0000+OFFSET0                   ; Output #0
2900      Y:000132 Y:000132                   DC      $0e4000+OFFSET1                   ; Output #1
2901      Y:000133 Y:000133                   DC      $0e8000+OFFSET2                   ; Output #2
2902      Y:000134 Y:000134                   DC      $0ec000+OFFSET3                   ; Output #3
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 51



2903      Y:000135 Y:000135                   DC      $0f0000+OFFSET4                   ; Output #4
2904      Y:000136 Y:000136                   DC      $0f4000+OFFSET5                   ; Output #5
2905      Y:000137 Y:000137                   DC      $0f8000+OFFSET6                   ; Output #6
2906      Y:000138 Y:000138                   DC      $0fc000+OFFSET7                   ; Output #7
2907   
2908                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2909      Y:000139 Y:000139                   DC      $1e0000+OFFSET8                   ; Output #0
2910      Y:00013A Y:00013A                   DC      $1e4000+OFFSET9                   ; Output #1
2911      Y:00013B Y:00013B                   DC      $1e8000+OFFSET10                  ; Output #2
2912      Y:00013C Y:00013C                   DC      $1ec000+OFFSET11                  ; Output #3
2913      Y:00013D Y:00013D                   DC      $1f0000+OFFSET12                  ; Output #4
2914      Y:00013E Y:00013E                   DC      $1f4000+OFFSET13                  ; Output #5
2915      Y:00013F Y:00013F                   DC      $1f8000+OFFSET14                  ; Output #6
2916      Y:000140 Y:000140                   DC      $1fc000+OFFSET15                  ; Output #7
2917   
2918                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2919      Y:000141 Y:000141                   DC      $2e0000+OFFSET16                  ; Output #0
2920      Y:000142 Y:000142                   DC      $2e4000+OFFSET17                  ; Output #1
2921      Y:000143 Y:000143                   DC      $2e8000+OFFSET18                  ; Output #2
2922      Y:000144 Y:000144                   DC      $2ec000+OFFSET19                  ; Output #3
2923      Y:000145 Y:000145                   DC      $2f0000+OFFSET20                  ; Output #4
2924      Y:000146 Y:000146                   DC      $2f4000+OFFSET21                  ; Output #5
2925      Y:000147 Y:000147                   DC      $2f8000+OFFSET22                  ; Output #6
2926      Y:000148 Y:000148                   DC      $2fc000+OFFSET23                  ; Output #7
2927   
2928                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2929      Y:000149 Y:000149                   DC      $3e0000+OFFSET24                  ; Output #0
2930      Y:00014A Y:00014A                   DC      $3e4000+OFFSET25                  ; Output #1
2931      Y:00014B Y:00014B                   DC      $3e8000+OFFSET26                  ; Output #2
2932      Y:00014C Y:00014C                   DC      $3ec000+OFFSET27                  ; Output #3
2933      Y:00014D Y:00014D                   DC      $3f0000+OFFSET28                  ; Output #4
2934      Y:00014E Y:00014E                   DC      $3f4000+OFFSET29                  ; Output #5
2935      Y:00014F Y:00014F                   DC      $3f8000+OFFSET30                  ; Output #6
2936      Y:000150 Y:000150                   DC      $3fc000+OFFSET31                  ; Output #7
2937   
2938   
2939                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2940                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2941                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2942      Y:000151 Y:000151                   DC      $0c4000+@CVI((VDDOUT+Vmax2)/Vmax3*4095) ; Pin #17 VDDOUT
2943      Y:000152 Y:000152                   DC      $0c8000+@CVI((VDDUC+Vmax2)/Vmax3*4095) ; Pin #33 VDDUC
2944      Y:000153 Y:000153                   DC      $0cc000+@CVI((IREF+Vmax2)/Vmax3*4095) ; Pin #16 IREF
2945      Y:000154 Y:000154                   DC      $0d0000+@CVI((VDETCOM+Vmax2)/Vmax3*4095) ; Pin #32 VDETCOM
2946      Y:000155 Y:000155                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2947      Y:000156 Y:000156                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2948      Y:000157 Y:000157                   DC      $0dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2949   
2950                                ; Video board #2
2951      Y:000158 Y:000158                   DC      $1c4000+@CVI((VDDCL+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2952      Y:000159 Y:000159                   DC      $1c8000+@CVI((VROWOFF+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2953      Y:00015A Y:00015A                   DC      $1cc000+@CVI((VGGCL+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2954      Y:00015B Y:00015B                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2955      Y:00015C Y:00015C                   DC      $1d4000+@CVI((VNCOL+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2956      Y:00015D Y:00015D                   DC      $1d8000+@CVI((VNROW+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2957      Y:00015E Y:00015E                   DC      $1dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2958   
2959                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2960      Y:00015F Y:00015F                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2961      Y:000160 Y:000160                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2962      Y:000161 Y:000161                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  AladdinIII.waveforms  Page 52



2963      Y:000162 Y:000162                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2964      Y:000163 Y:000163                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2965      Y:000164 Y:000164                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2966      Y:000165 Y:000165                   DC      $2dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2967   
2968                                ; Video board #4
2969      Y:000166 Y:000166                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2970      Y:000167 Y:000167                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2971      Y:000168 Y:000168                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2972      Y:000169 Y:000169                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2973      Y:00016A Y:00016A                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2974      Y:00016B Y:00016B                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2975      Y:00016C Y:00016C                   DC      $3dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2976                                END_BIASES
2977                                          INCLUDE "CLOCK_ROW_RST.waveforms"         ;
2978                                      COMMENT *
2979   
2980   
2981                                   *
2982   
2983   
2984   
2985                                CLOCK_RR_ROW_1
2986      Y:00016D Y:00016D                   DC      END_CLOCK_RR_ROW_1-CLOCK_RR_ROW_1-1
2987      Y:00016E Y:00016E                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2988      Y:00016F Y:00016F                   DC      CLK3+DLY2+00000+F1+F2
2989      Y:000170 Y:000170                   DC      CLK3+DLY1+FSYNC+F1+F2
2990      Y:000171 Y:000171                   DC      CLK3+DLY2+FSYNC+00+F2
2991      Y:000172 Y:000172                   DC      CLK3+DLY0+FSYNC+F1+F2
2992                                END_CLOCK_RR_ROW_1
2993   
2994                                CLOCK_RR_ROW_2
2995      Y:000173 Y:000173                   DC      END_CLOCK_RR_ROW_2-CLOCK_RR_ROW_2-1
2996      Y:000174 Y:000174                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2997      Y:000175 Y:000175                   DC      CLK3+DLY2+00000+F1+F2
2998      Y:000176 Y:000176                   DC      CLK3+DLY1+FSYNC+F1+F2
2999      Y:000177 Y:000177                   DC      CLK3+DLY2+FSYNC+00+F2
3000      Y:000178 Y:000178                   DC      CLK3+DLY0+FSYNC+F1+F2
3001                                END_CLOCK_RR_ROW_2
3002   
3003                                CLOCK_RR_ROW_3
3004      Y:000179 Y:000179                   DC      END_CLOCK_RR_ROW_3-CLOCK_RR_ROW_3-1
3005      Y:00017A Y:00017A                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
3006      Y:00017B Y:00017B                   DC      CLK3+DLY2+00000+F1+F2
3007      Y:00017C Y:00017C                   DC      CLK3+DLY1+FSYNC+F1+F2
3008      Y:00017D Y:00017D                   DC      CLK3+DLY2+FSYNC+00+F2
3009      Y:00017E Y:00017E                   DC      CLK3+DLY0+FSYNC+F1+F2
3010                                END_CLOCK_RR_ROW_3
3011   
3012                                CLOCK_RR_ROW_4
3013      Y:00017F Y:00017F                   DC      END_CLOCK_RR_ROW_4-CLOCK_RR_ROW_4-1
3014      Y:000180 Y:000180                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3015      Y:000181 Y:000181                   DC      CLK3+DLY2+00000+F1+F2
3016      Y:000182 Y:000182                   DC      CLK3+DLY1+FSYNC+F1+F2
3017      Y:000183 Y:000183                   DC      CLK3+DLY2+FSYNC+00+F2
3018      Y:000184 Y:000184                   DC      CLK3+DLY0+FSYNC+F1+F2
3019                                END_CLOCK_RR_ROW_4
3020   
3021   
3022   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_ROW_RST.waveforms  Page 53



3023                                CLOCK_RESET_ROW_1
3024      Y:000185 Y:000185                   DC      END_CLOCK_RESET_ROW_1-CLOCK_RESET_ROW_1-1
3025      Y:000186 Y:000186                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3026      Y:000187 Y:000187                   DC      CLK3+DLY0+00000+F1+F2
3027      Y:000188 Y:000188                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
3028      Y:000189 Y:000189                   DC      CLK3+DLY4+FSYNC+F1+F2
3029      Y:00018A Y:00018A                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3030      Y:00018B Y:00018B                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
3031      Y:00018C Y:00018C                   DC      CLK3+DLY2+FSYNC+00+F2
3032      Y:00018D Y:00018D                   DC      CLK3+DLY0+FSYNC+F1+F2
3033                                END_CLOCK_RESET_ROW_1
3034   
3035                                CLOCK_RESET_ROW_2
3036      Y:00018E Y:00018E                   DC      END_CLOCK_RESET_ROW_2-CLOCK_RESET_ROW_2-1
3037      Y:00018F Y:00018F                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3038      Y:000190 Y:000190                   DC      CLK3+DLY0+00000+F1+F2
3039      Y:000191 Y:000191                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3040      Y:000192 Y:000192                   DC      CLK3+DLY4+FSYNC+F1+F2
3041      Y:000193 Y:000193                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3042      Y:000194 Y:000194                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3043      Y:000195 Y:000195                   DC      CLK3+DLY2+FSYNC+00+F2
3044      Y:000196 Y:000196                   DC      CLK3+DLY0+FSYNC+F1+F2
3045                                END_CLOCK_RESET_ROW_2
3046   
3047                                CLOCK_RESET_ROW_3
3048      Y:000197 Y:000197                   DC      END_CLOCK_RESET_ROW_3-CLOCK_RESET_ROW_3-1
3049      Y:000198 Y:000198                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3050      Y:000199 Y:000199                   DC      CLK3+DLY0+00000+F1+F2
3051      Y:00019A Y:00019A                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
3052      Y:00019B Y:00019B                   DC      CLK3+DLY4+FSYNC+F1+F2
3053      Y:00019C Y:00019C                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3054      Y:00019D Y:00019D                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
3055      Y:00019E Y:00019E                   DC      CLK3+DLY2+FSYNC+00+F2
3056      Y:00019F Y:00019F                   DC      CLK3+DLY0+FSYNC+F1+F2
3057                                END_CLOCK_RESET_ROW_3
3058   
3059                                CLOCK_RESET_ROW_4
3060      Y:0001A0 Y:0001A0                   DC      END_CLOCK_RESET_ROW_4-CLOCK_RESET_ROW_4-1
3061      Y:0001A1 Y:0001A1                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3062      Y:0001A2 Y:0001A2                   DC      CLK3+DLY0+00000+F1+F2
3063      Y:0001A3 Y:0001A3                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3064      Y:0001A4 Y:0001A4                   DC      CLK3+DLY4+FSYNC+F1+F2
3065      Y:0001A5 Y:0001A5                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3066      Y:0001A6 Y:0001A6                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3067      Y:0001A7 Y:0001A7                   DC      CLK3+DLY2+FSYNC+00+F2
3068      Y:0001A8 Y:0001A8                   DC      CLK3+DLY0+FSYNC+F1+F2
3069                                END_CLOCK_RESET_ROW_4
3070   
3071                                CLOCK_CDS_RESET_ROW_1
3072      Y:0001A9 Y:0001A9                   DC      END_CLOCK_CDS_RESET_ROW_1-CLOCK_CDS_RESET_ROW_1-1
3073      Y:0001AA Y:0001AA                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3074      Y:0001AB Y:0001AB                   DC      CLK3+DLY0+00000+F1+F2
3075      Y:0001AC Y:0001AC                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
3076      Y:0001AD Y:0001AD                   DC      CLK3+DLY4+FSYNC+F1+F2
3077      Y:0001AE Y:0001AE                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3078      Y:0001AF Y:0001AF                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
3079      Y:0001B0 Y:0001B0                   DC      CLK3+DLY2+FSYNC+00+F2
3080      Y:0001B1 Y:0001B1                   DC      CLK3+DLY0+FSYNC+F1+F2
3081                                END_CLOCK_CDS_RESET_ROW_1
3082   
3083                                CLOCK_CDS_RESET_ROW_2
3084      Y:0001B2 Y:0001B2                   DC      END_CLOCK_CDS_RESET_ROW_2-CLOCK_CDS_RESET_ROW_2-1
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_ROW_RST.waveforms  Page 54



3085      Y:0001B3 Y:0001B3                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3086      Y:0001B4 Y:0001B4                   DC      CLK3+DLY0+00000+F1+F2
3087      Y:0001B5 Y:0001B5                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3088      Y:0001B6 Y:0001B6                   DC      CLK3+DLY4+FSYNC+F1+F2
3089      Y:0001B7 Y:0001B7                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3090      Y:0001B8 Y:0001B8                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
3091      Y:0001B9 Y:0001B9                   DC      CLK3+DLY2+FSYNC+00+F2
3092      Y:0001BA Y:0001BA                   DC      CLK3+DLY0+FSYNC+F1+F2
3093                                END_CLOCK_CDS_RESET_ROW_2
3094   
3095                                CLOCK_CDS_RESET_ROW_3
3096      Y:0001BB Y:0001BB                   DC      END_CLOCK_CDS_RESET_ROW_3-CLOCK_CDS_RESET_ROW_3-1
3097      Y:0001BC Y:0001BC                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3098      Y:0001BD Y:0001BD                   DC      CLK3+DLY0+00000+F1+F2
3099      Y:0001BE Y:0001BE                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
3100      Y:0001BF Y:0001BF                   DC      CLK3+DLY4+FSYNC+F1+F2
3101      Y:0001C0 Y:0001C0                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3102      Y:0001C1 Y:0001C1                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
3103      Y:0001C2 Y:0001C2                   DC      CLK3+DLY2+FSYNC+00+F2
3104      Y:0001C3 Y:0001C3                   DC      CLK3+DLY0+FSYNC+F1+F2
3105                                END_CLOCK_CDS_RESET_ROW_3
3106   
3107                                CLOCK_CDS_RESET_ROW_4
3108      Y:0001C4 Y:0001C4                   DC      END_CLOCK_CDS_RESET_ROW_4-CLOCK_CDS_RESET_ROW_4-1
3109      Y:0001C5 Y:0001C5                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3110      Y:0001C6 Y:0001C6                   DC      CLK3+DLY0+00000+F1+F2
3111      Y:0001C7 Y:0001C7                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3112      Y:0001C8 Y:0001C8                   DC      CLK3+DLY4+FSYNC+F1+F2
3113      Y:0001C9 Y:0001C9                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3114      Y:0001CA Y:0001CA                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
3115      Y:0001CB Y:0001CB                   DC      CLK3+DLY2+FSYNC+00+F2
3116      Y:0001CC Y:0001CC                   DC      CLK3+DLY0+FSYNC+F1+F2
3117                                END_CLOCK_CDS_RESET_ROW_4
3118   
3119                                RESET_ROW_12
3120      Y:0001CD Y:0001CD                   DC      END_RESET_ROW_12-RESET_ROW_12-1
3121      Y:0001CE Y:0001CE                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3122      Y:0001CF Y:0001CF                   DC      CLK3+DLY0+00000+F1+F2
3123      Y:0001D0 Y:0001D0                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
3124      Y:0001D1 Y:0001D1                   DC      CLK3+DLY4+FSYNC+F1+F2
3125      Y:0001D2 Y:0001D2                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3126      Y:0001D3 Y:0001D3                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
3127                                END_RESET_ROW_12
3128   
3129                                RESET_ROW_34
3130      Y:0001D4 Y:0001D4                   DC      END_RESET_ROW_34-RESET_ROW_34-1
3131      Y:0001D5 Y:0001D5                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3132      Y:0001D6 Y:0001D6                   DC      CLK3+DLY0+00000+F1+F2
3133      Y:0001D7 Y:0001D7                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
3134      Y:0001D8 Y:0001D8                   DC      CLK3+DLY4+FSYNC+F1+F2
3135      Y:0001D9 Y:0001D9                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3136      Y:0001DA Y:0001DA                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
3137                                END_RESET_ROW_34
3138   
3139                                          INCLUDE "CLOCK_GLOBAL_RST.waveforms"      ;
3140   
3141   
3142   
3143                                FRAME_RESET
3144      Y:0001DB Y:0001DB                   DC      END_FRAME_RESET-FRAME_RESET-1
3145      Y:0001DC Y:0001DC                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3146      Y:0001DD Y:0001DD                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_GLOBAL_RST.waveforms  Page 55



3147      Y:0001DE Y:0001DE                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
3148      Y:0001DF Y:0001DF                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3149      Y:0001E0 Y:0001E0                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3150      Y:0001E1 Y:0001E1                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3151      Y:0001E2 Y:0001E2                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
3152      Y:0001E3 Y:0001E3                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
3153      Y:0001E4 Y:0001E4                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3154      Y:0001E5 Y:0001E5                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3155      Y:0001E6 Y:0001E6                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3156      Y:0001E7 Y:0001E7                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
3157      Y:0001E8 Y:0001E8                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
3158      Y:0001E9 Y:0001E9                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3159      Y:0001EA Y:0001EA                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3160      Y:0001EB Y:0001EB                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3161      Y:0001EC Y:0001EC                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
3162      Y:0001ED Y:0001ED                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
3163      Y:0001EE Y:0001EE                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3164      Y:0001EF Y:0001EF                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3165                                END_FRAME_RESET
3166   
3167                                          INCLUDE "CLOCK_READOUT.waveforms"         ;
3168                                ; Video processor bit definitions
3169   
3170                                ;  Bit #3 = Move A/D data to FIFO   (high going edge)
3171                                ;  Bit #2 = A/D Convert       (low going edge to start conversion)
3172                                ;  Bit #1 = Reset Integrator     (=0 to reset)
3173                                ;  Bit #0 = Integrate      (=0 to integrate)
3174   
3175                                ; STARTS HERE THE READOUT OF 6DS
3176      080000                    DTW       EQU     $080000                           ;  Tw Fast Sync Time (320ns + 40ns exec = 36
0ns)
3177      0F0000                    PAD_TIM   EQU     $0F0000                           ;  Pixel PAD Time       (640ns)
3178      0F0000                    ADC_TIM   EQU     $0F0000                           ;  Pixel PAD Time       (640ns)
3179      180000                    INT_TIM   EQU     $180000                           ;  Pixel Sample Time    (1000ns)
3180      8C0000                    SXM_TIM   EQU     $8C0000                           ;  Pixel Transmit Delay    (5640ns)NOT USED
3181      040000                    ADC_CNV   EQU     $040000                           ;  ADC Sample Time         (100ns)
3182      000000                    STL_TIM   EQU     $000000                           ;  A Generic Settling time (0ns)
3183      180000                    RST_TIM   EQU     $180000                           ;  Reset Time reduced      (1000ns)
3184      000000                    STP_TIM   EQU     $000000                           ;  Stop Reseting
3185      080000                    FIP_TIM   EQU     $080000                           ;  $08 seems ok but have to test with signal
 as it's settling time of integrator stage
3186      000000                    RST_DLY   EQU     $000000                           ;  Delay before resetting the integrator
3187      000000                    PIX_RTE   EQU     $000000                           ;  Delay to adjust the pixel rate only for X
DS not needed for XINT_XDS
3188      0C0000                    ADC_HLD   EQU     $0C0000                           ;  Wait for ADC to setlle before moving to F
IFO (Hold)   (480ns)
3189      040000                    RST_STL   EQU     $040000                           ;  Wait after reset of Integrator before Int
egration (100ns)
3190      080000                    INT_STL   EQU     $080000                           ;  Wait for Integrator output to settle befo
re A2D (360ns)
3191   
3192   
3193   
3194                                ; Copy of the clocking bit definition for easy reference
3195                                ;  DC CLK2+DELAY+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
3196                                ;  DC CLK3+DELAY+FSYNC+F1+F2
3197   
3198   
3199   
3200                                FRAME_INIT
3201      Y:0001F0 Y:0001F0                   DC      END_FRAME_INIT-FRAME_INIT-1
3202      Y:0001F1 Y:0001F1                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 56



3203      Y:0001F2 Y:0001F2                   DC      CLK2+DLY4+00000+S1+S2+SOE+0000+VRSTOFF+VRSTR+000000
3204      Y:0001F3 Y:0001F3                   DC      CLK2+DLY4+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3205      Y:0001F4 Y:0001F4                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3206      Y:0001F5 Y:0001F5                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3207      Y:0001F6 Y:0001F6                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3208                                END_FRAME_INIT
3209   
3210   
3211                                CLOCK_ROW_1
3212      Y:0001F7 Y:0001F7                   DC      END_CLOCK_ROW_1-CLOCK_ROW_1-1
3213      Y:0001F8 Y:0001F8                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
3214      Y:0001F9 Y:0001F9                   DC      CLK3+DLY2+00000+F1+F2
3215      Y:0001FA Y:0001FA                   DC      CLK3+DLY1+FSYNC+F1+F2
3216      Y:0001FB Y:0001FB                   DC      CLK3+DLY2+FSYNC+00+F2
3217      Y:0001FC Y:0001FC                   DC      CLK3+DLY0+FSYNC+F1+F2
3218                                END_CLOCK_ROW_1
3219   
3220                                CLOCK_ROW_2
3221      Y:0001FD Y:0001FD                   DC      END_CLOCK_ROW_2-CLOCK_ROW_2-1
3222      Y:0001FE Y:0001FE                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+000000
3223      Y:0001FF Y:0001FF                   DC      CLK3+DLY2+00000+F1+F2
3224      Y:000200 Y:000200                   DC      CLK3+DLY1+FSYNC+F1+F2
3225      Y:000201 Y:000201                   DC      CLK3+DLY2+FSYNC+00+F2
3226      Y:000202 Y:000202                   DC      CLK3+DLY0+FSYNC+F1+F2
3227                                END_CLOCK_ROW_2
3228   
3229                                CLOCK_ROW_3
3230      Y:000203 Y:000203                   DC      END_CLOCK_ROW_3-CLOCK_ROW_3-1
3231      Y:000204 Y:000204                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
3232      Y:000205 Y:000205                   DC      CLK3+DLY2+00000+F1+F2
3233      Y:000206 Y:000206                   DC      CLK3+DLY1+FSYNC+F1+F2
3234      Y:000207 Y:000207                   DC      CLK3+DLY2+FSYNC+00+F2
3235      Y:000208 Y:000208                   DC      CLK3+DLY0+FSYNC+F1+F2
3236                                END_CLOCK_ROW_3
3237   
3238                                CLOCK_ROW_4
3239      Y:000209 Y:000209                   DC      END_CLOCK_ROW_4-CLOCK_ROW_4-1
3240      Y:00020A Y:00020A                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+000000
3241      Y:00020B Y:00020B                   DC      CLK3+DLY2+00000+F1+F2
3242      Y:00020C Y:00020C                   DC      CLK3+DLY1+FSYNC+F1+F2
3243      Y:00020D Y:00020D                   DC      CLK3+DLY2+FSYNC+00+F2
3244      Y:00020E Y:00020E                   DC      CLK3+DLY0+FSYNC+F1+F2
3245                                END_CLOCK_ROW_4
3246   
3247   
3248   
3249   
3250                                CLOCK_COLUMN
3251      Y:00020F Y:00020F                   DC      END_CLOCK_COLUMN-CLOCK_COLUMN-1
3252      Y:000210 Y:000210                   DC      CLK3+DLYA+FSYNC+F1+00
3253      Y:000211 Y:000211                   DC      CLK3+DLYB+FSYNC+F1+F2
3254      Y:000212 Y:000212                   DC      CLK3+DLYA+FSYNC+00+F2
3255      Y:000213 Y:000213                   DC      CLK3+DLYB+FSYNC+F1+F2
3256                                END_CLOCK_COLUMN
3257   
3258   
3259   
3260   
3261   
3262   
3263                                RD_COL_PIPELINE_TEST
3264      Y:000214 Y:000214                   DC      END_RD_COL_PIPELINE_TEST-RD_COL_PIPELINE_TEST-1
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 57



3265      Y:000215 Y:000215                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1                40ns
3266      Y:000216 Y:000216                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -                   640ns
3267      Y:000217 Y:000217                   DC      VIDEO+ADC_TIM+%0111               ; Hold No Pixel         1000ns
3268      Y:000218 Y:000218                   DC      VIDEO+STL_TIM+%0101               ; Move No Pixel                 40ns
3269      Y:000219 Y:000219                   DC      VIDEO+$000000+%0101               ; Place for SXMIT               40ns
3270      Y:00021A Y:00021A                   DC      VIDEO+SXM_TIM+%0101               ; Settling time             3880ns
3271      Y:00021B Y:00021B                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting         40ns
3272      Y:00021C Y:00021C                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1         1000ns
3273      Y:00021D Y:00021D                   DC      VIDEO+$000000+%0111               ; Stop Integration      40ns
3274      Y:00021E Y:00021E                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D cnv Pix 1   40ns
3275      Y:00021F Y:00021F                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1              360ns
3276      Y:000220 Y:000220                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2                40ns
3277      Y:000221 Y:000221                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
3278      Y:000222 Y:000222                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert      1000ns
3279      Y:000223 Y:000223                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data FIFO    40ns
3280      Y:000224 Y:000224                   DC      SXMIT                             ; SXMIT the Previous    40ns
3281      Y:000225 Y:000225                   DC      VIDEO+SXM_TIM+%0101               ; Settling time             3880ns
3282      Y:000226 Y:000226                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting                 40ns
3283      Y:000227 Y:000227                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3         1000ns
3284      Y:000228 Y:000228                   DC      VIDEO+$000000+%0111               ; Stop Integration      40ns
3285      Y:000229 Y:000229                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert     40ns
3286      Y:00022A Y:00022A                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3              360ns
3287                                END_RD_COL_PIPELINE_TEST
3288   
3289                                ; This code reads out most of the array, with full image transmission
3290                                RD_COLS_TEST
3291      Y:00022B Y:00022B                   DC      END_RD_COLS_TEST-RD_COLS_TEST-1   ;
3292      Y:00022C Y:00022C                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
3293      Y:00022D Y:00022D                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3294      Y:00022E Y:00022E                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
3295      Y:00022F Y:00022F                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
3296      Y:000230 Y:000230                   DC      SXMIT                             ; SXMIT the Previous Pixel 1 - X32 (40ns)
3297      Y:000231 Y:000231                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (3880ns)
3298      Y:000232 Y:000232                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3299      Y:000233 Y:000233                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
3300      Y:000234 Y:000234                   DC      VIDEO+$000000+%0111               ; Stop Integration
3301      Y:000235 Y:000235                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (400ns)
3302      Y:000236 Y:000236                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
3303      Y:000237 Y:000237                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 3 (40ns)
3304      Y:000238 Y:000238                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3305      Y:000239 Y:000239                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 2 (1us)
3306      Y:00023A Y:00023A                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 2 (40ns)
3307      Y:00023B Y:00023B                   DC      SXMIT                             ; SXMIT the Previous Pixel 2 - X32 (40ns)
3308      Y:00023C Y:00023C                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
3309      Y:00023D Y:00023D                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3310      Y:00023E Y:00023E                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3 (760ns)
3311      Y:00023F Y:00023F                   DC      VIDEO+$000000+%0111               ; Stop Integration
3312      Y:000240 Y:000240                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 3 (400ns)
3313      Y:000241 Y:000241                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3 (240ns)
3314                                END_RD_COLS_TEST
3315   
3316                                ; This transmits the last pixels in each row, emptying the pipeline
3317                                LAST_8INROW_TEST
3318      Y:000242 Y:000242                   DC      END_LAST_8INROW_TEST-LAST_8INROW_TEST-1
3319      Y:000243 Y:000243                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
3320      Y:000244 Y:000244                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3321      Y:000245 Y:000245                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
3322      Y:000246 Y:000246                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
3323      Y:000247 Y:000247                   DC      SXMIT                             ; SXMIT the Previous Pixel 1 - X32 (40ns)
3324      Y:000248 Y:000248                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
3325      Y:000249 Y:000249                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3326      Y:00024A Y:00024A                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 58



3327      Y:00024B Y:00024B                   DC      VIDEO+$000000+%0111               ; Stop Integration
3328      Y:00024C Y:00024C                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (40+40ns)
3329      Y:00024D Y:00024D                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
3330                                END_LAST_8INROW_TEST
3331   
3332   
3333   
3334   
3335   
3336   
3337   
3338                                ; Define CLOCK as a macro to produce in-line code to reduce execution time
3339                                ; Here we do INT and A2D 6 times successively
3340                                 RD_COL_MACRO1
3341                                          MACRO
3342 m                                        DC      VIDEO+RST_DLY+%0111               ; Wait 4 Reset Integrator    40ns
3343 m                                        DC      VIDEO+RST_TIM+%0101               ; Reset Integrator           1000ns
3344 m                                        DC      VIDEO+RST_STL+%0111               ; Stop Reset & wait          100ns
3345 m                                        DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1             1000ns
3346 m                                        DC      VIDEO+INT_STL+%0111               ; Stop Integration & wait    360ns <----Leac
h March 5, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1      40ns
3347 m                                        DC      VIDEO+ADC_CNV+%0011               ; A/D Conversion             100ns
3348 m                                        DC      VIDEO+ADC_HLD+%0111               ; Hold A/D convert              480ns
3349 m                                        DC      VIDEO+STL_TIM+%1111               ; Move A/D data FIFO         40ns
3350 m                              ;  DC      SXMIT                           ; SXMIT                      40ns
3351 m                                        ENDM
3352   
3353                                 RD_COL_MACRO2
3354                                          MACRO
3355 m                                        DC      VIDEO+RST_DLY+%0111               ; Wait 4 Reset Integrator    40ns
3356 m                                        DC      VIDEO+RST_TIM+%0101               ; Reset Integrator           1000ns
3357 m                                        DC      VIDEO+RST_STL+%0111               ; Stop Reset & wait          100ns
3358 m                                        DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1             1000ns
3359 m                                        DC      VIDEO+INT_STL+%0111               ; Stop Integration & wait    360ns <----Leac
h March 5, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1      40ns
3360 m                                        DC      VIDEO+ADC_CNV+%0011               ; A/D Conversion             100ns
3361 m                                        DC      VIDEO+ADC_HLD+%0111               ; Hold A/D convert              480ns
3362 m                                        DC      VIDEO+STL_TIM+%1111               ; Move A/D data FIFO         40ns
3363 m                                        DC      SXMIT                             ; SXMIT                   40ns
3364 m                                        ENDM
3365   
3366                                ; This code initiates the pipeline for each row - no image transmission yet
3367                                ; Modified by L. Boucher for 6 Digital Samples
3368   
3369   
3370                                RD_COL_PIPELINE1
3371      Y:00024E Y:00024E                   DC      END_RD_COL_PIPELINE1-RD_COL_PIPELINE1-1
3372      Y:00024F Y:00024F                   DC      CLK3+$000000+FSYNC+F1+F2          ; trick to loop with rd_cols
3373      Y:000250 Y:000250                   DC      CLK3+$080000+FSYNC+F1+00          ;DTW 08 Select Pixel 1        40ns
3374                                END_RD_COL_PIPELINE1
3375   
3376   
3377                                RD_COLS1
3378      Y:000251 Y:000251                   DC      END_RD_COLS1-RD_COLS1-1           ;
3379      Y:000252 Y:000252                   DC      CLK3+$000000+FSYNC+F1+F2          ; Deselect Pixel 2         360ns
3380      Y:000253 Y:000253                   DC      CLK3+$900000+FSYNC+F1+00          ;DTW 08 Select next Pixel           40ns
3381                                END_RD_COLS1
3382   
3383   
3384                                RD_COLS2
3385      Y:000254 Y:000254                   DC      END_RD_COLS2-RD_COLS2-1           ;
3386      Y:000255 Y:000255                   DC      CLK3+$000000+FSYNC+F1+F2          ; Deselect Pixel 3         (240ns)
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 59



3387      Y:000256 Y:000256                   DC      CLK3+$900000+FSYNC+00+F2          ;DTW 08 Select Pixel 4        (40ns)
3388                                END_RD_COLS2
3389   
3390                                ;RD_COL_PIPELINE1
3391                                ;   DC END_RD_COL_PIPELINE1-RD_COL_PIPELINE1-1
3392                                ;   DC      CLK3+000+FSYNC+F1+F2     ; trick to loop with rd_cols
3393                                ;   DC      CLK3+000+FSYNC+F1+00     ; Select Pixel 1        40ns
3394                                ;END_RD_COL_PIPELINE1
3395                                ;
3396                                ;
3397                                ;RD_COLS1
3398                                ;   DC END_RD_COLS1-RD_COLS1-1 ;
3399                                ;   DC      CLK3+DTW+FSYNC+F1+F2     ; Deselect Pixel 2         360ns
3400                                ;   DC      CLK3+000+FSYNC+F1+00     ; Select next Pixel           40ns
3401                                ;END_RD_COLS1
3402                                ;
3403                                ;
3404                                ;RD_COLS2
3405                                ;   DC END_RD_COLS2-RD_COLS2-1 ;
3406                                ;   DC      CLK3+DTW+FSYNC+F1+F2     ; Deselect Pixel 3         (240ns)
3407                                ;   DC      CLK3+000+FSYNC+00+F2     ; Select Pixel 4        (40ns)
3408                                ;END_RD_COLS2
3409                                ;
3410                                ;
3411   
3412   
3413                                ; This transmits the last pixels in each row, emptying the pipeline
3414                                ; Modified by L. Boucher for 6 Digital Samples
3415                                ;LAST_8INROW
3416                                ;   DC END_LAST_8INROW-LAST_8INROW-1
3417                                ;   DC      CLK3+DTW+FSYNC+F1+F2     ; Deselect Pixel        360ns
3418                                ;   DC      CLK3+000+FSYNC+F1+00     ; Select next Pixel           40ns
3419                                ;
3420                                ;   RD_COLS1 ; Macro
3421                                ;   RD_COLS1
3422                                ;   RD_COLS1
3426                                ;
3427                                ;END_LAST_8INROW
3428                                ;
3429   
3430   
3431                                ;RD_COLS_A
3432                                ;   DC END_RD_COLS_A-RD_COLS_A-1 ;
3433                                ;   DC      CLK3+DTW+FSYNC+F1+F2     ; Deselect Pixel 2         360ns
3434                                ;   DC      CLK3+000+FSYNC+F1+00     ; Select next Pixel           40ns
3435                                ;END_RD_COLS_A
3436                                ;
3437                                ;
3438                                ;RD_COLS_B
3439                                ;   DC END_RD_COLS_B-RD_COLS_B-1 ;
3440                                ;   DC      CLK3+DTW+FSYNC+F1+F2     ; Deselect Pixel 3         (240ns)
3441                                ;   DC      CLK3+000+FSYNC+00+F2     ; Select Pixel 4        (40ns)
3442                                ;END_RD_COLS_B
3443   
3444   
3445                                SAMPLE_COL
3446      Y:000257 Y:000257                   DC      END_SAMPLE_COL-SAMPLE_COL-1       ;
3447   
3448   
3449                                ;        DC      VIDEO+$000000+%0111             ; Wait 4 Reset Integrator    40ns
3450      Y:000258 Y:000258                   DC      VIDEO+$020000+%0101               ;SXM_TIM 8C       ; Settling time (3880ns)
3451      Y:000259 Y:000259                   DC      VIDEO+$000000+%0111               ;STP_TIM 00      ; Stop Reseting
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 60



3452      Y:00025A Y:00025A                   DC      VIDEO+$180000+%0110               ;INT_TIM 18     ; Integrate Pixel 2 (760ns)
3453      Y:00025B Y:00025B                   DC      VIDEO+$000000+%0111               ;00       ; Stop Integration
3454      Y:00025C Y:00025C                   DC      VIDEO+$040000+%0011               ;ADC_CNV 04       ; Start A/D convert Pixel 
2 (400ns)
3455      Y:00025D Y:00025D                   DC      VIDEO+$0F0000+%0111               ;PAD_TIM 0F       ; Pad Delay - 40ns
3456      Y:00025E Y:00025E                   DC      VIDEO+$0F0000+%0111               ;ADC_TIM 0F       ; Hold A/D convert sig Pix
el 2 (1us)
3457      Y:00025F Y:00025F                   DC      VIDEO+$000000+%1101               ;STL_TIM 00       ; Move A/D data to FIFO Pi
xel 2 (40ns)
3458      Y:000260 Y:000260                   DC      SXMIT                             ; SXMIT the Previous Pixel 2 - X32 (40ns)
3459   
3460   
3461                                ;  DC      VIDEO+RST_DLY+%0111             ; Wait 4 Reset Integrator    40ns
3462                                ;  DC      VIDEO+RST_TIM+%0101             ; Reset Integrator           1000ns
3463                                ;  DC      VIDEO+RST_STL+%0111             ; Stop Reset & wait          100ns
3464                                ;  DC      VIDEO+INT_TIM+%0110             ; Integrate Pixel 1             1000ns
3465                                ;  DC      VIDEO+INT_STL+%0111             ; Stop Integration & wait    360ns <----Leach March 5
, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1      40ns
3466                                ;  DC      VIDEO+ADC_CNV+%0011             ; A/D Conversion             100ns
3467                                ;  DC      VIDEO+ADC_HLD+%0111             ; Hold A/D convert              480ns
3468                                ;  DC      VIDEO+STL_TIM+%1111             ; Move A/D data FIFO         40ns
3469                                ;  DC      SXMIT                           ; SXMIT                   40ns
3470                                END_SAMPLE_COL
3471   
3472   
3473   
3474   
3475   
3476   
3477                                ; ENDS HERE THE REAOUDT OF THE 6DS
3478   
3479   
3480   
3481   
3482   
3483   
3484                                ; This code intiates the pipeline of pixels for each row
3485                                RD_NTX_PIPELINE
3486      Y:000261 Y:000261                   DC      END_RD_NTX_PIPELINE-RD_NTX_PIPELINE-1
3487      Y:000262 Y:000262                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1  40ns
3488      Y:000263 Y:000263                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -    640ns
3489      Y:000264 Y:000264                   DC      VIDEO+ADC_TIM+%0111               ; Hold No Pixel         1000ns
3490      Y:000265 Y:000265                   DC      VIDEO+STL_TIM+%0101               ; Move No Pixel      400ns
3491      Y:000266 Y:000266                   DC      VIDEO+$000000+%0101               ; Place for SXMIT    40ns
3492      Y:000267 Y:000267                   DC      VIDEO+SXM_TIM+%0101               ; Settling time        3880ns
3493      Y:000268 Y:000268                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting          40ns
3494      Y:000269 Y:000269                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1    1000ns
3495      Y:00026A Y:00026A                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
3496      Y:00026B Y:00026B                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D cnv Pix 1    40ns
3497      Y:00026C Y:00026C                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1   360ns
3498      Y:00026D Y:00026D                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2   40ns
3499      Y:00026E Y:00026E                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -         640ns
3500      Y:00026F Y:00026F                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert     1000ns
3501      Y:000270 Y:000270                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data FIFO     40ns
3502      Y:000271 Y:000271                   DC      VIDEO+0000000+%0101               ; Settling time           40ns
3503      Y:000272 Y:000272                   DC      VIDEO+SXM_TIM+%0101               ; Settling time        3880ns
3504      Y:000273 Y:000273                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting      40ns
3505      Y:000274 Y:000274                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3    1000ns
3506      Y:000275 Y:000275                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
3507      Y:000276 Y:000276                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert      40ns
3508      Y:000277 Y:000277                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3   360ns
3509                                END_RD_NTX_PIPELINE
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  CLOCK_READOUT.waveforms  Page 61



3510   
3511                                RD_NTX
3512      Y:000278 Y:000278                   DC      END_RD_NTX-RD_NTX-1
3513      Y:000279 Y:000279                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
3514      Y:00027A Y:00027A                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3515      Y:00027B Y:00027B                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
3516      Y:00027C Y:00027C                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
3517      Y:00027D Y:00027D                   DC      VIDEO+0000000+%0101               ; Settling time           40ns
3518      Y:00027E Y:00027E                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
3519      Y:00027F Y:00027F                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3520      Y:000280 Y:000280                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
3521      Y:000281 Y:000281                   DC      VIDEO+$000000+%0111               ; Stop Integration
3522      Y:000282 Y:000282                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (400ns)
3523      Y:000283 Y:000283                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
3524      Y:000284 Y:000284                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 3 (40ns)
3525      Y:000285 Y:000285                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3526      Y:000286 Y:000286                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 2 (1us)
3527      Y:000287 Y:000287                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 2 (40ns)
3528      Y:000288 Y:000288                   DC      VIDEO+0000000+%0101               ; Settling time           40ns
3529      Y:000289 Y:000289                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
3530      Y:00028A Y:00028A                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3531      Y:00028B Y:00028B                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3 (760ns)
3532      Y:00028C Y:00028C                   DC      VIDEO+$000000+%0111               ; Stop Integration
3533      Y:00028D Y:00028D                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 3 (400ns)
3534      Y:00028E Y:00028E                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3 (240ns)
3535                                END_RD_NTX
3536   
3537                                LAST_NTX_8INROW
3538      Y:00028F Y:00028F                   DC      END_LAST_NTX_8INROW-LAST_NTX_8INROW
3539      Y:000290 Y:000290                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
3540      Y:000291 Y:000291                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
3541      Y:000292 Y:000292                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
3542      Y:000293 Y:000293                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
3543      Y:000294 Y:000294                   DC      VIDEO+0000000+%0101               ; Settling time           40ns
3544      Y:000295 Y:000295                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
3545      Y:000296 Y:000296                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
3546      Y:000297 Y:000297                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
3547      Y:000298 Y:000298                   DC      VIDEO+$000000+%0111               ; Stop Integration
3548      Y:000299 Y:000299                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (40+40ns)
3549      Y:00029A Y:00029A                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
3550                                END_LAST_NTX_8INROW
3551   
3552   
3553   
3554   
3555   
3556   
3557   
3558   
3559   
3560   
3561   
3562   
3563   
3564   
3565   
3566   
3567   
3568   
3569   
3570   
3571   
Motorola DSP56300 Assembler  Version 6.3.4   25-05-07  21:53:00  tim.asm  Page 62



3572                                 END_APPLICATON_Y_MEMORY
3573      00029B                              EQU     @LCV(L)
3574   
3575                                ; End of program
3576                                          END

0    Errors
0    Warnings


