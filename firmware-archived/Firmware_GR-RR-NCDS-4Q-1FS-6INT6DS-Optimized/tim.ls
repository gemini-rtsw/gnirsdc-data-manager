Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 1



1                                 COMMENT *
2      
3                          This file is used to generate DSP code for the Gen III = ARC-22
4                                  250 MHz timing boards to operate one quadrant of an
5                                  Aladdin III infrared array with one 8-channel ARC-46 video
6                                  board.
7                                  MODIFIED L BOUCHER SO WE DON'T RUN LAST_8INROWS WFM CLOCK
8                             *
9      
10                                   PAGE    132                               ; Printronix page width - 132 columns
11     
12                         ; Include the boot and header files so addressing is easy
13                                   INCLUDE "timboot.asm"
14                         ;  This file is used to generate boot DSP code for the Gen III 250 MHz fiber
15                         ;       optic timing board = ARC22 using a DSP56303 as its main processor.
16     
17                         ; Various addressing control registers
18        FFFFFB           BCR       EQU     $FFFFFB                           ; Bus Control Register
19        FFFFF9           AAR0      EQU     $FFFFF9                           ; Address Attribute Register, channel 0
20        FFFFF8           AAR1      EQU     $FFFFF8                           ; Address Attribute Register, channel 1
21        FFFFF7           AAR2      EQU     $FFFFF7                           ; Address Attribute Register, channel 2
22        FFFFF6           AAR3      EQU     $FFFFF6                           ; Address Attribute Register, channel 3
23        FFFFFD           PCTL      EQU     $FFFFFD                           ; PLL control register
24        FFFFFE           IPRP      EQU     $FFFFFE                           ; Interrupt Priority register - Peripheral
25        FFFFFF           IPRC      EQU     $FFFFFF                           ; Interrupt Priority register - Core
26     
27                         ; Port E is the Synchronous Communications Interface (SCI) port
28        FFFF9F           PCRE      EQU     $FFFF9F                           ; Port Control Register
29        FFFF9E           PRRE      EQU     $FFFF9E                           ; Port Direction Register
30        FFFF9D           PDRE      EQU     $FFFF9D                           ; Port Data Register
31        FFFF9C           SCR       EQU     $FFFF9C                           ; SCI Control Register
32        FFFF9B           SCCR      EQU     $FFFF9B                           ; SCI Clock Control Register
33     
34        FFFF9A           SRXH      EQU     $FFFF9A                           ; SCI Receive Data Register, High byte
35        FFFF99           SRXM      EQU     $FFFF99                           ; SCI Receive Data Register, Middle byte
36        FFFF98           SRXL      EQU     $FFFF98                           ; SCI Receive Data Register, Low byte
37     
38        FFFF97           STXH      EQU     $FFFF97                           ; SCI Transmit Data register, High byte
39        FFFF96           STXM      EQU     $FFFF96                           ; SCI Transmit Data register, Middle byte
40        FFFF95           STXL      EQU     $FFFF95                           ; SCI Transmit Data register, Low byte
41     
42        FFFF94           STXA      EQU     $FFFF94                           ; SCI Transmit Address Register
43        FFFF93           SSR       EQU     $FFFF93                           ; SCI Status Register
44     
45        000009           SCITE     EQU     9                                 ; X:SCR bit set to enable the SCI transmitter
46        000008           SCIRE     EQU     8                                 ; X:SCR bit set to enable the SCI receiver
47        000000           TRNE      EQU     0                                 ; This is set in X:SSR when the transmitter
48                                                                             ;  shift and data registers are both empty
49        000001           TDRE      EQU     1                                 ; This is set in X:SSR when the transmitter
50                                                                             ;  data register is empty
51        000002           RDRF      EQU     2                                 ; X:SSR bit set when receiver register is full
52        00000F           SELSCI    EQU     15                                ; 1 for SCI to backplane, 0 to front connector
53     
54     
55                         ; ESSI Flags
56        000006           TDE       EQU     6                                 ; Set when transmitter data register is empty
57        000007           RDF       EQU     7                                 ; Set when receiver is full of data
58        000010           TE        EQU     16                                ; Transmitter enable
59     
60                         ; Phase Locked Loop initialization
61        050003           PLL_INIT  EQU     $050003                           ; PLL = 25 MHz x 2 = 100 MHz
62     
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 2



63                         ; Port B general purpose I/O
64        FFFFC4           HPCR      EQU     $FFFFC4                           ; Control register (bits 1-6 cleared for GPIO)
65        FFFFC9           HDR       EQU     $FFFFC9                           ; Data register
66        FFFFC8           HDDR      EQU     $FFFFC8                           ; Data Direction Register bits (=1 for output)
67     
68                         ; Port C is Enhanced Synchronous Serial Port 0 = ESSI0
69        FFFFBF           PCRC      EQU     $FFFFBF                           ; Port C Control Register
70        FFFFBE           PRRC      EQU     $FFFFBE                           ; Port C Data direction Register
71        FFFFBD           PDRC      EQU     $FFFFBD                           ; Port C GPIO Data Register
72        FFFFBC           TX00      EQU     $FFFFBC                           ; Transmit Data Register #0
73        FFFFB8           RX0       EQU     $FFFFB8                           ; Receive data register
74        FFFFB7           SSISR0    EQU     $FFFFB7                           ; Status Register
75        FFFFB6           CRB0      EQU     $FFFFB6                           ; Control Register B
76        FFFFB5           CRA0      EQU     $FFFFB5                           ; Control Register A
77     
78                         ; Port D is Enhanced Synchronous Serial Port 1 = ESSI1
79        FFFFAF           PCRD      EQU     $FFFFAF                           ; Port D Control Register
80        FFFFAE           PRRD      EQU     $FFFFAE                           ; Port D Data direction Register
81        FFFFAD           PDRD      EQU     $FFFFAD                           ; Port D GPIO Data Register
82        FFFFAC           TX10      EQU     $FFFFAC                           ; Transmit Data Register 0
83        FFFFA7           SSISR1    EQU     $FFFFA7                           ; Status Register
84        FFFFA6           CRB1      EQU     $FFFFA6                           ; Control Register B
85        FFFFA5           CRA1      EQU     $FFFFA5                           ; Control Register A
86     
87                         ; Timer module addresses
88        FFFF8F           TCSR0     EQU     $FFFF8F                           ; Timer control and status register
89        FFFF8E           TLR0      EQU     $FFFF8E                           ; Timer load register = 0
90        FFFF8D           TCPR0     EQU     $FFFF8D                           ; Timer compare register = exposure time
91        FFFF8C           TCR0      EQU     $FFFF8C                           ; Timer count register = elapsed time
92        FFFF83           TPLR      EQU     $FFFF83                           ; Timer prescaler load register => milliseconds
93        FFFF82           TPCR      EQU     $FFFF82                           ; Timer prescaler count register
94        000000           TIM_BIT   EQU     0                                 ; Set to enable the timer
95        000009           TRM       EQU     9                                 ; Set to enable the timer preloading
96        000015           TCF       EQU     21                                ; Set when timer counter = compare register
97     
98                         ; Board specific addresses and constants
99        FFFFF1           RDFO      EQU     $FFFFF1                           ; Read incoming fiber optic data byte
100       FFFFF2           WRFO      EQU     $FFFFF2                           ; Write fiber optic data replies
101       FFFFF3           WRSS      EQU     $FFFFF3                           ; Write switch state
102       FFFFF5           WRLATCH   EQU     $FFFFF5                           ; Write to a latch
103       010000           RDAD      EQU     $010000                           ; Read A/D values into the DSP
104       000009           EF        EQU     9                                 ; Serial receiver empty flag
105    
106                        ; DSP port A bit equates
107       000000           PWROK     EQU     0                                 ; Power control board says power is OK
108       000001           LED1      EQU     1                                 ; Control one of two LEDs
109       000002           LVEN      EQU     2                                 ; Low voltage power enable
110       000003           HVEN      EQU     3                                 ; High voltage power enable
111       00000E           SSFHF     EQU     14                                ; Switch state FIFO half full flag
112       00000A           EXT_IN0   EQU     10                                ; External digital I/O to the timing board
113       00000B           EXT_IN1   EQU     11
114       00000C           EXT_OUT0  EQU     12
115       00000D           EXT_OUT1  EQU     13
116    
117                        ; Port D equate
118       000001           SSFEF     EQU     1                                 ; Switch state FIFO empty flag
119    
120                        ; Other equates
121       000002           WRENA     EQU     2                                 ; Enable writing to the EEPROM
122    
123                        ; Latch U25 bit equates
124       000000           CDAC      EQU     0                                 ; Clear the analog board DACs
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 3



125       000002           ENCK      EQU     2                                 ; Enable the clock outputs
126       000004           SHUTTER   EQU     4                                 ; Control the shutter
127       000005           TIM_U_RST EQU     5                                 ; Reset the utility board
128    
129                        ; Software status bits, defined at X:<STATUS = X:0
130       000000           ST_RCV    EQU     0                                 ; Set to indicate word is from SCI = utility board
131       000002           IDLMODE   EQU     2                                 ; Set if need to idle after readout
132       000003           ST_SHUT   EQU     3                                 ; Set to indicate shutter is closed, clear for open
133       000004           ST_RDC    EQU     4                                 ; Set if executing 'RDC' command - reading out
134       000005           SPLIT_S   EQU     5                                 ; Set if split serial
135       000006           SPLIT_P   EQU     6                                 ; Set if split parallel
136       000007           MPP       EQU     7                                 ; Set if parallels are in MPP mode
137       000008           NOT_CLR   EQU     8                                 ; Set if not to clear CCD before exposure
138       00000A           TST_IMG   EQU     10                                ; Set if controller is to generate a test image
139       00000B           SHUT      EQU     11                                ; Set if opening shutter at beginning of exposure
140       00000C           ST_DITH   EQU     12                                ; Set if to dither during exposure
141       00000D           ST_SYNC   EQU     13                                ; Set if starting exposure on SYNC = high signal
142       00000E           ST_CNRD   EQU     14                                ; Set if in continous readout mode
143       00000F           ST_DIRTY  EQU     15                                ; Set if waveform tables need to be updated
144       000010           ST_SA     EQU     16                                ; Set if in subarray readout mode
145       000011           ST_CDS    EQU     17                                ; Set for correlated double sample readout
146       000012           ST_RRR    EQU     18                                ; Set if row-by-row reset while reading out and expos
ing
147    
148                        ; Address for the table containing the incoming SCI words
149       000400           SCI_TABLE EQU     $400
150    
151    
152                        ; Specify controller configuration bits of the X:STATUS word
153                        ;   to describe the software capabilities of this application file
154                        ; The bit is set (=1) if the capability is supported by the controller
155    
156    
157                                COMMENT *
158    
159                        BIT #'s         FUNCTION
160                        2,1,0           Video Processor
161                                                000     ARC41, CCD Rev. 3
162                                                001     CCD Gen I
163                                                010     ARC42, dual readout CCD
164                                                011     ARC44, 4-readout IR coadder
165                                                100     ARC45. dual readout CCD
166                                                101     ARC46 = 8-channel IR
167                                                110     ARC48 = 8 channel CCD
168                                                111     ARC47 = 4-channel CCD
169    
170                        4,3             Timing Board
171                                                00      ARC20, Rev. 4, Gen II
172                                                01      Gen I
173                                                10      ARC22, Gen III, 250 MHz
174    
175                        6,5             Utility Board
176                                                00      No utility board
177                                                01      ARC50
178    
179                        7               Shutter
180                                                0       No shutter support
181                                                1       Yes shutter support
182    
183                        9,8             Temperature readout
184                                                00      No temperature readout
185                                                01      Polynomial Diode calibration
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 4



186                                                10      Linear temperature sensor calibration
187    
188                        10              Subarray readout
189                                                0       Not supported
190                                                1       Yes supported
191    
192                        11              Binning
193                                                0       Not supported
194                                                1       Yes supported
195    
196                        12              Split-Serial readout
197                                                0       Not supported
198                                                1       Yes supported
199    
200                        13              Split-Parallel readout
201                                                0       Not supported
202                                                1       Yes supported
203    
204                        14              MPP = Inverted parallel clocks
205                                                0       Not supported
206                                                1       Yes supported
207    
208                        16,15           Clock Driver Board
209                                                00      ARC30 or ARC31
210                                                01      ARC32, CCD and IR
211                                                11      No clock driver board (Gen I)
212    
213                        19,18,17                Special implementations
214                                                000     Somewhere else
215                                                001     Mount Laguna Observatory
216                                                010     NGST Aladdin
217                                                xxx     Other
218                                *
219    
220                        CCDVIDREV3B
221       000000                     EQU     $000000                           ; CCD Video Processor Rev. 3
222       000000           ARC41     EQU     $000000
223       000001           VIDGENI   EQU     $000001                           ; CCD Video Processor Gen I
224       000002           IRREV4    EQU     $000002                           ; IR Video Processor Rev. 4
225       000002           ARC42     EQU     $000002
226       000003           COADDER   EQU     $000003                           ; IR Coadder
227       000003           ARC44     EQU     $000003
228       000004           CCDVIDREV5 EQU    $000004                           ; Differential input CCD video Rev. 5
229       000004           ARC45     EQU     $000004
230       000005           ARC46     EQU     $000005                           ; 8-channel IR video board
231       000006           ARC48     EQU     $000006                           ; 8-channel CCD video board
232       000007           ARC47     EQU     $000007                           ; 4-channel CCD video board
233       000000           TIMREV4   EQU     $000000                           ; Timing Revision 4 = 50 MHz
234       000000           ARC20     EQU     $000000
235       000008           TIMGENI   EQU     $000008                           ; Timing Gen I = 40 MHz
236       000010           TIMREV5   EQU     $000010                           ; Timing Revision 5 = 250 MHz
237       000010           ARC22     EQU     $000010
238       008000           ARC32     EQU     $008000                           ; CCD & IR clock driver board
239       000020           UTILREV3  EQU     $000020                           ; Utility Rev. 3 supported
240       000020           ARC50     EQU     $000020
241       000080           SHUTTER_CC EQU    $000080                           ; Shutter supported
242       000100           TEMP_POLY EQU     $000100                           ; Polynomial calibration
243                        TEMP_LINEAR
244       000200                     EQU     $000200                           ; Linear calibration
245       000400           SUBARRAY  EQU     $000400                           ; Subarray readout supported
246       000800           BINNING   EQU     $000800                           ; Binning supported
247                        SPLIT_SERIAL
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 5



248       001000                     EQU     $001000                           ; Split serial supported
249                        SPLIT_PARALLEL
250       002000                     EQU     $002000                           ; Split parallel supported
251       004000           MPP_CC    EQU     $004000                           ; Inverted clocks supported
252       018000           CLKDRVGENI EQU    $018000                           ; No clock driver board - Gen I
253       020000           MLO       EQU     $020000                           ; Set if Mount Laguna Observatory
254       040000           NGST      EQU     $040000                           ; NGST Aladdin implementation
255       100000           CONT_RD   EQU     $100000                           ; Continuous readout implemented
256    
257                        ; Special address for two words for the DSP to bootstrap code from the EEPROM
258                                  IF      @SCP("HOST","ROM")
265                                  ENDIF
266    
267                                  IF      @SCP("HOST","HOST")
268       P:000000 P:000000                   ORG     P:0,P:0
269       P:000000 P:000000 0C0190            JMP     <INIT
270       P:000001 P:000001 000000            NOP
271                                           ENDIF
272    
273                                 ;  This ISR receives serial words a byte at a time over the asynchronous
274                                 ;    serial link (SCI) and squashes them into a single 24-bit word
275       P:000002 P:000002 602400  SCI_RCV   MOVE              R0,X:<SAVE_R0           ; Save R0
276       P:000003 P:000003 052139            MOVEC             SR,X:<SAVE_SR           ; Save Status Register
277       P:000004 P:000004 60A700            MOVE              X:<SCI_R0,R0            ; Restore R0 = pointer to SCI receive regist
er
278       P:000005 P:000005 542300            MOVE              A1,X:<SAVE_A1           ; Save A1
279       P:000006 P:000006 452200            MOVE              X1,X:<SAVE_X1           ; Save X1
280       P:000007 P:000007 54A600            MOVE              X:<SCI_A1,A1            ; Get SRX value of accumulator contents
281       P:000008 P:000008 45E000            MOVE              X:(R0),X1               ; Get the SCI byte
282       P:000009 P:000009 0AD041            BCLR    #1,R0                             ; Test for the address being $FFF6 = last by
te
283       P:00000A P:00000A 000000            NOP
284       P:00000B P:00000B 000000            NOP
285       P:00000C P:00000C 000000            NOP
286       P:00000D P:00000D 205862            OR      X1,A      (R0)+                   ; Add the byte into the 24-bit word
287       P:00000E P:00000E 0E0013            JCC     <MID_BYT                          ; Not the last byte => only restore register
s
288       P:00000F P:00000F 545C00  END_BYT   MOVE              A1,X:(R4)+              ; Put the 24-bit word into the SCI buffer
289       P:000010 P:000010 60F400            MOVE              #SRXL,R0                ; Re-establish first address of SCI interfac
e
                            FFFF98
290       P:000012 P:000012 2C0000            MOVE              #0,A1                   ; For zeroing out SCI_A1
291       P:000013 P:000013 602700  MID_BYT   MOVE              R0,X:<SCI_R0            ; Save the SCI receiver address
292       P:000014 P:000014 542600            MOVE              A1,X:<SCI_A1            ; Save A1 for next interrupt
293       P:000015 P:000015 05A139            MOVEC             X:<SAVE_SR,SR           ; Restore Status Register
294       P:000016 P:000016 54A300            MOVE              X:<SAVE_A1,A1           ; Restore A1
295       P:000017 P:000017 45A200            MOVE              X:<SAVE_X1,X1           ; Restore X1
296       P:000018 P:000018 60A400            MOVE              X:<SAVE_R0,R0           ; Restore R0
297       P:000019 P:000019 000004            RTI                                       ; Return from interrupt service
298    
299                                 ; Clear error condition and interrupt on SCI receiver
300       P:00001A P:00001A 077013  CLR_ERR   MOVEP             X:SSR,X:RCV_ERR         ; Read SCI status register
                            000025
301       P:00001C P:00001C 077018            MOVEP             X:SRXL,X:RCV_ERR        ; This clears any error
                            000025
302       P:00001E P:00001E 000004            RTI
303    
304       P:00001F P:00001F                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
305       P:000030 P:000030                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
306       P:000040 P:000040                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
307    
308                                 ; Tune the table so the following instruction is at P:$50 exactly.
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 6



309       P:000050 P:000050 0D0002            JSR     SCI_RCV                           ; SCI receive data interrupt
310       P:000051 P:000051 000000            NOP
311       P:000052 P:000052 0D001A            JSR     CLR_ERR                           ; SCI receive error interrupt
312       P:000053 P:000053 000000            NOP
313    
314                                 ; *******************  Command Processing  ******************
315    
316                                 ; Read the header and check it for self-consistency
317       P:000054 P:000054 609F00  START     MOVE              X:<IDL_ADR,R0
318       P:000055 P:000055 018FA0            JSET    #TIM_BIT,X:TCSR0,EXPOSING         ; If exposing go check the timer
                            0003BA
319       P:000057 P:000057 0A00A4            JSET    #ST_RDC,X:<STATUS,CONTINUE_READING
                            100000
320       P:000059 P:000059 0AE080            JMP     (R0)
321    
322       P:00005A P:00005A 330700  TST_RCV   MOVE              #<COM_BUF,R3
323       P:00005B P:00005B 0D00A5            JSR     <GET_RCV
324       P:00005C P:00005C 0E005B            JCC     *-1
325    
326                                 ; Check the header and read all the remaining words in the command
327       P:00005D P:00005D 0C00FF  PRC_RCV   JMP     <CHK_HDR                          ; Update HEADER and NWORDS
328       P:00005E P:00005E 578600  PR_RCV    MOVE              X:<NWORDS,B             ; Read this many words total in the command
329       P:00005F P:00005F 000000            NOP
330       P:000060 P:000060 01418C            SUB     #1,B                              ; We've already read the header
331       P:000061 P:000061 000000            NOP
332       P:000062 P:000062 06CF00            DO      B,RD_COM
                            00006A
333       P:000064 P:000064 205B00            MOVE              (R3)+                   ; Increment past what's been read already
334       P:000065 P:000065 0B0080  GET_WRD   JSCLR   #ST_RCV,X:STATUS,CHK_FO
                            0000A9
335       P:000067 P:000067 0B00A0            JSSET   #ST_RCV,X:STATUS,CHK_SCI
                            0000D5
336       P:000069 P:000069 0E0065            JCC     <GET_WRD
337       P:00006A P:00006A 000000            NOP
338       P:00006B P:00006B 330700  RD_COM    MOVE              #<COM_BUF,R3            ; Restore R3 = beginning of the command
339    
340                                 ; Is this command for the timing board?
341       P:00006C P:00006C 448500            MOVE              X:<HEADER,X0
342       P:00006D P:00006D 579B00            MOVE              X:<DMASK,B
343       P:00006E P:00006E 459A4E            AND     X0,B      X:<TIM_DRB,X1           ; Extract destination byte
344       P:00006F P:00006F 20006D            CMP     X1,B                              ; Does header = timing board number?
345       P:000070 P:000070 0EA080            JEQ     <COMMAND                          ; Yes, process it here
346       P:000071 P:000071 0E909D            JLT     <FO_XMT                           ; Send it to fiber optic transmitter
347    
348                                 ; Transmit the command to the utility board over the SCI port
349       P:000072 P:000072 060600            DO      X:<NWORDS,DON_XMT                 ; Transmit NWORDS
                            00007E
350       P:000074 P:000074 60F400            MOVE              #STXL,R0                ; SCI first byte address
                            FFFF95
351       P:000076 P:000076 44DB00            MOVE              X:(R3)+,X0              ; Get the 24-bit word to transmit
352       P:000077 P:000077 060380            DO      #3,SCI_SPT
                            00007D
353       P:000079 P:000079 019381            JCLR    #TDRE,X:SSR,*                     ; Continue ONLY if SCI XMT is empty
                            000079
354       P:00007B P:00007B 445800            MOVE              X0,X:(R0)+              ; Write to SCI, byte pointer + 1
355       P:00007C P:00007C 000000            NOP                                       ; Delay for the status flag to be set
356       P:00007D P:00007D 000000            NOP
357                                 SCI_SPT
358       P:00007E P:00007E 000000            NOP
359                                 DON_XMT
360       P:00007F P:00007F 0C0054            JMP     <START
361    
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 7



362                                 ; Process the receiver entry - is it in the command table ?
363       P:000080 P:000080 0203DF  COMMAND   MOVE              X:(R3+1),B              ; Get the command
364       P:000081 P:000081 205B00            MOVE              (R3)+
365       P:000082 P:000082 205B00            MOVE              (R3)+                   ; Point R3 to the first argument
366       P:000083 P:000083 302800            MOVE              #<COM_TBL,R0            ; Get the command table starting address
367       P:000084 P:000084 061C80            DO      #NUM_COM,END_COM                  ; Loop over the command table
                            00008B
368       P:000086 P:000086 47D800            MOVE              X:(R0)+,Y1              ; Get the command table entry
369       P:000087 P:000087 62E07D            CMP     Y1,B      X:(R0),R2               ; Does receiver = table entries address?
370       P:000088 P:000088 0E208B            JNE     <NOT_COM                          ; No, keep looping
371       P:000089 P:000089 00008C            ENDDO                                     ; Restore the DO loop system registers
372       P:00008A P:00008A 0AE280            JMP     (R2)                              ; Jump execution to the command
373       P:00008B P:00008B 205800  NOT_COM   MOVE              (R0)+                   ; Increment the register past the table addr
ess
374                                 END_COM
375       P:00008C P:00008C 0C008D            JMP     <ERROR                            ; The command is not in the table
376    
377                                 ; It's not in the command table - send an error message
378       P:00008D P:00008D 479D00  ERROR     MOVE              X:<ERR,Y1               ; Send the message - there was an error
379       P:00008E P:00008E 0C0090            JMP     <FINISH1                          ; This protects against unknown commands
380    
381                                 ; Send a reply packet - header and reply
382       P:00008F P:00008F 479800  FINISH    MOVE              X:<DONE,Y1              ; Send 'DON' as the reply
383       P:000090 P:000090 578500  FINISH1   MOVE              X:<HEADER,B             ; Get header of incoming command
384       P:000091 P:000091 469C00            MOVE              X:<SMASK,Y0             ; This was the source byte, and is to
385       P:000092 P:000092 330700            MOVE              #<COM_BUF,R3            ;     become the destination byte
386       P:000093 P:000093 46935E            AND     Y0,B      X:<TWO,Y0
387       P:000094 P:000094 0C1ED1            LSR     #8,B                              ; Shift right eight bytes, add it to the
388       P:000095 P:000095 460600            MOVE              Y0,X:<NWORDS            ;     header, and put 2 as the number
389       P:000096 P:000096 469958            ADD     Y0,B      X:<SBRD,Y0              ;     of words in the string
390       P:000097 P:000097 200058            ADD     Y0,B                              ; Add source board's header, set Y1 for abov
e
391       P:000098 P:000098 000000            NOP
392       P:000099 P:000099 575B00            MOVE              B,X:(R3)+               ; Put the new header on the transmitter stac
k
393       P:00009A P:00009A 475B00            MOVE              Y1,X:(R3)+              ; Put the argument on the transmitter stack
394       P:00009B P:00009B 570500            MOVE              B,X:<HEADER
395       P:00009C P:00009C 0C006B            JMP     <RD_COM                           ; Decide where to send the reply, and do it
396    
397                                 ; Transmit words to the host computer over the fiber optics link
398       P:00009D P:00009D 63F400  FO_XMT    MOVE              #COM_BUF,R3
                            000007
399       P:00009F P:00009F 060600            DO      X:<NWORDS,DON_FFO                 ; Transmit all the words in the command
                            0000A3
400       P:0000A1 P:0000A1 57DB00            MOVE              X:(R3)+,B
401       P:0000A2 P:0000A2 0D00EB            JSR     <XMT_WRD
402       P:0000A3 P:0000A3 000000            NOP
403       P:0000A4 P:0000A4 0C0054  DON_FFO   JMP     <START
404    
405                                 ; Check for commands from the fiber optic FIFO and the utility board (SCI)
406       P:0000A5 P:0000A5 0D00A9  GET_RCV   JSR     <CHK_FO                           ; Check for fiber optic command from FIFO
407       P:0000A6 P:0000A6 0E80A8            JCS     <RCV_RTS                          ; If there's a command, check the header
408       P:0000A7 P:0000A7 0D00D5            JSR     <CHK_SCI                          ; Check for an SCI command
409       P:0000A8 P:0000A8 00000C  RCV_RTS   RTS
410    
411                                 ; Because of FIFO metastability require that EF be stable for two tests
412       P:0000A9 P:0000A9 0A8989  CHK_FO    JCLR    #EF,X:HDR,TST2                    ; EF = Low,  Low  => CLR SR, return
                            0000AC
413       P:0000AB P:0000AB 0C00AF            JMP     <TST3                             ;      High, Low  => try again
414       P:0000AC P:0000AC 0A8989  TST2      JCLR    #EF,X:HDR,CLR_CC                  ;      Low,  High => try again
                            0000D1
415       P:0000AE P:0000AE 0C00A9            JMP     <CHK_FO                           ;      High, High => read FIFO
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 8



416       P:0000AF P:0000AF 0A8989  TST3      JCLR    #EF,X:HDR,CHK_FO
                            0000A9
417    
418       P:0000B1 P:0000B1 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
419       P:0000B3 P:0000B3 000000            NOP
420       P:0000B4 P:0000B4 000000            NOP
421       P:0000B5 P:0000B5 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
422       P:0000B7 P:0000B7 2B0000            MOVE              #0,B2
423       P:0000B8 P:0000B8 0140CE            AND     #$FF,B
                            0000FF
424       P:0000BA P:0000BA 0140CD            CMP     #>$AC,B                           ; It must be $AC to be a valid word
                            0000AC
425       P:0000BC P:0000BC 0E20D1            JNE     <CLR_CC
426       P:0000BD P:0000BD 4EF000            MOVE                          Y:RDFO,Y0   ; Read the MS byte
                            FFFFF1
427       P:0000BF P:0000BF 0C1951            INSERT  #$008010,Y0,B
                            008010
428       P:0000C1 P:0000C1 4EF000            MOVE                          Y:RDFO,Y0   ; Read the middle byte
                            FFFFF1
429       P:0000C3 P:0000C3 0C1951            INSERT  #$008008,Y0,B
                            008008
430       P:0000C5 P:0000C5 4EF000            MOVE                          Y:RDFO,Y0   ; Read the LS byte
                            FFFFF1
431       P:0000C7 P:0000C7 0C1951            INSERT  #$008000,Y0,B
                            008000
432       P:0000C9 P:0000C9 000000            NOP
433       P:0000CA P:0000CA 516300            MOVE              B0,X:(R3)               ; Put the word into COM_BUF
434       P:0000CB P:0000CB 0A0000            BCLR    #ST_RCV,X:<STATUS                 ; Its a command from the host computer
435       P:0000CC P:0000CC 000000  SET_CC    NOP
436       P:0000CD P:0000CD 0AF960            BSET    #0,SR                             ; Valid word => SR carry bit = 1
437       P:0000CE P:0000CE 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
438       P:0000D0 P:0000D0 00000C            RTS
439       P:0000D1 P:0000D1 0AF940  CLR_CC    BCLR    #0,SR                             ; Not valid word => SR carry bit = 0
440       P:0000D2 P:0000D2 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
441       P:0000D4 P:0000D4 00000C            RTS
442    
443                                 ; Test the SCI (= synchronous communications interface) for new words
444       P:0000D5 P:0000D5 44F000  CHK_SCI   MOVE              X:(SCI_TABLE+33),X0
                            000421
445       P:0000D7 P:0000D7 228E00            MOVE              R4,A
446       P:0000D8 P:0000D8 209000            MOVE              X0,R0
447       P:0000D9 P:0000D9 200045            CMP     X0,A
448       P:0000DA P:0000DA 0EA0D1            JEQ     <CLR_CC                           ; There is no new SCI word
449       P:0000DB P:0000DB 44D800            MOVE              X:(R0)+,X0
450       P:0000DC P:0000DC 446300            MOVE              X0,X:(R3)
451       P:0000DD P:0000DD 220E00            MOVE              R0,A
452       P:0000DE P:0000DE 0140C5            CMP     #(SCI_TABLE+32),A                 ; Wrap it around the circular
                            000420
453       P:0000E0 P:0000E0 0EA0E4            JEQ     <INIT_PROCESSED_SCI               ;   buffer boundary
454       P:0000E1 P:0000E1 547000            MOVE              A1,X:(SCI_TABLE+33)
                            000421
455       P:0000E3 P:0000E3 0C00E9            JMP     <SCI_END
456                                 INIT_PROCESSED_SCI
457       P:0000E4 P:0000E4 56F400            MOVE              #SCI_TABLE,A
                            000400
458       P:0000E6 P:0000E6 000000            NOP
459       P:0000E7 P:0000E7 567000            MOVE              A,X:(SCI_TABLE+33)
                            000421
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 9



460       P:0000E9 P:0000E9 0A0020  SCI_END   BSET    #ST_RCV,X:<STATUS                 ; Its a utility board (SCI) word
461       P:0000EA P:0000EA 0C00CC            JMP     <SET_CC
462    
463                                 ; Transmit the word in B1 to the host computer over the fiber optic data link
464                                 XMT_WRD
465       P:0000EB P:0000EB 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
466       P:0000ED P:0000ED 60F400            MOVE              #FO_HDR+1,R0
                            000002
467       P:0000EF P:0000EF 060380            DO      #3,XMT_WRD1
                            0000F3
468       P:0000F1 P:0000F1 0C1D91            ASL     #8,B,B
469       P:0000F2 P:0000F2 000000            NOP
470       P:0000F3 P:0000F3 535800            MOVE              B2,X:(R0)+
471                                 XMT_WRD1
472       P:0000F4 P:0000F4 60F400            MOVE              #FO_HDR,R0
                            000001
473       P:0000F6 P:0000F6 61F400            MOVE              #WRFO,R1
                            FFFFF2
474       P:0000F8 P:0000F8 060480            DO      #4,XMT_WRD2
                            0000FB
475       P:0000FA P:0000FA 46D800            MOVE              X:(R0)+,Y0              ; Should be MOVEP  X:(R0)+,Y:WRFO
476       P:0000FB P:0000FB 4E6100            MOVE                          Y0,Y:(R1)
477                                 XMT_WRD2
478       P:0000FC P:0000FC 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
479       P:0000FE P:0000FE 00000C            RTS
480    
481                                 ; Check the command or reply header in X:(R3) for self-consistency
482       P:0000FF P:0000FF 46E300  CHK_HDR   MOVE              X:(R3),Y0
483       P:000100 P:000100 579600            MOVE              X:<MASK1,B              ; Test for S.LE.3 and D.LE.3 and N.LE.7
484       P:000101 P:000101 20005E            AND     Y0,B
485       P:000102 P:000102 0E208D            JNE     <ERROR                            ; Test failed
486       P:000103 P:000103 579700            MOVE              X:<MASK2,B              ; Test for either S.NE.0 or D.NE.0
487       P:000104 P:000104 20005E            AND     Y0,B
488       P:000105 P:000105 0EA08D            JEQ     <ERROR                            ; Test failed
489       P:000106 P:000106 579500            MOVE              X:<SEVEN,B
490       P:000107 P:000107 20005E            AND     Y0,B                              ; Extract NWORDS, must be > 0
491       P:000108 P:000108 0EA08D            JEQ     <ERROR
492       P:000109 P:000109 44E300            MOVE              X:(R3),X0
493       P:00010A P:00010A 440500            MOVE              X0,X:<HEADER            ; Its a correct header
494       P:00010B P:00010B 550600            MOVE              B1,X:<NWORDS            ; Number of words in the command
495       P:00010C P:00010C 0C005E            JMP     <PR_RCV
496    
497                                 ;  *****************  Boot Commands  *******************
498    
499                                 ; Test Data Link - simply return value received after 'TDL'
500       P:00010D P:00010D 47DB00  TDL       MOVE              X:(R3)+,Y1              ; Get the data value
501       P:00010E P:00010E 0C0090            JMP     <FINISH1                          ; Return from executing TDL command
502    
503                                 ; Read DSP or EEPROM memory ('RDM' address): read memory, reply with value
504       P:00010F P:00010F 47DB00  RDMEM     MOVE              X:(R3)+,Y1
505       P:000110 P:000110 20EF00            MOVE              Y1,B
506       P:000111 P:000111 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
507       P:000113 P:000113 21B000            MOVE              B1,R0                   ; Need the address in an address register
508       P:000114 P:000114 20EF00            MOVE              Y1,B
509       P:000115 P:000115 000000            NOP
510       P:000116 P:000116 0ACF14            JCLR    #20,B,RDX                         ; Test address bit for Program memory
                            00011A
511       P:000118 P:000118 07E087            MOVE              P:(R0),Y1               ; Read from Program Memory
512       P:000119 P:000119 0C0090            JMP     <FINISH1                          ; Send out a header with the value
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 10



513       P:00011A P:00011A 0ACF15  RDX       JCLR    #21,B,RDY                         ; Test address bit for X: memory
                            00011E
514       P:00011C P:00011C 47E000            MOVE              X:(R0),Y1               ; Write to X data memory
515       P:00011D P:00011D 0C0090            JMP     <FINISH1                          ; Send out a header with the value
516       P:00011E P:00011E 0ACF16  RDY       JCLR    #22,B,RDR                         ; Test address bit for Y: memory
                            000122
517       P:000120 P:000120 4FE000            MOVE                          Y:(R0),Y1   ; Read from Y data memory
518       P:000121 P:000121 0C0090            JMP     <FINISH1                          ; Send out a header with the value
519       P:000122 P:000122 0ACF17  RDR       JCLR    #23,B,ERROR                       ; Test address bit for read from EEPROM memo
ry
                            00008D
520       P:000124 P:000124 479400            MOVE              X:<THREE,Y1             ; Convert to word address to a byte address
521       P:000125 P:000125 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
522       P:000126 P:000126 2000B8            MPY     Y0,Y1,B                           ; Multiply
523       P:000127 P:000127 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
524       P:000128 P:000128 213000            MOVE              B0,R0                   ; Need to address memory
525       P:000129 P:000129 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
526       P:00012A P:00012A 0D0178            JSR     <RD_WORD                          ; Read word from EEPROM
527       P:00012B P:00012B 21A700            MOVE              B1,Y1                   ; FINISH1 transmits Y1 as its reply
528       P:00012C P:00012C 0C0090            JMP     <FINISH1
529    
530                                 ; Program WRMEM ('WRM' address datum): write to memory, reply 'DON'.
531       P:00012D P:00012D 47DB00  WRMEM     MOVE              X:(R3)+,Y1              ; Get the address to be written to
532       P:00012E P:00012E 20EF00            MOVE              Y1,B
533       P:00012F P:00012F 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
534       P:000131 P:000131 21B000            MOVE              B1,R0                   ; Need the address in an address register
535       P:000132 P:000132 20EF00            MOVE              Y1,B
536       P:000133 P:000133 46DB00            MOVE              X:(R3)+,Y0              ; Get datum into Y0 so MOVE works easily
537       P:000134 P:000134 0ACF14            JCLR    #20,B,WRX                         ; Test address bit for Program memory
                            000138
538       P:000136 P:000136 076086            MOVE              Y0,P:(R0)               ; Write to Program memory
539       P:000137 P:000137 0C008F            JMP     <FINISH
540       P:000138 P:000138 0ACF15  WRX       JCLR    #21,B,WRY                         ; Test address bit for X: memory
                            00013C
541       P:00013A P:00013A 466000            MOVE              Y0,X:(R0)               ; Write to X: memory
542       P:00013B P:00013B 0C008F            JMP     <FINISH
543       P:00013C P:00013C 0ACF16  WRY       JCLR    #22,B,WRR                         ; Test address bit for Y: memory
                            000140
544       P:00013E P:00013E 4E6000            MOVE                          Y0,Y:(R0)   ; Write to Y: memory
545       P:00013F P:00013F 0C008F            JMP     <FINISH
546       P:000140 P:000140 0ACF17  WRR       JCLR    #23,B,ERROR                       ; Test address bit for write to EEPROM
                            00008D
547       P:000142 P:000142 013D02            BCLR    #WRENA,X:PDRC                     ; WR_ENA* = 0 to enable EEPROM writing
548       P:000143 P:000143 460E00            MOVE              Y0,X:<SV_A1             ; Save the datum to be written
549       P:000144 P:000144 479400            MOVE              X:<THREE,Y1             ; Convert word address to a byte address
550       P:000145 P:000145 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
551       P:000146 P:000146 2000B8            MPY     Y1,Y0,B                           ; Multiply
552       P:000147 P:000147 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
553       P:000148 P:000148 213000            MOVE              B0,R0                   ; Need to address memory
554       P:000149 P:000149 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
555       P:00014A P:00014A 558E00            MOVE              X:<SV_A1,B1             ; Get the datum to be written
556       P:00014B P:00014B 060380            DO      #3,L1WRR                          ; Loop over three bytes of the word
                            000154
557       P:00014D P:00014D 07588D            MOVE              B1,P:(R0)+              ; Write each EEPROM byte
558       P:00014E P:00014E 0C1C91            ASR     #8,B,B
559       P:00014F P:00014F 469E00            MOVE              X:<C100K,Y0             ; Move right one byte, enter delay = 1 msec
560       P:000150 P:000150 06C600            DO      Y0,L2WRR                          ; Delay by 12 milliseconds for EEPROM write
                            000153
561       P:000152 P:000152 060CA0            REP     #12                               ; Assume 100 MHz DSP56303
562       P:000153 P:000153 000000            NOP
563                                 L2WRR
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 11



564       P:000154 P:000154 000000            NOP                                       ; DO loop nesting restriction
565                                 L1WRR
566       P:000155 P:000155 013D22            BSET    #WRENA,X:PDRC                     ; WR_ENA* = 1 to disable EEPROM writing
567       P:000156 P:000156 0C008F            JMP     <FINISH
568    
569                                 ; Load application code from P: memory into its proper locations
570       P:000157 P:000157 47DB00  LDAPPL    MOVE              X:(R3)+,Y1              ; Application number, not used yet
571       P:000158 P:000158 0D015A            JSR     <LOAD_APPLICATION
572       P:000159 P:000159 0C008F            JMP     <FINISH
573    
574                                 LOAD_APPLICATION
575       P:00015A P:00015A 60F400            MOVE              #$8000,R0               ; Starting EEPROM address
                            008000
576       P:00015C P:00015C 0D0178            JSR     <RD_WORD                          ; Number of words in boot code
577       P:00015D P:00015D 21A600            MOVE              B1,Y0
578       P:00015E P:00015E 479400            MOVE              X:<THREE,Y1
579       P:00015F P:00015F 2000B8            MPY     Y0,Y1,B
580       P:000160 P:000160 20002A            ASR     B
581       P:000161 P:000161 213000            MOVE              B0,R0                   ; EEPROM address of start of P: application
582       P:000162 P:000162 0AD06F            BSET    #15,R0                            ; To access EEPROM
583       P:000163 P:000163 0D0178            JSR     <RD_WORD                          ; Read number of words in application P:
584       P:000164 P:000164 61F400            MOVE              #(X_BOOT_START+1),R1    ; End of boot P: code that needs keeping
                            00022B
585       P:000166 P:000166 06CD00            DO      B1,RD_APPL_P
                            000169
586       P:000168 P:000168 0D0178            JSR     <RD_WORD
587       P:000169 P:000169 07598D            MOVE              B1,P:(R1)+
588                                 RD_APPL_P
589       P:00016A P:00016A 0D0178            JSR     <RD_WORD                          ; Read number of words in application X:
590       P:00016B P:00016B 61F400            MOVE              #END_COMMAND_TABLE,R1
                            000036
591       P:00016D P:00016D 06CD00            DO      B1,RD_APPL_X
                            000170
592       P:00016F P:00016F 0D0178            JSR     <RD_WORD
593       P:000170 P:000170 555900            MOVE              B1,X:(R1)+
594                                 RD_APPL_X
595       P:000171 P:000171 0D0178            JSR     <RD_WORD                          ; Read number of words in application Y:
596       P:000172 P:000172 310100            MOVE              #1,R1                   ; There is no Y: memory in the boot code
597       P:000173 P:000173 06CD00            DO      B1,RD_APPL_Y
                            000176
598       P:000175 P:000175 0D0178            JSR     <RD_WORD
599       P:000176 P:000176 5D5900            MOVE                          B1,Y:(R1)+
600                                 RD_APPL_Y
601       P:000177 P:000177 00000C            RTS
602    
603                                 ; Read one word from EEPROM location R0 into accumulator B1
604       P:000178 P:000178 060380  RD_WORD   DO      #3,L_RDBYTE
                            00017B
605       P:00017A P:00017A 07D88B            MOVE              P:(R0)+,B2
606       P:00017B P:00017B 0C1C91            ASR     #8,B,B
607                                 L_RDBYTE
608       P:00017C P:00017C 00000C            RTS
609    
610                                 ; Come to here on a 'STP' command so 'DON' can be sent
611                                 STOP_IDLE_CLOCKING
612       P:00017D P:00017D 305A00            MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
613       P:00017E P:00017E 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
614       P:00017F P:00017F 0A0002            BCLR    #IDLMODE,X:<STATUS                ; Don't idle after readout
615       P:000180 P:000180 0C008F            JMP     <FINISH
616    
617                                 ; Routines executed after the DSP boots and initializes
618       P:000181 P:000181 305A00  STARTUP   MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 12



619       P:000182 P:000182 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
620       P:000183 P:000183 44F400            MOVE              #50000,X0               ; Delay by 500 milliseconds
                            00C350
621       P:000185 P:000185 06C400            DO      X0,L_DELAY
                            000188
622       P:000187 P:000187 06E8A3            REP     #1000
623       P:000188 P:000188 000000            NOP
624                                 L_DELAY
625       P:000189 P:000189 57F400            MOVE              #$020002,B              ; Normal reply after booting is 'SYR'
                            020002
626       P:00018B P:00018B 0D00EB            JSR     <XMT_WRD
627       P:00018C P:00018C 57F400            MOVE              #'SYR',B
                            535952
628       P:00018E P:00018E 0D00EB            JSR     <XMT_WRD
629    
630       P:00018F P:00018F 0C0054            JMP     <START                            ; Start normal command processing
631    
632                                 ; *******************  DSP  INITIALIZATION  CODE  **********************
633                                 ; This code initializes the DSP right after booting, and is overwritten
634                                 ;   by application code
635       P:000190 P:000190 08F4BD  INIT      MOVEP             #PLL_INIT,X:PCTL        ; Initialize PLL to 100 MHz
                            050003
636       P:000192 P:000192 000000            NOP
637    
638                                 ; Set operation mode register OMR to normal expanded
639       P:000193 P:000193 0500BA            MOVEC             #$0000,OMR              ; Operating Mode Register = Normal Expanded
640       P:000194 P:000194 0500BB            MOVEC             #0,SP                   ; Reset the Stack Pointer SP
641    
642                                 ; Program the AA = address attribute pins
643       P:000195 P:000195 08F4B9            MOVEP             #$FFFC21,X:AAR0         ; Y = $FFF000 to $FFFFFF asserts commands
                            FFFC21
644       P:000197 P:000197 08F4B8            MOVEP             #$008909,X:AAR1         ; P = $008000 to $00FFFF accesses the EEPROM
                            008909
645       P:000199 P:000199 08F4B7            MOVEP             #$010C11,X:AAR2         ; X = $010000 to $010FFF reads A/D values
                            010C11
646       P:00019B P:00019B 08F4B6            MOVEP             #$080621,X:AAR3         ; Y = $080000 to $0BFFFF R/W from SRAM
                            080621
647    
648       P:00019D P:00019D 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Enable clearing of DACs
649       P:00019E P:00019E 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable clock and DAC output switches
650       P:00019F P:00019F 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Execute these two operations
                            00000F
651    
652                                 ; Program the DRAM memory access and addressing
653       P:0001A1 P:0001A1 08F4BB            MOVEP             #$028FE1,X:BCR          ; Bus Control Register
                            028FE1
654    
655                                 ; Program the Host port B for parallel I/O
656       P:0001A3 P:0001A3 08F484            MOVEP             #>1,X:HPCR              ; All pins enabled as GPIO
                            000001
657       P:0001A5 P:0001A5 08F489            MOVEP             #$810C,X:HDR
                            00810C
658       P:0001A7 P:0001A7 08F488            MOVEP             #$B10E,X:HDDR           ; Data Direction Register
                            00B10E
659                                                                                     ;  (1 for Output, 0 for Input)
660    
661                                 ; Port B conversion from software bits to schematic labels
662                                 ;       PB0 = PWROK             PB08 = PRSFIFO*
663                                 ;       PB1 = LED1              PB09 = EF*
664                                 ;       PB2 = LVEN              PB10 = EXT-IN0
665                                 ;       PB3 = HVEN              PB11 = EXT-IN1
666                                 ;       PB4 = STATUS0           PB12 = EXT-OUT0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 13



667                                 ;       PB5 = STATUS1           PB13 = EXT-OUT1
668                                 ;       PB6 = STATUS2           PB14 = SSFHF*
669                                 ;       PB7 = STATUS3           PB15 = SELSCI
670    
671                                 ; Program the serial port ESSI0 = Port C for serial communication with
672                                 ;   the utility board
673       P:0001A9 P:0001A9 07F43F            MOVEP             #>0,X:PCRC              ; Software reset of ESSI0
                            000000
674       P:0001AB P:0001AB 07F435            MOVEP             #$180809,X:CRA0         ; Divide 100 MHz by 20 to get 5.0 MHz
                            180809
675                                                                                     ; DC[4:0] = 0 for non-network operation
676                                                                                     ; WL0-WL2 = 3 for 24-bit data words
677                                                                                     ; SSC1 = 0 for SC1 not used
678       P:0001AD P:0001AD 07F436            MOVEP             #$020020,X:CRB0         ; SCKD = 1 for internally generated clock
                            020020
679                                                                                     ; SCD2 = 0 so frame sync SC2 is an output
680                                                                                     ; SHFD = 0 for MSB shifted first
681                                                                                     ; FSL = 0, frame sync length not used
682                                                                                     ; CKP = 0 for rising clock edge transitions
683                                                                                     ; SYN = 0 for asynchronous
684                                                                                     ; TE0 = 1 to enable transmitter #0
685                                                                                     ; MOD = 0 for normal, non-networked mode
686                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
687                                                                                     ; RE = 1 to enable receiver
688       P:0001AF P:0001AF 07F43F            MOVEP             #%111001,X:PCRC         ; Control Register (0 for GPIO, 1 for ESSI)
                            000039
689       P:0001B1 P:0001B1 07F43E            MOVEP             #%000110,X:PRRC         ; Data Direction Register (0 for In, 1 for O
ut)
                            000006
690       P:0001B3 P:0001B3 07F43D            MOVEP             #%000100,X:PDRC         ; Data Register - WR_ENA* = 1
                            000004
691    
692                                 ; Port C version = Analog boards
693                                 ;       MOVEP   #$000809,X:CRA0 ; Divide 100 MHz by 20 to get 5.0 MHz
694                                 ;       MOVEP   #$000030,X:CRB0 ; SCKD = 1 for internally generated clock
695                                 ;       MOVEP   #%100000,X:PCRC ; Control Register (0 for GPIO, 1 for ESSI)
696                                 ;       MOVEP   #%000100,X:PRRC ; Data Direction Register (0 for In, 1 for Out)
697                                 ;       MOVEP   #%000000,X:PDRC ; Data Register: 'not used' = 0 outputs
698    
699       P:0001B5 P:0001B5 07F43C            MOVEP             #0,X:TX00               ; Initialize the transmitter to zero
                            000000
700       P:0001B7 P:0001B7 000000            NOP
701       P:0001B8 P:0001B8 000000            NOP
702       P:0001B9 P:0001B9 013630            BSET    #TE,X:CRB0                        ; Enable the SSI transmitter
703    
704                                 ; Conversion from software bits to schematic labels for Port C
705                                 ;       PC0 = SC00 = UTL-T-SCK
706                                 ;       PC1 = SC01 = 2_XMT = SYNC on prototype
707                                 ;       PC2 = SC02 = WR_ENA*
708                                 ;       PC3 = SCK0 = TIM-U-SCK
709                                 ;       PC4 = SRD0 = UTL-T-STD
710                                 ;       PC5 = STD0 = TIM-U-STD
711    
712                                 ; Program the serial port ESSI1 = Port D for serial transmission to
713                                 ;   the analog boards and two parallel I/O input pins
714       P:0001BA P:0001BA 07F42F            MOVEP             #>0,X:PCRD              ; Software reset of ESSI0
                            000000
715       P:0001BC P:0001BC 07F425            MOVEP             #$000809,X:CRA1         ; Divide 100 MHz by 20 to get 5.0 MHz
                            000809
716                                                                                     ; DC[4:0] = 0
717                                                                                     ; WL[2:0] = ALC = 0 for 8-bit data words
718                                                                                     ; SSC1 = 0 for SC1 not used
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 14



719       P:0001BE P:0001BE 07F426            MOVEP             #$000030,X:CRB1         ; SCKD = 1 for internally generated clock
                            000030
720                                                                                     ; SCD2 = 1 so frame sync SC2 is an output
721                                                                                     ; SHFD = 0 for MSB shifted first
722                                                                                     ; CKP = 0 for rising clock edge transitions
723                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
724                                                                                     ; MOD = 0 so its not networked mode
725       P:0001C0 P:0001C0 07F42F            MOVEP             #%100000,X:PCRD         ; Control Register (0 for GPIO, 1 for ESSI)
                            000020
726                                                                                     ; PD3 = SCK1, PD5 = STD1 for ESSI
727       P:0001C2 P:0001C2 07F42E            MOVEP             #%000100,X:PRRD         ; Data Direction Register (0 for In, 1 for O
ut)
                            000004
728       P:0001C4 P:0001C4 07F42D            MOVEP             #%000100,X:PDRD         ; Data Register: 'not used' = 0 outputs
                            000004
729       P:0001C6 P:0001C6 07F42C            MOVEP             #0,X:TX10               ; Initialize the transmitter to zero
                            000000
730       P:0001C8 P:0001C8 000000            NOP
731       P:0001C9 P:0001C9 000000            NOP
732       P:0001CA P:0001CA 012630            BSET    #TE,X:CRB1                        ; Enable the SSI transmitter
733    
734                                 ; Conversion from software bits to schematic labels for Port D
735                                 ; PD0 = SC10 = 2_XMT_? input
736                                 ; PD1 = SC11 = SSFEF* input
737                                 ; PD2 = SC12 = PWR_EN
738                                 ; PD3 = SCK1 = TIM-A-SCK
739                                 ; PD4 = SRD1 = PWRRST
740                                 ; PD5 = STD1 = TIM-A-STD
741    
742                                 ; Program the SCI port to communicate with the utility board
743       P:0001CB P:0001CB 07F41C            MOVEP             #$0B04,X:SCR            ; SCI programming: 11-bit asynchronous
                            000B04
744                                                                                     ;   protocol (1 start, 8 data, 1 even parity
,
745                                                                                     ;   1 stop); LSB before MSB; enable receiver
746                                                                                     ;   and its interrupts; transmitter interrup
ts
747                                                                                     ;   disabled.
748       P:0001CD P:0001CD 07F41B            MOVEP             #$0003,X:SCCR           ; SCI clock: utility board data rate =
                            000003
749                                                                                     ;   (390,625 kbits/sec); internal clock.
750       P:0001CF P:0001CF 07F41F            MOVEP             #%011,X:PCRE            ; Port Control Register = RXD, TXD enabled
                            000003
751       P:0001D1 P:0001D1 07F41E            MOVEP             #%000,X:PRRE            ; Port Direction Register (0 = Input)
                            000000
752    
753                                 ;       PE0 = RXD
754                                 ;       PE1 = TXD
755                                 ;       PE2 = SCLK
756    
757                                 ; Program one of the three timers as an exposure timer
758       P:0001D3 P:0001D3 07F403            MOVEP             #$C34F,X:TPLR           ; Prescaler to generate millisecond timer,
                            00C34F
759                                                                                     ;  counting from the system clock / 2 = 50 M
Hz
760       P:0001D5 P:0001D5 07F40F            MOVEP             #$208200,X:TCSR0        ; Clear timer complete bit and enable presca
ler
                            208200
761       P:0001D7 P:0001D7 07F40E            MOVEP             #0,X:TLR0               ; Timer load register
                            000000
762    
763                                 ; Enable interrupts for the SCI port only
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 15



764       P:0001D9 P:0001D9 08F4BF            MOVEP             #$000000,X:IPRC         ; No interrupts allowed
                            000000
765       P:0001DB P:0001DB 08F4BE            MOVEP             #>$80,X:IPRP            ; Enable SCI interrupt only, IPR = 1
                            000080
766       P:0001DD P:0001DD 00FCB8            ANDI    #$FC,MR                           ; Unmask all interrupt levels
767    
768                                 ; Initialize the fiber optic serial receiver circuitry
769       P:0001DE P:0001DE 061480            DO      #20,L_FO_INIT
                            0001E3
770       P:0001E0 P:0001E0 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
771       P:0001E2 P:0001E2 0605A0            REP     #5
772       P:0001E3 P:0001E3 000000            NOP
773                                 L_FO_INIT
774    
775                                 ; Pulse PRSFIFO* low to revive the CMDRST* instruction and reset the FIFO
776       P:0001E4 P:0001E4 44F400            MOVE              #1000000,X0             ; Delay by 10 milliseconds
                            0F4240
777       P:0001E6 P:0001E6 06C400            DO      X0,*+3
                            0001E8
778       P:0001E8 P:0001E8 000000            NOP
779       P:0001E9 P:0001E9 0A8908            BCLR    #8,X:HDR
780       P:0001EA P:0001EA 0614A0            REP     #20
781       P:0001EB P:0001EB 000000            NOP
782       P:0001EC P:0001EC 0A8928            BSET    #8,X:HDR
783    
784                                 ; Reset the utility board
785       P:0001ED P:0001ED 0A0F05            BCLR    #5,X:<LATCH
786       P:0001EE P:0001EE 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
787       P:0001F0 P:0001F0 06C8A0            REP     #200                              ; Delay by RESET* low time
788       P:0001F1 P:0001F1 000000            NOP
789       P:0001F2 P:0001F2 0A0F25            BSET    #5,X:<LATCH
790       P:0001F3 P:0001F3 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
791       P:0001F5 P:0001F5 56F400            MOVE              #200000,A               ; Delay 2 msec for utility boot
                            030D40
792       P:0001F7 P:0001F7 06CE00            DO      A,*+3
                            0001F9
793       P:0001F9 P:0001F9 000000            NOP
794    
795                                 ; Put all the analog switch inputs to low so they draw minimum current
796       P:0001FA P:0001FA 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
797       P:0001FB P:0001FB 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
798       P:0001FD P:0001FD 20001B            CLR     B
799       P:0001FE P:0001FE 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
800       P:0001FF P:0001FF 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
801       P:000201 P:000201 060F80            DO      #15,L_ANALOG                      ; Fifteen video processor boards maximum
                            000209
802       P:000203 P:000203 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
803       P:000204 P:000204 200040            ADD     X0,A
804       P:000205 P:000205 5F7000            MOVE                          B,Y:WRSS    ; This is for the fast analog switches
                            FFFFF3
805       P:000207 P:000207 0620A3            REP     #800                              ; Delay for the serial data transmission
806       P:000208 P:000208 000000            NOP
807       P:000209 P:000209 200068            ADD     X1,B                              ; Increment the video and clock driver numbe
rs
808                                 L_ANALOG
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 16



809       P:00020A P:00020A 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
810       P:00020B P:00020B 0C0223            JMP     <SKIP
811    
812                                 ; Transmit contents of accumulator A1 over the synchronous serial transmitter
813                                 XMIT_A_WORD
814       P:00020C P:00020C 07F42C            MOVEP             #0,X:TX10               ; This helps, don't know why
                            000000
815       P:00020E P:00020E 547000            MOVE              A1,X:SV_A1
                            00000E
816       P:000210 P:000210 000000            NOP
817       P:000211 P:000211 01A786            JCLR    #TDE,X:SSISR1,*                   ; Start bit
                            000211
818       P:000213 P:000213 07F42C            MOVEP             #$010000,X:TX10
                            010000
819       P:000215 P:000215 060380            DO      #3,L_X
                            00021B
820       P:000217 P:000217 01A786            JCLR    #TDE,X:SSISR1,*                   ; Three data bytes
                            000217
821       P:000219 P:000219 04CCCC            MOVEP             A1,X:TX10
822       P:00021A P:00021A 0C1E90            LSL     #8,A
823       P:00021B P:00021B 000000            NOP
824                                 L_X
825       P:00021C P:00021C 01A786            JCLR    #TDE,X:SSISR1,*                   ; Zeroes to bring transmitter low
                            00021C
826       P:00021E P:00021E 07F42C            MOVEP             #0,X:TX10
                            000000
827       P:000220 P:000220 54F000            MOVE              X:SV_A1,A1
                            00000E
828       P:000222 P:000222 00000C            RTS
829    
830                                 SKIP
831    
832                                 ; Set up the circular SCI buffer, 32 words in size
833       P:000223 P:000223 64F400            MOVE              #SCI_TABLE,R4
                            000400
834       P:000225 P:000225 051FA4            MOVE              #31,M4
835       P:000226 P:000226 647000            MOVE              R4,X:(SCI_TABLE+33)
                            000421
836    
837                                           IF      @SCP("HOST","ROM")
845                                           ENDIF
846    
847       P:000228 P:000228 44F400            MOVE              #>$AC,X0
                            0000AC
848       P:00022A P:00022A 440100            MOVE              X0,X:<FO_HDR
849    
850       P:00022B P:00022B 0C0181            JMP     <STARTUP
851    
852                                 ;  ****************  X: Memory tables  ********************
853    
854                                 ; Define the address in P: space where the table of constants begins
855    
856                                  X_BOOT_START
857       00022A                              EQU     @LCV(L)-2
858    
859                                           IF      @SCP("HOST","ROM")
861                                           ENDIF
862                                           IF      @SCP("HOST","HOST")
863       X:000000 X:000000                   ORG     X:0,X:0
864                                           ENDIF
865    
866                                 ; Special storage area - initialization constants and scratch space
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 17



867       X:000000 X:000000         STATUS    DC      4                                 ; Controller status bits
868    
869       000001                    FO_HDR    EQU     STATUS+1                          ; Fiber optic write bytes
870       000005                    HEADER    EQU     FO_HDR+4                          ; Command header
871       000006                    NWORDS    EQU     HEADER+1                          ; Number of words in the command
872       000007                    COM_BUF   EQU     NWORDS+1                          ; Command buffer
873       00000E                    SV_A1     EQU     COM_BUF+7                         ; Save accumulator A1
874    
875                                           IF      @SCP("HOST","ROM")
880                                           ENDIF
881    
882                                           IF      @SCP("HOST","HOST")
883       X:00000F X:00000F                   ORG     X:$F,X:$F
884                                           ENDIF
885    
886                                 ; Parameter table in P: space to be copied into X: space during
887                                 ;   initialization, and is copied from ROM by the DSP boot
888       X:00000F X:00000F         LATCH     DC      $3A                               ; Starting value in latch chip U25
889                                  EXPOSURE_TIME
890       X:000010 X:000010                   DC      0                                 ; Exposure time in milliseconds
891                                  ELAPSED_TIME
892       X:000011 X:000011                   DC      0                                 ; Time elapsed so far in the exposure
893       X:000012 X:000012         ONE       DC      1                                 ; One
894       X:000013 X:000013         TWO       DC      2                                 ; Two
895       X:000014 X:000014         THREE     DC      3                                 ; Three
896       X:000015 X:000015         SEVEN     DC      7                                 ; Seven
897       X:000016 X:000016         MASK1     DC      $FCFCF8                           ; Mask for checking header
898       X:000017 X:000017         MASK2     DC      $030300                           ; Mask for checking header
899       X:000018 X:000018         DONE      DC      'DON'                             ; Standard reply
900       X:000019 X:000019         SBRD      DC      $020000                           ; Source Identification number
901       X:00001A X:00001A         TIM_DRB   DC      $000200                           ; Destination = timing board number
902       X:00001B X:00001B         DMASK     DC      $00FF00                           ; Mask to get destination board number
903       X:00001C X:00001C         SMASK     DC      $FF0000                           ; Mask to get source board number
904       X:00001D X:00001D         ERR       DC      'ERR'                             ; An error occurred
905       X:00001E X:00001E         C100K     DC      100000                            ; Delay for WRROM = 1 millisec
906       X:00001F X:00001F         IDL_ADR   DC      TST_RCV                           ; Address of idling routine
907       X:000020 X:000020         EXP_ADR   DC      0                                 ; Jump to this address during exposures
908    
909                                 ; Places for saving register values
910       X:000021 X:000021         SAVE_SR   DC      0                                 ; Status Register
911       X:000022 X:000022         SAVE_X1   DC      0
912       X:000023 X:000023         SAVE_A1   DC      0
913       X:000024 X:000024         SAVE_R0   DC      0
914       X:000025 X:000025         RCV_ERR   DC      0
915       X:000026 X:000026         SCI_A1    DC      0                                 ; Contents of accumulator A1 in RCV ISR
916       X:000027 X:000027         SCI_R0    DC      SRXL
917    
918                                 ; Command table
919       000028                    COM_TBL_R EQU     @LCV(R)
920       X:000028 X:000028         COM_TBL   DC      'TDL',TDL                         ; Test Data Link
921       X:00002A X:00002A                   DC      'RDM',RDMEM                       ; Read from DSP or EEPROM memory
922       X:00002C X:00002C                   DC      'WRM',WRMEM                       ; Write to DSP memory
923       X:00002E X:00002E                   DC      'LDA',LDAPPL                      ; Load application from EEPROM to DSP
924       X:000030 X:000030                   DC      'STP',STOP_IDLE_CLOCKING
925       X:000032 X:000032                   DC      'DON',START                       ; Nothing special
926       X:000034 X:000034                   DC      'ERR',START                       ; Nothing special
927    
928                                  END_COMMAND_TABLE
929       000036                              EQU     @LCV(R)
930    
931                                 ; The table at SCI_TABLE is for words received from the utility board, written by
932                                 ;   the interrupt service routine SCI_RCV. Note that it is 32 words long,
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timboot.asm  Page 18



933                                 ;   hard coded, and the 33rd location contains the pointer to words that have
934                                 ;   been processed by moving them from the SCI_TABLE to the COM_BUF.
935    
936                                           IF      @SCP("HOST","ROM")
938                                           ENDIF
939    
940       000036                    END_ADR   EQU     @LCV(L)                           ; End address of P: code written to ROM
941    
942       P:00022C P:00022C                   ORG     P:,P:
943    
944       108015                    CC        EQU     ARC22+ARC32+ARC46+CONT_RD
945    
946                                 ; Put number of words of application in P: for loading application from EEPROM
947       P:00022C P:00022C                   DC      TIMBOOT_X_MEMORY-@LCV(L)-1
948    
949                                 ; Define CLOCK as a macro to produce in-line code to reduce execution time
950                                 CLOCK     MACRO
951  m                                        JCLR    #SSFHF,X:HDR,*                    ; Don't overfill the WRSS FIFO
952  m                                        REP     Y:(R0)+                           ; Repeat
953  m                                        MOVEP   Y:(R0)+,Y:WRSS                    ; Write the waveform to the FIFO
954  m                                        ENDM
955    
956                                 ; Continuously reset and read array, checking for commands every four rows
957                                 CONT_RST
958       P:00022D P:00022D 60F400            MOVE              #FRAME_RESET,R0
                            000016
959                                           CLOCK
963       P:000233 P:000233 60F400            MOVE              #FRAME_RESET,R0
                            000016
964                                           CLOCK
968       P:000239 P:000239 60F400            MOVE              #FRAME_RESET,R0
                            000016
969                                           CLOCK
973       P:00023F P:00023F 60F400            MOVE              #FRAME_RESET,R0
                            000016
974                                           CLOCK
978       P:000245 P:000245 068080            DO      #128,L_RESET
                            00026C
979       P:000247 P:000247 60F400            MOVE              #CLOCK_ROW_1,R0
                            00002B
980                                           CLOCK
984       P:00024D P:00024D 0D026E            JSR     <CLK_COL
985       P:00024E P:00024E 60F400            MOVE              #CLOCK_ROW_2,R0
                            000031
986                                           CLOCK
990       P:000254 P:000254 0D026E            JSR     <CLK_COL
991       P:000255 P:000255 60F400            MOVE              #CLOCK_ROW_3,R0
                            000037
992                                           CLOCK
996       P:00025B P:00025B 0D026E            JSR     <CLK_COL
997       P:00025C P:00025C 60F400            MOVE              #CLOCK_ROW_4,R0
                            00003D
998                                           CLOCK
1002      P:000262 P:000262 0D026E            JSR     <CLK_COL
1003      P:000263 P:000263 44F400            MOVE              #(CLK2+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR),X0
                            00207F
1004      P:000265 P:000265 4C7000            MOVE                          X0,Y:WRSS
                            FFFFF3
1005   
1006      P:000267 P:000267 330700            MOVE              #COM_BUF,R3
1007      P:000268 P:000268 0D00A5            JSR     <GET_RCV                          ; Look for a new command every 4 rows
1008      P:000269 P:000269 0E026C            JCC     <NO_COM                           ; If none, then stay here
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 19



1009      P:00026A P:00026A 00008C            ENDDO
1010      P:00026B P:00026B 0C005D            JMP     <PRC_RCV
1011      P:00026C P:00026C 000000  NO_COM    NOP
1012                                L_RESET
1013      P:00026D P:00026D 0C022D            JMP     <CONT_RST
1014   
1015                                ; Simple clocking routine for resetting and clearing
1016      P:00026E P:00026E 062080  CLK_COL   DO      #32,L_CLOCK
                            000275
1017      P:000270 P:000270 60F400            MOVE              #CLOCK_COLUMN,R0
                            0000B1
1018                                          CLOCK
1022                                L_CLOCK
1023      P:000276 P:000276 00000C            RTS
1024   
1025                                ;  ************************  Readout subroutines  ********************
1026                                ; Normal readout of the whole array
1027   
1028                                NORMAL_READOUT
1029                                ;       ;MOVE   #FRAME_RESET,R0
1030                                ;       ;CLOCK
1031                                ;       JCLR    #ST_CDS,X:STATUS,*+3
1032                                ;       JSR     <READOUT                ; Read the array
1033                                ;       JSR     <WAIT_TO_FINISH_CLOCKING
1034                                ;       MOVE    #L_EXP1,R7              ; Return address at end of exposure
1035                                ;       JMP     <EXPOSE                 ; Delay for specified exposure time
1036                                ;L_EXP1
1037                                ;       JSR     <READOUT
1038                                ;       JMP     <DONE_READOUT
1039   
1040   
1041                                RESET_ARRAY
1042      P:000277 P:000277 60F400            MOVE              #FRAME_RESET,R0
                            000016
1043      P:000279 P:000279 0D046B            JSR     <CLOCK
1044      P:00027A P:00027A 60F400            MOVE              #FRAME_RESET,R0
                            000016
1045      P:00027C P:00027C 0D046B            JSR     <CLOCK
1046      P:00027D P:00027D 60F400            MOVE              #FRAME_RESET,R0
                            000016
1047      P:00027F P:00027F 0D046B            JSR     <CLOCK
1048      P:000280 P:000280 60F400            MOVE              #FRAME_RESET,R0
                            000016
1049      P:000282 P:000282 0D046B            JSR     <CLOCK
1050      P:000283 P:000283 00000C            RTS
1051   
1052                                ; Now start reading out the image with the frame initialization clocks first
1053                                READOUT
1054      P:000284 P:000284 0D045B            JSR     <PCI_READ_IMAGE
1055      P:000285 P:000285 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1056                                          CLOCK
1060      P:00028B P:00028B 068080            DO      #128,L_READOUT
                            0002A9
1061      P:00028D P:00028D 60F400            MOVE              #CLOCK_ROW_1,R0
                            00002B
1062                                          CLOCK
1066      P:000293 P:000293 0D0351            JSR     <CLK_COL_AND_READ
1067      P:000294 P:000294 60F400            MOVE              #CLOCK_ROW_2,R0
                            000031
1068                                          CLOCK
1072      P:00029A P:00029A 0D0351            JSR     <CLK_COL_AND_READ
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 20



1073      P:00029B P:00029B 60F400            MOVE              #CLOCK_ROW_3,R0
                            000037
1074                                          CLOCK
1078      P:0002A1 P:0002A1 0D0351            JSR     <CLK_COL_AND_READ
1079      P:0002A2 P:0002A2 60F400            MOVE              #CLOCK_ROW_4,R0
                            00003D
1080                                          CLOCK
1084      P:0002A8 P:0002A8 0D0351            JSR     <CLK_COL_AND_READ
1085      P:0002A9 P:0002A9 000000            NOP
1086                                L_READOUT
1087      P:0002AA P:0002AA 00000C            RTS
1088   
1089                                ; Row-by-row reset and readout, for high illumination levels
1090                                ROW_BY_ROW_RESET_READOUT
1091      P:0002AB P:0002AB 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1092      P:0002AC P:0002AC 0A0024            BSET    #ST_RDC,X:<STATUS                 ; Set status to reading out
1093      P:0002AD P:0002AD 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1094      P:0002AF P:0002AF 0D00EB            JSR     <XMT_WRD
1095      P:0002B0 P:0002B0 57F400            MOVE              #'RDA',B
                            524441
1096      P:0002B2 P:0002B2 0D00EB            JSR     <XMT_WRD
1097      P:0002B3 P:0002B3 57F400            MOVE              #1024,B                 ; Number of columns to read
                            000400
1098      P:0002B5 P:0002B5 0D00EB            JSR     <XMT_WRD
1099      P:0002B6 P:0002B6 0A00B1            JSET    #ST_CDS,X:STATUS,RRR_CDS
                            0002F5
1100   
1101                                ; Read out the image in single read mode, row-by-row reset
1102      P:0002B8 P:0002B8 57F400            MOVE              #1024,B                 ; Number of rows to read
                            000400
1103      P:0002BA P:0002BA 0D00EB            JSR     <XMT_WRD
1104      P:0002BB P:0002BB 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1105                                          CLOCK
1109      P:0002C1 P:0002C1 068080            DO      #128,L_RR_RESET_READOUT
                            0002F3
1110      P:0002C3 P:0002C3 60F400            MOVE              #RESET_ROW_12,R0
                            0000A3
1111                                          CLOCK
1115      P:0002C9 P:0002C9 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1116      P:0002CA P:0002CA 67F400            MOVE              #L_RR12,R7
                            0002CD
1117      P:0002CC P:0002CC 0C03AA            JMP     <EXPOSE
1118                                L_RR12
1119      P:0002CD P:0002CD 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            000043
1120                                          CLOCK
1124      P:0002D3 P:0002D3 0D0351            JSR     <CLK_COL_AND_READ
1125      P:0002D4 P:0002D4 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000049
1126                                          CLOCK
1130      P:0002DA P:0002DA 0D0351            JSR     <CLK_COL_AND_READ
1131   
1132      P:0002DB P:0002DB 60F400            MOVE              #RESET_ROW_34,R0
                            0000AA
1133                                          CLOCK
1137      P:0002E1 P:0002E1 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1138      P:0002E2 P:0002E2 67F400            MOVE              #L_RR34,R7
                            0002E5
1139      P:0002E4 P:0002E4 0C03AA            JMP     <EXPOSE
1140                                L_RR34
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 21



1141      P:0002E5 P:0002E5 60F400            MOVE              #CLOCK_RR_ROW_3,R0
                            00004F
1142                                          CLOCK
1146      P:0002EB P:0002EB 0D0351            JSR     <CLK_COL_AND_READ
1147      P:0002EC P:0002EC 60F400            MOVE              #CLOCK_RR_ROW_4,R0
                            000055
1148                                          CLOCK
1152      P:0002F2 P:0002F2 0D0351            JSR     <CLK_COL_AND_READ
1153      P:0002F3 P:0002F3 000000            NOP
1154                                L_RR_RESET_READOUT
1155   
1156      P:0002F4 P:0002F4 0C0341            JMP     <DONE_READOUT
1157   
1158                                ; Read out the image in CDS mode, row-by-row reset
1159      P:0002F5 P:0002F5 57F400  RRR_CDS   MOVE              #1024,B
                            000400
1160      P:0002F7 P:0002F7 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1161      P:0002F8 P:0002F8 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1162                                          CLOCK
1166      P:0002FE P:0002FE 068080            DO      #128,CDS_RR_RESET_READOUT
                            000340
1167      P:000300 P:000300 60F400            MOVE              #CLOCK_CDS_RESET_ROW_1,R0
                            00007F
1168                                          CLOCK
1172      P:000306 P:000306 0D0351            JSR     <CLK_COL_AND_READ
1173      P:000307 P:000307 60F400            MOVE              #CLOCK_CDS_RESET_ROW_2,R0
                            000088
1174                                          CLOCK
1178      P:00030D P:00030D 0D0351            JSR     <CLK_COL_AND_READ
1179      P:00030E P:00030E 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1180      P:00030F P:00030F 67F400            MOVE              #CDS_RR1,R7
                            000312
1181      P:000311 P:000311 0C03AA            JMP     <EXPOSE
1182                                CDS_RR1
1183      P:000312 P:000312 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            000043
1184                                          CLOCK
1188      P:000318 P:000318 0D0351            JSR     <CLK_COL_AND_READ
1189      P:000319 P:000319 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000049
1190                                          CLOCK
1194      P:00031F P:00031F 0D0351            JSR     <CLK_COL_AND_READ
1195   
1196      P:000320 P:000320 60F400            MOVE              #CLOCK_CDS_RESET_ROW_3,R0
                            000091
1197                                          CLOCK
1201      P:000326 P:000326 0D0351            JSR     <CLK_COL_AND_READ
1202      P:000327 P:000327 60F400            MOVE              #CLOCK_CDS_RESET_ROW_4,R0
                            00009A
1203                                          CLOCK
1207      P:00032D P:00032D 0D0351            JSR     <CLK_COL_AND_READ
1208      P:00032E P:00032E 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1209      P:00032F P:00032F 67F400            MOVE              #CDS_RR3,R7
                            000332
1210      P:000331 P:000331 0C03AA            JMP     <EXPOSE
1211                                CDS_RR3
1212      P:000332 P:000332 60F400            MOVE              #CLOCK_RR_ROW_3,R0
                            00004F
1213                                          CLOCK
1217      P:000338 P:000338 0D0351            JSR     <CLK_COL_AND_READ
1218      P:000339 P:000339 60F400            MOVE              #CLOCK_RR_ROW_4,R0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 22



                            000055
1219                                          CLOCK
1223      P:00033F P:00033F 0D0351            JSR     <CLK_COL_AND_READ
1224      P:000340 P:000340 000000            NOP
1225                                CDS_RR_RESET_READOUT
1226   
1227                                ; This is code for continuous readout - check if more frames are needed
1228                                DONE_READOUT
1229      P:000341 P:000341 5E8B00            MOVE                          Y:<N_FRAMES,A ; Are we in continuous readout mode?
1230      P:000342 P:000342 014185            CMP     #1,A
1231      P:000343 P:000343 0EF34A            JLE     <RDA_END
1232      P:000344 P:000344 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1233      P:000345 P:000345 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1234   
1235                                ; Check for a command once. Only the ABORT command should be issued.
1236      P:000346 P:000346 330700            MOVE              #COM_BUF,R3
1237      P:000347 P:000347 0D00A5            JSR     <GET_RCV                          ; Was a command received?
1238      P:000348 P:000348 0E03EC            JCC     <NEXT_FRAME                       ; If no, get the next frame
1239      P:000349 P:000349 0C005D            JMP     <PRC_RCV                          ; If yes, go process it
1240   
1241                                ; Restore the controller to non-image data transfer and idling if necessary
1242      P:00034A P:00034A 60F400  RDA_END   MOVE              #CONT_RST,R0            ; Process commands, don't idle,
                            00022D
1243      P:00034C P:00034C 601F00            MOVE              R0,X:<IDL_ADR           ;    during the exposure
1244      P:00034D P:00034D 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1245      P:00034E P:00034E 0C0054            JMP     <START
1246   
1247   
1248                                ;  ********  End of readout routines  ****************
1249   
1250                                ; Simple implementation
1251      P:00034F P:00034F 010F20  CONTRD    BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer
1252      P:000350 P:000350 0C0054            JMP     <START
1253   
1254                                CLK_COL_AND_READ
1255      P:000351 P:000351 60F400            MOVE              #RD_COL_PIPELINE,R0
                            0000B6
1256                                          CLOCK
1260      P:000357 P:000357 061F80            DO      #31,L_CLOCK_COLUMN_AND_READ
                            00035F
1261      P:000359 P:000359 60F400            MOVE              #RD_COLS,R0
                            000127
1262                                          CLOCK
1266      P:00035F P:00035F 000000            NOP
1267                                L_CLOCK_COLUMN_AND_READ
1268                                ;       MOVE    #LAST_8INROW,R0         ;  Clock last 8 pixels          ; commented by Luc so it
 reads properlyt the image
1269                                ;       CLOCK                                           ; no need of last8 in rows
1270      P:000360 P:000360 00000C            RTS
1271   
1272                                ; ******  Include many routines not directly needed for readout  *******
1273                                          INCLUDE "timIRmisc.asm"
1274                                ; Miscellaneous IR array control routines, common to all detector types
1275   
1276                                POWER_OFF
1277      P:000361 P:000361 0D038E            JSR     <CLEAR_SWITCHES_AND_DACS          ; Clear switches and DACs
1278      P:000362 P:000362 0A8922            BSET    #LVEN,X:HDR                       ; Turn off low +/- 6.5, +/- 16.5 supplies
1279      P:000363 P:000363 0A8923            BSET    #HVEN,X:HDR                       ; Turn off high +36 supply
1280      P:000364 P:000364 0C008F            JMP     <FINISH
1281   
1282                                ; Start power-on cycle
1283                                POWER_ON
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 23



1284      P:000365 P:000365 0D038E            JSR     <CLEAR_SWITCHES_AND_DACS          ; Clear all analog switches
1285      P:000366 P:000366 0D0370            JSR     <PON                              ; Turn on the power control board
1286      P:000367 P:000367 0A8980            JCLR    #PWROK,X:HDR,PWR_ERR              ; Test if the power turned on properly
                            00036D
1287      P:000369 P:000369 60F400            MOVE              #CONT_RST,R0            ; Put controller in continuous readout
                            00022D
1288      P:00036B P:00036B 601F00            MOVE              R0,X:<IDL_ADR           ;   state
1289      P:00036C P:00036C 0C008F            JMP     <FINISH
1290   
1291                                ; The power failed to turn on because of an error on the power control board
1292      P:00036D P:00036D 0A8922  PWR_ERR   BSET    #LVEN,X:HDR                       ; Turn off the low voltage emable line
1293      P:00036E P:00036E 0A8923            BSET    #HVEN,X:HDR                       ; Turn off the high voltage emable line
1294      P:00036F P:00036F 0C008D            JMP     <ERROR
1295   
1296                                ; Now ramp up the low voltages (+/- 6.5V, 16.5V) and delay them to turn on
1297      P:000370 P:000370 0A0F20  PON       BSET    #CDAC,X:<LATCH                    ; Disable clearing of DACs
1298      P:000371 P:000371 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1299   
1300                                ; Write all the bias voltages to the DACs
1301                                SET_BIASES
1302      P:000373 P:000373 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1303      P:000374 P:000374 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1304      P:000375 P:000375 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1305      P:000377 P:000377 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1306      P:000379 P:000379 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1307      P:00037A P:00037A 0A8923            BSET    #HVEN,X:HDR
1308      P:00037B P:00037B 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1309      P:00037D P:00037D 0D042F            JSR     <MILLISEC_DELAY
1310   
1311                                ; Write the values to the clock driver and DC bias supplies
1312      P:00037E P:00037E 60F400            MOVE              #BIASES,R0              ; Turn on the power before writing to
                            00023D
1313      P:000380 P:000380 0D047B            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1314      P:000381 P:000381 60F400            MOVE              #CLOCKS,R0              ;  power to be written to
                            00020B
1315      P:000383 P:000383 0D047B            JSR     <SET_DAC
1316      P:000384 P:000384 0D0476            JSR     <PAL_DLY
1317   
1318      P:000385 P:000385 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1319      P:000386 P:000386 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
1320      P:000388 P:000388 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1321      P:000389 P:000389 00000C            RTS
1322   
1323                                SET_BIAS_VOLTAGES
1324      P:00038A P:00038A 0D0373            JSR     <SET_BIASES
1325      P:00038B P:00038B 0C008F            JMP     <FINISH
1326   
1327      P:00038C P:00038C 0D038E  CLR_SWS   JSR     <CLEAR_SWITCHES_AND_DACS
1328      P:00038D P:00038D 0C008F            JMP     <FINISH
1329   
1330                                CLEAR_SWITCHES_AND_DACS
1331      P:00038E P:00038E 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Clear all the DACs
1332      P:00038F P:00038F 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable all the output switches
1333      P:000390 P:000390 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1334      P:000392 P:000392 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1335      P:000393 P:000393 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 24



                            0C3000
1336      P:000395 P:000395 20001B            CLR     B
1337      P:000396 P:000396 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
1338      P:000397 P:000397 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
1339      P:000399 P:000399 060F80            DO      #15,L_VIDEO                       ; Fifteen video processor boards maximum
                            0003A0
1340      P:00039B P:00039B 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1341      P:00039C P:00039C 200040            ADD     X0,A
1342      P:00039D P:00039D 5F7000            MOVE                          B,Y:WRSS
                            FFFFF3
1343      P:00039F P:00039F 0D0476            JSR     <PAL_DLY                          ; Delay for the serial data transmission
1344      P:0003A0 P:0003A0 200068            ADD     X1,B
1345                                L_VIDEO
1346      P:0003A1 P:0003A1 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1347      P:0003A2 P:0003A2 00000C            RTS
1348   
1349                                ; Fast clear of the array, executed as a command
1350      P:0003A3 P:0003A3 60F400  CLEAR     MOVE              #FRAME_RESET,R0
                            000016
1351                                          CLOCK
1355      P:0003A9 P:0003A9 0C008F            JMP     <FINISH
1356   
1357                                ; Start the exposure timer and monitor its progress
1358                                EXPOSE
1359      P:0003AA P:0003AA 07F40E            MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1360      P:0003AC P:0003AC 240000            MOVE              #0,X0
1361      P:0003AD P:0003AD 441100            MOVE              X0,X:<ELAPSED_TIME      ; Set elapsed exposure time to zero
1362      P:0003AE P:0003AE 579000            MOVE              X:<EXPOSURE_TIME,B
1363      P:0003AF P:0003AF 20000B            TST     B                                 ; Special test for zero exposure time
1364      P:0003B0 P:0003B0 0EA3BC            JEQ     <END_EXP                          ; Don't even start an exposure
1365      P:0003B1 P:0003B1 01418C            SUB     #1,B                              ; Timer counts from X:TCPR0+1 to zero
1366      P:0003B2 P:0003B2 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1367      P:0003B3 P:0003B3 577000            MOVE              B,X:TCPR0
                            FFFF8D
1368                                CHK_RCV
1369      P:0003B5 P:0003B5 0A8989            JCLR    #EF,X:HDR,CHK_TIM                 ; Simple test for fast execution
                            0003BA
1370      P:0003B7 P:0003B7 330700            MOVE              #COM_BUF,R3             ; The beginning of the command buffer
1371      P:0003B8 P:0003B8 0D00A5            JSR     <GET_RCV                          ; Check for an incoming command
1372      P:0003B9 P:0003B9 0E805D            JCS     <PRC_RCV                          ; If command is received, go check it
1373                                CHK_TIM
1374      P:0003BA P:0003BA 018F95            JCLR    #TCF,X:TCSR0,CHK_RCV              ; Wait for timer to equal compare value
                            0003B5
1375                                END_EXP
1376      P:0003BC P:0003BC 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the timer
1377      P:0003BD P:0003BD 0AE780            JMP     (R7)                              ; This contains the return address
1378   
1379                                ;  *****************  Start the exposure  *****************
1380                                ;START_EXPOSURE
1381                                ;       MOVE    #TST_RCV,R0             ; Process commands, don't idle,
1382                                ;       MOVE    R0,X:<IDL_ADR           ;    during the exposure
1383                                START_EXPOSURE
1384      P:0003BE P:0003BE 0D0408            JSR     <INIT_PCI_IMAGE_ADDRESS
1385      P:0003BF P:0003BF 305A00            MOVE              #TST_RCV,R0             ; Process commands, don't idle,
1386      P:0003C0 P:0003C0 601F00            MOVE              R0,X:<IDL_ADR           ;    during the exposure
1387      P:0003C1 P:0003C1 000000            NOP
1388      P:0003C2 P:0003C2 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
1389      P:0003C3 P:0003C3 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 25



1390      P:0003C4 P:0003C4 060A40            DO      Y:<NFS,RD1_END                    ; Fowler sampling
                            0003CC
1391      P:0003C6 P:0003C6 0D0284            JSR     <READOUT                          ; Read out the FPA
1392      P:0003C7 P:0003C7 000000            NOP
1393      P:0003C8 P:0003C8 000000            NOP
1394      P:0003C9 P:0003C9 000000            NOP
1395      P:0003CA P:0003CA 000000            NOP
1396      P:0003CB P:0003CB 000000            NOP
1397      P:0003CC P:0003CC 000000            NOP
1398                                RD1_END
1399      P:0003CD P:0003CD 67F400            MOVE              #L_SEX1,R7              ; Return address at end of exposure
                            0003D1
1400      P:0003CF P:0003CF 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1401      P:0003D0 P:0003D0 0C03AA            JMP     <EXPOSE                           ; Delay for specified exposure time
1402                                L_SEX1
1403      P:0003D1 P:0003D1 060A40            DO      Y:<NFS,RD2_END                    ; Fowler sampling
                            0003D9
1404      P:0003D3 P:0003D3 0D0284            JSR     <READOUT                          ; Go read out the FPA
1405      P:0003D4 P:0003D4 000000            NOP
1406      P:0003D5 P:0003D5 000000            NOP
1407      P:0003D6 P:0003D6 000000            NOP
1408      P:0003D7 P:0003D7 000000            NOP
1409      P:0003D8 P:0003D8 000000            NOP
1410      P:0003D9 P:0003D9 000000            NOP
1411                                RD2_END
1412      P:0003DA P:0003DA 60F400            MOVE              #CONT_RST,R0            ; Continuously read array in idle mode
                            00022D
1413      P:0003DC P:0003DC 601F00            MOVE              R0,X:<IDL_ADR
1414      P:0003DD P:0003DD 000000            NOP
1415      P:0003DE P:0003DE 0C0054            JMP     <START
1416   
1417   
1418   
1419                                ; Test for continuous readout
1420      P:0003DF P:0003DF 5E8B00            MOVE                          Y:<N_FRAMES,A
1421      P:0003E0 P:0003E0 014185            CMP     #1,A
1422      P:0003E1 P:0003E1 0EF3F8            JLE     <INIT_PCI_BOARD
1423   
1424                                INIT_FRAME_COUNT
1425      P:0003E2 P:0003E2 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1426      P:0003E3 P:0003E3 57F400            MOVE              #$020102,B              ; Initialize the PCI frame counter
                            020102
1427      P:0003E5 P:0003E5 0D00EB            JSR     <XMT_WRD
1428      P:0003E6 P:0003E6 57F400            MOVE              #'IFC',B
                            494643
1429      P:0003E8 P:0003E8 0D00EB            JSR     <XMT_WRD
1430      P:0003E9 P:0003E9 240000            MOVE              #0,X0
1431      P:0003EA P:0003EA 4C0C00            MOVE                          X0,Y:<I_FRAME ; Initialize the frame number
1432      P:0003EB P:0003EB 0C03F8            JMP     <INIT_PCI_BOARD
1433   
1434                                ; Start up the next frame of the coaddition series
1435                                NEXT_FRAME
1436      P:0003EC P:0003EC 5E8C00            MOVE                          Y:<I_FRAME,A ; Get the # of frames coadded so far
1437      P:0003ED P:0003ED 014180            ADD     #1,A
1438      P:0003EE P:0003EE 4C8B00            MOVE                          Y:<N_FRAMES,X0 ; See if we've coadded enough frames
1439      P:0003EF P:0003EF 5C0C00            MOVE                          A1,Y:<I_FRAME ; Increment the coaddition frame counter
1440      P:0003F0 P:0003F0 200045            CMP     X0,A
1441      P:0003F1 P:0003F1 0E134A            JGE     <RDA_END                          ; End of coaddition sequence
1442   
1443      P:0003F2 P:0003F2 5E8D00            MOVE                          Y:<IBUFFER,A ; Get the position in the buffer
1444      P:0003F3 P:0003F3 014180            ADD     #1,A
1445      P:0003F4 P:0003F4 4C8E00            MOVE                          Y:<N_FPB,X0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 26



1446      P:0003F5 P:0003F5 5C0D00            MOVE                          A1,Y:<IBUFFER
1447      P:0003F6 P:0003F6 200045            CMP     X0,A
1448      P:0003F7 P:0003F7 0E9400            JLT     <SEX_1                            ; Test if the frame buffer is full
1449   
1450                                INIT_PCI_BOARD
1451      P:0003F8 P:0003F8 240000            MOVE              #0,X0
1452      P:0003F9 P:0003F9 4C0D00            MOVE                          X0,Y:<IBUFFER ; IBUFFER counts from 0 to N_FPB
1453      P:0003FA P:0003FA 57F400            MOVE              #$020102,B
                            020102
1454      P:0003FC P:0003FC 0D00EB            JSR     <XMT_WRD
1455      P:0003FD P:0003FD 57F400            MOVE              #'IIA',B                ; Initialize the PCI image address
                            494941
1456      P:0003FF P:0003FF 0D00EB            JSR     <XMT_WRD
1457   
1458                                ; Start the exposure
1459      P:000400 P:000400 0A00AA  SEX_1     JSET    #TST_IMG,X:STATUS,SYNTHETIC_IMAGE
                            00043B
1460      P:000402 P:000402 56F400            MOVE              #$0c1000,A              ; Reset video processor FIFOs
                            0C1000
1461      P:000404 P:000404 0D0454            JSR     <WR_BIAS
1462      P:000405 P:000405 0A00B2            JSET    #ST_RRR,X:STATUS,ROW_BY_ROW_RESET_READOUT
                            0002AB
1463      P:000407 P:000407 0C0277            JMP     <NORMAL_READOUT
1464   
1465   
1466                                ; ********************* Initialize PCI image address ***********************
1467                                INIT_PCI_IMAGE_ADDRESS
1468      P:000408 P:000408 57F400            MOVE              #$020102,B              ; Initialize the PCI image address
                            020102
1469      P:00040A P:00040A 0D00EB            JSR     <XMT_WRD
1470      P:00040B P:00040B 57F400            MOVE              #'IIA',B
                            494941
1471      P:00040D P:00040D 0D00EB            JSR     <XMT_WRD
1472      P:00040E P:00040E 00000C            RTS
1473   
1474   
1475                                ; Set the desired exposure time
1476                                SET_EXPOSURE_TIME
1477      P:00040F P:00040F 46DB00            MOVE              X:(R3)+,Y0
1478      P:000410 P:000410 461000            MOVE              Y0,X:EXPOSURE_TIME
1479      P:000411 P:000411 018F80            JCLR    #TIM_BIT,X:TCSR0,FINISH           ; Return if exposure not occurring
                            00008F
1480      P:000413 P:000413 467000            MOVE              Y0,X:TCPR0              ; Update timer if exposure in progress
                            FFFF8D
1481      P:000415 P:000415 0C008F            JMP     <FINISH
1482   
1483                                ; Read the time remaining until the exposure ends
1484                                READ_EXPOSURE_TIME
1485      P:000416 P:000416 018FA0            JSET    #TIM_BIT,X:TCSR0,RD_TIM           ; Read DSP timer if its running
                            00041A
1486      P:000418 P:000418 479100            MOVE              X:<ELAPSED_TIME,Y1
1487      P:000419 P:000419 0C0090            JMP     <FINISH1
1488      P:00041A P:00041A 47F000  RD_TIM    MOVE              X:TCR0,Y1               ; Read elapsed exposure time
                            FFFF8C
1489      P:00041C P:00041C 0C0090            JMP     <FINISH1
1490   
1491                                ; Pause the exposure - close the shutter and stop the timer
1492                                PAUSE_EXPOSURE
1493      P:00041D P:00041D 07700C            MOVEP             X:TCR0,X:ELAPSED_TIME   ; Save the elapsed exposure time
                            000011
1494      P:00041F P:00041F 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1495      P:000420 P:000420 0C008F            JMP     <FINISH
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 27



1496   
1497                                ; Resume the exposure - open the shutter if needed and restart the timer
1498                                RESUME_EXPOSURE
1499      P:000421 P:000421 07F00E            MOVEP             X:ELAPSED_TIME,X:TLR0   ; Restore elapsed exposure time
                            000011
1500      P:000423 P:000423 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Re-enable the DSP exposure timer
1501      P:000424 P:000424 0C008F  L_RES     JMP     <FINISH
1502   
1503                                ; Special ending after abort command to send a 'DON' to the host computer
1504                                ; Abort exposure - close the shutter, stop the timer and resume idle mode
1505                                ABORT_EXPOSURE
1506      P:000425 P:000425 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1507      P:000426 P:000426 60F400            MOVE              #CONT_RST,R0
                            00022D
1508      P:000428 P:000428 601F00            MOVE              R0,X:<IDL_ADR
1509      P:000429 P:000429 0D0468            JSR     <WAIT_TO_FINISH_CLOCKING
1510      P:00042A P:00042A 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1511      P:00042B P:00042B 06A08F            DO      #4000,*+3                         ; Wait 40 microsec for the fiber
                            00042D
1512      P:00042D P:00042D 000000            NOP                                       ;  optic to clear out
1513      P:00042E P:00042E 0C008F            JMP     <FINISH
1514   
1515                                ; Short delay for the array to settle down after a global reset
1516                                MILLISEC_DELAY
1517      P:00042F P:00042F 200003            TST     A
1518      P:000430 P:000430 0E2432            JNE     <DLY_IT
1519      P:000431 P:000431 00000C            RTS
1520      P:000432 P:000432 07F40E  DLY_IT    MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1521      P:000434 P:000434 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1522      P:000435 P:000435 567000            MOVE              A,X:TCPR0               ; Desired elapsed time
                            FFFF8D
1523      P:000437 P:000437 018F95  CNT_DWN   JCLR    #TCF,X:TCSR0,CNT_DWN              ; Wait here for timer to count down
                            000437
1524      P:000439 P:000439 010F00            BCLR    #TIM_BIT,X:TCSR0
1525      P:00043A P:00043A 00000C            RTS
1526   
1527                                ; Generate a synthetic image by simply incrementing the pixel counts
1528                                SYNTHETIC_IMAGE
1529      P:00043B P:00043B 0D045B            JSR     <PCI_READ_IMAGE
1530      P:00043C P:00043C 200013            CLR     A
1531      P:00043D P:00043D 060240            DO      Y:<NPR,LPR_TST                    ; Loop over each line readout
                            000448
1532      P:00043F P:00043F 060140            DO      Y:<NSR,LSR_TST                    ; Loop over number of pixels per line
                            000447
1533      P:000441 P:000441 0614A0            REP     #20                               ; #20 => 1.0 microsec per pixel
1534      P:000442 P:000442 000000            NOP
1535      P:000443 P:000443 014180            ADD     #1,A                              ; Pixel data = Pixel data + 1
1536      P:000444 P:000444 000000            NOP
1537      P:000445 P:000445 21CF00            MOVE              A,B
1538      P:000446 P:000446 0D044A            JSR     <XMT_PIX                          ; Transmit the pixel data
1539      P:000447 P:000447 000000            NOP
1540                                LSR_TST
1541      P:000448 P:000448 000000            NOP
1542                                LPR_TST
1543      P:000449 P:000449 00000C            RTS
1544   
1545                                ; Transmit the 16-bit pixel datum in B1 to the host computer
1546      P:00044A P:00044A 0C1DA1  XMT_PIX   ASL     #16,B,B
1547      P:00044B P:00044B 000000            NOP
1548      P:00044C P:00044C 216500            MOVE              B2,X1
1549      P:00044D P:00044D 0C1D91            ASL     #8,B,B
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 28



1550      P:00044E P:00044E 000000            NOP
1551      P:00044F P:00044F 216400            MOVE              B2,X0
1552      P:000450 P:000450 000000            NOP
1553      P:000451 P:000451 09C532            MOVEP             X1,Y:WRFO
1554      P:000452 P:000452 09C432            MOVEP             X0,Y:WRFO
1555      P:000453 P:000453 00000C            RTS
1556   
1557                                ; Write a number to an analog board over the serial link
1558      P:000454 P:000454 012F23  WR_BIAS   BSET    #3,X:PCRD                         ; Turn on the serial clock
1559      P:000455 P:000455 0D0476            JSR     <PAL_DLY
1560      P:000456 P:000456 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1561      P:000457 P:000457 0D0476            JSR     <PAL_DLY
1562      P:000458 P:000458 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1563      P:000459 P:000459 0D0476            JSR     <PAL_DLY
1564      P:00045A P:00045A 00000C            RTS
1565   
1566                                ; Alert the PCI interface board that images are coming soon
1567                                ;   Image size = 512columns x 512 x # of Fowler samples x 2 if CDS
1568   
1569                                PCI_READ_IMAGE
1570      P:00045B P:00045B 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1571      P:00045D P:00045D 0D00EB            JSR     <XMT_WRD
1572      P:00045E P:00045E 57F400            MOVE              #'RDA',B
                            524441
1573      P:000460 P:000460 0D00EB            JSR     <XMT_WRD
1574      P:000461 P:000461 57F400            MOVE              #'NSR',B                ; Number of columns to read 512 for 1Q
                            4E5352
1575      P:000463 P:000463 0D00EB            JSR     <XMT_WRD
1576      P:000464 P:000464 57F400            MOVE              #'NPR',B                ; 512 x 2FS x2 (because we always do CDS)
                            4E5052
1577      P:000466 P:000466 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1578      P:000467 P:000467 00000C            RTS
1579   
1580                                ; Wait for the clocking to be complete before proceeding
1581                                WAIT_TO_FINISH_CLOCKING
1582      P:000468 P:000468 01ADA1            JSET    #SSFEF,X:PDRD,*                   ; Wait for the SS FIFO to be empty
                            000468
1583      P:00046A P:00046A 00000C            RTS
1584   
1585                                ; This MOVEP instruction executes in 30 nanosec, 20 nanosec for the MOVEP,
1586                                ;   and 10 nanosec for the wait state that is required for SRAM writes and
1587                                ;   FIFO setup times. It looks reliable, so will be used for now.
1588   
1589                                ; Core subroutine for clocking
1590                                CLOCK
1591      P:00046B P:00046B 0A898E            JCLR    #SSFHF,X:HDR,*                    ; Only write to FIFO if < half full
                            00046B
1592      P:00046D P:00046D 000000            NOP
1593      P:00046E P:00046E 0A898E            JCLR    #SSFHF,X:HDR,CLOCK                ; Guard against metastability
                            00046B
1594      P:000470 P:000470 4CD800            MOVE                          Y:(R0)+,X0  ; # of waveform entries
1595      P:000471 P:000471 06C400            DO      X0,CLK1                           ; Repeat X0 times
                            000473
1596      P:000473 P:000473 09D8F3            MOVEP             Y:(R0)+,Y:WRSS          ; 30 nsec Write the waveform to the SS
1597                                CLK1
1598      P:000474 P:000474 000000            NOP
1599      P:000475 P:000475 00000C            RTS                                       ; Return from subroutine
1600   
1601                                ; Delay for serial writes to the PALs and DACs by 8 microsec
1602      P:000476 P:000476 062083  PAL_DLY   DO      #800,DLY                          ; Wait 8 usec for serial data transmission
                            000478
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 29



1603      P:000478 P:000478 000000            NOP
1604      P:000479 P:000479 000000  DLY       NOP
1605      P:00047A P:00047A 00000C            RTS
1606   
1607                                ; Read DAC values from a table, and write them to the DACs
1608      P:00047B P:00047B 065840  SET_DAC   DO      Y:(R0)+,L_DAC                     ; Repeat Y:(R0)+ times
                            000482
1609      P:00047D P:00047D 5ED800            MOVE                          Y:(R0)+,A   ; Read the table entry
1610      P:00047E P:00047E 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1611      P:00047F P:00047F 000000            NOP
1612      P:000480 P:000480 0D0476            JSR     <PAL_DLY
1613      P:000481 P:000481 0D0476            JSR     <PAL_DLY
1614      P:000482 P:000482 000000            NOP
1615      P:000483 P:000483 00000C  L_DAC     RTS
1616   
1617                                ; Let the host computer read the controller configuration
1618                                READ_CONTROLLER_CONFIGURATION
1619      P:000484 P:000484 4F8800            MOVE                          Y:<CONFIG,Y1 ; Just transmit the configuration
1620      P:000485 P:000485 0C0090            JMP     <FINISH1
1621   
1622                                ; Set a particular DAC numbers, for setting DC bias voltages, clock driver
1623                                ;   voltages and video processor offset
1624                                ;
1625                                ; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
1626                                ;
1627                                ;                               #BOARD is from 0 to 15
1628                                ;                               #DAC number
1629                                ;                               #voltage is from 0 to 4095
1630   
1631                                SET_BIAS_NUMBER                                     ; Set bias number
1632      P:000486 P:000486 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1633      P:000487 P:000487 56DB00            MOVE              X:(R3)+,A               ; First argument is board number, 0 to 15
1634      P:000488 P:000488 0614A0            REP     #20
1635      P:000489 P:000489 200033            LSL     A
1636      P:00048A P:00048A 000000            NOP
1637      P:00048B P:00048B 21C500            MOVE              A,X1                    ; Save the board number
1638      P:00048C P:00048C 56DB00            MOVE              X:(R3)+,A               ; Second argument is DAC number
1639      P:00048D P:00048D 000000            NOP
1640      P:00048E P:00048E 5C0000            MOVE                          A1,Y:0      ; Save the DAC number for a little while
1641      P:00048F P:00048F 57DB00            MOVE              X:(R3)+,B               ; Third argument is 'VID' or 'CLK' string
1642      P:000490 P:000490 0140CD            CMP     #'VID',B
                            564944
1643      P:000492 P:000492 0EA4CC            JEQ     <ERR_SBN                          ; Video board offsets aren't supported
1644      P:000493 P:000493 0140CD            CMP     #'CLK',B
                            434C4B
1645      P:000495 P:000495 0E24CC            JNE     <ERR_SBN
1646   
1647                                ; For ARC32 do some trickiness to set the chip select and address bits
1648      P:000496 P:000496 218F00            MOVE              A1,B
1649      P:000497 P:000497 060EA0            REP     #14
1650      P:000498 P:000498 200033            LSL     A
1651      P:000499 P:000499 240E00            MOVE              #$0E0000,X0
1652      P:00049A P:00049A 200046            AND     X0,A
1653      P:00049B P:00049B 44F400            MOVE              #>7,X0
                            000007
1654      P:00049D P:00049D 20004E            AND     X0,B                              ; Get 3 least significant bits of clock #
1655      P:00049E P:00049E 01408D            CMP     #0,B
1656      P:00049F P:00049F 0E24A2            JNE     <CLK_1
1657      P:0004A0 P:0004A0 0ACE68            BSET    #8,A
1658      P:0004A1 P:0004A1 0C04BD            JMP     <BD_SET
1659      P:0004A2 P:0004A2 01418D  CLK_1     CMP     #1,B
1660      P:0004A3 P:0004A3 0E24A6            JNE     <CLK_2
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 30



1661      P:0004A4 P:0004A4 0ACE69            BSET    #9,A
1662      P:0004A5 P:0004A5 0C04BD            JMP     <BD_SET
1663      P:0004A6 P:0004A6 01428D  CLK_2     CMP     #2,B
1664      P:0004A7 P:0004A7 0E24AA            JNE     <CLK_3
1665      P:0004A8 P:0004A8 0ACE6A            BSET    #10,A
1666      P:0004A9 P:0004A9 0C04BD            JMP     <BD_SET
1667      P:0004AA P:0004AA 01438D  CLK_3     CMP     #3,B
1668      P:0004AB P:0004AB 0E24AE            JNE     <CLK_4
1669      P:0004AC P:0004AC 0ACE6B            BSET    #11,A
1670      P:0004AD P:0004AD 0C04BD            JMP     <BD_SET
1671      P:0004AE P:0004AE 01448D  CLK_4     CMP     #4,B
1672      P:0004AF P:0004AF 0E24B2            JNE     <CLK_5
1673      P:0004B0 P:0004B0 0ACE6D            BSET    #13,A
1674      P:0004B1 P:0004B1 0C04BD            JMP     <BD_SET
1675      P:0004B2 P:0004B2 01458D  CLK_5     CMP     #5,B
1676      P:0004B3 P:0004B3 0E24B6            JNE     <CLK_6
1677      P:0004B4 P:0004B4 0ACE6E            BSET    #14,A
1678      P:0004B5 P:0004B5 0C04BD            JMP     <BD_SET
1679      P:0004B6 P:0004B6 01468D  CLK_6     CMP     #6,B
1680      P:0004B7 P:0004B7 0E24BA            JNE     <CLK_7
1681      P:0004B8 P:0004B8 0ACE6F            BSET    #15,A
1682      P:0004B9 P:0004B9 0C04BD            JMP     <BD_SET
1683      P:0004BA P:0004BA 01478D  CLK_7     CMP     #7,B
1684      P:0004BB P:0004BB 0E24BD            JNE     <BD_SET
1685      P:0004BC P:0004BC 0ACE70            BSET    #16,A
1686   
1687      P:0004BD P:0004BD 200062  BD_SET    OR      X1,A                              ; Add on the board number
1688      P:0004BE P:0004BE 000000            NOP
1689      P:0004BF P:0004BF 21C400            MOVE              A,X0
1690      P:0004C0 P:0004C0 56DB00            MOVE              X:(R3)+,A               ; Fourth argument is voltage value, 0 to $ff
f
1691      P:0004C1 P:0004C1 0604A0            REP     #4
1692      P:0004C2 P:0004C2 200023            LSR     A                                 ; Convert 12 bits to 8 bits for ARC32
1693      P:0004C3 P:0004C3 46F400            MOVE              #>$FF,Y0                ; Mask off just 8 bits
                            0000FF
1694      P:0004C5 P:0004C5 200056            AND     Y0,A
1695      P:0004C6 P:0004C6 200042            OR      X0,A
1696      P:0004C7 P:0004C7 000000            NOP
1697      P:0004C8 P:0004C8 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1698      P:0004C9 P:0004C9 0D0476            JSR     <PAL_DLY                          ; Wait for the number to be sent
1699      P:0004CA P:0004CA 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1700      P:0004CB P:0004CB 0C008F            JMP     <FINISH
1701      P:0004CC P:0004CC 56DB00  ERR_SBN   MOVE              X:(R3)+,A               ; Read and discard the fourth argument
1702      P:0004CD P:0004CD 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1703      P:0004CE P:0004CE 0C008D            JMP     <ERROR
1704   
1705                                ; Specify the MUX value to be output on the clock driver board
1706                                ; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
1707                                ;                               #clock_driver_board from 0 to 15
1708                                ;                               #MUX1, #MUX2 from 0 to 23
1709   
1710      P:0004CF P:0004CF 012F23  SET_MUX   BSET    #3,X:PCRD                         ; Turn on the serial clock
1711      P:0004D0 P:0004D0 56DB00            MOVE              X:(R3)+,A               ; Clock driver board number
1712      P:0004D1 P:0004D1 0614A0            REP     #20
1713      P:0004D2 P:0004D2 200033            LSL     A
1714      P:0004D3 P:0004D3 44F400            MOVE              #$001000,X0             ; Bits to select MUX on ARC32 board
                            001000
1715      P:0004D5 P:0004D5 200042            OR      X0,A
1716      P:0004D6 P:0004D6 000000            NOP
1717      P:0004D7 P:0004D7 218500            MOVE              A1,X1                   ; Move here for later use
1718   
1719                                ; Get the first MUX number
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 31



1720      P:0004D8 P:0004D8 56DB00            MOVE              X:(R3)+,A               ; Get the first MUX number
1721      P:0004D9 P:0004D9 200003            TST     A
1722      P:0004DA P:0004DA 0E951F            JLT     <ERR_SM1
1723      P:0004DB P:0004DB 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1724      P:0004DD P:0004DD 200045            CMP     X0,A
1725      P:0004DE P:0004DE 0E151F            JGE     <ERR_SM1
1726      P:0004DF P:0004DF 21CF00            MOVE              A,B
1727      P:0004E0 P:0004E0 44F400            MOVE              #>7,X0
                            000007
1728      P:0004E2 P:0004E2 20004E            AND     X0,B
1729      P:0004E3 P:0004E3 44F400            MOVE              #>$18,X0
                            000018
1730      P:0004E5 P:0004E5 200046            AND     X0,A
1731      P:0004E6 P:0004E6 0E24E9            JNE     <SMX_1                            ; Test for 0 <= MUX number <= 7
1732      P:0004E7 P:0004E7 0ACD63            BSET    #3,B1
1733      P:0004E8 P:0004E8 0C04F4            JMP     <SMX_A
1734      P:0004E9 P:0004E9 44F400  SMX_1     MOVE              #>$08,X0
                            000008
1735      P:0004EB P:0004EB 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1736      P:0004EC P:0004EC 0E24EF            JNE     <SMX_2
1737      P:0004ED P:0004ED 0ACD64            BSET    #4,B1
1738      P:0004EE P:0004EE 0C04F4            JMP     <SMX_A
1739      P:0004EF P:0004EF 44F400  SMX_2     MOVE              #>$10,X0
                            000010
1740      P:0004F1 P:0004F1 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
1741      P:0004F2 P:0004F2 0E251F            JNE     <ERR_SM1
1742      P:0004F3 P:0004F3 0ACD65            BSET    #5,B1
1743      P:0004F4 P:0004F4 20006A  SMX_A     OR      X1,B1                             ; Add prefix to MUX numbers
1744      P:0004F5 P:0004F5 000000            NOP
1745      P:0004F6 P:0004F6 21A700            MOVE              B1,Y1
1746   
1747                                ; Add on the second MUX number
1748      P:0004F7 P:0004F7 56DB00            MOVE              X:(R3)+,A               ; Get the next MUX number
1749      P:0004F8 P:0004F8 200003            TST     A
1750      P:0004F9 P:0004F9 0E9520            JLT     <ERR_SM2
1751      P:0004FA P:0004FA 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1752      P:0004FC P:0004FC 200045            CMP     X0,A
1753      P:0004FD P:0004FD 0E1520            JGE     <ERR_SM2
1754      P:0004FE P:0004FE 0606A0            REP     #6
1755      P:0004FF P:0004FF 200033            LSL     A
1756      P:000500 P:000500 000000            NOP
1757      P:000501 P:000501 21CF00            MOVE              A,B
1758      P:000502 P:000502 44F400            MOVE              #$1C0,X0
                            0001C0
1759      P:000504 P:000504 20004E            AND     X0,B
1760      P:000505 P:000505 44F400            MOVE              #>$600,X0
                            000600
1761      P:000507 P:000507 200046            AND     X0,A
1762      P:000508 P:000508 0E250B            JNE     <SMX_3                            ; Test for 0 <= MUX number <= 7
1763      P:000509 P:000509 0ACD69            BSET    #9,B1
1764      P:00050A P:00050A 0C0516            JMP     <SMX_B
1765      P:00050B P:00050B 44F400  SMX_3     MOVE              #>$200,X0
                            000200
1766      P:00050D P:00050D 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1767      P:00050E P:00050E 0E2511            JNE     <SMX_4
1768      P:00050F P:00050F 0ACD6A            BSET    #10,B1
1769      P:000510 P:000510 0C0516            JMP     <SMX_B
1770      P:000511 P:000511 44F400  SMX_4     MOVE              #>$400,X0
                            000400
1771      P:000513 P:000513 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  timIRmisc.asm  Page 32



1772      P:000514 P:000514 0E2520            JNE     <ERR_SM2
1773      P:000515 P:000515 0ACD6B            BSET    #11,B1
1774      P:000516 P:000516 200078  SMX_B     ADD     Y1,B                              ; Add prefix to MUX numbers
1775      P:000517 P:000517 000000            NOP
1776      P:000518 P:000518 21AE00            MOVE              B1,A
1777      P:000519 P:000519 0140C6            AND     #$F01FFF,A                        ; Just to be sure
                            F01FFF
1778      P:00051B P:00051B 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1779      P:00051C P:00051C 0D0476            JSR     <PAL_DLY                          ; Delay for all this to happen
1780      P:00051D P:00051D 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1781      P:00051E P:00051E 0C008F            JMP     <FINISH
1782      P:00051F P:00051F 56DB00  ERR_SM1   MOVE              X:(R3)+,A               ; Throw off the last argument
1783      P:000520 P:000520 012F03  ERR_SM2   BCLR    #3,X:PCRD                         ; Turn the serial clock off
1784      P:000521 P:000521 0C008D            JMP     <ERROR
1785   
1786   
1787                                CORRELATED_DOUBLE_SAMPLE
1788      P:000522 P:000522 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
1789      P:000523 P:000523 0AC420            JSET    #0,X0,CDS_SET
                            000527
1790      P:000525 P:000525 0A0011            BCLR    #ST_CDS,X:STATUS
1791      P:000526 P:000526 0C008F            JMP     <FINISH
1792      P:000527 P:000527 0A0031  CDS_SET   BSET    #ST_CDS,X:STATUS
1793      P:000528 P:000528 0C008F            JMP     <FINISH
1794   
1795                                SELECT_ROW_BY_ROW_RESET
1796      P:000529 P:000529 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
1797      P:00052A P:00052A 0AC420            JSET    #0,X0,RR_SET
                            00052E
1798      P:00052C P:00052C 0A0012            BCLR    #ST_RRR,X:STATUS
1799      P:00052D P:00052D 0C008F            JMP     <FINISH
1800      P:00052E P:00052E 0A0032  RR_SET    BSET    #ST_RRR,X:STATUS
1801      P:00052F P:00052F 0C008F            JMP     <FINISH
1802   
1803                                ;******************************************************************************
1804                                ; Set number of Fowler samples per frame
1805                                SET_NUMBER_OF_FOWLER_SAMPLES
1806      P:000530 P:000530 44DB00            MOVE              X:(R3)+,X0
1807      P:000531 P:000531 4C0A00            MOVE                          X0,Y:<NFS   ; Number of Fowler samples
1808      P:000532 P:000532 0C008F            JMP     <FINISH
1809   
1810                                ;******************************************************************************
1811                                ; Set the number of RESET frame.
1812                                ;SET_NUMBER_OF_RESET
1813                                ;       MOVE    X:(R3)+,X0
1814                                ;       MOVE    X0,Y:<NRESET
1815                                ;       JMP     <FINISH
1816   
1817   
1818                                ; Continuous readout commands
1819                                SET_NUMBER_OF_FRAMES                                ; Number of frames to obtain
1820      P:000533 P:000533 44DB00            MOVE              X:(R3)+,X0              ;   in an exposure sequence
1821      P:000534 P:000534 4C0B00            MOVE                          X0,Y:<N_FRAMES
1822      P:000535 P:000535 0C008F            JMP     <FINISH
1823   
1824                                SET_NUMBER_OF_FRAMES_PER_BUFFER                     ; Number of frames in each image
1825      P:000536 P:000536 44DB00            MOVE              X:(R3)+,X0              ;   buffer in the host computer
1826      P:000537 P:000537 4C0E00            MOVE                          X0,Y:<N_FPB ;   system memory
1827      P:000538 P:000538 0C008F            JMP     <FINISH
1828   
1829   
1830                                 TIMBOOT_X_MEMORY
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 33



1831      000539                              EQU     @LCV(L)
1832   
1833                                ;  ****************  Setup memory tables in X: space ********************
1834   
1835                                ; Define the address in P: space where the table of constants begins
1836   
1837                                          IF      @SCP("HOST","HOST")
1838      X:000036 X:000036                   ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
1839                                          ENDIF
1840   
1841                                          IF      @SCP("HOST","ROM")
1843                                          ENDIF
1844   
1845                                ; Application commands
1846      X:000036 X:000036                   DC      'PON',POWER_ON
1847      X:000038 X:000038                   DC      'POF',POWER_OFF
1848      X:00003A X:00003A                   DC      'SBV',SET_BIAS_VOLTAGES
1849      X:00003C X:00003C                   DC      'IDL',FINISH
1850      X:00003E X:00003E                   DC      'CLR',CLEAR
1851   
1852                                ; Exposure and readout control routines
1853      X:000040 X:000040                   DC      'SET',SET_EXPOSURE_TIME
1854      X:000042 X:000042                   DC      'RET',READ_EXPOSURE_TIME
1855      X:000044 X:000044                   DC      'SEX',START_EXPOSURE
1856      X:000046 X:000046                   DC      'PEX',PAUSE_EXPOSURE
1857      X:000048 X:000048                   DC      'REX',RESUME_EXPOSURE
1858      X:00004A X:00004A                   DC      'AEX',ABORT_EXPOSURE
1859      X:00004C X:00004C                   DC      'ABR',ABORT_EXPOSURE
1860      X:00004E X:00004E                   DC      'CDS',CORRELATED_DOUBLE_SAMPLE
1861      X:000050 X:000050                   DC      'RRR',SELECT_ROW_BY_ROW_RESET
1862      X:000052 X:000052                   DC      'SFS',SET_NUMBER_OF_FOWLER_SAMPLES
1863   
1864                                ; Support routines
1865      X:000054 X:000054                   DC      'SBN',SET_BIAS_NUMBER
1866      X:000056 X:000056                   DC      'SMX',SET_MUX
1867      X:000058 X:000058                   DC      'CSW',CLR_SWS
1868      X:00005A X:00005A                   DC      'RCC',READ_CONTROLLER_CONFIGURATION
1869   
1870                                ; Continuous readout commands
1871      X:00005C X:00005C                   DC      'SNF',SET_NUMBER_OF_FRAMES
1872      X:00005E X:00005E                   DC      'FPB',SET_NUMBER_OF_FRAMES_PER_BUFFER
1873   
1874                                 END_APPLICATON_COMMAND_TABLE
1875      000060                              EQU     @LCV(L)
1876   
1877                                          IF      @SCP("HOST","HOST")
1878      00001C                    NUM_COM   EQU     (@LCV(R)-COM_TBL_R)/2             ; Number of boot +
1879                                                                                    ;  application commands
1880      0003BA                    EXPOSING  EQU     CHK_TIM                           ; Address if exposing
1881                                 CONTINUE_READING
1882      100000                              EQU     CONT_RD                           ; Address if reading out
1883                                          ENDIF
1884   
1885                                          IF      @SCP("HOST","ROM")
1887                                          ENDIF
1888   
1889                                ; Now let's go for the timing waveform tables
1890                                          IF      @SCP("HOST","HOST")
1891      Y:000000 Y:000000                   ORG     Y:0,Y:0
1892                                          ENDIF
1893   
1894      Y:000000 Y:000000         GAIN      DC      END_APPLICATON_Y_MEMORY-@LCV(L)-1
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 34



1895   
1896      Y:000001 Y:000001         NSR       DC      12288                             ; 512 x6DS x4 for 4 Quadrants
1897      Y:000002 Y:000002         NPR       DC      1024                              ; 2048 = 2(CDS) x NFS=1 x 512
1898      Y:000003 Y:000003         NSCLR     DC      0                                 ; Not used
1899      Y:000004 Y:000004         NPCLR     DC      0                                 ; Not used
1900      Y:000005 Y:000005         DUMMY     DC      0,0                               ; Binning parameters (reserved)
1901      Y:000007 Y:000007         TST_DAT   DC      0                                 ; Temporary definition for test images
1902      Y:000008 Y:000008         CONFIG    DC      CC                                ; Controller configuration
1903      Y:000009 Y:000009         TRM_ADR   DC      0                                 ; Test RAM memory error address
1904      Y:00000A Y:00000A         NFS       DC      1                                 ; Number of Fowler samples
1905   
1906                                ; Continuous readout parameters
1907      Y:00000B Y:00000B         N_FRAMES  DC      1                                 ; Total number of frames to read out
1908      Y:00000C Y:00000C         I_FRAME   DC      0                                 ; Number of frames read out so far
1909      Y:00000D Y:00000D         IBUFFER   DC      0                                 ; Number of frames read into the PCI buffer
1910      Y:00000E Y:00000E         N_FPB     DC      0                                 ; Number of frames per PCI image buffer
1911   
1912                                ; Include the waveform table for the designated IR array
1913                                          INCLUDE "AladdinIII.waveforms"            ; Readout and clocking waveform file
1914                                       COMMENT *
1915   
1916                                Waveform tables for Aladdin III IR array to be used with one ARC-46 =
1917                                        8-channel video processor boards and Gen III = ARC22 = 250 MHz
1918                                        timing board and ARC-32 clock driver board.
1919                                Modified Feb. 2009 for row-by-row reset for high flux observations
1920   
1921                                        *
1922   
1923      000001                    AD        EQU     $000001                           ; Bit to start A/D conversion
1924      000002                    XFER      EQU     $000002                           ; Bit to transfer A/D counts into the A/D FI
FO
1925      00F7C0                    SXMIT     EQU     $00F7C0                           ; Transmit 32 pixels = 4 Aladdin quadrants
1926   
1927                                ; Definitions of readout variables
1928      002000                    CLK2      EQU     $002000                           ; Clock driver board lower half
1929      003000                    CLK3      EQU     $003000                           ; Clock driver board upper half
1930      000000                    VIDEO     EQU     $000000                           ; Video processor board switches
1931   
1932                                ; Various delay parameters
1933      100000                    DLY0      EQU     $100000
1934      180000                    DLY1      EQU     $180000                           ; 1.0 microsec
1935      320000                    DLY2      EQU     $320000                           ; 2.0 microsec
1936      640000                    DLY4      EQU     $640000                           ; 4.0 microsec
1937      930000                    DLY6      EQU     $930000                           ; 6.0 microsec
1938   
1939      130000                    DLYA      EQU     $130000                           ; Pixel readout delay parameters
1940      040000                    DLYB      EQU     $040000
1941      C00000                    DLYG      EQU     $C00000
1942   
1943      0C0000                    XMT_DLY   EQU     $0C0000                           ; Delay per SXMIT for the fiber optic transm
itter
1944   
1945                                ; Voltages for operating the Aladdin III focal plane array. The clock driver
1946                                ;   needs to be jumpered for bipolar operation because of the output source
1947                                ;   load resistor driver, VSSOUT = +1.0
1948   
1949   
1950                                ; Voltages for operating the Aladdin III focal plane array ORIGINAL
1951                                ;CLK_HI         EQU     +0.0    ; Clock voltage low
1952                                ;CLK_LO         EQU     -5.0    ; Clock voltage low
1953                                ;VRW_LO         EQU     -4.0    ; VrowON low voltage
1954                                ;VRST_HI                EQU     -3.5    ; VrstG high voltage
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 35



1955                                ;VRST_LO                EQU     -5.8    ; VrstG low voltage
1956                                ;ZERO           EQU      0.0    ; Unused clock driver voltage
1957      000002                    ADREF     EQU     +2                                ; A/D converter voltage reference
1958      00000D                    Vmax      EQU     13                                ; Maximum clock driver voltage, clock board
1959      2.600000E+001             Vmax1     EQU     2.0*Vmax
1960      7.500000E+000             Vmax2     EQU     7.5                               ; 2 x Maximum clock driver voltage
1961      1.500000E+001             Vmax3     EQU     2.0*Vmax2
1962   
1963                                ; Voltages for operating the Aladdin III focal plane array TWEAKED BY LUC AS NASA IRTF
1964      -5.000000E-001            CLK_HI    EQU     -0.5                              ; Clock voltage high
1965      -5.800000E+000            CLK_LO    EQU     -5.8                              ; Clock voltage low
1966      -4.000000E+000            VRW_LO    EQU     -4.0                              ; VrowON low voltage
1967      -3.500000E+000            VRST_HI   EQU     -3.5                              ; VrstG high voltage
1968      -5.800000E+000            VRST_LO   EQU     -5.8                              ; VrstG low voltage
1969      0.000000E+000             ZERO      EQU     0.0                               ; Unused clock driver voltage
1970   
1971   
1972                                ; Define switch state bits for CLK2 = bottom of clock board
1973      000001                    SSYNC     EQU     1                                 ; Slow Sync             Pin #1
1974      000002                    S1        EQU     2                                 ; Slow phase 1          Pin #2
1975      000004                    S2        EQU     4                                 ; Slow phase 2          Pin #3
1976      000008                    SOE       EQU     8                                 ; Odd/Even row select   Pin #4
1977      000010                    RDES      EQU     $10                               ; Row deselect          Pin #5
1978      000020                    VRSTOFF   EQU     $20                               ; Global reset = VrstG  Pin #6
1979      000040                    VRSTR     EQU     $40                               ; Row reset bias        Pin #7
1980      000080                    VROWON    EQU     $80                               ; Bias to row enable    Pin #8
1981   
1982                                ; Define switch state bits for CLK3 = top of clock board
1983      000001                    FSYNC     EQU     1                                 ; Fast sync             Pin #13
1984      000002                    F1        EQU     2                                 ; Fast phase 1          Pin #14
1985      000004                    F2        EQU     4                                 ; Fast phase 2          Pin #15
1986   
1987                                ; Aladdin III DC bias voltage definition
1988                                ; Per Peter Onaka, "you shouldn't forward bias the InSb = VDDUC should always be more negative t
han VDET."
1989                                ; FIXME
1990      -2.800000E+000            VGGCL     EQU     -2.8                              ; p16 Board2 Column Clamp Clock, was -3.1V b
ut UIST sets it to 0V and IRTF defines it at -3.1V but never switches it
1991      -2.800000E+000            VDDCL     EQU     -2.8                              ; p17 Board2 Column Clamp Bias  was -3.6V no
w as UIST
1992      -4.000000E+000            VDDUC     EQU     -4.0                              ; p33 Board1 Negative Unit Cell Bias set to 
same as VdetCom for warm testing else -4V
1993      -5.950000E+000            VNROW     EQU     -5.95                             ; p31 Board2 Negative row supply
1994      -5.950000E+000            VNCOL     EQU     -5.95                             ; p15 Board2 Negative column supply
1995      -1.500000E+000            VDDOUT    EQU     -1.5                              ; p17 Board1 Drain voltage for drivers  was 
-1.2 now as UIST
1996      -3.400000E+000            VDETCOM   EQU     -3.4                              ; p32 Board1 Detector Common not for MUX sho
uld be same as VdduC for warm testing else -3.4V
1997      -2.000000E+000            IREF      EQU     -2.0                              ; p16 Board1 Reference current for Iidle and
 Islew
1998      4.500000E+000             VSSOUT    EQU     +4.5                              ; Source follower load voltage
1999      -5.000000E-001            VROWOFF   EQU     -0.5                              ; p33 Board2 Applied to SF transistor gate M
2 when row is not selected
2000   
2001                                ;V1             EQU -0.8                ; Voltages to test the video boards and firmware
2002                                ;V2             EQU     -0.9            ; Set in conjunction with offset and gain settings
2003                                ;V3             EQU     -1                      ; for testing of each video board with the jumpe
r connector
2004                                ;V4             EQU     -1.2
2005                                ;V5             EQU     -1.4
2006                                ;V6             EQU     -1.5
2007                                ;V7             EQU     +5.0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 36



2008   
2009                                ; Video offset variable
2010                                ;OFFSET EQU     $760            ; for operation of the Aladdin III array -
2011                                                                                    ;   64k DN at -1.0 volts input => full well
2012                                                                                    ;    0k DN at -2.0 volts input => dark
2013                                                                                    ; Increase offset to lower image counts
2014   
2015      0007B0                    OFFSETB1  EQU     $7B0                              ; with slow int gain $760 gives 4kADU dark w
ith fast 8A0
2016      0007B0                    OFFSETB2  EQU     $7B0                              ; with fast int gain
2017      0007B0                    OFFSETB3  EQU     $7B0                              ; with fast int gain
2018      0007B0                    OFFSETB4  EQU     $7B0                              ; with fast int gain
2019   
2020      0007B0                    OFFSET0   EQU     OFFSETB1
2021      0007B0                    OFFSET1   EQU     OFFSETB1
2022      0007B0                    OFFSET2   EQU     OFFSETB1
2023      0007B0                    OFFSET3   EQU     OFFSETB1
2024      0007B0                    OFFSET4   EQU     OFFSETB1
2025      0007B0                    OFFSET5   EQU     OFFSETB1
2026      0007B0                    OFFSET6   EQU     OFFSETB1
2027      0007B0                    OFFSET7   EQU     OFFSETB1
2028   
2029      0007B0                    OFFSET8   EQU     OFFSETB2
2030      0007B0                    OFFSET9   EQU     OFFSETB2
2031      0007B0                    OFFSET10  EQU     OFFSETB2
2032      0007B0                    OFFSET11  EQU     OFFSETB2
2033      0007B0                    OFFSET12  EQU     OFFSETB2
2034      0007B0                    OFFSET13  EQU     OFFSETB2
2035      0007B0                    OFFSET14  EQU     OFFSETB2
2036      0007B0                    OFFSET15  EQU     OFFSETB2
2037   
2038      0007B0                    OFFSET16  EQU     OFFSETB3
2039      0007B0                    OFFSET17  EQU     OFFSETB3
2040      0007B0                    OFFSET18  EQU     OFFSETB3
2041      0007B0                    OFFSET19  EQU     OFFSETB3
2042      0007B0                    OFFSET20  EQU     OFFSETB3
2043      0007B0                    OFFSET21  EQU     OFFSETB3
2044      0007B0                    OFFSET22  EQU     OFFSETB3
2045      0007B0                    OFFSET23  EQU     OFFSETB3
2046   
2047      0007B0                    OFFSET24  EQU     OFFSETB4
2048      0007B0                    OFFSET25  EQU     OFFSETB4
2049      0007B0                    OFFSET26  EQU     OFFSETB4
2050      0007B0                    OFFSET27  EQU     OFFSETB4
2051      0007B0                    OFFSET28  EQU     OFFSETB4
2052      0007B0                    OFFSET29  EQU     OFFSETB4
2053      0007B0                    OFFSET30  EQU     OFFSETB4
2054      0007B0                    OFFSET31  EQU     OFFSETB4
2055   
2056                                ; Copy of the clocking bit definition for easy reference
2057                                ;       DC      CLK2+DELAY+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2058                                ;       DC      CLK3+DELAY+FSYNC+F1+F2
2059   
2060                                FRAME_INIT
2061      Y:00000F Y:00000F                   DC      END_FRAME_INIT-FRAME_INIT-1
2062      Y:000010 Y:000010                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2063      Y:000011 Y:000011                   DC      CLK2+DLY4+00000+S1+S2+SOE+0000+VRSTOFF+VRSTR+000000
2064      Y:000012 Y:000012                   DC      CLK2+DLY4+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2065      Y:000013 Y:000013                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2066      Y:000014 Y:000014                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2067      Y:000015 Y:000015                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2068                                END_FRAME_INIT
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 37



2069   
2070                                FRAME_RESET
2071      Y:000016 Y:000016                   DC      END_FRAME_RESET-FRAME_RESET-1
2072      Y:000017 Y:000017                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2073      Y:000018 Y:000018                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2074      Y:000019 Y:000019                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2075      Y:00001A Y:00001A                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2076      Y:00001B Y:00001B                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2077      Y:00001C Y:00001C                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2078      Y:00001D Y:00001D                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2079      Y:00001E Y:00001E                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2080      Y:00001F Y:00001F                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2081      Y:000020 Y:000020                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2082      Y:000021 Y:000021                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2083      Y:000022 Y:000022                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2084      Y:000023 Y:000023                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2085      Y:000024 Y:000024                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2086      Y:000025 Y:000025                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2087      Y:000026 Y:000026                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2088      Y:000027 Y:000027                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2089      Y:000028 Y:000028                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2090      Y:000029 Y:000029                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2091      Y:00002A Y:00002A                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2092                                END_FRAME_RESET
2093   
2094                                CLOCK_ROW_1
2095      Y:00002B Y:00002B                   DC      END_CLOCK_ROW_1-CLOCK_ROW_1-1
2096      Y:00002C Y:00002C                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2097      Y:00002D Y:00002D                   DC      CLK3+DLY2+00000+F1+F2
2098      Y:00002E Y:00002E                   DC      CLK3+DLY1+FSYNC+F1+F2
2099      Y:00002F Y:00002F                   DC      CLK3+DLY2+FSYNC+00+F2
2100      Y:000030 Y:000030                   DC      CLK3+DLY0+FSYNC+F1+F2
2101                                END_CLOCK_ROW_1
2102   
2103                                CLOCK_ROW_2
2104      Y:000031 Y:000031                   DC      END_CLOCK_ROW_2-CLOCK_ROW_2-1
2105      Y:000032 Y:000032                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+000000
2106      Y:000033 Y:000033                   DC      CLK3+DLY2+00000+F1+F2
2107      Y:000034 Y:000034                   DC      CLK3+DLY1+FSYNC+F1+F2
2108      Y:000035 Y:000035                   DC      CLK3+DLY2+FSYNC+00+F2
2109      Y:000036 Y:000036                   DC      CLK3+DLY0+FSYNC+F1+F2
2110                                END_CLOCK_ROW_2
2111   
2112                                CLOCK_ROW_3
2113      Y:000037 Y:000037                   DC      END_CLOCK_ROW_3-CLOCK_ROW_3-1
2114      Y:000038 Y:000038                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2115      Y:000039 Y:000039                   DC      CLK3+DLY2+00000+F1+F2
2116      Y:00003A Y:00003A                   DC      CLK3+DLY1+FSYNC+F1+F2
2117      Y:00003B Y:00003B                   DC      CLK3+DLY2+FSYNC+00+F2
2118      Y:00003C Y:00003C                   DC      CLK3+DLY0+FSYNC+F1+F2
2119                                END_CLOCK_ROW_3
2120   
2121                                CLOCK_ROW_4
2122      Y:00003D Y:00003D                   DC      END_CLOCK_ROW_4-CLOCK_ROW_4-1
2123      Y:00003E Y:00003E                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+000000
2124      Y:00003F Y:00003F                   DC      CLK3+DLY2+00000+F1+F2
2125      Y:000040 Y:000040                   DC      CLK3+DLY1+FSYNC+F1+F2
2126      Y:000041 Y:000041                   DC      CLK3+DLY2+FSYNC+00+F2
2127      Y:000042 Y:000042                   DC      CLK3+DLY0+FSYNC+F1+F2
2128                                END_CLOCK_ROW_4
2129   
2130                                CLOCK_RR_ROW_1
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 38



2131      Y:000043 Y:000043                   DC      END_CLOCK_RR_ROW_1-CLOCK_RR_ROW_1-1
2132      Y:000044 Y:000044                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2133      Y:000045 Y:000045                   DC      CLK3+DLY2+00000+F1+F2
2134      Y:000046 Y:000046                   DC      CLK3+DLY1+FSYNC+F1+F2
2135      Y:000047 Y:000047                   DC      CLK3+DLY2+FSYNC+00+F2
2136      Y:000048 Y:000048                   DC      CLK3+DLY0+FSYNC+F1+F2
2137                                END_CLOCK_RR_ROW_1
2138   
2139                                CLOCK_RR_ROW_2
2140      Y:000049 Y:000049                   DC      END_CLOCK_RR_ROW_2-CLOCK_RR_ROW_2-1
2141      Y:00004A Y:00004A                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2142      Y:00004B Y:00004B                   DC      CLK3+DLY2+00000+F1+F2
2143      Y:00004C Y:00004C                   DC      CLK3+DLY1+FSYNC+F1+F2
2144      Y:00004D Y:00004D                   DC      CLK3+DLY2+FSYNC+00+F2
2145      Y:00004E Y:00004E                   DC      CLK3+DLY0+FSYNC+F1+F2
2146                                END_CLOCK_RR_ROW_2
2147   
2148                                CLOCK_RR_ROW_3
2149      Y:00004F Y:00004F                   DC      END_CLOCK_RR_ROW_3-CLOCK_RR_ROW_3-1
2150      Y:000050 Y:000050                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2151      Y:000051 Y:000051                   DC      CLK3+DLY2+00000+F1+F2
2152      Y:000052 Y:000052                   DC      CLK3+DLY1+FSYNC+F1+F2
2153      Y:000053 Y:000053                   DC      CLK3+DLY2+FSYNC+00+F2
2154      Y:000054 Y:000054                   DC      CLK3+DLY0+FSYNC+F1+F2
2155                                END_CLOCK_RR_ROW_3
2156   
2157                                CLOCK_RR_ROW_4
2158      Y:000055 Y:000055                   DC      END_CLOCK_RR_ROW_4-CLOCK_RR_ROW_4-1
2159      Y:000056 Y:000056                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2160      Y:000057 Y:000057                   DC      CLK3+DLY2+00000+F1+F2
2161      Y:000058 Y:000058                   DC      CLK3+DLY1+FSYNC+F1+F2
2162      Y:000059 Y:000059                   DC      CLK3+DLY2+FSYNC+00+F2
2163      Y:00005A Y:00005A                   DC      CLK3+DLY0+FSYNC+F1+F2
2164                                END_CLOCK_RR_ROW_4
2165   
2166                                CLOCK_RESET_ROW_1
2167      Y:00005B Y:00005B                   DC      END_CLOCK_RESET_ROW_1-CLOCK_RESET_ROW_1-1
2168      Y:00005C Y:00005C                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2169      Y:00005D Y:00005D                   DC      CLK3+DLY0+00000+F1+F2
2170      Y:00005E Y:00005E                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2171      Y:00005F Y:00005F                   DC      CLK3+DLY4+FSYNC+F1+F2
2172      Y:000060 Y:000060                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2173      Y:000061 Y:000061                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2174      Y:000062 Y:000062                   DC      CLK3+DLY2+FSYNC+00+F2
2175      Y:000063 Y:000063                   DC      CLK3+DLY0+FSYNC+F1+F2
2176                                END_CLOCK_RESET_ROW_1
2177   
2178                                CLOCK_RESET_ROW_2
2179      Y:000064 Y:000064                   DC      END_CLOCK_RESET_ROW_2-CLOCK_RESET_ROW_2-1
2180      Y:000065 Y:000065                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2181      Y:000066 Y:000066                   DC      CLK3+DLY0+00000+F1+F2
2182      Y:000067 Y:000067                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2183      Y:000068 Y:000068                   DC      CLK3+DLY4+FSYNC+F1+F2
2184      Y:000069 Y:000069                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2185      Y:00006A Y:00006A                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2186      Y:00006B Y:00006B                   DC      CLK3+DLY2+FSYNC+00+F2
2187      Y:00006C Y:00006C                   DC      CLK3+DLY0+FSYNC+F1+F2
2188                                END_CLOCK_RESET_ROW_2
2189   
2190                                CLOCK_RESET_ROW_3
2191      Y:00006D Y:00006D                   DC      END_CLOCK_RESET_ROW_3-CLOCK_RESET_ROW_3-1
2192      Y:00006E Y:00006E                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 39



2193      Y:00006F Y:00006F                   DC      CLK3+DLY0+00000+F1+F2
2194      Y:000070 Y:000070                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
2195      Y:000071 Y:000071                   DC      CLK3+DLY4+FSYNC+F1+F2
2196      Y:000072 Y:000072                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2197      Y:000073 Y:000073                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2198      Y:000074 Y:000074                   DC      CLK3+DLY2+FSYNC+00+F2
2199      Y:000075 Y:000075                   DC      CLK3+DLY0+FSYNC+F1+F2
2200                                END_CLOCK_RESET_ROW_3
2201   
2202                                CLOCK_RESET_ROW_4
2203      Y:000076 Y:000076                   DC      END_CLOCK_RESET_ROW_4-CLOCK_RESET_ROW_4-1
2204      Y:000077 Y:000077                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2205      Y:000078 Y:000078                   DC      CLK3+DLY0+00000+F1+F2
2206      Y:000079 Y:000079                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2207      Y:00007A Y:00007A                   DC      CLK3+DLY4+FSYNC+F1+F2
2208      Y:00007B Y:00007B                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2209      Y:00007C Y:00007C                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2210      Y:00007D Y:00007D                   DC      CLK3+DLY2+FSYNC+00+F2
2211      Y:00007E Y:00007E                   DC      CLK3+DLY0+FSYNC+F1+F2
2212                                END_CLOCK_RESET_ROW_4
2213   
2214                                CLOCK_CDS_RESET_ROW_1
2215      Y:00007F Y:00007F                   DC      END_CLOCK_CDS_RESET_ROW_1-CLOCK_CDS_RESET_ROW_1-1
2216      Y:000080 Y:000080                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2217      Y:000081 Y:000081                   DC      CLK3+DLY0+00000+F1+F2
2218      Y:000082 Y:000082                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2219      Y:000083 Y:000083                   DC      CLK3+DLY4+FSYNC+F1+F2
2220      Y:000084 Y:000084                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2221      Y:000085 Y:000085                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2222      Y:000086 Y:000086                   DC      CLK3+DLY2+FSYNC+00+F2
2223      Y:000087 Y:000087                   DC      CLK3+DLY0+FSYNC+F1+F2
2224                                END_CLOCK_CDS_RESET_ROW_1
2225   
2226                                CLOCK_CDS_RESET_ROW_2
2227      Y:000088 Y:000088                   DC      END_CLOCK_CDS_RESET_ROW_2-CLOCK_CDS_RESET_ROW_2-1
2228      Y:000089 Y:000089                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2229      Y:00008A Y:00008A                   DC      CLK3+DLY0+00000+F1+F2
2230      Y:00008B Y:00008B                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2231      Y:00008C Y:00008C                   DC      CLK3+DLY4+FSYNC+F1+F2
2232      Y:00008D Y:00008D                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2233      Y:00008E Y:00008E                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2234      Y:00008F Y:00008F                   DC      CLK3+DLY2+FSYNC+00+F2
2235      Y:000090 Y:000090                   DC      CLK3+DLY0+FSYNC+F1+F2
2236                                END_CLOCK_CDS_RESET_ROW_2
2237   
2238                                CLOCK_CDS_RESET_ROW_3
2239      Y:000091 Y:000091                   DC      END_CLOCK_CDS_RESET_ROW_3-CLOCK_CDS_RESET_ROW_3-1
2240      Y:000092 Y:000092                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2241      Y:000093 Y:000093                   DC      CLK3+DLY0+00000+F1+F2
2242      Y:000094 Y:000094                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
2243      Y:000095 Y:000095                   DC      CLK3+DLY4+FSYNC+F1+F2
2244      Y:000096 Y:000096                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2245      Y:000097 Y:000097                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2246      Y:000098 Y:000098                   DC      CLK3+DLY2+FSYNC+00+F2
2247      Y:000099 Y:000099                   DC      CLK3+DLY0+FSYNC+F1+F2
2248                                END_CLOCK_CDS_RESET_ROW_3
2249   
2250                                CLOCK_CDS_RESET_ROW_4
2251      Y:00009A Y:00009A                   DC      END_CLOCK_CDS_RESET_ROW_4-CLOCK_CDS_RESET_ROW_4-1
2252      Y:00009B Y:00009B                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2253      Y:00009C Y:00009C                   DC      CLK3+DLY0+00000+F1+F2
2254      Y:00009D Y:00009D                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 40



2255      Y:00009E Y:00009E                   DC      CLK3+DLY4+FSYNC+F1+F2
2256      Y:00009F Y:00009F                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2257      Y:0000A0 Y:0000A0                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2258      Y:0000A1 Y:0000A1                   DC      CLK3+DLY2+FSYNC+00+F2
2259      Y:0000A2 Y:0000A2                   DC      CLK3+DLY0+FSYNC+F1+F2
2260                                END_CLOCK_CDS_RESET_ROW_4
2261   
2262                                RESET_ROW_12
2263      Y:0000A3 Y:0000A3                   DC      END_RESET_ROW_12-RESET_ROW_12-1
2264      Y:0000A4 Y:0000A4                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2265      Y:0000A5 Y:0000A5                   DC      CLK3+DLY0+00000+F1+F2
2266      Y:0000A6 Y:0000A6                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2267      Y:0000A7 Y:0000A7                   DC      CLK3+DLY4+FSYNC+F1+F2
2268      Y:0000A8 Y:0000A8                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2269      Y:0000A9 Y:0000A9                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2270                                END_RESET_ROW_12
2271   
2272                                RESET_ROW_34
2273      Y:0000AA Y:0000AA                   DC      END_RESET_ROW_34-RESET_ROW_34-1
2274      Y:0000AB Y:0000AB                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2275      Y:0000AC Y:0000AC                   DC      CLK3+DLY0+00000+F1+F2
2276      Y:0000AD Y:0000AD                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
2277      Y:0000AE Y:0000AE                   DC      CLK3+DLY4+FSYNC+F1+F2
2278      Y:0000AF Y:0000AF                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2279      Y:0000B0 Y:0000B0                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2280                                END_RESET_ROW_34
2281   
2282                                CLOCK_COLUMN
2283      Y:0000B1 Y:0000B1                   DC      END_CLOCK_COLUMN-CLOCK_COLUMN-1
2284      Y:0000B2 Y:0000B2                   DC      CLK3+DLYA+FSYNC+F1+00
2285      Y:0000B3 Y:0000B3                   DC      CLK3+DLYB+FSYNC+F1+F2
2286      Y:0000B4 Y:0000B4                   DC      CLK3+DLYA+FSYNC+00+F2
2287      Y:0000B5 Y:0000B5                   DC      CLK3+DLYB+FSYNC+F1+F2
2288                                END_CLOCK_COLUMN
2289   
2290                                ; Video processor bit definitions
2291   
2292                                ;       Bit #3 = Move A/D data to FIFO  (high going edge)
2293                                ;       Bit #2 = A/D Convert            (low going edge to start conversion)
2294                                ;       Bit #1 = Reset Integrator       (=0 to reset)
2295                                ;       Bit #0 = Integrate              (=0 to integrate)
2296   
2297                                ; STARTS HERE THE READOUT OF 6DS
2298      080000                    DTW       EQU     $080000                           ;  Tw Fast Sync Time (320ns + 40ns exec = 36
0ns)
2299      0F0000                    PAD_TIM   EQU     $0F0000                           ;  Pixel PAD Time                       (640
ns)
2300      0F0000                    ADC_TIM   EQU     $0F0000                           ;  Pixel PAD Time                       (640
ns)
2301      180000                    INT_TIM   EQU     $180000                           ;  Pixel Sample Time            (1000ns)
2302      8C0000                    SXM_TIM   EQU     $8C0000                           ;  Pixel Transmit Delay         (5640ns)NOT 
USED
2303      040000                    ADC_CNV   EQU     $040000                           ;  ADC Sample Time                      (100
ns)
2304      000000                    STL_TIM   EQU     $000000                           ;  A Generic Settling time      (0ns)
2305      180000                    RST_TIM   EQU     $180000                           ;  Reset Time reduced           (1000ns)
2306      000000                    STP_TIM   EQU     $000000                           ;  Stop Reseting
2307      080000                    FIP_TIM   EQU     $080000                           ;  $08 seems ok but have to test with signal
 as it's settling time of integrator stage
2308      000000                    RST_DLY   EQU     $000000                           ;  Delay before resetting the integrator
2309      000000                    PIX_RTE   EQU     $000000                           ;  Delay to adjust the pixel rate only for X
DS not needed for XINT_XDS
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 41



2310      0C0000                    ADC_HLD   EQU     $0C0000                           ;  Wait for ADC to setlle before moving to F
IFO (Hold)  (480ns)
2311      040000                    RST_STL   EQU     $040000                           ;  Wait after reset of Integrator before Int
egration (100ns)
2312      080000                    INT_STL   EQU     $080000                           ;  Wait for Integrator output to settle befo
re A2D (360ns)
2313   
2314                                ; Define CLOCK as a macro to produce in-line code to reduce execution time
2315                                ; Here we do INT and A2D 6 times successively
2316                                 RD_COL_MACRO1
2317                                          MACRO
2318 m                                        DC      VIDEO+RST_DLY+%0111               ; Wait 4 Reset Integrator       40ns
2319 m                                        DC      VIDEO+RST_TIM+%0101               ; Reset Integrator                      1000
ns
2320 m                                        DC      VIDEO+RST_STL+%0111               ; Stop Reset & wait                         
    100ns
2321 m                                        DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1                     1000
ns
2322 m                                        DC      VIDEO+INT_STL+%0111               ; Stop Integration & wait               360n
s   <----Leach March 5, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1           40ns
2323 m                                        DC      VIDEO+ADC_CNV+%0011               ; A/D Conversion                        100n
s
2324 m                                        DC      VIDEO+ADC_HLD+%0111               ; Hold A/D convert                      480n
s
2325 m                                        DC      VIDEO+STL_TIM+%1111               ; Move A/D data FIFO                    40ns
2326 m                              ;       DC      SXMIT                           ; SXMIT                                         
        40ns
2327 m                                        ENDM
2328   
2329                                 RD_COL_MACRO2
2330                                          MACRO
2331 m                                        DC      VIDEO+RST_DLY+%0111               ; Wait 4 Reset Integrator       40ns
2332 m                                        DC      VIDEO+RST_TIM+%0101               ; Reset Integrator                      1000
ns
2333 m                                        DC      VIDEO+RST_STL+%0111               ; Stop Reset & wait                         
    100ns
2334 m                                        DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1                     1000
ns
2335 m                                        DC      VIDEO+INT_STL+%0111               ; Stop Integration & wait               360n
s   <----Leach March 5, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1           40ns
2336 m                                        DC      VIDEO+ADC_CNV+%0011               ; A/D Conversion                        100n
s
2337 m                                        DC      VIDEO+ADC_HLD+%0111               ; Hold A/D convert                      480n
s
2338 m                                        DC      VIDEO+STL_TIM+%1111               ; Move A/D data FIFO                    40ns
2339 m                                        DC      SXMIT                             ; SXMIT                                     
    40ns
2340 m                                        ENDM
2341   
2342                                ; This code initiates the pipeline for each row - no image transmission yet
2343                                ; Modified by L. Boucher for 6 Digital Samples
2344                                RD_COL_PIPELINE
2345      Y:0000B6 Y:0000B6                   DC      END_RD_COL_PIPELINE-RD_COL_PIPELINE-1
2346      Y:0000B7 Y:0000B7                   DC      CLK3+000+FSYNC+F1+F2              ; trick to loop with rd_cols
2347      Y:0000B8 Y:0000B8                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1                        40ns
2348   
2349                                          RD_COL_MACRO2                             ; Macro
2359                                          RD_COL_MACRO2
2369                                          RD_COL_MACRO2
2379                                          RD_COL_MACRO2
2389                                          RD_COL_MACRO2
2399                                          RD_COL_MACRO2
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 42



2409   
2410      Y:0000EF Y:0000EF                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1                      360n
s
2411      Y:0000F0 Y:0000F0                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2                        40ns
2412   
2413                                          RD_COL_MACRO2                             ; Macro
2423                                          RD_COL_MACRO2
2433                                          RD_COL_MACRO2
2443                                          RD_COL_MACRO2
2453                                          RD_COL_MACRO2
2463                                          RD_COL_MACRO2
2473   
2474                                END_RD_COL_PIPELINE
2475   
2476                                RD_COLS1  MACRO
2477 m                                        DC      VIDEO+RST_DLY+%0111               ; Wait 4 Reset Integrator       40ns
2478 m                                        DC      VIDEO+RST_TIM+%0101               ; Reset Integrator                      1000
ns
2479 m                                        DC      VIDEO+RST_STL+%0111               ; Stop Reset & wait                         
    100ns
2480 m                                        DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1                     1000
ns
2481 m                                        DC      VIDEO+INT_STL+%0111               ; Stop Integration & wait               360n
s   <----Leach March 5, 2020DC      VIDEO+ADC_CNV+%0011             ; Start A/D cnv Pix 1 Sample1           40ns
2482 m                                        DC      VIDEO+ADC_CNV+%0011               ; A/D Conversion                        100n
s
2483 m                                        DC      VIDEO+ADC_HLD+%0111               ; Hold A/D convert                      480n
s
2484 m                                        DC      VIDEO+STL_TIM+%1111               ; Move A/D data FIFO                    40ns
2485 m                                        DC      SXMIT                             ; SXMIT                                     
    40ns
2486 m                                        ENDM
2487   
2488                                ; This code reads out most of the array, with full image transmission
2489                                ; Modified by L. Boucher for 6 Digital Samples
2490                                RD_COLS
2491      Y:000127 Y:000127                   DC      END_RD_COLS-RD_COLS-1             ;
2492      Y:000128 Y:000128                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 2                      360n
s
2493      Y:000129 Y:000129                   DC      CLK3+000+FSYNC+F1+00              ; Select next Pixel                     40ns
2494   
2495                                          RD_COLS1                                  ; Macro
2505                                          RD_COLS1
2515                                          RD_COLS1
2525                                          RD_COLS1
2535                                          RD_COLS1
2545                                          RD_COLS1
2555   
2556      Y:000160 Y:000160                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3                      (240
ns)
2557      Y:000161 Y:000161                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 4                        (40n
s)
2558   
2559                                          RD_COLS1                                  ; Macro
2569                                          RD_COLS1
2579                                          RD_COLS1
2589                                          RD_COLS1
2599                                          RD_COLS1
2609                                          RD_COLS1
2619   
2620                                END_RD_COLS
2621   
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 43



2622                                ; This transmits the last pixels in each row, emptying the pipeline
2623                                ; Modified by L. Boucher for 6 Digital Samples
2624                                LAST_8INROW
2625      Y:000198 Y:000198                   DC      END_LAST_8INROW-LAST_8INROW
2626      Y:000199 Y:000199                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel                        360n
s
2627      Y:00019A Y:00019A                   DC      CLK3+000+FSYNC+F1+00              ; Select next Pixel                     40ns
2628   
2629                                          RD_COLS1                                  ; Macro
2639                                          RD_COLS1
2649                                          RD_COLS1
2659                                          RD_COLS1
2669                                          RD_COLS1
2679                                          RD_COLS1
2689   
2690                                END_LAST_8INROW
2691   
2692                                ; ENDS HERE THE REAOUDT OF THE 6DS
2693   
2694   
2695                                ; This code intiates the pipeline of pixels for each row
2696                                RD_NTX_PIPELINE
2697      Y:0001D1 Y:0001D1                   DC      END_RD_NTX_PIPELINE-RD_NTX_PIPELINE-1
2698      Y:0001D2 Y:0001D2                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1        40ns
2699      Y:0001D3 Y:0001D3                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
2700      Y:0001D4 Y:0001D4                   DC      VIDEO+ADC_TIM+%0111               ; Hold No Pixel        1000ns
2701      Y:0001D5 Y:0001D5                   DC      VIDEO+STL_TIM+%0101               ; Move No Pixel          400ns
2702      Y:0001D6 Y:0001D6                   DC      VIDEO+$000000+%0101               ; Place for SXMIT        40ns
2703      Y:0001D7 Y:0001D7                   DC      VIDEO+SXM_TIM+%0101               ; Settling time            3880ns
2704      Y:0001D8 Y:0001D8                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting          40ns
2705      Y:0001D9 Y:0001D9                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1    1000ns
2706      Y:0001DA Y:0001DA                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
2707      Y:0001DB Y:0001DB                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D cnv Pix 1    40ns
2708      Y:0001DC Y:0001DC                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1      360ns
2709      Y:0001DD Y:0001DD                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2         40ns
2710      Y:0001DE Y:0001DE                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
2711      Y:0001DF Y:0001DF                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert     1000ns
2712      Y:0001E0 Y:0001E0                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data FIFO     40ns
2713      Y:0001E1 Y:0001E1                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2714      Y:0001E2 Y:0001E2                   DC      VIDEO+SXM_TIM+%0101               ; Settling time            3880ns
2715      Y:0001E3 Y:0001E3                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting          40ns
2716      Y:0001E4 Y:0001E4                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3    1000ns
2717      Y:0001E5 Y:0001E5                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
2718      Y:0001E6 Y:0001E6                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert      40ns
2719      Y:0001E7 Y:0001E7                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3      360ns
2720                                END_RD_NTX_PIPELINE
2721   
2722                                RD_NTX
2723      Y:0001E8 Y:0001E8                   DC      END_RD_NTX-RD_NTX-1
2724      Y:0001E9 Y:0001E9                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2725      Y:0001EA Y:0001EA                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2726      Y:0001EB Y:0001EB                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2727      Y:0001EC Y:0001EC                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2728      Y:0001ED Y:0001ED                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2729      Y:0001EE Y:0001EE                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2730      Y:0001EF Y:0001EF                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2731      Y:0001F0 Y:0001F0                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2732      Y:0001F1 Y:0001F1                   DC      VIDEO+$000000+%0111               ; Stop Integration
2733      Y:0001F2 Y:0001F2                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (400ns)
2734      Y:0001F3 Y:0001F3                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2735      Y:0001F4 Y:0001F4                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 3 (40ns)
2736      Y:0001F5 Y:0001F5                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 44



2737      Y:0001F6 Y:0001F6                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 2 (1us)
2738      Y:0001F7 Y:0001F7                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 2 (40ns)
2739      Y:0001F8 Y:0001F8                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2740      Y:0001F9 Y:0001F9                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2741      Y:0001FA Y:0001FA                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2742      Y:0001FB Y:0001FB                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3 (760ns)
2743      Y:0001FC Y:0001FC                   DC      VIDEO+$000000+%0111               ; Stop Integration
2744      Y:0001FD Y:0001FD                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 3 (400ns)
2745      Y:0001FE Y:0001FE                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3 (240ns)
2746                                END_RD_NTX
2747   
2748                                LAST_NTX_8INROW
2749      Y:0001FF Y:0001FF                   DC      END_LAST_NTX_8INROW-LAST_NTX_8INROW
2750      Y:000200 Y:000200                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2751      Y:000201 Y:000201                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2752      Y:000202 Y:000202                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2753      Y:000203 Y:000203                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2754      Y:000204 Y:000204                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2755      Y:000205 Y:000205                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2756      Y:000206 Y:000206                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2757      Y:000207 Y:000207                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2758      Y:000208 Y:000208                   DC      VIDEO+$000000+%0111               ; Stop Integration
2759      Y:000209 Y:000209                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (40+40ns)
2760      Y:00020A Y:00020A                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2761                                END_LAST_NTX_8INROW
2762   
2763      Y:00020B Y:00020B         CLOCKS    DC      END_CLOCKS-CLOCKS-1
2764      Y:00020C Y:00020C                   DC      $2A0080                           ; DAC = unbuffered mode
2765      Y:00020D Y:00020D                   DC      $200100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #1, SSYNC
2766      Y:00020E Y:00020E                   DC      $200200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2767      Y:00020F Y:00020F                   DC      $200400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #2, S1
2768      Y:000210 Y:000210                   DC      $200800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2769      Y:000211 Y:000211                   DC      $202000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #3, S2
2770      Y:000212 Y:000212                   DC      $204000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2771      Y:000213 Y:000213                   DC      $208000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #4, SOE
2772      Y:000214 Y:000214                   DC      $210000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2773      Y:000215 Y:000215                   DC      $220100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #5, RDES
2774      Y:000216 Y:000216                   DC      $220200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2775      Y:000217 Y:000217                   DC      $220400+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #6, VRSTOFF
2776      Y:000218 Y:000218                   DC      $220800+@CVI(((VRST_LO+Vmax)/Vmax)*255) ;   = VrstG
2777      Y:000219 Y:000219                   DC      $222000+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #7, VRSTR
2778      Y:00021A Y:00021A                   DC      $224000+@CVI(((VRST_LO+Vmax)/Vmax)*255)
2779      Y:00021B Y:00021B                   DC      $228000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #8, VROWON
2780      Y:00021C Y:00021C                   DC      $230000+@CVI(((VRW_LO+Vmax)/Vmax)*255)
2781      Y:00021D Y:00021D                   DC      $240100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #9, Unused
2782      Y:00021E Y:00021E                   DC      $240200+@CVI(((ZERO+Vmax)/Vmax)*255)
2783      Y:00021F Y:00021F                   DC      $240400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #10, Unused
2784      Y:000220 Y:000220                   DC      $240800+@CVI(((ZERO+Vmax)/Vmax)*255)
2785      Y:000221 Y:000221                   DC      $242000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #11, Unused
2786      Y:000222 Y:000222                   DC      $244000+@CVI(((ZERO+Vmax)/Vmax)*255)
2787      Y:000223 Y:000223                   DC      $248000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #12, Unused
2788      Y:000224 Y:000224                   DC      $250000+@CVI(((ZERO+Vmax)/Vmax)*255)
2789   
2790                                ; Upper bank
2791      Y:000225 Y:000225                   DC      $260100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #13, FSYNC
2792      Y:000226 Y:000226                   DC      $260200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2793      Y:000227 Y:000227                   DC      $260400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #14, F1
2794      Y:000228 Y:000228                   DC      $260800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2795      Y:000229 Y:000229                   DC      $262000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #15, F2
2796      Y:00022A Y:00022A                   DC      $264000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2797      Y:00022B Y:00022B                   DC      $268000+@CVI(((ZERO+Vmax)/Vmax)*255)
2798      Y:00022C Y:00022C                   DC      $270000+@CVI(((ZERO+Vmax)/Vmax)*255)
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 45



2799      Y:00022D Y:00022D                   DC      $280100+@CVI(((ZERO+Vmax)/Vmax)*255)
2800      Y:00022E Y:00022E                   DC      $280200+@CVI(((ZERO+Vmax)/Vmax)*255)
2801      Y:00022F Y:00022F                   DC      $280400+@CVI(((ZERO+Vmax)/Vmax)*255)
2802      Y:000230 Y:000230                   DC      $280800+@CVI(((ZERO+Vmax)/Vmax)*255)
2803      Y:000231 Y:000231                   DC      $282000+@CVI(((ZERO+Vmax)/Vmax)*255)
2804      Y:000232 Y:000232                   DC      $284000+@CVI(((ZERO+Vmax)/Vmax)*255)
2805      Y:000233 Y:000233                   DC      $288000+@CVI(((ZERO+Vmax)/Vmax)*255)
2806      Y:000234 Y:000234                   DC      $290000+@CVI(((ZERO+Vmax)/Vmax)*255)
2807      Y:000235 Y:000235                   DC      $2A0100+@CVI(((ZERO+Vmax)/Vmax)*255)
2808      Y:000236 Y:000236                   DC      $2A0200+@CVI(((ZERO+Vmax)/Vmax)*255)
2809      Y:000237 Y:000237                   DC      $2A0400+@CVI(((ZERO+Vmax)/Vmax)*255)
2810      Y:000238 Y:000238                   DC      $2A0800+@CVI(((ZERO+Vmax)/Vmax)*255)
2811      Y:000239 Y:000239                   DC      $2A2000+@CVI(((ZERO+Vmax)/Vmax)*255)
2812      Y:00023A Y:00023A                   DC      $2A4000+@CVI(((ZERO+Vmax)/Vmax)*255)
2813      Y:00023B Y:00023B                   DC      $2A8000+@CVI(((ZERO+Vmax)/Vmax)*255)
2814      Y:00023C Y:00023C                   DC      $2B0000+@CVI(((ZERO+Vmax)/Vmax)*255)
2815                                END_CLOCKS
2816   
2817                                ; Video offset assignments
2818      Y:00023D Y:00023D         BIASES    DC      END_BIASES-BIASES-1
2819   
2820                                ; Integrator gain and a few other things
2821                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2822                                ;       DC      $0c3000                 ; Integrate 2, High gain
2823      Y:00023E Y:00023E                   DC      $0c3000                           ; Integrate 2, High gain
2824      Y:00023F Y:00023F                   DC      $1c3000                           ; Integrate 2, High gain
2825      Y:000240 Y:000240                   DC      $2c3000                           ; Integrate 2, High gain
2826      Y:000241 Y:000241                   DC      $3c3000                           ; Integrate 2, High gain
2827      Y:000242 Y:000242                   DC      $0c1000                           ; Reset image data FIFOs
2828      Y:000243 Y:000243                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2829      Y:000244 Y:000244                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2830      Y:000245 Y:000245                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2831      Y:000246 Y:000246                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2832   
2833                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2834      Y:000247 Y:000247                   DC      $0e0000+OFFSET0                   ; Output #0
2835      Y:000248 Y:000248                   DC      $0e4000+OFFSET1                   ; Output #1
2836      Y:000249 Y:000249                   DC      $0e8000+OFFSET2                   ; Output #2
2837      Y:00024A Y:00024A                   DC      $0ec000+OFFSET3                   ; Output #3
2838      Y:00024B Y:00024B                   DC      $0f0000+OFFSET4                   ; Output #4
2839      Y:00024C Y:00024C                   DC      $0f4000+OFFSET5                   ; Output #5
2840      Y:00024D Y:00024D                   DC      $0f8000+OFFSET6                   ; Output #6
2841      Y:00024E Y:00024E                   DC      $0fc000+OFFSET7                   ; Output #7
2842   
2843                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2844      Y:00024F Y:00024F                   DC      $1e0000+OFFSET8                   ; Output #0
2845      Y:000250 Y:000250                   DC      $1e4000+OFFSET9                   ; Output #1
2846      Y:000251 Y:000251                   DC      $1e8000+OFFSET10                  ; Output #2
2847      Y:000252 Y:000252                   DC      $1ec000+OFFSET11                  ; Output #3
2848      Y:000253 Y:000253                   DC      $1f0000+OFFSET12                  ; Output #4
2849      Y:000254 Y:000254                   DC      $1f4000+OFFSET13                  ; Output #5
2850      Y:000255 Y:000255                   DC      $1f8000+OFFSET14                  ; Output #6
2851      Y:000256 Y:000256                   DC      $1fc000+OFFSET15                  ; Output #7
2852   
2853                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2854      Y:000257 Y:000257                   DC      $2e0000+OFFSET16                  ; Output #0
2855      Y:000258 Y:000258                   DC      $2e4000+OFFSET17                  ; Output #1
2856      Y:000259 Y:000259                   DC      $2e8000+OFFSET18                  ; Output #2
2857      Y:00025A Y:00025A                   DC      $2ec000+OFFSET19                  ; Output #3
2858      Y:00025B Y:00025B                   DC      $2f0000+OFFSET20                  ; Output #4
2859      Y:00025C Y:00025C                   DC      $2f4000+OFFSET21                  ; Output #5
2860      Y:00025D Y:00025D                   DC      $2f8000+OFFSET22                  ; Output #6
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  AladdinIII.waveforms  Page 46



2861      Y:00025E Y:00025E                   DC      $2fc000+OFFSET23                  ; Output #7
2862   
2863                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2864      Y:00025F Y:00025F                   DC      $3e0000+OFFSET24                  ; Output #0
2865      Y:000260 Y:000260                   DC      $3e4000+OFFSET25                  ; Output #1
2866      Y:000261 Y:000261                   DC      $3e8000+OFFSET26                  ; Output #2
2867      Y:000262 Y:000262                   DC      $3ec000+OFFSET27                  ; Output #3
2868      Y:000263 Y:000263                   DC      $3f0000+OFFSET28                  ; Output #4
2869      Y:000264 Y:000264                   DC      $3f4000+OFFSET29                  ; Output #5
2870      Y:000265 Y:000265                   DC      $3f8000+OFFSET30                  ; Output #6
2871      Y:000266 Y:000266                   DC      $3fc000+OFFSET31                  ; Output #7
2872   
2873   
2874                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2875                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2876                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2877      Y:000267 Y:000267                   DC      $0c4000+@CVI((VDDOUT+Vmax2)/Vmax3*4095) ; Pin #17 VDDOUT
2878      Y:000268 Y:000268                   DC      $0c8000+@CVI((VDDUC+Vmax2)/Vmax3*4095) ; Pin #33 VDDUC
2879      Y:000269 Y:000269                   DC      $0cc000+@CVI((IREF+Vmax2)/Vmax3*4095) ; Pin #16 IREF
2880      Y:00026A Y:00026A                   DC      $0d0000+@CVI((VDETCOM+Vmax2)/Vmax3*4095) ; Pin #32 VDETCOM
2881      Y:00026B Y:00026B                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2882      Y:00026C Y:00026C                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2883      Y:00026D Y:00026D                   DC      $0dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2884   
2885                                ; Video board #2
2886      Y:00026E Y:00026E                   DC      $1c4000+@CVI((VDDCL+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2887      Y:00026F Y:00026F                   DC      $1c8000+@CVI((VROWOFF+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2888      Y:000270 Y:000270                   DC      $1cc000+@CVI((VGGCL+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2889      Y:000271 Y:000271                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2890      Y:000272 Y:000272                   DC      $1d4000+@CVI((VNCOL+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2891      Y:000273 Y:000273                   DC      $1d8000+@CVI((VNROW+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2892      Y:000274 Y:000274                   DC      $1dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2893   
2894                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2895      Y:000275 Y:000275                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2896      Y:000276 Y:000276                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2897      Y:000277 Y:000277                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2898      Y:000278 Y:000278                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2899      Y:000279 Y:000279                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2900      Y:00027A Y:00027A                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2901      Y:00027B Y:00027B                   DC      $2dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2902   
2903                                ; Video board #4
2904      Y:00027C Y:00027C                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2905      Y:00027D Y:00027D                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2906      Y:00027E Y:00027E                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2907      Y:00027F Y:00027F                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2908      Y:000280 Y:000280                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2909      Y:000281 Y:000281                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2910      Y:000282 Y:000282                   DC      $3dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2911                                END_BIASES
2912   
2913                                 END_APPLICATON_Y_MEMORY
2914      000283                              EQU     @LCV(L)
2915   
2916                                ; End of program
2917                                          END

Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:51:24  tim.asm  Page 47



0    Errors
0    Warnings


