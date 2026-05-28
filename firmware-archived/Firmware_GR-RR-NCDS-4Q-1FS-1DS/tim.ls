Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 1



1                                 COMMENT *
2      
3                          This file is used to generate DSP code for the Gen III = ARC-22
4                                  250 MHz timing boards to operate one quadrant of an
5                                  Aladdin III infrared array with one 8-channel ARC-46 video
6                                  board.
7                             *
8      
9                                    PAGE    132                               ; Printronix page width - 132 columns
10     
11                         ; Include the boot and header files so addressing is easy
12                                   INCLUDE "timboot.asm"
13                         ;  This file is used to generate boot DSP code for the Gen III 250 MHz fiber
14                         ;       optic timing board = ARC22 using a DSP56303 as its main processor.
15     
16                         ; Various addressing control registers
17        FFFFFB           BCR       EQU     $FFFFFB                           ; Bus Control Register
18        FFFFF9           AAR0      EQU     $FFFFF9                           ; Address Attribute Register, channel 0
19        FFFFF8           AAR1      EQU     $FFFFF8                           ; Address Attribute Register, channel 1
20        FFFFF7           AAR2      EQU     $FFFFF7                           ; Address Attribute Register, channel 2
21        FFFFF6           AAR3      EQU     $FFFFF6                           ; Address Attribute Register, channel 3
22        FFFFFD           PCTL      EQU     $FFFFFD                           ; PLL control register
23        FFFFFE           IPRP      EQU     $FFFFFE                           ; Interrupt Priority register - Peripheral
24        FFFFFF           IPRC      EQU     $FFFFFF                           ; Interrupt Priority register - Core
25     
26                         ; Port E is the Synchronous Communications Interface (SCI) port
27        FFFF9F           PCRE      EQU     $FFFF9F                           ; Port Control Register
28        FFFF9E           PRRE      EQU     $FFFF9E                           ; Port Direction Register
29        FFFF9D           PDRE      EQU     $FFFF9D                           ; Port Data Register
30        FFFF9C           SCR       EQU     $FFFF9C                           ; SCI Control Register
31        FFFF9B           SCCR      EQU     $FFFF9B                           ; SCI Clock Control Register
32     
33        FFFF9A           SRXH      EQU     $FFFF9A                           ; SCI Receive Data Register, High byte
34        FFFF99           SRXM      EQU     $FFFF99                           ; SCI Receive Data Register, Middle byte
35        FFFF98           SRXL      EQU     $FFFF98                           ; SCI Receive Data Register, Low byte
36     
37        FFFF97           STXH      EQU     $FFFF97                           ; SCI Transmit Data register, High byte
38        FFFF96           STXM      EQU     $FFFF96                           ; SCI Transmit Data register, Middle byte
39        FFFF95           STXL      EQU     $FFFF95                           ; SCI Transmit Data register, Low byte
40     
41        FFFF94           STXA      EQU     $FFFF94                           ; SCI Transmit Address Register
42        FFFF93           SSR       EQU     $FFFF93                           ; SCI Status Register
43     
44        000009           SCITE     EQU     9                                 ; X:SCR bit set to enable the SCI transmitter
45        000008           SCIRE     EQU     8                                 ; X:SCR bit set to enable the SCI receiver
46        000000           TRNE      EQU     0                                 ; This is set in X:SSR when the transmitter
47                                                                             ;  shift and data registers are both empty
48        000001           TDRE      EQU     1                                 ; This is set in X:SSR when the transmitter
49                                                                             ;  data register is empty
50        000002           RDRF      EQU     2                                 ; X:SSR bit set when receiver register is full
51        00000F           SELSCI    EQU     15                                ; 1 for SCI to backplane, 0 to front connector
52     
53     
54                         ; ESSI Flags
55        000006           TDE       EQU     6                                 ; Set when transmitter data register is empty
56        000007           RDF       EQU     7                                 ; Set when receiver is full of data
57        000010           TE        EQU     16                                ; Transmitter enable
58     
59                         ; Phase Locked Loop initialization
60        050003           PLL_INIT  EQU     $050003                           ; PLL = 25 MHz x 2 = 100 MHz
61     
62                         ; Port B general purpose I/O
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 2



63        FFFFC4           HPCR      EQU     $FFFFC4                           ; Control register (bits 1-6 cleared for GPIO)
64        FFFFC9           HDR       EQU     $FFFFC9                           ; Data register
65        FFFFC8           HDDR      EQU     $FFFFC8                           ; Data Direction Register bits (=1 for output)
66     
67                         ; Port C is Enhanced Synchronous Serial Port 0 = ESSI0
68        FFFFBF           PCRC      EQU     $FFFFBF                           ; Port C Control Register
69        FFFFBE           PRRC      EQU     $FFFFBE                           ; Port C Data direction Register
70        FFFFBD           PDRC      EQU     $FFFFBD                           ; Port C GPIO Data Register
71        FFFFBC           TX00      EQU     $FFFFBC                           ; Transmit Data Register #0
72        FFFFB8           RX0       EQU     $FFFFB8                           ; Receive data register
73        FFFFB7           SSISR0    EQU     $FFFFB7                           ; Status Register
74        FFFFB6           CRB0      EQU     $FFFFB6                           ; Control Register B
75        FFFFB5           CRA0      EQU     $FFFFB5                           ; Control Register A
76     
77                         ; Port D is Enhanced Synchronous Serial Port 1 = ESSI1
78        FFFFAF           PCRD      EQU     $FFFFAF                           ; Port D Control Register
79        FFFFAE           PRRD      EQU     $FFFFAE                           ; Port D Data direction Register
80        FFFFAD           PDRD      EQU     $FFFFAD                           ; Port D GPIO Data Register
81        FFFFAC           TX10      EQU     $FFFFAC                           ; Transmit Data Register 0
82        FFFFA7           SSISR1    EQU     $FFFFA7                           ; Status Register
83        FFFFA6           CRB1      EQU     $FFFFA6                           ; Control Register B
84        FFFFA5           CRA1      EQU     $FFFFA5                           ; Control Register A
85     
86                         ; Timer module addresses
87        FFFF8F           TCSR0     EQU     $FFFF8F                           ; Timer control and status register
88        FFFF8E           TLR0      EQU     $FFFF8E                           ; Timer load register = 0
89        FFFF8D           TCPR0     EQU     $FFFF8D                           ; Timer compare register = exposure time
90        FFFF8C           TCR0      EQU     $FFFF8C                           ; Timer count register = elapsed time
91        FFFF83           TPLR      EQU     $FFFF83                           ; Timer prescaler load register => milliseconds
92        FFFF82           TPCR      EQU     $FFFF82                           ; Timer prescaler count register
93        000000           TIM_BIT   EQU     0                                 ; Set to enable the timer
94        000009           TRM       EQU     9                                 ; Set to enable the timer preloading
95        000015           TCF       EQU     21                                ; Set when timer counter = compare register
96     
97                         ; Board specific addresses and constants
98        FFFFF1           RDFO      EQU     $FFFFF1                           ; Read incoming fiber optic data byte
99        FFFFF2           WRFO      EQU     $FFFFF2                           ; Write fiber optic data replies
100       FFFFF3           WRSS      EQU     $FFFFF3                           ; Write switch state
101       FFFFF5           WRLATCH   EQU     $FFFFF5                           ; Write to a latch
102       010000           RDAD      EQU     $010000                           ; Read A/D values into the DSP
103       000009           EF        EQU     9                                 ; Serial receiver empty flag
104    
105                        ; DSP port A bit equates
106       000000           PWROK     EQU     0                                 ; Power control board says power is OK
107       000001           LED1      EQU     1                                 ; Control one of two LEDs
108       000002           LVEN      EQU     2                                 ; Low voltage power enable
109       000003           HVEN      EQU     3                                 ; High voltage power enable
110       00000E           SSFHF     EQU     14                                ; Switch state FIFO half full flag
111       00000A           EXT_IN0   EQU     10                                ; External digital I/O to the timing board
112       00000B           EXT_IN1   EQU     11
113       00000C           EXT_OUT0  EQU     12
114       00000D           EXT_OUT1  EQU     13
115    
116                        ; Port D equate
117       000001           SSFEF     EQU     1                                 ; Switch state FIFO empty flag
118    
119                        ; Other equates
120       000002           WRENA     EQU     2                                 ; Enable writing to the EEPROM
121    
122                        ; Latch U25 bit equates
123       000000           CDAC      EQU     0                                 ; Clear the analog board DACs
124       000002           ENCK      EQU     2                                 ; Enable the clock outputs
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 3



125       000004           SHUTTER   EQU     4                                 ; Control the shutter
126       000005           TIM_U_RST EQU     5                                 ; Reset the utility board
127    
128                        ; Software status bits, defined at X:<STATUS = X:0
129       000000           ST_RCV    EQU     0                                 ; Set to indicate word is from SCI = utility board
130       000002           IDLMODE   EQU     2                                 ; Set if need to idle after readout
131       000003           ST_SHUT   EQU     3                                 ; Set to indicate shutter is closed, clear for open
132       000004           ST_RDC    EQU     4                                 ; Set if executing 'RDC' command - reading out
133       000005           SPLIT_S   EQU     5                                 ; Set if split serial
134       000006           SPLIT_P   EQU     6                                 ; Set if split parallel
135       000007           MPP       EQU     7                                 ; Set if parallels are in MPP mode
136       000008           NOT_CLR   EQU     8                                 ; Set if not to clear CCD before exposure
137       00000A           TST_IMG   EQU     10                                ; Set if controller is to generate a test image
138       00000B           SHUT      EQU     11                                ; Set if opening shutter at beginning of exposure
139       00000C           ST_DITH   EQU     12                                ; Set if to dither during exposure
140       00000D           ST_SYNC   EQU     13                                ; Set if starting exposure on SYNC = high signal
141       00000E           ST_CNRD   EQU     14                                ; Set if in continous readout mode
142       00000F           ST_DIRTY  EQU     15                                ; Set if waveform tables need to be updated
143       000010           ST_SA     EQU     16                                ; Set if in subarray readout mode
144       000011           ST_CDS    EQU     17                                ; Set for correlated double sample readout
145       000012           ST_RRR    EQU     18                                ; Set if row-by-row reset while reading out and expos
ing
146    
147                        ; Address for the table containing the incoming SCI words
148       000400           SCI_TABLE EQU     $400
149    
150    
151                        ; Specify controller configuration bits of the X:STATUS word
152                        ;   to describe the software capabilities of this application file
153                        ; The bit is set (=1) if the capability is supported by the controller
154    
155    
156                                COMMENT *
157    
158                        BIT #'s         FUNCTION
159                        2,1,0           Video Processor
160                                                000     ARC41, CCD Rev. 3
161                                                001     CCD Gen I
162                                                010     ARC42, dual readout CCD
163                                                011     ARC44, 4-readout IR coadder
164                                                100     ARC45. dual readout CCD
165                                                101     ARC46 = 8-channel IR
166                                                110     ARC48 = 8 channel CCD
167                                                111     ARC47 = 4-channel CCD
168    
169                        4,3             Timing Board
170                                                00      ARC20, Rev. 4, Gen II
171                                                01      Gen I
172                                                10      ARC22, Gen III, 250 MHz
173    
174                        6,5             Utility Board
175                                                00      No utility board
176                                                01      ARC50
177    
178                        7               Shutter
179                                                0       No shutter support
180                                                1       Yes shutter support
181    
182                        9,8             Temperature readout
183                                                00      No temperature readout
184                                                01      Polynomial Diode calibration
185                                                10      Linear temperature sensor calibration
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 4



186    
187                        10              Subarray readout
188                                                0       Not supported
189                                                1       Yes supported
190    
191                        11              Binning
192                                                0       Not supported
193                                                1       Yes supported
194    
195                        12              Split-Serial readout
196                                                0       Not supported
197                                                1       Yes supported
198    
199                        13              Split-Parallel readout
200                                                0       Not supported
201                                                1       Yes supported
202    
203                        14              MPP = Inverted parallel clocks
204                                                0       Not supported
205                                                1       Yes supported
206    
207                        16,15           Clock Driver Board
208                                                00      ARC30 or ARC31
209                                                01      ARC32, CCD and IR
210                                                11      No clock driver board (Gen I)
211    
212                        19,18,17                Special implementations
213                                                000     Somewhere else
214                                                001     Mount Laguna Observatory
215                                                010     NGST Aladdin
216                                                xxx     Other
217                                *
218    
219                        CCDVIDREV3B
220       000000                     EQU     $000000                           ; CCD Video Processor Rev. 3
221       000000           ARC41     EQU     $000000
222       000001           VIDGENI   EQU     $000001                           ; CCD Video Processor Gen I
223       000002           IRREV4    EQU     $000002                           ; IR Video Processor Rev. 4
224       000002           ARC42     EQU     $000002
225       000003           COADDER   EQU     $000003                           ; IR Coadder
226       000003           ARC44     EQU     $000003
227       000004           CCDVIDREV5 EQU    $000004                           ; Differential input CCD video Rev. 5
228       000004           ARC45     EQU     $000004
229       000005           ARC46     EQU     $000005                           ; 8-channel IR video board
230       000006           ARC48     EQU     $000006                           ; 8-channel CCD video board
231       000007           ARC47     EQU     $000007                           ; 4-channel CCD video board
232       000000           TIMREV4   EQU     $000000                           ; Timing Revision 4 = 50 MHz
233       000000           ARC20     EQU     $000000
234       000008           TIMGENI   EQU     $000008                           ; Timing Gen I = 40 MHz
235       000010           TIMREV5   EQU     $000010                           ; Timing Revision 5 = 250 MHz
236       000010           ARC22     EQU     $000010
237       008000           ARC32     EQU     $008000                           ; CCD & IR clock driver board
238       000020           UTILREV3  EQU     $000020                           ; Utility Rev. 3 supported
239       000020           ARC50     EQU     $000020
240       000080           SHUTTER_CC EQU    $000080                           ; Shutter supported
241       000100           TEMP_POLY EQU     $000100                           ; Polynomial calibration
242                        TEMP_LINEAR
243       000200                     EQU     $000200                           ; Linear calibration
244       000400           SUBARRAY  EQU     $000400                           ; Subarray readout supported
245       000800           BINNING   EQU     $000800                           ; Binning supported
246                        SPLIT_SERIAL
247       001000                     EQU     $001000                           ; Split serial supported
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 5



248                        SPLIT_PARALLEL
249       002000                     EQU     $002000                           ; Split parallel supported
250       004000           MPP_CC    EQU     $004000                           ; Inverted clocks supported
251       018000           CLKDRVGENI EQU    $018000                           ; No clock driver board - Gen I
252       020000           MLO       EQU     $020000                           ; Set if Mount Laguna Observatory
253       040000           NGST      EQU     $040000                           ; NGST Aladdin implementation
254       100000           CONT_RD   EQU     $100000                           ; Continuous readout implemented
255    
256                        ; Special address for two words for the DSP to bootstrap code from the EEPROM
257                                  IF      @SCP("HOST","ROM")
264                                  ENDIF
265    
266                                  IF      @SCP("HOST","HOST")
267       P:000000 P:000000                   ORG     P:0,P:0
268       P:000000 P:000000 0C0190            JMP     <INIT
269       P:000001 P:000001 000000            NOP
270                                           ENDIF
271    
272                                 ;  This ISR receives serial words a byte at a time over the asynchronous
273                                 ;    serial link (SCI) and squashes them into a single 24-bit word
274       P:000002 P:000002 602400  SCI_RCV   MOVE              R0,X:<SAVE_R0           ; Save R0
275       P:000003 P:000003 052139            MOVEC             SR,X:<SAVE_SR           ; Save Status Register
276       P:000004 P:000004 60A700            MOVE              X:<SCI_R0,R0            ; Restore R0 = pointer to SCI receive regist
er
277       P:000005 P:000005 542300            MOVE              A1,X:<SAVE_A1           ; Save A1
278       P:000006 P:000006 452200            MOVE              X1,X:<SAVE_X1           ; Save X1
279       P:000007 P:000007 54A600            MOVE              X:<SCI_A1,A1            ; Get SRX value of accumulator contents
280       P:000008 P:000008 45E000            MOVE              X:(R0),X1               ; Get the SCI byte
281       P:000009 P:000009 0AD041            BCLR    #1,R0                             ; Test for the address being $FFF6 = last by
te
282       P:00000A P:00000A 000000            NOP
283       P:00000B P:00000B 000000            NOP
284       P:00000C P:00000C 000000            NOP
285       P:00000D P:00000D 205862            OR      X1,A      (R0)+                   ; Add the byte into the 24-bit word
286       P:00000E P:00000E 0E0013            JCC     <MID_BYT                          ; Not the last byte => only restore register
s
287       P:00000F P:00000F 545C00  END_BYT   MOVE              A1,X:(R4)+              ; Put the 24-bit word into the SCI buffer
288       P:000010 P:000010 60F400            MOVE              #SRXL,R0                ; Re-establish first address of SCI interfac
e
                            FFFF98
289       P:000012 P:000012 2C0000            MOVE              #0,A1                   ; For zeroing out SCI_A1
290       P:000013 P:000013 602700  MID_BYT   MOVE              R0,X:<SCI_R0            ; Save the SCI receiver address
291       P:000014 P:000014 542600            MOVE              A1,X:<SCI_A1            ; Save A1 for next interrupt
292       P:000015 P:000015 05A139            MOVEC             X:<SAVE_SR,SR           ; Restore Status Register
293       P:000016 P:000016 54A300            MOVE              X:<SAVE_A1,A1           ; Restore A1
294       P:000017 P:000017 45A200            MOVE              X:<SAVE_X1,X1           ; Restore X1
295       P:000018 P:000018 60A400            MOVE              X:<SAVE_R0,R0           ; Restore R0
296       P:000019 P:000019 000004            RTI                                       ; Return from interrupt service
297    
298                                 ; Clear error condition and interrupt on SCI receiver
299       P:00001A P:00001A 077013  CLR_ERR   MOVEP             X:SSR,X:RCV_ERR         ; Read SCI status register
                            000025
300       P:00001C P:00001C 077018            MOVEP             X:SRXL,X:RCV_ERR        ; This clears any error
                            000025
301       P:00001E P:00001E 000004            RTI
302    
303       P:00001F P:00001F                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
304       P:000030 P:000030                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
305       P:000040 P:000040                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
306    
307                                 ; Tune the table so the following instruction is at P:$50 exactly.
308       P:000050 P:000050 0D0002            JSR     SCI_RCV                           ; SCI receive data interrupt
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 6



309       P:000051 P:000051 000000            NOP
310       P:000052 P:000052 0D001A            JSR     CLR_ERR                           ; SCI receive error interrupt
311       P:000053 P:000053 000000            NOP
312    
313                                 ; *******************  Command Processing  ******************
314    
315                                 ; Read the header and check it for self-consistency
316       P:000054 P:000054 609F00  START     MOVE              X:<IDL_ADR,R0
317       P:000055 P:000055 018FA0            JSET    #TIM_BIT,X:TCSR0,EXPOSING         ; If exposing go check the timer
                            0003C0
318       P:000057 P:000057 0A00A4            JSET    #ST_RDC,X:<STATUS,CONTINUE_READING
                            100000
319       P:000059 P:000059 0AE080            JMP     (R0)
320    
321       P:00005A P:00005A 330700  TST_RCV   MOVE              #<COM_BUF,R3
322       P:00005B P:00005B 0D00A5            JSR     <GET_RCV
323       P:00005C P:00005C 0E005B            JCC     *-1
324    
325                                 ; Check the header and read all the remaining words in the command
326       P:00005D P:00005D 0C00FF  PRC_RCV   JMP     <CHK_HDR                          ; Update HEADER and NWORDS
327       P:00005E P:00005E 578600  PR_RCV    MOVE              X:<NWORDS,B             ; Read this many words total in the command
328       P:00005F P:00005F 000000            NOP
329       P:000060 P:000060 01418C            SUB     #1,B                              ; We've already read the header
330       P:000061 P:000061 000000            NOP
331       P:000062 P:000062 06CF00            DO      B,RD_COM
                            00006A
332       P:000064 P:000064 205B00            MOVE              (R3)+                   ; Increment past what's been read already
333       P:000065 P:000065 0B0080  GET_WRD   JSCLR   #ST_RCV,X:STATUS,CHK_FO
                            0000A9
334       P:000067 P:000067 0B00A0            JSSET   #ST_RCV,X:STATUS,CHK_SCI
                            0000D5
335       P:000069 P:000069 0E0065            JCC     <GET_WRD
336       P:00006A P:00006A 000000            NOP
337       P:00006B P:00006B 330700  RD_COM    MOVE              #<COM_BUF,R3            ; Restore R3 = beginning of the command
338    
339                                 ; Is this command for the timing board?
340       P:00006C P:00006C 448500            MOVE              X:<HEADER,X0
341       P:00006D P:00006D 579B00            MOVE              X:<DMASK,B
342       P:00006E P:00006E 459A4E            AND     X0,B      X:<TIM_DRB,X1           ; Extract destination byte
343       P:00006F P:00006F 20006D            CMP     X1,B                              ; Does header = timing board number?
344       P:000070 P:000070 0EA080            JEQ     <COMMAND                          ; Yes, process it here
345       P:000071 P:000071 0E909D            JLT     <FO_XMT                           ; Send it to fiber optic transmitter
346    
347                                 ; Transmit the command to the utility board over the SCI port
348       P:000072 P:000072 060600            DO      X:<NWORDS,DON_XMT                 ; Transmit NWORDS
                            00007E
349       P:000074 P:000074 60F400            MOVE              #STXL,R0                ; SCI first byte address
                            FFFF95
350       P:000076 P:000076 44DB00            MOVE              X:(R3)+,X0              ; Get the 24-bit word to transmit
351       P:000077 P:000077 060380            DO      #3,SCI_SPT
                            00007D
352       P:000079 P:000079 019381            JCLR    #TDRE,X:SSR,*                     ; Continue ONLY if SCI XMT is empty
                            000079
353       P:00007B P:00007B 445800            MOVE              X0,X:(R0)+              ; Write to SCI, byte pointer + 1
354       P:00007C P:00007C 000000            NOP                                       ; Delay for the status flag to be set
355       P:00007D P:00007D 000000            NOP
356                                 SCI_SPT
357       P:00007E P:00007E 000000            NOP
358                                 DON_XMT
359       P:00007F P:00007F 0C0054            JMP     <START
360    
361                                 ; Process the receiver entry - is it in the command table ?
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 7



362       P:000080 P:000080 0203DF  COMMAND   MOVE              X:(R3+1),B              ; Get the command
363       P:000081 P:000081 205B00            MOVE              (R3)+
364       P:000082 P:000082 205B00            MOVE              (R3)+                   ; Point R3 to the first argument
365       P:000083 P:000083 302800            MOVE              #<COM_TBL,R0            ; Get the command table starting address
366       P:000084 P:000084 061C80            DO      #NUM_COM,END_COM                  ; Loop over the command table
                            00008B
367       P:000086 P:000086 47D800            MOVE              X:(R0)+,Y1              ; Get the command table entry
368       P:000087 P:000087 62E07D            CMP     Y1,B      X:(R0),R2               ; Does receiver = table entries address?
369       P:000088 P:000088 0E208B            JNE     <NOT_COM                          ; No, keep looping
370       P:000089 P:000089 00008C            ENDDO                                     ; Restore the DO loop system registers
371       P:00008A P:00008A 0AE280            JMP     (R2)                              ; Jump execution to the command
372       P:00008B P:00008B 205800  NOT_COM   MOVE              (R0)+                   ; Increment the register past the table addr
ess
373                                 END_COM
374       P:00008C P:00008C 0C008D            JMP     <ERROR                            ; The command is not in the table
375    
376                                 ; It's not in the command table - send an error message
377       P:00008D P:00008D 479D00  ERROR     MOVE              X:<ERR,Y1               ; Send the message - there was an error
378       P:00008E P:00008E 0C0090            JMP     <FINISH1                          ; This protects against unknown commands
379    
380                                 ; Send a reply packet - header and reply
381       P:00008F P:00008F 479800  FINISH    MOVE              X:<DONE,Y1              ; Send 'DON' as the reply
382       P:000090 P:000090 578500  FINISH1   MOVE              X:<HEADER,B             ; Get header of incoming command
383       P:000091 P:000091 469C00            MOVE              X:<SMASK,Y0             ; This was the source byte, and is to
384       P:000092 P:000092 330700            MOVE              #<COM_BUF,R3            ;     become the destination byte
385       P:000093 P:000093 46935E            AND     Y0,B      X:<TWO,Y0
386       P:000094 P:000094 0C1ED1            LSR     #8,B                              ; Shift right eight bytes, add it to the
387       P:000095 P:000095 460600            MOVE              Y0,X:<NWORDS            ;     header, and put 2 as the number
388       P:000096 P:000096 469958            ADD     Y0,B      X:<SBRD,Y0              ;     of words in the string
389       P:000097 P:000097 200058            ADD     Y0,B                              ; Add source board's header, set Y1 for abov
e
390       P:000098 P:000098 000000            NOP
391       P:000099 P:000099 575B00            MOVE              B,X:(R3)+               ; Put the new header on the transmitter stac
k
392       P:00009A P:00009A 475B00            MOVE              Y1,X:(R3)+              ; Put the argument on the transmitter stack
393       P:00009B P:00009B 570500            MOVE              B,X:<HEADER
394       P:00009C P:00009C 0C006B            JMP     <RD_COM                           ; Decide where to send the reply, and do it
395    
396                                 ; Transmit words to the host computer over the fiber optics link
397       P:00009D P:00009D 63F400  FO_XMT    MOVE              #COM_BUF,R3
                            000007
398       P:00009F P:00009F 060600            DO      X:<NWORDS,DON_FFO                 ; Transmit all the words in the command
                            0000A3
399       P:0000A1 P:0000A1 57DB00            MOVE              X:(R3)+,B
400       P:0000A2 P:0000A2 0D00EB            JSR     <XMT_WRD
401       P:0000A3 P:0000A3 000000            NOP
402       P:0000A4 P:0000A4 0C0054  DON_FFO   JMP     <START
403    
404                                 ; Check for commands from the fiber optic FIFO and the utility board (SCI)
405       P:0000A5 P:0000A5 0D00A9  GET_RCV   JSR     <CHK_FO                           ; Check for fiber optic command from FIFO
406       P:0000A6 P:0000A6 0E80A8            JCS     <RCV_RTS                          ; If there's a command, check the header
407       P:0000A7 P:0000A7 0D00D5            JSR     <CHK_SCI                          ; Check for an SCI command
408       P:0000A8 P:0000A8 00000C  RCV_RTS   RTS
409    
410                                 ; Because of FIFO metastability require that EF be stable for two tests
411       P:0000A9 P:0000A9 0A8989  CHK_FO    JCLR    #EF,X:HDR,TST2                    ; EF = Low,  Low  => CLR SR, return
                            0000AC
412       P:0000AB P:0000AB 0C00AF            JMP     <TST3                             ;      High, Low  => try again
413       P:0000AC P:0000AC 0A8989  TST2      JCLR    #EF,X:HDR,CLR_CC                  ;      Low,  High => try again
                            0000D1
414       P:0000AE P:0000AE 0C00A9            JMP     <CHK_FO                           ;      High, High => read FIFO
415       P:0000AF P:0000AF 0A8989  TST3      JCLR    #EF,X:HDR,CHK_FO
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 8



                            0000A9
416    
417       P:0000B1 P:0000B1 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
418       P:0000B3 P:0000B3 000000            NOP
419       P:0000B4 P:0000B4 000000            NOP
420       P:0000B5 P:0000B5 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
421       P:0000B7 P:0000B7 2B0000            MOVE              #0,B2
422       P:0000B8 P:0000B8 0140CE            AND     #$FF,B
                            0000FF
423       P:0000BA P:0000BA 0140CD            CMP     #>$AC,B                           ; It must be $AC to be a valid word
                            0000AC
424       P:0000BC P:0000BC 0E20D1            JNE     <CLR_CC
425       P:0000BD P:0000BD 4EF000            MOVE                          Y:RDFO,Y0   ; Read the MS byte
                            FFFFF1
426       P:0000BF P:0000BF 0C1951            INSERT  #$008010,Y0,B
                            008010
427       P:0000C1 P:0000C1 4EF000            MOVE                          Y:RDFO,Y0   ; Read the middle byte
                            FFFFF1
428       P:0000C3 P:0000C3 0C1951            INSERT  #$008008,Y0,B
                            008008
429       P:0000C5 P:0000C5 4EF000            MOVE                          Y:RDFO,Y0   ; Read the LS byte
                            FFFFF1
430       P:0000C7 P:0000C7 0C1951            INSERT  #$008000,Y0,B
                            008000
431       P:0000C9 P:0000C9 000000            NOP
432       P:0000CA P:0000CA 516300            MOVE              B0,X:(R3)               ; Put the word into COM_BUF
433       P:0000CB P:0000CB 0A0000            BCLR    #ST_RCV,X:<STATUS                 ; Its a command from the host computer
434       P:0000CC P:0000CC 000000  SET_CC    NOP
435       P:0000CD P:0000CD 0AF960            BSET    #0,SR                             ; Valid word => SR carry bit = 1
436       P:0000CE P:0000CE 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
437       P:0000D0 P:0000D0 00000C            RTS
438       P:0000D1 P:0000D1 0AF940  CLR_CC    BCLR    #0,SR                             ; Not valid word => SR carry bit = 0
439       P:0000D2 P:0000D2 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
440       P:0000D4 P:0000D4 00000C            RTS
441    
442                                 ; Test the SCI (= synchronous communications interface) for new words
443       P:0000D5 P:0000D5 44F000  CHK_SCI   MOVE              X:(SCI_TABLE+33),X0
                            000421
444       P:0000D7 P:0000D7 228E00            MOVE              R4,A
445       P:0000D8 P:0000D8 209000            MOVE              X0,R0
446       P:0000D9 P:0000D9 200045            CMP     X0,A
447       P:0000DA P:0000DA 0EA0D1            JEQ     <CLR_CC                           ; There is no new SCI word
448       P:0000DB P:0000DB 44D800            MOVE              X:(R0)+,X0
449       P:0000DC P:0000DC 446300            MOVE              X0,X:(R3)
450       P:0000DD P:0000DD 220E00            MOVE              R0,A
451       P:0000DE P:0000DE 0140C5            CMP     #(SCI_TABLE+32),A                 ; Wrap it around the circular
                            000420
452       P:0000E0 P:0000E0 0EA0E4            JEQ     <INIT_PROCESSED_SCI               ;   buffer boundary
453       P:0000E1 P:0000E1 547000            MOVE              A1,X:(SCI_TABLE+33)
                            000421
454       P:0000E3 P:0000E3 0C00E9            JMP     <SCI_END
455                                 INIT_PROCESSED_SCI
456       P:0000E4 P:0000E4 56F400            MOVE              #SCI_TABLE,A
                            000400
457       P:0000E6 P:0000E6 000000            NOP
458       P:0000E7 P:0000E7 567000            MOVE              A,X:(SCI_TABLE+33)
                            000421
459       P:0000E9 P:0000E9 0A0020  SCI_END   BSET    #ST_RCV,X:<STATUS                 ; Its a utility board (SCI) word
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 9



460       P:0000EA P:0000EA 0C00CC            JMP     <SET_CC
461    
462                                 ; Transmit the word in B1 to the host computer over the fiber optic data link
463                                 XMT_WRD
464       P:0000EB P:0000EB 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
465       P:0000ED P:0000ED 60F400            MOVE              #FO_HDR+1,R0
                            000002
466       P:0000EF P:0000EF 060380            DO      #3,XMT_WRD1
                            0000F3
467       P:0000F1 P:0000F1 0C1D91            ASL     #8,B,B
468       P:0000F2 P:0000F2 000000            NOP
469       P:0000F3 P:0000F3 535800            MOVE              B2,X:(R0)+
470                                 XMT_WRD1
471       P:0000F4 P:0000F4 60F400            MOVE              #FO_HDR,R0
                            000001
472       P:0000F6 P:0000F6 61F400            MOVE              #WRFO,R1
                            FFFFF2
473       P:0000F8 P:0000F8 060480            DO      #4,XMT_WRD2
                            0000FB
474       P:0000FA P:0000FA 46D800            MOVE              X:(R0)+,Y0              ; Should be MOVEP  X:(R0)+,Y:WRFO
475       P:0000FB P:0000FB 4E6100            MOVE                          Y0,Y:(R1)
476                                 XMT_WRD2
477       P:0000FC P:0000FC 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
478       P:0000FE P:0000FE 00000C            RTS
479    
480                                 ; Check the command or reply header in X:(R3) for self-consistency
481       P:0000FF P:0000FF 46E300  CHK_HDR   MOVE              X:(R3),Y0
482       P:000100 P:000100 579600            MOVE              X:<MASK1,B              ; Test for S.LE.3 and D.LE.3 and N.LE.7
483       P:000101 P:000101 20005E            AND     Y0,B
484       P:000102 P:000102 0E208D            JNE     <ERROR                            ; Test failed
485       P:000103 P:000103 579700            MOVE              X:<MASK2,B              ; Test for either S.NE.0 or D.NE.0
486       P:000104 P:000104 20005E            AND     Y0,B
487       P:000105 P:000105 0EA08D            JEQ     <ERROR                            ; Test failed
488       P:000106 P:000106 579500            MOVE              X:<SEVEN,B
489       P:000107 P:000107 20005E            AND     Y0,B                              ; Extract NWORDS, must be > 0
490       P:000108 P:000108 0EA08D            JEQ     <ERROR
491       P:000109 P:000109 44E300            MOVE              X:(R3),X0
492       P:00010A P:00010A 440500            MOVE              X0,X:<HEADER            ; Its a correct header
493       P:00010B P:00010B 550600            MOVE              B1,X:<NWORDS            ; Number of words in the command
494       P:00010C P:00010C 0C005E            JMP     <PR_RCV
495    
496                                 ;  *****************  Boot Commands  *******************
497    
498                                 ; Test Data Link - simply return value received after 'TDL'
499       P:00010D P:00010D 47DB00  TDL       MOVE              X:(R3)+,Y1              ; Get the data value
500       P:00010E P:00010E 0C0090            JMP     <FINISH1                          ; Return from executing TDL command
501    
502                                 ; Read DSP or EEPROM memory ('RDM' address): read memory, reply with value
503       P:00010F P:00010F 47DB00  RDMEM     MOVE              X:(R3)+,Y1
504       P:000110 P:000110 20EF00            MOVE              Y1,B
505       P:000111 P:000111 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
506       P:000113 P:000113 21B000            MOVE              B1,R0                   ; Need the address in an address register
507       P:000114 P:000114 20EF00            MOVE              Y1,B
508       P:000115 P:000115 000000            NOP
509       P:000116 P:000116 0ACF14            JCLR    #20,B,RDX                         ; Test address bit for Program memory
                            00011A
510       P:000118 P:000118 07E087            MOVE              P:(R0),Y1               ; Read from Program Memory
511       P:000119 P:000119 0C0090            JMP     <FINISH1                          ; Send out a header with the value
512       P:00011A P:00011A 0ACF15  RDX       JCLR    #21,B,RDY                         ; Test address bit for X: memory
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 10



                            00011E
513       P:00011C P:00011C 47E000            MOVE              X:(R0),Y1               ; Write to X data memory
514       P:00011D P:00011D 0C0090            JMP     <FINISH1                          ; Send out a header with the value
515       P:00011E P:00011E 0ACF16  RDY       JCLR    #22,B,RDR                         ; Test address bit for Y: memory
                            000122
516       P:000120 P:000120 4FE000            MOVE                          Y:(R0),Y1   ; Read from Y data memory
517       P:000121 P:000121 0C0090            JMP     <FINISH1                          ; Send out a header with the value
518       P:000122 P:000122 0ACF17  RDR       JCLR    #23,B,ERROR                       ; Test address bit for read from EEPROM memo
ry
                            00008D
519       P:000124 P:000124 479400            MOVE              X:<THREE,Y1             ; Convert to word address to a byte address
520       P:000125 P:000125 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
521       P:000126 P:000126 2000B8            MPY     Y0,Y1,B                           ; Multiply
522       P:000127 P:000127 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
523       P:000128 P:000128 213000            MOVE              B0,R0                   ; Need to address memory
524       P:000129 P:000129 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
525       P:00012A P:00012A 0D0178            JSR     <RD_WORD                          ; Read word from EEPROM
526       P:00012B P:00012B 21A700            MOVE              B1,Y1                   ; FINISH1 transmits Y1 as its reply
527       P:00012C P:00012C 0C0090            JMP     <FINISH1
528    
529                                 ; Program WRMEM ('WRM' address datum): write to memory, reply 'DON'.
530       P:00012D P:00012D 47DB00  WRMEM     MOVE              X:(R3)+,Y1              ; Get the address to be written to
531       P:00012E P:00012E 20EF00            MOVE              Y1,B
532       P:00012F P:00012F 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
533       P:000131 P:000131 21B000            MOVE              B1,R0                   ; Need the address in an address register
534       P:000132 P:000132 20EF00            MOVE              Y1,B
535       P:000133 P:000133 46DB00            MOVE              X:(R3)+,Y0              ; Get datum into Y0 so MOVE works easily
536       P:000134 P:000134 0ACF14            JCLR    #20,B,WRX                         ; Test address bit for Program memory
                            000138
537       P:000136 P:000136 076086            MOVE              Y0,P:(R0)               ; Write to Program memory
538       P:000137 P:000137 0C008F            JMP     <FINISH
539       P:000138 P:000138 0ACF15  WRX       JCLR    #21,B,WRY                         ; Test address bit for X: memory
                            00013C
540       P:00013A P:00013A 466000            MOVE              Y0,X:(R0)               ; Write to X: memory
541       P:00013B P:00013B 0C008F            JMP     <FINISH
542       P:00013C P:00013C 0ACF16  WRY       JCLR    #22,B,WRR                         ; Test address bit for Y: memory
                            000140
543       P:00013E P:00013E 4E6000            MOVE                          Y0,Y:(R0)   ; Write to Y: memory
544       P:00013F P:00013F 0C008F            JMP     <FINISH
545       P:000140 P:000140 0ACF17  WRR       JCLR    #23,B,ERROR                       ; Test address bit for write to EEPROM
                            00008D
546       P:000142 P:000142 013D02            BCLR    #WRENA,X:PDRC                     ; WR_ENA* = 0 to enable EEPROM writing
547       P:000143 P:000143 460E00            MOVE              Y0,X:<SV_A1             ; Save the datum to be written
548       P:000144 P:000144 479400            MOVE              X:<THREE,Y1             ; Convert word address to a byte address
549       P:000145 P:000145 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
550       P:000146 P:000146 2000B8            MPY     Y1,Y0,B                           ; Multiply
551       P:000147 P:000147 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
552       P:000148 P:000148 213000            MOVE              B0,R0                   ; Need to address memory
553       P:000149 P:000149 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
554       P:00014A P:00014A 558E00            MOVE              X:<SV_A1,B1             ; Get the datum to be written
555       P:00014B P:00014B 060380            DO      #3,L1WRR                          ; Loop over three bytes of the word
                            000154
556       P:00014D P:00014D 07588D            MOVE              B1,P:(R0)+              ; Write each EEPROM byte
557       P:00014E P:00014E 0C1C91            ASR     #8,B,B
558       P:00014F P:00014F 469E00            MOVE              X:<C100K,Y0             ; Move right one byte, enter delay = 1 msec
559       P:000150 P:000150 06C600            DO      Y0,L2WRR                          ; Delay by 12 milliseconds for EEPROM write
                            000153
560       P:000152 P:000152 060CA0            REP     #12                               ; Assume 100 MHz DSP56303
561       P:000153 P:000153 000000            NOP
562                                 L2WRR
563       P:000154 P:000154 000000            NOP                                       ; DO loop nesting restriction
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 11



564                                 L1WRR
565       P:000155 P:000155 013D22            BSET    #WRENA,X:PDRC                     ; WR_ENA* = 1 to disable EEPROM writing
566       P:000156 P:000156 0C008F            JMP     <FINISH
567    
568                                 ; Load application code from P: memory into its proper locations
569       P:000157 P:000157 47DB00  LDAPPL    MOVE              X:(R3)+,Y1              ; Application number, not used yet
570       P:000158 P:000158 0D015A            JSR     <LOAD_APPLICATION
571       P:000159 P:000159 0C008F            JMP     <FINISH
572    
573                                 LOAD_APPLICATION
574       P:00015A P:00015A 60F400            MOVE              #$8000,R0               ; Starting EEPROM address
                            008000
575       P:00015C P:00015C 0D0178            JSR     <RD_WORD                          ; Number of words in boot code
576       P:00015D P:00015D 21A600            MOVE              B1,Y0
577       P:00015E P:00015E 479400            MOVE              X:<THREE,Y1
578       P:00015F P:00015F 2000B8            MPY     Y0,Y1,B
579       P:000160 P:000160 20002A            ASR     B
580       P:000161 P:000161 213000            MOVE              B0,R0                   ; EEPROM address of start of P: application
581       P:000162 P:000162 0AD06F            BSET    #15,R0                            ; To access EEPROM
582       P:000163 P:000163 0D0178            JSR     <RD_WORD                          ; Read number of words in application P:
583       P:000164 P:000164 61F400            MOVE              #(X_BOOT_START+1),R1    ; End of boot P: code that needs keeping
                            00022B
584       P:000166 P:000166 06CD00            DO      B1,RD_APPL_P
                            000169
585       P:000168 P:000168 0D0178            JSR     <RD_WORD
586       P:000169 P:000169 07598D            MOVE              B1,P:(R1)+
587                                 RD_APPL_P
588       P:00016A P:00016A 0D0178            JSR     <RD_WORD                          ; Read number of words in application X:
589       P:00016B P:00016B 61F400            MOVE              #END_COMMAND_TABLE,R1
                            000036
590       P:00016D P:00016D 06CD00            DO      B1,RD_APPL_X
                            000170
591       P:00016F P:00016F 0D0178            JSR     <RD_WORD
592       P:000170 P:000170 555900            MOVE              B1,X:(R1)+
593                                 RD_APPL_X
594       P:000171 P:000171 0D0178            JSR     <RD_WORD                          ; Read number of words in application Y:
595       P:000172 P:000172 310100            MOVE              #1,R1                   ; There is no Y: memory in the boot code
596       P:000173 P:000173 06CD00            DO      B1,RD_APPL_Y
                            000176
597       P:000175 P:000175 0D0178            JSR     <RD_WORD
598       P:000176 P:000176 5D5900            MOVE                          B1,Y:(R1)+
599                                 RD_APPL_Y
600       P:000177 P:000177 00000C            RTS
601    
602                                 ; Read one word from EEPROM location R0 into accumulator B1
603       P:000178 P:000178 060380  RD_WORD   DO      #3,L_RDBYTE
                            00017B
604       P:00017A P:00017A 07D88B            MOVE              P:(R0)+,B2
605       P:00017B P:00017B 0C1C91            ASR     #8,B,B
606                                 L_RDBYTE
607       P:00017C P:00017C 00000C            RTS
608    
609                                 ; Come to here on a 'STP' command so 'DON' can be sent
610                                 STOP_IDLE_CLOCKING
611       P:00017D P:00017D 305A00            MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
612       P:00017E P:00017E 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
613       P:00017F P:00017F 0A0002            BCLR    #IDLMODE,X:<STATUS                ; Don't idle after readout
614       P:000180 P:000180 0C008F            JMP     <FINISH
615    
616                                 ; Routines executed after the DSP boots and initializes
617       P:000181 P:000181 305A00  STARTUP   MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
618       P:000182 P:000182 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 12



619       P:000183 P:000183 44F400            MOVE              #50000,X0               ; Delay by 500 milliseconds
                            00C350
620       P:000185 P:000185 06C400            DO      X0,L_DELAY
                            000188
621       P:000187 P:000187 06E8A3            REP     #1000
622       P:000188 P:000188 000000            NOP
623                                 L_DELAY
624       P:000189 P:000189 57F400            MOVE              #$020002,B              ; Normal reply after booting is 'SYR'
                            020002
625       P:00018B P:00018B 0D00EB            JSR     <XMT_WRD
626       P:00018C P:00018C 57F400            MOVE              #'SYR',B
                            535952
627       P:00018E P:00018E 0D00EB            JSR     <XMT_WRD
628    
629       P:00018F P:00018F 0C0054            JMP     <START                            ; Start normal command processing
630    
631                                 ; *******************  DSP  INITIALIZATION  CODE  **********************
632                                 ; This code initializes the DSP right after booting, and is overwritten
633                                 ;   by application code
634       P:000190 P:000190 08F4BD  INIT      MOVEP             #PLL_INIT,X:PCTL        ; Initialize PLL to 100 MHz
                            050003
635       P:000192 P:000192 000000            NOP
636    
637                                 ; Set operation mode register OMR to normal expanded
638       P:000193 P:000193 0500BA            MOVEC             #$0000,OMR              ; Operating Mode Register = Normal Expanded
639       P:000194 P:000194 0500BB            MOVEC             #0,SP                   ; Reset the Stack Pointer SP
640    
641                                 ; Program the AA = address attribute pins
642       P:000195 P:000195 08F4B9            MOVEP             #$FFFC21,X:AAR0         ; Y = $FFF000 to $FFFFFF asserts commands
                            FFFC21
643       P:000197 P:000197 08F4B8            MOVEP             #$008909,X:AAR1         ; P = $008000 to $00FFFF accesses the EEPROM
                            008909
644       P:000199 P:000199 08F4B7            MOVEP             #$010C11,X:AAR2         ; X = $010000 to $010FFF reads A/D values
                            010C11
645       P:00019B P:00019B 08F4B6            MOVEP             #$080621,X:AAR3         ; Y = $080000 to $0BFFFF R/W from SRAM
                            080621
646    
647       P:00019D P:00019D 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Enable clearing of DACs
648       P:00019E P:00019E 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable clock and DAC output switches
649       P:00019F P:00019F 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Execute these two operations
                            00000F
650    
651                                 ; Program the DRAM memory access and addressing
652       P:0001A1 P:0001A1 08F4BB            MOVEP             #$028FE1,X:BCR          ; Bus Control Register
                            028FE1
653    
654                                 ; Program the Host port B for parallel I/O
655       P:0001A3 P:0001A3 08F484            MOVEP             #>1,X:HPCR              ; All pins enabled as GPIO
                            000001
656       P:0001A5 P:0001A5 08F489            MOVEP             #$810C,X:HDR
                            00810C
657       P:0001A7 P:0001A7 08F488            MOVEP             #$B10E,X:HDDR           ; Data Direction Register
                            00B10E
658                                                                                     ;  (1 for Output, 0 for Input)
659    
660                                 ; Port B conversion from software bits to schematic labels
661                                 ;       PB0 = PWROK             PB08 = PRSFIFO*
662                                 ;       PB1 = LED1              PB09 = EF*
663                                 ;       PB2 = LVEN              PB10 = EXT-IN0
664                                 ;       PB3 = HVEN              PB11 = EXT-IN1
665                                 ;       PB4 = STATUS0           PB12 = EXT-OUT0
666                                 ;       PB5 = STATUS1           PB13 = EXT-OUT1
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 13



667                                 ;       PB6 = STATUS2           PB14 = SSFHF*
668                                 ;       PB7 = STATUS3           PB15 = SELSCI
669    
670                                 ; Program the serial port ESSI0 = Port C for serial communication with
671                                 ;   the utility board
672       P:0001A9 P:0001A9 07F43F            MOVEP             #>0,X:PCRC              ; Software reset of ESSI0
                            000000
673       P:0001AB P:0001AB 07F435            MOVEP             #$180809,X:CRA0         ; Divide 100 MHz by 20 to get 5.0 MHz
                            180809
674                                                                                     ; DC[4:0] = 0 for non-network operation
675                                                                                     ; WL0-WL2 = 3 for 24-bit data words
676                                                                                     ; SSC1 = 0 for SC1 not used
677       P:0001AD P:0001AD 07F436            MOVEP             #$020020,X:CRB0         ; SCKD = 1 for internally generated clock
                            020020
678                                                                                     ; SCD2 = 0 so frame sync SC2 is an output
679                                                                                     ; SHFD = 0 for MSB shifted first
680                                                                                     ; FSL = 0, frame sync length not used
681                                                                                     ; CKP = 0 for rising clock edge transitions
682                                                                                     ; SYN = 0 for asynchronous
683                                                                                     ; TE0 = 1 to enable transmitter #0
684                                                                                     ; MOD = 0 for normal, non-networked mode
685                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
686                                                                                     ; RE = 1 to enable receiver
687       P:0001AF P:0001AF 07F43F            MOVEP             #%111001,X:PCRC         ; Control Register (0 for GPIO, 1 for ESSI)
                            000039
688       P:0001B1 P:0001B1 07F43E            MOVEP             #%000110,X:PRRC         ; Data Direction Register (0 for In, 1 for O
ut)
                            000006
689       P:0001B3 P:0001B3 07F43D            MOVEP             #%000100,X:PDRC         ; Data Register - WR_ENA* = 1
                            000004
690    
691                                 ; Port C version = Analog boards
692                                 ;       MOVEP   #$000809,X:CRA0 ; Divide 100 MHz by 20 to get 5.0 MHz
693                                 ;       MOVEP   #$000030,X:CRB0 ; SCKD = 1 for internally generated clock
694                                 ;       MOVEP   #%100000,X:PCRC ; Control Register (0 for GPIO, 1 for ESSI)
695                                 ;       MOVEP   #%000100,X:PRRC ; Data Direction Register (0 for In, 1 for Out)
696                                 ;       MOVEP   #%000000,X:PDRC ; Data Register: 'not used' = 0 outputs
697    
698       P:0001B5 P:0001B5 07F43C            MOVEP             #0,X:TX00               ; Initialize the transmitter to zero
                            000000
699       P:0001B7 P:0001B7 000000            NOP
700       P:0001B8 P:0001B8 000000            NOP
701       P:0001B9 P:0001B9 013630            BSET    #TE,X:CRB0                        ; Enable the SSI transmitter
702    
703                                 ; Conversion from software bits to schematic labels for Port C
704                                 ;       PC0 = SC00 = UTL-T-SCK
705                                 ;       PC1 = SC01 = 2_XMT = SYNC on prototype
706                                 ;       PC2 = SC02 = WR_ENA*
707                                 ;       PC3 = SCK0 = TIM-U-SCK
708                                 ;       PC4 = SRD0 = UTL-T-STD
709                                 ;       PC5 = STD0 = TIM-U-STD
710    
711                                 ; Program the serial port ESSI1 = Port D for serial transmission to
712                                 ;   the analog boards and two parallel I/O input pins
713       P:0001BA P:0001BA 07F42F            MOVEP             #>0,X:PCRD              ; Software reset of ESSI0
                            000000
714       P:0001BC P:0001BC 07F425            MOVEP             #$000809,X:CRA1         ; Divide 100 MHz by 20 to get 5.0 MHz
                            000809
715                                                                                     ; DC[4:0] = 0
716                                                                                     ; WL[2:0] = ALC = 0 for 8-bit data words
717                                                                                     ; SSC1 = 0 for SC1 not used
718       P:0001BE P:0001BE 07F426            MOVEP             #$000030,X:CRB1         ; SCKD = 1 for internally generated clock
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 14



                            000030
719                                                                                     ; SCD2 = 1 so frame sync SC2 is an output
720                                                                                     ; SHFD = 0 for MSB shifted first
721                                                                                     ; CKP = 0 for rising clock edge transitions
722                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
723                                                                                     ; MOD = 0 so its not networked mode
724       P:0001C0 P:0001C0 07F42F            MOVEP             #%100000,X:PCRD         ; Control Register (0 for GPIO, 1 for ESSI)
                            000020
725                                                                                     ; PD3 = SCK1, PD5 = STD1 for ESSI
726       P:0001C2 P:0001C2 07F42E            MOVEP             #%000100,X:PRRD         ; Data Direction Register (0 for In, 1 for O
ut)
                            000004
727       P:0001C4 P:0001C4 07F42D            MOVEP             #%000100,X:PDRD         ; Data Register: 'not used' = 0 outputs
                            000004
728       P:0001C6 P:0001C6 07F42C            MOVEP             #0,X:TX10               ; Initialize the transmitter to zero
                            000000
729       P:0001C8 P:0001C8 000000            NOP
730       P:0001C9 P:0001C9 000000            NOP
731       P:0001CA P:0001CA 012630            BSET    #TE,X:CRB1                        ; Enable the SSI transmitter
732    
733                                 ; Conversion from software bits to schematic labels for Port D
734                                 ; PD0 = SC10 = 2_XMT_? input
735                                 ; PD1 = SC11 = SSFEF* input
736                                 ; PD2 = SC12 = PWR_EN
737                                 ; PD3 = SCK1 = TIM-A-SCK
738                                 ; PD4 = SRD1 = PWRRST
739                                 ; PD5 = STD1 = TIM-A-STD
740    
741                                 ; Program the SCI port to communicate with the utility board
742       P:0001CB P:0001CB 07F41C            MOVEP             #$0B04,X:SCR            ; SCI programming: 11-bit asynchronous
                            000B04
743                                                                                     ;   protocol (1 start, 8 data, 1 even parity
,
744                                                                                     ;   1 stop); LSB before MSB; enable receiver
745                                                                                     ;   and its interrupts; transmitter interrup
ts
746                                                                                     ;   disabled.
747       P:0001CD P:0001CD 07F41B            MOVEP             #$0003,X:SCCR           ; SCI clock: utility board data rate =
                            000003
748                                                                                     ;   (390,625 kbits/sec); internal clock.
749       P:0001CF P:0001CF 07F41F            MOVEP             #%011,X:PCRE            ; Port Control Register = RXD, TXD enabled
                            000003
750       P:0001D1 P:0001D1 07F41E            MOVEP             #%000,X:PRRE            ; Port Direction Register (0 = Input)
                            000000
751    
752                                 ;       PE0 = RXD
753                                 ;       PE1 = TXD
754                                 ;       PE2 = SCLK
755    
756                                 ; Program one of the three timers as an exposure timer
757       P:0001D3 P:0001D3 07F403            MOVEP             #$C34F,X:TPLR           ; Prescaler to generate millisecond timer,
                            00C34F
758                                                                                     ;  counting from the system clock / 2 = 50 M
Hz
759       P:0001D5 P:0001D5 07F40F            MOVEP             #$208200,X:TCSR0        ; Clear timer complete bit and enable presca
ler
                            208200
760       P:0001D7 P:0001D7 07F40E            MOVEP             #0,X:TLR0               ; Timer load register
                            000000
761    
762                                 ; Enable interrupts for the SCI port only
763       P:0001D9 P:0001D9 08F4BF            MOVEP             #$000000,X:IPRC         ; No interrupts allowed
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 15



                            000000
764       P:0001DB P:0001DB 08F4BE            MOVEP             #>$80,X:IPRP            ; Enable SCI interrupt only, IPR = 1
                            000080
765       P:0001DD P:0001DD 00FCB8            ANDI    #$FC,MR                           ; Unmask all interrupt levels
766    
767                                 ; Initialize the fiber optic serial receiver circuitry
768       P:0001DE P:0001DE 061480            DO      #20,L_FO_INIT
                            0001E3
769       P:0001E0 P:0001E0 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
770       P:0001E2 P:0001E2 0605A0            REP     #5
771       P:0001E3 P:0001E3 000000            NOP
772                                 L_FO_INIT
773    
774                                 ; Pulse PRSFIFO* low to revive the CMDRST* instruction and reset the FIFO
775       P:0001E4 P:0001E4 44F400            MOVE              #1000000,X0             ; Delay by 10 milliseconds
                            0F4240
776       P:0001E6 P:0001E6 06C400            DO      X0,*+3
                            0001E8
777       P:0001E8 P:0001E8 000000            NOP
778       P:0001E9 P:0001E9 0A8908            BCLR    #8,X:HDR
779       P:0001EA P:0001EA 0614A0            REP     #20
780       P:0001EB P:0001EB 000000            NOP
781       P:0001EC P:0001EC 0A8928            BSET    #8,X:HDR
782    
783                                 ; Reset the utility board
784       P:0001ED P:0001ED 0A0F05            BCLR    #5,X:<LATCH
785       P:0001EE P:0001EE 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
786       P:0001F0 P:0001F0 06C8A0            REP     #200                              ; Delay by RESET* low time
787       P:0001F1 P:0001F1 000000            NOP
788       P:0001F2 P:0001F2 0A0F25            BSET    #5,X:<LATCH
789       P:0001F3 P:0001F3 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
790       P:0001F5 P:0001F5 56F400            MOVE              #200000,A               ; Delay 2 msec for utility boot
                            030D40
791       P:0001F7 P:0001F7 06CE00            DO      A,*+3
                            0001F9
792       P:0001F9 P:0001F9 000000            NOP
793    
794                                 ; Put all the analog switch inputs to low so they draw minimum current
795       P:0001FA P:0001FA 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
796       P:0001FB P:0001FB 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
797       P:0001FD P:0001FD 20001B            CLR     B
798       P:0001FE P:0001FE 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
799       P:0001FF P:0001FF 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
800       P:000201 P:000201 060F80            DO      #15,L_ANALOG                      ; Fifteen video processor boards maximum
                            000209
801       P:000203 P:000203 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
802       P:000204 P:000204 200040            ADD     X0,A
803       P:000205 P:000205 5F7000            MOVE                          B,Y:WRSS    ; This is for the fast analog switches
                            FFFFF3
804       P:000207 P:000207 0620A3            REP     #800                              ; Delay for the serial data transmission
805       P:000208 P:000208 000000            NOP
806       P:000209 P:000209 200068            ADD     X1,B                              ; Increment the video and clock driver numbe
rs
807                                 L_ANALOG
808       P:00020A P:00020A 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 16



809       P:00020B P:00020B 0C0223            JMP     <SKIP
810    
811                                 ; Transmit contents of accumulator A1 over the synchronous serial transmitter
812                                 XMIT_A_WORD
813       P:00020C P:00020C 07F42C            MOVEP             #0,X:TX10               ; This helps, don't know why
                            000000
814       P:00020E P:00020E 547000            MOVE              A1,X:SV_A1
                            00000E
815       P:000210 P:000210 000000            NOP
816       P:000211 P:000211 01A786            JCLR    #TDE,X:SSISR1,*                   ; Start bit
                            000211
817       P:000213 P:000213 07F42C            MOVEP             #$010000,X:TX10
                            010000
818       P:000215 P:000215 060380            DO      #3,L_X
                            00021B
819       P:000217 P:000217 01A786            JCLR    #TDE,X:SSISR1,*                   ; Three data bytes
                            000217
820       P:000219 P:000219 04CCCC            MOVEP             A1,X:TX10
821       P:00021A P:00021A 0C1E90            LSL     #8,A
822       P:00021B P:00021B 000000            NOP
823                                 L_X
824       P:00021C P:00021C 01A786            JCLR    #TDE,X:SSISR1,*                   ; Zeroes to bring transmitter low
                            00021C
825       P:00021E P:00021E 07F42C            MOVEP             #0,X:TX10
                            000000
826       P:000220 P:000220 54F000            MOVE              X:SV_A1,A1
                            00000E
827       P:000222 P:000222 00000C            RTS
828    
829                                 SKIP
830    
831                                 ; Set up the circular SCI buffer, 32 words in size
832       P:000223 P:000223 64F400            MOVE              #SCI_TABLE,R4
                            000400
833       P:000225 P:000225 051FA4            MOVE              #31,M4
834       P:000226 P:000226 647000            MOVE              R4,X:(SCI_TABLE+33)
                            000421
835    
836                                           IF      @SCP("HOST","ROM")
844                                           ENDIF
845    
846       P:000228 P:000228 44F400            MOVE              #>$AC,X0
                            0000AC
847       P:00022A P:00022A 440100            MOVE              X0,X:<FO_HDR
848    
849       P:00022B P:00022B 0C0181            JMP     <STARTUP
850    
851                                 ;  ****************  X: Memory tables  ********************
852    
853                                 ; Define the address in P: space where the table of constants begins
854    
855                                  X_BOOT_START
856       00022A                              EQU     @LCV(L)-2
857    
858                                           IF      @SCP("HOST","ROM")
860                                           ENDIF
861                                           IF      @SCP("HOST","HOST")
862       X:000000 X:000000                   ORG     X:0,X:0
863                                           ENDIF
864    
865                                 ; Special storage area - initialization constants and scratch space
866       X:000000 X:000000         STATUS    DC      4                                 ; Controller status bits
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 17



867    
868       000001                    FO_HDR    EQU     STATUS+1                          ; Fiber optic write bytes
869       000005                    HEADER    EQU     FO_HDR+4                          ; Command header
870       000006                    NWORDS    EQU     HEADER+1                          ; Number of words in the command
871       000007                    COM_BUF   EQU     NWORDS+1                          ; Command buffer
872       00000E                    SV_A1     EQU     COM_BUF+7                         ; Save accumulator A1
873    
874                                           IF      @SCP("HOST","ROM")
879                                           ENDIF
880    
881                                           IF      @SCP("HOST","HOST")
882       X:00000F X:00000F                   ORG     X:$F,X:$F
883                                           ENDIF
884    
885                                 ; Parameter table in P: space to be copied into X: space during
886                                 ;   initialization, and is copied from ROM by the DSP boot
887       X:00000F X:00000F         LATCH     DC      $3A                               ; Starting value in latch chip U25
888                                  EXPOSURE_TIME
889       X:000010 X:000010                   DC      0                                 ; Exposure time in milliseconds
890                                  ELAPSED_TIME
891       X:000011 X:000011                   DC      0                                 ; Time elapsed so far in the exposure
892       X:000012 X:000012         ONE       DC      1                                 ; One
893       X:000013 X:000013         TWO       DC      2                                 ; Two
894       X:000014 X:000014         THREE     DC      3                                 ; Three
895       X:000015 X:000015         SEVEN     DC      7                                 ; Seven
896       X:000016 X:000016         MASK1     DC      $FCFCF8                           ; Mask for checking header
897       X:000017 X:000017         MASK2     DC      $030300                           ; Mask for checking header
898       X:000018 X:000018         DONE      DC      'DON'                             ; Standard reply
899       X:000019 X:000019         SBRD      DC      $020000                           ; Source Identification number
900       X:00001A X:00001A         TIM_DRB   DC      $000200                           ; Destination = timing board number
901       X:00001B X:00001B         DMASK     DC      $00FF00                           ; Mask to get destination board number
902       X:00001C X:00001C         SMASK     DC      $FF0000                           ; Mask to get source board number
903       X:00001D X:00001D         ERR       DC      'ERR'                             ; An error occurred
904       X:00001E X:00001E         C100K     DC      100000                            ; Delay for WRROM = 1 millisec
905       X:00001F X:00001F         IDL_ADR   DC      TST_RCV                           ; Address of idling routine
906       X:000020 X:000020         EXP_ADR   DC      0                                 ; Jump to this address during exposures
907    
908                                 ; Places for saving register values
909       X:000021 X:000021         SAVE_SR   DC      0                                 ; Status Register
910       X:000022 X:000022         SAVE_X1   DC      0
911       X:000023 X:000023         SAVE_A1   DC      0
912       X:000024 X:000024         SAVE_R0   DC      0
913       X:000025 X:000025         RCV_ERR   DC      0
914       X:000026 X:000026         SCI_A1    DC      0                                 ; Contents of accumulator A1 in RCV ISR
915       X:000027 X:000027         SCI_R0    DC      SRXL
916    
917                                 ; Command table
918       000028                    COM_TBL_R EQU     @LCV(R)
919       X:000028 X:000028         COM_TBL   DC      'TDL',TDL                         ; Test Data Link
920       X:00002A X:00002A                   DC      'RDM',RDMEM                       ; Read from DSP or EEPROM memory
921       X:00002C X:00002C                   DC      'WRM',WRMEM                       ; Write to DSP memory
922       X:00002E X:00002E                   DC      'LDA',LDAPPL                      ; Load application from EEPROM to DSP
923       X:000030 X:000030                   DC      'STP',STOP_IDLE_CLOCKING
924       X:000032 X:000032                   DC      'DON',START                       ; Nothing special
925       X:000034 X:000034                   DC      'ERR',START                       ; Nothing special
926    
927                                  END_COMMAND_TABLE
928       000036                              EQU     @LCV(R)
929    
930                                 ; The table at SCI_TABLE is for words received from the utility board, written by
931                                 ;   the interrupt service routine SCI_RCV. Note that it is 32 words long,
932                                 ;   hard coded, and the 33rd location contains the pointer to words that have
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timboot.asm  Page 18



933                                 ;   been processed by moving them from the SCI_TABLE to the COM_BUF.
934    
935                                           IF      @SCP("HOST","ROM")
937                                           ENDIF
938    
939       000036                    END_ADR   EQU     @LCV(L)                           ; End address of P: code written to ROM
940    
941       P:00022C P:00022C                   ORG     P:,P:
942    
943       108015                    CC        EQU     ARC22+ARC32+ARC46+CONT_RD
944    
945                                 ; Put number of words of application in P: for loading application from EEPROM
946       P:00022C P:00022C                   DC      TIMBOOT_X_MEMORY-@LCV(L)-1
947    
948                                 ; Define CLOCK as a macro to produce in-line code to reduce execution time
949                                 CLOCK     MACRO
950  m                                        JCLR    #SSFHF,X:HDR,*                    ; Don't overfill the WRSS FIFO
951  m                                        REP     Y:(R0)+                           ; Repeat
952  m                                        MOVEP   Y:(R0)+,Y:WRSS                    ; Write the waveform to the FIFO
953  m                                        ENDM
954    
955                                 ; Continuously reset and read array, checking for commands every four rows
956                                 CONT_RST
957       P:00022D P:00022D 60F400            MOVE              #FRAME_RESET,R0
                            000016
958                                           CLOCK
962       P:000233 P:000233 60F400            MOVE              #FRAME_RESET,R0
                            000016
963                                           CLOCK
967       P:000239 P:000239 60F400            MOVE              #FRAME_RESET,R0
                            000016
968                                           CLOCK
972       P:00023F P:00023F 60F400            MOVE              #FRAME_RESET,R0
                            000016
973                                           CLOCK
977       P:000245 P:000245 068080            DO      #128,L_RESET
                            00026C
978       P:000247 P:000247 60F400            MOVE              #CLOCK_ROW_1,R0
                            00002B
979                                           CLOCK
983       P:00024D P:00024D 0D026E            JSR     <CLK_COL
984       P:00024E P:00024E 60F400            MOVE              #CLOCK_ROW_2,R0
                            000031
985                                           CLOCK
989       P:000254 P:000254 0D026E            JSR     <CLK_COL
990       P:000255 P:000255 60F400            MOVE              #CLOCK_ROW_3,R0
                            000037
991                                           CLOCK
995       P:00025B P:00025B 0D026E            JSR     <CLK_COL
996       P:00025C P:00025C 60F400            MOVE              #CLOCK_ROW_4,R0
                            00003D
997                                           CLOCK
1001      P:000262 P:000262 0D026E            JSR     <CLK_COL
1002      P:000263 P:000263 44F400            MOVE              #(CLK2+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR),X0
                            00207F
1003      P:000265 P:000265 4C7000            MOVE                          X0,Y:WRSS
                            FFFFF3
1004   
1005      P:000267 P:000267 330700            MOVE              #COM_BUF,R3
1006      P:000268 P:000268 0D00A5            JSR     <GET_RCV                          ; Look for a new command every 4 rows
1007      P:000269 P:000269 0E026C            JCC     <NO_COM                           ; If none, then stay here
1008      P:00026A P:00026A 00008C            ENDDO
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 19



1009      P:00026B P:00026B 0C005D            JMP     <PRC_RCV
1010      P:00026C P:00026C 000000  NO_COM    NOP
1011                                L_RESET
1012      P:00026D P:00026D 0C022D            JMP     <CONT_RST
1013   
1014                                ; Simple clocking routine for resetting and clearing
1015      P:00026E P:00026E 062080  CLK_COL   DO      #32,L_CLOCK
                            000275
1016      P:000270 P:000270 60F400            MOVE              #CLOCK_COLUMN,R0
                            0000B1
1017                                          CLOCK
1021                                L_CLOCK
1022      P:000276 P:000276 00000C            RTS
1023   
1024                                ;  ************************  Readout subroutines  ********************
1025                                ; Normal readout of the whole array
1026   
1027                                NORMAL_READOUT
1028                                ;       ;MOVE   #FRAME_RESET,R0
1029                                ;       ;CLOCK
1030                                ;       JCLR    #ST_CDS,X:STATUS,*+3
1031                                ;       JSR     <READOUT                ; Read the array
1032                                ;       JSR     <WAIT_TO_FINISH_CLOCKING
1033                                ;       MOVE    #L_EXP1,R7              ; Return address at end of exposure
1034                                ;       JMP     <EXPOSE                 ; Delay for specified exposure time
1035                                ;L_EXP1
1036                                ;       JSR     <READOUT
1037                                ;       JMP     <DONE_READOUT
1038   
1039   
1040                                RESET_ARRAY
1041      P:000277 P:000277 60F400            MOVE              #FRAME_RESET,R0
                            000016
1042      P:000279 P:000279 0D0471            JSR     <CLOCK
1043      P:00027A P:00027A 60F400            MOVE              #FRAME_RESET,R0
                            000016
1044      P:00027C P:00027C 0D0471            JSR     <CLOCK
1045      P:00027D P:00027D 60F400            MOVE              #FRAME_RESET,R0
                            000016
1046      P:00027F P:00027F 0D0471            JSR     <CLOCK
1047      P:000280 P:000280 60F400            MOVE              #FRAME_RESET,R0
                            000016
1048      P:000282 P:000282 0D0471            JSR     <CLOCK
1049      P:000283 P:000283 00000C            RTS
1050   
1051                                ; Now start reading out the image with the frame initialization clocks first
1052                                READOUT
1053      P:000284 P:000284 0D0461            JSR     <PCI_READ_IMAGE
1054      P:000285 P:000285 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1055                                          CLOCK
1059      P:00028B P:00028B 068080            DO      #128,L_READOUT
                            0002A9
1060      P:00028D P:00028D 60F400            MOVE              #CLOCK_ROW_1,R0
                            00002B
1061                                          CLOCK
1065      P:000293 P:000293 0D0351            JSR     <CLK_COL_AND_READ
1066      P:000294 P:000294 60F400            MOVE              #CLOCK_ROW_2,R0
                            000031
1067                                          CLOCK
1071      P:00029A P:00029A 0D0351            JSR     <CLK_COL_AND_READ
1072      P:00029B P:00029B 60F400            MOVE              #CLOCK_ROW_3,R0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 20



                            000037
1073                                          CLOCK
1077      P:0002A1 P:0002A1 0D0351            JSR     <CLK_COL_AND_READ
1078      P:0002A2 P:0002A2 60F400            MOVE              #CLOCK_ROW_4,R0
                            00003D
1079                                          CLOCK
1083      P:0002A8 P:0002A8 0D0351            JSR     <CLK_COL_AND_READ
1084      P:0002A9 P:0002A9 000000            NOP
1085                                L_READOUT
1086      P:0002AA P:0002AA 00000C            RTS
1087   
1088                                ; Row-by-row reset and readout, for high illumination levels
1089                                ROW_BY_ROW_RESET_READOUT
1090      P:0002AB P:0002AB 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1091      P:0002AC P:0002AC 0A0024            BSET    #ST_RDC,X:<STATUS                 ; Set status to reading out
1092      P:0002AD P:0002AD 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1093      P:0002AF P:0002AF 0D00EB            JSR     <XMT_WRD
1094      P:0002B0 P:0002B0 57F400            MOVE              #'RDA',B
                            524441
1095      P:0002B2 P:0002B2 0D00EB            JSR     <XMT_WRD
1096      P:0002B3 P:0002B3 57F400            MOVE              #1024,B                 ; Number of columns to read
                            000400
1097      P:0002B5 P:0002B5 0D00EB            JSR     <XMT_WRD
1098      P:0002B6 P:0002B6 0A00B1            JSET    #ST_CDS,X:STATUS,RRR_CDS
                            0002F5
1099   
1100                                ; Read out the image in single read mode, row-by-row reset
1101      P:0002B8 P:0002B8 57F400            MOVE              #1024,B                 ; Number of rows to read
                            000400
1102      P:0002BA P:0002BA 0D00EB            JSR     <XMT_WRD
1103      P:0002BB P:0002BB 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1104                                          CLOCK
1108      P:0002C1 P:0002C1 068080            DO      #128,L_RR_RESET_READOUT
                            0002F3
1109      P:0002C3 P:0002C3 60F400            MOVE              #RESET_ROW_12,R0
                            0000A3
1110                                          CLOCK
1114      P:0002C9 P:0002C9 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1115      P:0002CA P:0002CA 67F400            MOVE              #L_RR12,R7
                            0002CD
1116      P:0002CC P:0002CC 0C03B0            JMP     <EXPOSE
1117                                L_RR12
1118      P:0002CD P:0002CD 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            000043
1119                                          CLOCK
1123      P:0002D3 P:0002D3 0D0351            JSR     <CLK_COL_AND_READ
1124      P:0002D4 P:0002D4 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000049
1125                                          CLOCK
1129      P:0002DA P:0002DA 0D0351            JSR     <CLK_COL_AND_READ
1130   
1131      P:0002DB P:0002DB 60F400            MOVE              #RESET_ROW_34,R0
                            0000AA
1132                                          CLOCK
1136      P:0002E1 P:0002E1 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1137      P:0002E2 P:0002E2 67F400            MOVE              #L_RR34,R7
                            0002E5
1138      P:0002E4 P:0002E4 0C03B0            JMP     <EXPOSE
1139                                L_RR34
1140      P:0002E5 P:0002E5 60F400            MOVE              #CLOCK_RR_ROW_3,R0
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 21



                            00004F
1141                                          CLOCK
1145      P:0002EB P:0002EB 0D0351            JSR     <CLK_COL_AND_READ
1146      P:0002EC P:0002EC 60F400            MOVE              #CLOCK_RR_ROW_4,R0
                            000055
1147                                          CLOCK
1151      P:0002F2 P:0002F2 0D0351            JSR     <CLK_COL_AND_READ
1152      P:0002F3 P:0002F3 000000            NOP
1153                                L_RR_RESET_READOUT
1154   
1155      P:0002F4 P:0002F4 0C0341            JMP     <DONE_READOUT
1156   
1157                                ; Read out the image in CDS mode, row-by-row reset
1158      P:0002F5 P:0002F5 57F400  RRR_CDS   MOVE              #1024,B
                            000400
1159      P:0002F7 P:0002F7 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1160      P:0002F8 P:0002F8 60F400            MOVE              #FRAME_INIT,R0
                            00000F
1161                                          CLOCK
1165      P:0002FE P:0002FE 068080            DO      #128,CDS_RR_RESET_READOUT
                            000340
1166      P:000300 P:000300 60F400            MOVE              #CLOCK_CDS_RESET_ROW_1,R0
                            00007F
1167                                          CLOCK
1171      P:000306 P:000306 0D0351            JSR     <CLK_COL_AND_READ
1172      P:000307 P:000307 60F400            MOVE              #CLOCK_CDS_RESET_ROW_2,R0
                            000088
1173                                          CLOCK
1177      P:00030D P:00030D 0D0351            JSR     <CLK_COL_AND_READ
1178      P:00030E P:00030E 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1179      P:00030F P:00030F 67F400            MOVE              #CDS_RR1,R7
                            000312
1180      P:000311 P:000311 0C03B0            JMP     <EXPOSE
1181                                CDS_RR1
1182      P:000312 P:000312 60F400            MOVE              #CLOCK_RR_ROW_1,R0
                            000043
1183                                          CLOCK
1187      P:000318 P:000318 0D0351            JSR     <CLK_COL_AND_READ
1188      P:000319 P:000319 60F400            MOVE              #CLOCK_RR_ROW_2,R0
                            000049
1189                                          CLOCK
1193      P:00031F P:00031F 0D0351            JSR     <CLK_COL_AND_READ
1194   
1195      P:000320 P:000320 60F400            MOVE              #CLOCK_CDS_RESET_ROW_3,R0
                            000091
1196                                          CLOCK
1200      P:000326 P:000326 0D0351            JSR     <CLK_COL_AND_READ
1201      P:000327 P:000327 60F400            MOVE              #CLOCK_CDS_RESET_ROW_4,R0
                            00009A
1202                                          CLOCK
1206      P:00032D P:00032D 0D0351            JSR     <CLK_COL_AND_READ
1207      P:00032E P:00032E 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1208      P:00032F P:00032F 67F400            MOVE              #CDS_RR3,R7
                            000332
1209      P:000331 P:000331 0C03B0            JMP     <EXPOSE
1210                                CDS_RR3
1211      P:000332 P:000332 60F400            MOVE              #CLOCK_RR_ROW_3,R0
                            00004F
1212                                          CLOCK
1216      P:000338 P:000338 0D0351            JSR     <CLK_COL_AND_READ
1217      P:000339 P:000339 60F400            MOVE              #CLOCK_RR_ROW_4,R0
                            000055
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 22



1218                                          CLOCK
1222      P:00033F P:00033F 0D0351            JSR     <CLK_COL_AND_READ
1223      P:000340 P:000340 000000            NOP
1224                                CDS_RR_RESET_READOUT
1225   
1226                                ; This is code for continuous readout - check if more frames are needed
1227                                DONE_READOUT
1228      P:000341 P:000341 5E8B00            MOVE                          Y:<N_FRAMES,A ; Are we in continuous readout mode?
1229      P:000342 P:000342 014185            CMP     #1,A
1230      P:000343 P:000343 0EF34A            JLE     <RDA_END
1231      P:000344 P:000344 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1232      P:000345 P:000345 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1233   
1234                                ; Check for a command once. Only the ABORT command should be issued.
1235      P:000346 P:000346 330700            MOVE              #COM_BUF,R3
1236      P:000347 P:000347 0D00A5            JSR     <GET_RCV                          ; Was a command received?
1237      P:000348 P:000348 0E03F2            JCC     <NEXT_FRAME                       ; If no, get the next frame
1238      P:000349 P:000349 0C005D            JMP     <PRC_RCV                          ; If yes, go process it
1239   
1240                                ; Restore the controller to non-image data transfer and idling if necessary
1241      P:00034A P:00034A 60F400  RDA_END   MOVE              #CONT_RST,R0            ; Process commands, don't idle,
                            00022D
1242      P:00034C P:00034C 601F00            MOVE              R0,X:<IDL_ADR           ;    during the exposure
1243      P:00034D P:00034D 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1244      P:00034E P:00034E 0C0054            JMP     <START
1245   
1246   
1247                                ;  ********  End of readout routines  ****************
1248   
1249                                ; Simple implementation
1250      P:00034F P:00034F 010F20  CONTRD    BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer
1251      P:000350 P:000350 0C0054            JMP     <START
1252   
1253                                CLK_COL_AND_READ
1254      P:000351 P:000351 60F400            MOVE              #RD_COL_PIPELINE,R0
                            0000B6
1255                                          CLOCK
1259      P:000357 P:000357 061F80            DO      #31,L_CLOCK_COLUMN_AND_READ
                            00035F
1260      P:000359 P:000359 60F400            MOVE              #RD_COLS,R0
                            0000CD
1261                                          CLOCK
1265      P:00035F P:00035F 000000            NOP
1266                                L_CLOCK_COLUMN_AND_READ
1267      P:000360 P:000360 60F400            MOVE              #LAST_8INROW,R0         ;  Clock last 8 pixels
                            0000E4
1268                                          CLOCK
1272      P:000366 P:000366 00000C            RTS
1273   
1274                                ; ******  Include many routines not directly needed for readout  *******
1275                                          INCLUDE "timIRmisc.asm"
1276                                ; Miscellaneous IR array control routines, common to all detector types
1277   
1278                                POWER_OFF
1279      P:000367 P:000367 0D0394            JSR     <CLEAR_SWITCHES_AND_DACS          ; Clear switches and DACs
1280      P:000368 P:000368 0A8922            BSET    #LVEN,X:HDR                       ; Turn off low +/- 6.5, +/- 16.5 supplies
1281      P:000369 P:000369 0A8923            BSET    #HVEN,X:HDR                       ; Turn off high +36 supply
1282      P:00036A P:00036A 0C008F            JMP     <FINISH
1283   
1284                                ; Start power-on cycle
1285                                POWER_ON
1286      P:00036B P:00036B 0D0394            JSR     <CLEAR_SWITCHES_AND_DACS          ; Clear all analog switches
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 23



1287      P:00036C P:00036C 0D0376            JSR     <PON                              ; Turn on the power control board
1288      P:00036D P:00036D 0A8980            JCLR    #PWROK,X:HDR,PWR_ERR              ; Test if the power turned on properly
                            000373
1289      P:00036F P:00036F 60F400            MOVE              #CONT_RST,R0            ; Put controller in continuous readout
                            00022D
1290      P:000371 P:000371 601F00            MOVE              R0,X:<IDL_ADR           ;   state
1291      P:000372 P:000372 0C008F            JMP     <FINISH
1292   
1293                                ; The power failed to turn on because of an error on the power control board
1294      P:000373 P:000373 0A8922  PWR_ERR   BSET    #LVEN,X:HDR                       ; Turn off the low voltage emable line
1295      P:000374 P:000374 0A8923            BSET    #HVEN,X:HDR                       ; Turn off the high voltage emable line
1296      P:000375 P:000375 0C008D            JMP     <ERROR
1297   
1298                                ; Now ramp up the low voltages (+/- 6.5V, 16.5V) and delay them to turn on
1299      P:000376 P:000376 0A0F20  PON       BSET    #CDAC,X:<LATCH                    ; Disable clearing of DACs
1300      P:000377 P:000377 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1301   
1302                                ; Write all the bias voltages to the DACs
1303                                SET_BIASES
1304      P:000379 P:000379 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1305      P:00037A P:00037A 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1306      P:00037B P:00037B 09F4B3            MOVEP             #$002000,Y:WRSS         ; Set clock driver switches low
                            002000
1307      P:00037D P:00037D 09F4B3            MOVEP             #$003000,Y:WRSS
                            003000
1308      P:00037F P:00037F 0A8902            BCLR    #LVEN,X:HDR                       ; LVEN = Low => Turn on +/- 6.5V,
1309      P:000380 P:000380 0A8923            BSET    #HVEN,X:HDR
1310      P:000381 P:000381 56F400            MOVE              #>40,A                  ; Delay for the power to turn on
                            000028
1311      P:000383 P:000383 0D0435            JSR     <MILLISEC_DELAY
1312   
1313                                ; Write the values to the clock driver and DC bias supplies
1314      P:000384 P:000384 60F400            MOVE              #BIASES,R0              ; Turn on the power before writing to
                            00015C
1315      P:000386 P:000386 0D0481            JSR     <SET_DAC                          ;  the DACs since the MAX829 DAcs need
1316      P:000387 P:000387 60F400            MOVE              #CLOCKS,R0              ;  power to be written to
                            00012A
1317      P:000389 P:000389 0D0481            JSR     <SET_DAC
1318      P:00038A P:00038A 0D047C            JSR     <PAL_DLY
1319   
1320      P:00038B P:00038B 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable the output switches
1321      P:00038C P:00038C 09F0B5            MOVEP             X:LATCH,Y:WRLATCH
                            00000F
1322      P:00038E P:00038E 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1323      P:00038F P:00038F 00000C            RTS
1324   
1325                                SET_BIAS_VOLTAGES
1326      P:000390 P:000390 0D0379            JSR     <SET_BIASES
1327      P:000391 P:000391 0C008F            JMP     <FINISH
1328   
1329      P:000392 P:000392 0D0394  CLR_SWS   JSR     <CLEAR_SWITCHES_AND_DACS
1330      P:000393 P:000393 0C008F            JMP     <FINISH
1331   
1332                                CLEAR_SWITCHES_AND_DACS
1333      P:000394 P:000394 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Clear all the DACs
1334      P:000395 P:000395 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable all the output switches
1335      P:000396 P:000396 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1336      P:000398 P:000398 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1337      P:000399 P:000399 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 24



1338      P:00039B P:00039B 20001B            CLR     B
1339      P:00039C P:00039C 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
1340      P:00039D P:00039D 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
1341      P:00039F P:00039F 060F80            DO      #15,L_VIDEO                       ; Fifteen video processor boards maximum
                            0003A6
1342      P:0003A1 P:0003A1 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1343      P:0003A2 P:0003A2 200040            ADD     X0,A
1344      P:0003A3 P:0003A3 5F7000            MOVE                          B,Y:WRSS
                            FFFFF3
1345      P:0003A5 P:0003A5 0D047C            JSR     <PAL_DLY                          ; Delay for the serial data transmission
1346      P:0003A6 P:0003A6 200068            ADD     X1,B
1347                                L_VIDEO
1348      P:0003A7 P:0003A7 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1349      P:0003A8 P:0003A8 00000C            RTS
1350   
1351                                ; Fast clear of the array, executed as a command
1352      P:0003A9 P:0003A9 60F400  CLEAR     MOVE              #FRAME_RESET,R0
                            000016
1353                                          CLOCK
1357      P:0003AF P:0003AF 0C008F            JMP     <FINISH
1358   
1359                                ; Start the exposure timer and monitor its progress
1360                                EXPOSE
1361      P:0003B0 P:0003B0 07F40E            MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1362      P:0003B2 P:0003B2 240000            MOVE              #0,X0
1363      P:0003B3 P:0003B3 441100            MOVE              X0,X:<ELAPSED_TIME      ; Set elapsed exposure time to zero
1364      P:0003B4 P:0003B4 579000            MOVE              X:<EXPOSURE_TIME,B
1365      P:0003B5 P:0003B5 20000B            TST     B                                 ; Special test for zero exposure time
1366      P:0003B6 P:0003B6 0EA3C2            JEQ     <END_EXP                          ; Don't even start an exposure
1367      P:0003B7 P:0003B7 01418C            SUB     #1,B                              ; Timer counts from X:TCPR0+1 to zero
1368      P:0003B8 P:0003B8 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1369      P:0003B9 P:0003B9 577000            MOVE              B,X:TCPR0
                            FFFF8D
1370                                CHK_RCV
1371      P:0003BB P:0003BB 0A8989            JCLR    #EF,X:HDR,CHK_TIM                 ; Simple test for fast execution
                            0003C0
1372      P:0003BD P:0003BD 330700            MOVE              #COM_BUF,R3             ; The beginning of the command buffer
1373      P:0003BE P:0003BE 0D00A5            JSR     <GET_RCV                          ; Check for an incoming command
1374      P:0003BF P:0003BF 0E805D            JCS     <PRC_RCV                          ; If command is received, go check it
1375                                CHK_TIM
1376      P:0003C0 P:0003C0 018F95            JCLR    #TCF,X:TCSR0,CHK_RCV              ; Wait for timer to equal compare value
                            0003BB
1377                                END_EXP
1378      P:0003C2 P:0003C2 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the timer
1379      P:0003C3 P:0003C3 0AE780            JMP     (R7)                              ; This contains the return address
1380   
1381                                ;  *****************  Start the exposure  *****************
1382                                ;START_EXPOSURE
1383                                ;       MOVE    #TST_RCV,R0             ; Process commands, don't idle,
1384                                ;       MOVE    R0,X:<IDL_ADR           ;    during the exposure
1385                                START_EXPOSURE
1386      P:0003C4 P:0003C4 0D040E            JSR     <INIT_PCI_IMAGE_ADDRESS
1387      P:0003C5 P:0003C5 305A00            MOVE              #TST_RCV,R0             ; Process commands, don't idle,
1388      P:0003C6 P:0003C6 601F00            MOVE              R0,X:<IDL_ADR           ;    during the exposure
1389      P:0003C7 P:0003C7 000000            NOP
1390      P:0003C8 P:0003C8 0D0277            JSR     <RESET_ARRAY                      ; Clear out the FPA
1391      P:0003C9 P:0003C9 000000            NOP
1392      P:0003CA P:0003CA 060A40            DO      Y:<NFS,RD1_END                    ; Fowler sampling
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 25



                            0003D2
1393      P:0003CC P:0003CC 0D0284            JSR     <READOUT                          ; Read out the FPA
1394      P:0003CD P:0003CD 000000            NOP
1395      P:0003CE P:0003CE 000000            NOP
1396      P:0003CF P:0003CF 000000            NOP
1397      P:0003D0 P:0003D0 000000            NOP
1398      P:0003D1 P:0003D1 000000            NOP
1399      P:0003D2 P:0003D2 000000            NOP
1400                                RD1_END
1401      P:0003D3 P:0003D3 67F400            MOVE              #L_SEX1,R7              ; Return address at end of exposure
                            0003D7
1402      P:0003D5 P:0003D5 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1403      P:0003D6 P:0003D6 0C03B0            JMP     <EXPOSE                           ; Delay for specified exposure time
1404                                L_SEX1
1405      P:0003D7 P:0003D7 060A40            DO      Y:<NFS,RD2_END                    ; Fowler sampling
                            0003DF
1406      P:0003D9 P:0003D9 0D0284            JSR     <READOUT                          ; Go read out the FPA
1407      P:0003DA P:0003DA 000000            NOP
1408      P:0003DB P:0003DB 000000            NOP
1409      P:0003DC P:0003DC 000000            NOP
1410      P:0003DD P:0003DD 000000            NOP
1411      P:0003DE P:0003DE 000000            NOP
1412      P:0003DF P:0003DF 000000            NOP
1413                                RD2_END
1414      P:0003E0 P:0003E0 60F400            MOVE              #CONT_RST,R0            ; Continuously read array in idle mode
                            00022D
1415      P:0003E2 P:0003E2 601F00            MOVE              R0,X:<IDL_ADR
1416      P:0003E3 P:0003E3 000000            NOP
1417      P:0003E4 P:0003E4 0C0054            JMP     <START
1418   
1419   
1420   
1421                                ; Test for continuous readout
1422      P:0003E5 P:0003E5 5E8B00            MOVE                          Y:<N_FRAMES,A
1423      P:0003E6 P:0003E6 014185            CMP     #1,A
1424      P:0003E7 P:0003E7 0EF3FE            JLE     <INIT_PCI_BOARD
1425   
1426                                INIT_FRAME_COUNT
1427      P:0003E8 P:0003E8 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1428      P:0003E9 P:0003E9 57F400            MOVE              #$020102,B              ; Initialize the PCI frame counter
                            020102
1429      P:0003EB P:0003EB 0D00EB            JSR     <XMT_WRD
1430      P:0003EC P:0003EC 57F400            MOVE              #'IFC',B
                            494643
1431      P:0003EE P:0003EE 0D00EB            JSR     <XMT_WRD
1432      P:0003EF P:0003EF 240000            MOVE              #0,X0
1433      P:0003F0 P:0003F0 4C0C00            MOVE                          X0,Y:<I_FRAME ; Initialize the frame number
1434      P:0003F1 P:0003F1 0C03FE            JMP     <INIT_PCI_BOARD
1435   
1436                                ; Start up the next frame of the coaddition series
1437                                NEXT_FRAME
1438      P:0003F2 P:0003F2 5E8C00            MOVE                          Y:<I_FRAME,A ; Get the # of frames coadded so far
1439      P:0003F3 P:0003F3 014180            ADD     #1,A
1440      P:0003F4 P:0003F4 4C8B00            MOVE                          Y:<N_FRAMES,X0 ; See if we've coadded enough frames
1441      P:0003F5 P:0003F5 5C0C00            MOVE                          A1,Y:<I_FRAME ; Increment the coaddition frame counter
1442      P:0003F6 P:0003F6 200045            CMP     X0,A
1443      P:0003F7 P:0003F7 0E134A            JGE     <RDA_END                          ; End of coaddition sequence
1444   
1445      P:0003F8 P:0003F8 5E8D00            MOVE                          Y:<IBUFFER,A ; Get the position in the buffer
1446      P:0003F9 P:0003F9 014180            ADD     #1,A
1447      P:0003FA P:0003FA 4C8E00            MOVE                          Y:<N_FPB,X0
1448      P:0003FB P:0003FB 5C0D00            MOVE                          A1,Y:<IBUFFER
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 26



1449      P:0003FC P:0003FC 200045            CMP     X0,A
1450      P:0003FD P:0003FD 0E9406            JLT     <SEX_1                            ; Test if the frame buffer is full
1451   
1452                                INIT_PCI_BOARD
1453      P:0003FE P:0003FE 240000            MOVE              #0,X0
1454      P:0003FF P:0003FF 4C0D00            MOVE                          X0,Y:<IBUFFER ; IBUFFER counts from 0 to N_FPB
1455      P:000400 P:000400 57F400            MOVE              #$020102,B
                            020102
1456      P:000402 P:000402 0D00EB            JSR     <XMT_WRD
1457      P:000403 P:000403 57F400            MOVE              #'IIA',B                ; Initialize the PCI image address
                            494941
1458      P:000405 P:000405 0D00EB            JSR     <XMT_WRD
1459   
1460                                ; Start the exposure
1461      P:000406 P:000406 0A00AA  SEX_1     JSET    #TST_IMG,X:STATUS,SYNTHETIC_IMAGE
                            000441
1462      P:000408 P:000408 56F400            MOVE              #$0c1000,A              ; Reset video processor FIFOs
                            0C1000
1463      P:00040A P:00040A 0D045A            JSR     <WR_BIAS
1464      P:00040B P:00040B 0A00B2            JSET    #ST_RRR,X:STATUS,ROW_BY_ROW_RESET_READOUT
                            0002AB
1465      P:00040D P:00040D 0C0277            JMP     <NORMAL_READOUT
1466   
1467   
1468                                ; ********************* Initialize PCI image address ***********************
1469                                INIT_PCI_IMAGE_ADDRESS
1470      P:00040E P:00040E 57F400            MOVE              #$020102,B              ; Initialize the PCI image address
                            020102
1471      P:000410 P:000410 0D00EB            JSR     <XMT_WRD
1472      P:000411 P:000411 57F400            MOVE              #'IIA',B
                            494941
1473      P:000413 P:000413 0D00EB            JSR     <XMT_WRD
1474      P:000414 P:000414 00000C            RTS
1475   
1476   
1477                                ; Set the desired exposure time
1478                                SET_EXPOSURE_TIME
1479      P:000415 P:000415 46DB00            MOVE              X:(R3)+,Y0
1480      P:000416 P:000416 461000            MOVE              Y0,X:EXPOSURE_TIME
1481      P:000417 P:000417 018F80            JCLR    #TIM_BIT,X:TCSR0,FINISH           ; Return if exposure not occurring
                            00008F
1482      P:000419 P:000419 467000            MOVE              Y0,X:TCPR0              ; Update timer if exposure in progress
                            FFFF8D
1483      P:00041B P:00041B 0C008F            JMP     <FINISH
1484   
1485                                ; Read the time remaining until the exposure ends
1486                                READ_EXPOSURE_TIME
1487      P:00041C P:00041C 018FA0            JSET    #TIM_BIT,X:TCSR0,RD_TIM           ; Read DSP timer if its running
                            000420
1488      P:00041E P:00041E 479100            MOVE              X:<ELAPSED_TIME,Y1
1489      P:00041F P:00041F 0C0090            JMP     <FINISH1
1490      P:000420 P:000420 47F000  RD_TIM    MOVE              X:TCR0,Y1               ; Read elapsed exposure time
                            FFFF8C
1491      P:000422 P:000422 0C0090            JMP     <FINISH1
1492   
1493                                ; Pause the exposure - close the shutter and stop the timer
1494                                PAUSE_EXPOSURE
1495      P:000423 P:000423 07700C            MOVEP             X:TCR0,X:ELAPSED_TIME   ; Save the elapsed exposure time
                            000011
1496      P:000425 P:000425 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1497      P:000426 P:000426 0C008F            JMP     <FINISH
1498   
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 27



1499                                ; Resume the exposure - open the shutter if needed and restart the timer
1500                                RESUME_EXPOSURE
1501      P:000427 P:000427 07F00E            MOVEP             X:ELAPSED_TIME,X:TLR0   ; Restore elapsed exposure time
                            000011
1502      P:000429 P:000429 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Re-enable the DSP exposure timer
1503      P:00042A P:00042A 0C008F  L_RES     JMP     <FINISH
1504   
1505                                ; Special ending after abort command to send a 'DON' to the host computer
1506                                ; Abort exposure - close the shutter, stop the timer and resume idle mode
1507                                ABORT_EXPOSURE
1508      P:00042B P:00042B 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1509      P:00042C P:00042C 60F400            MOVE              #CONT_RST,R0
                            00022D
1510      P:00042E P:00042E 601F00            MOVE              R0,X:<IDL_ADR
1511      P:00042F P:00042F 0D046E            JSR     <WAIT_TO_FINISH_CLOCKING
1512      P:000430 P:000430 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1513      P:000431 P:000431 06A08F            DO      #4000,*+3                         ; Wait 40 microsec for the fiber
                            000433
1514      P:000433 P:000433 000000            NOP                                       ;  optic to clear out
1515      P:000434 P:000434 0C008F            JMP     <FINISH
1516   
1517                                ; Short delay for the array to settle down after a global reset
1518                                MILLISEC_DELAY
1519      P:000435 P:000435 200003            TST     A
1520      P:000436 P:000436 0E2438            JNE     <DLY_IT
1521      P:000437 P:000437 00000C            RTS
1522      P:000438 P:000438 07F40E  DLY_IT    MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1523      P:00043A P:00043A 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1524      P:00043B P:00043B 567000            MOVE              A,X:TCPR0               ; Desired elapsed time
                            FFFF8D
1525      P:00043D P:00043D 018F95  CNT_DWN   JCLR    #TCF,X:TCSR0,CNT_DWN              ; Wait here for timer to count down
                            00043D
1526      P:00043F P:00043F 010F00            BCLR    #TIM_BIT,X:TCSR0
1527      P:000440 P:000440 00000C            RTS
1528   
1529                                ; Generate a synthetic image by simply incrementing the pixel counts
1530                                SYNTHETIC_IMAGE
1531      P:000441 P:000441 0D0461            JSR     <PCI_READ_IMAGE
1532      P:000442 P:000442 200013            CLR     A
1533      P:000443 P:000443 060240            DO      Y:<NPR,LPR_TST                    ; Loop over each line readout
                            00044E
1534      P:000445 P:000445 060140            DO      Y:<NSR,LSR_TST                    ; Loop over number of pixels per line
                            00044D
1535      P:000447 P:000447 0614A0            REP     #20                               ; #20 => 1.0 microsec per pixel
1536      P:000448 P:000448 000000            NOP
1537      P:000449 P:000449 014180            ADD     #1,A                              ; Pixel data = Pixel data + 1
1538      P:00044A P:00044A 000000            NOP
1539      P:00044B P:00044B 21CF00            MOVE              A,B
1540      P:00044C P:00044C 0D0450            JSR     <XMT_PIX                          ; Transmit the pixel data
1541      P:00044D P:00044D 000000            NOP
1542                                LSR_TST
1543      P:00044E P:00044E 000000            NOP
1544                                LPR_TST
1545      P:00044F P:00044F 00000C            RTS
1546   
1547                                ; Transmit the 16-bit pixel datum in B1 to the host computer
1548      P:000450 P:000450 0C1DA1  XMT_PIX   ASL     #16,B,B
1549      P:000451 P:000451 000000            NOP
1550      P:000452 P:000452 216500            MOVE              B2,X1
1551      P:000453 P:000453 0C1D91            ASL     #8,B,B
1552      P:000454 P:000454 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 28



1553      P:000455 P:000455 216400            MOVE              B2,X0
1554      P:000456 P:000456 000000            NOP
1555      P:000457 P:000457 09C532            MOVEP             X1,Y:WRFO
1556      P:000458 P:000458 09C432            MOVEP             X0,Y:WRFO
1557      P:000459 P:000459 00000C            RTS
1558   
1559                                ; Write a number to an analog board over the serial link
1560      P:00045A P:00045A 012F23  WR_BIAS   BSET    #3,X:PCRD                         ; Turn on the serial clock
1561      P:00045B P:00045B 0D047C            JSR     <PAL_DLY
1562      P:00045C P:00045C 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1563      P:00045D P:00045D 0D047C            JSR     <PAL_DLY
1564      P:00045E P:00045E 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1565      P:00045F P:00045F 0D047C            JSR     <PAL_DLY
1566      P:000460 P:000460 00000C            RTS
1567   
1568                                ; Alert the PCI interface board that images are coming soon
1569                                ;   Image size = 512columns x 512 x # of Fowler samples x 2 if CDS
1570   
1571                                PCI_READ_IMAGE
1572      P:000461 P:000461 57F400            MOVE              #$020104,B              ; Send header word to the FO transmitter
                            020104
1573      P:000463 P:000463 0D00EB            JSR     <XMT_WRD
1574      P:000464 P:000464 57F400            MOVE              #'RDA',B
                            524441
1575      P:000466 P:000466 0D00EB            JSR     <XMT_WRD
1576      P:000467 P:000467 57F400            MOVE              #'NSR',B                ; Number of columns to read 2048 for 4Q
                            4E5352
1577      P:000469 P:000469 0D00EB            JSR     <XMT_WRD
1578      P:00046A P:00046A 57F400            MOVE              #'NPR',B                ; 512 x 2FS x2 (because we always do CDS)
                            4E5052
1579      P:00046C P:00046C 0D00EB            JSR     <XMT_WRD                          ; Number of rows to read
1580      P:00046D P:00046D 00000C            RTS
1581   
1582                                ; Wait for the clocking to be complete before proceeding
1583                                WAIT_TO_FINISH_CLOCKING
1584      P:00046E P:00046E 01ADA1            JSET    #SSFEF,X:PDRD,*                   ; Wait for the SS FIFO to be empty
                            00046E
1585      P:000470 P:000470 00000C            RTS
1586   
1587                                ; This MOVEP instruction executes in 30 nanosec, 20 nanosec for the MOVEP,
1588                                ;   and 10 nanosec for the wait state that is required for SRAM writes and
1589                                ;   FIFO setup times. It looks reliable, so will be used for now.
1590   
1591                                ; Core subroutine for clocking
1592                                CLOCK
1593      P:000471 P:000471 0A898E            JCLR    #SSFHF,X:HDR,*                    ; Only write to FIFO if < half full
                            000471
1594      P:000473 P:000473 000000            NOP
1595      P:000474 P:000474 0A898E            JCLR    #SSFHF,X:HDR,CLOCK                ; Guard against metastability
                            000471
1596      P:000476 P:000476 4CD800            MOVE                          Y:(R0)+,X0  ; # of waveform entries
1597      P:000477 P:000477 06C400            DO      X0,CLK1                           ; Repeat X0 times
                            000479
1598      P:000479 P:000479 09D8F3            MOVEP             Y:(R0)+,Y:WRSS          ; 30 nsec Write the waveform to the SS
1599                                CLK1
1600      P:00047A P:00047A 000000            NOP
1601      P:00047B P:00047B 00000C            RTS                                       ; Return from subroutine
1602   
1603                                ; Delay for serial writes to the PALs and DACs by 8 microsec
1604      P:00047C P:00047C 062083  PAL_DLY   DO      #800,DLY                          ; Wait 8 usec for serial data transmission
                            00047E
1605      P:00047E P:00047E 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 29



1606      P:00047F P:00047F 000000  DLY       NOP
1607      P:000480 P:000480 00000C            RTS
1608   
1609                                ; Read DAC values from a table, and write them to the DACs
1610      P:000481 P:000481 065840  SET_DAC   DO      Y:(R0)+,L_DAC                     ; Repeat Y:(R0)+ times
                            000488
1611      P:000483 P:000483 5ED800            MOVE                          Y:(R0)+,A   ; Read the table entry
1612      P:000484 P:000484 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1613      P:000485 P:000485 000000            NOP
1614      P:000486 P:000486 0D047C            JSR     <PAL_DLY
1615      P:000487 P:000487 0D047C            JSR     <PAL_DLY
1616      P:000488 P:000488 000000            NOP
1617      P:000489 P:000489 00000C  L_DAC     RTS
1618   
1619                                ; Let the host computer read the controller configuration
1620                                READ_CONTROLLER_CONFIGURATION
1621      P:00048A P:00048A 4F8800            MOVE                          Y:<CONFIG,Y1 ; Just transmit the configuration
1622      P:00048B P:00048B 0C0090            JMP     <FINISH1
1623   
1624                                ; Set a particular DAC numbers, for setting DC bias voltages, clock driver
1625                                ;   voltages and video processor offset
1626                                ;
1627                                ; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
1628                                ;
1629                                ;                               #BOARD is from 0 to 15
1630                                ;                               #DAC number
1631                                ;                               #voltage is from 0 to 4095
1632   
1633                                SET_BIAS_NUMBER                                     ; Set bias number
1634      P:00048C P:00048C 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1635      P:00048D P:00048D 56DB00            MOVE              X:(R3)+,A               ; First argument is board number, 0 to 15
1636      P:00048E P:00048E 0614A0            REP     #20
1637      P:00048F P:00048F 200033            LSL     A
1638      P:000490 P:000490 000000            NOP
1639      P:000491 P:000491 21C500            MOVE              A,X1                    ; Save the board number
1640      P:000492 P:000492 56DB00            MOVE              X:(R3)+,A               ; Second argument is DAC number
1641      P:000493 P:000493 000000            NOP
1642      P:000494 P:000494 5C0000            MOVE                          A1,Y:0      ; Save the DAC number for a little while
1643      P:000495 P:000495 57DB00            MOVE              X:(R3)+,B               ; Third argument is 'VID' or 'CLK' string
1644      P:000496 P:000496 0140CD            CMP     #'VID',B
                            564944
1645      P:000498 P:000498 0EA4D2            JEQ     <ERR_SBN                          ; Video board offsets aren't supported
1646      P:000499 P:000499 0140CD            CMP     #'CLK',B
                            434C4B
1647      P:00049B P:00049B 0E24D2            JNE     <ERR_SBN
1648   
1649                                ; For ARC32 do some trickiness to set the chip select and address bits
1650      P:00049C P:00049C 218F00            MOVE              A1,B
1651      P:00049D P:00049D 060EA0            REP     #14
1652      P:00049E P:00049E 200033            LSL     A
1653      P:00049F P:00049F 240E00            MOVE              #$0E0000,X0
1654      P:0004A0 P:0004A0 200046            AND     X0,A
1655      P:0004A1 P:0004A1 44F400            MOVE              #>7,X0
                            000007
1656      P:0004A3 P:0004A3 20004E            AND     X0,B                              ; Get 3 least significant bits of clock #
1657      P:0004A4 P:0004A4 01408D            CMP     #0,B
1658      P:0004A5 P:0004A5 0E24A8            JNE     <CLK_1
1659      P:0004A6 P:0004A6 0ACE68            BSET    #8,A
1660      P:0004A7 P:0004A7 0C04C3            JMP     <BD_SET
1661      P:0004A8 P:0004A8 01418D  CLK_1     CMP     #1,B
1662      P:0004A9 P:0004A9 0E24AC            JNE     <CLK_2
1663      P:0004AA P:0004AA 0ACE69            BSET    #9,A
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 30



1664      P:0004AB P:0004AB 0C04C3            JMP     <BD_SET
1665      P:0004AC P:0004AC 01428D  CLK_2     CMP     #2,B
1666      P:0004AD P:0004AD 0E24B0            JNE     <CLK_3
1667      P:0004AE P:0004AE 0ACE6A            BSET    #10,A
1668      P:0004AF P:0004AF 0C04C3            JMP     <BD_SET
1669      P:0004B0 P:0004B0 01438D  CLK_3     CMP     #3,B
1670      P:0004B1 P:0004B1 0E24B4            JNE     <CLK_4
1671      P:0004B2 P:0004B2 0ACE6B            BSET    #11,A
1672      P:0004B3 P:0004B3 0C04C3            JMP     <BD_SET
1673      P:0004B4 P:0004B4 01448D  CLK_4     CMP     #4,B
1674      P:0004B5 P:0004B5 0E24B8            JNE     <CLK_5
1675      P:0004B6 P:0004B6 0ACE6D            BSET    #13,A
1676      P:0004B7 P:0004B7 0C04C3            JMP     <BD_SET
1677      P:0004B8 P:0004B8 01458D  CLK_5     CMP     #5,B
1678      P:0004B9 P:0004B9 0E24BC            JNE     <CLK_6
1679      P:0004BA P:0004BA 0ACE6E            BSET    #14,A
1680      P:0004BB P:0004BB 0C04C3            JMP     <BD_SET
1681      P:0004BC P:0004BC 01468D  CLK_6     CMP     #6,B
1682      P:0004BD P:0004BD 0E24C0            JNE     <CLK_7
1683      P:0004BE P:0004BE 0ACE6F            BSET    #15,A
1684      P:0004BF P:0004BF 0C04C3            JMP     <BD_SET
1685      P:0004C0 P:0004C0 01478D  CLK_7     CMP     #7,B
1686      P:0004C1 P:0004C1 0E24C3            JNE     <BD_SET
1687      P:0004C2 P:0004C2 0ACE70            BSET    #16,A
1688   
1689      P:0004C3 P:0004C3 200062  BD_SET    OR      X1,A                              ; Add on the board number
1690      P:0004C4 P:0004C4 000000            NOP
1691      P:0004C5 P:0004C5 21C400            MOVE              A,X0
1692      P:0004C6 P:0004C6 56DB00            MOVE              X:(R3)+,A               ; Fourth argument is voltage value, 0 to $ff
f
1693      P:0004C7 P:0004C7 0604A0            REP     #4
1694      P:0004C8 P:0004C8 200023            LSR     A                                 ; Convert 12 bits to 8 bits for ARC32
1695      P:0004C9 P:0004C9 46F400            MOVE              #>$FF,Y0                ; Mask off just 8 bits
                            0000FF
1696      P:0004CB P:0004CB 200056            AND     Y0,A
1697      P:0004CC P:0004CC 200042            OR      X0,A
1698      P:0004CD P:0004CD 000000            NOP
1699      P:0004CE P:0004CE 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1700      P:0004CF P:0004CF 0D047C            JSR     <PAL_DLY                          ; Wait for the number to be sent
1701      P:0004D0 P:0004D0 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1702      P:0004D1 P:0004D1 0C008F            JMP     <FINISH
1703      P:0004D2 P:0004D2 56DB00  ERR_SBN   MOVE              X:(R3)+,A               ; Read and discard the fourth argument
1704      P:0004D3 P:0004D3 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1705      P:0004D4 P:0004D4 0C008D            JMP     <ERROR
1706   
1707                                ; Specify the MUX value to be output on the clock driver board
1708                                ; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
1709                                ;                               #clock_driver_board from 0 to 15
1710                                ;                               #MUX1, #MUX2 from 0 to 23
1711   
1712      P:0004D5 P:0004D5 012F23  SET_MUX   BSET    #3,X:PCRD                         ; Turn on the serial clock
1713      P:0004D6 P:0004D6 56DB00            MOVE              X:(R3)+,A               ; Clock driver board number
1714      P:0004D7 P:0004D7 0614A0            REP     #20
1715      P:0004D8 P:0004D8 200033            LSL     A
1716      P:0004D9 P:0004D9 44F400            MOVE              #$001000,X0             ; Bits to select MUX on ARC32 board
                            001000
1717      P:0004DB P:0004DB 200042            OR      X0,A
1718      P:0004DC P:0004DC 000000            NOP
1719      P:0004DD P:0004DD 218500            MOVE              A1,X1                   ; Move here for later use
1720   
1721                                ; Get the first MUX number
1722      P:0004DE P:0004DE 56DB00            MOVE              X:(R3)+,A               ; Get the first MUX number
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 31



1723      P:0004DF P:0004DF 200003            TST     A
1724      P:0004E0 P:0004E0 0E9525            JLT     <ERR_SM1
1725      P:0004E1 P:0004E1 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1726      P:0004E3 P:0004E3 200045            CMP     X0,A
1727      P:0004E4 P:0004E4 0E1525            JGE     <ERR_SM1
1728      P:0004E5 P:0004E5 21CF00            MOVE              A,B
1729      P:0004E6 P:0004E6 44F400            MOVE              #>7,X0
                            000007
1730      P:0004E8 P:0004E8 20004E            AND     X0,B
1731      P:0004E9 P:0004E9 44F400            MOVE              #>$18,X0
                            000018
1732      P:0004EB P:0004EB 200046            AND     X0,A
1733      P:0004EC P:0004EC 0E24EF            JNE     <SMX_1                            ; Test for 0 <= MUX number <= 7
1734      P:0004ED P:0004ED 0ACD63            BSET    #3,B1
1735      P:0004EE P:0004EE 0C04FA            JMP     <SMX_A
1736      P:0004EF P:0004EF 44F400  SMX_1     MOVE              #>$08,X0
                            000008
1737      P:0004F1 P:0004F1 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1738      P:0004F2 P:0004F2 0E24F5            JNE     <SMX_2
1739      P:0004F3 P:0004F3 0ACD64            BSET    #4,B1
1740      P:0004F4 P:0004F4 0C04FA            JMP     <SMX_A
1741      P:0004F5 P:0004F5 44F400  SMX_2     MOVE              #>$10,X0
                            000010
1742      P:0004F7 P:0004F7 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
1743      P:0004F8 P:0004F8 0E2525            JNE     <ERR_SM1
1744      P:0004F9 P:0004F9 0ACD65            BSET    #5,B1
1745      P:0004FA P:0004FA 20006A  SMX_A     OR      X1,B1                             ; Add prefix to MUX numbers
1746      P:0004FB P:0004FB 000000            NOP
1747      P:0004FC P:0004FC 21A700            MOVE              B1,Y1
1748   
1749                                ; Add on the second MUX number
1750      P:0004FD P:0004FD 56DB00            MOVE              X:(R3)+,A               ; Get the next MUX number
1751      P:0004FE P:0004FE 200003            TST     A
1752      P:0004FF P:0004FF 0E9526            JLT     <ERR_SM2
1753      P:000500 P:000500 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1754      P:000502 P:000502 200045            CMP     X0,A
1755      P:000503 P:000503 0E1526            JGE     <ERR_SM2
1756      P:000504 P:000504 0606A0            REP     #6
1757      P:000505 P:000505 200033            LSL     A
1758      P:000506 P:000506 000000            NOP
1759      P:000507 P:000507 21CF00            MOVE              A,B
1760      P:000508 P:000508 44F400            MOVE              #$1C0,X0
                            0001C0
1761      P:00050A P:00050A 20004E            AND     X0,B
1762      P:00050B P:00050B 44F400            MOVE              #>$600,X0
                            000600
1763      P:00050D P:00050D 200046            AND     X0,A
1764      P:00050E P:00050E 0E2511            JNE     <SMX_3                            ; Test for 0 <= MUX number <= 7
1765      P:00050F P:00050F 0ACD69            BSET    #9,B1
1766      P:000510 P:000510 0C051C            JMP     <SMX_B
1767      P:000511 P:000511 44F400  SMX_3     MOVE              #>$200,X0
                            000200
1768      P:000513 P:000513 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1769      P:000514 P:000514 0E2517            JNE     <SMX_4
1770      P:000515 P:000515 0ACD6A            BSET    #10,B1
1771      P:000516 P:000516 0C051C            JMP     <SMX_B
1772      P:000517 P:000517 44F400  SMX_4     MOVE              #>$400,X0
                            000400
1773      P:000519 P:000519 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
1774      P:00051A P:00051A 0E2526            JNE     <ERR_SM2
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  timIRmisc.asm  Page 32



1775      P:00051B P:00051B 0ACD6B            BSET    #11,B1
1776      P:00051C P:00051C 200078  SMX_B     ADD     Y1,B                              ; Add prefix to MUX numbers
1777      P:00051D P:00051D 000000            NOP
1778      P:00051E P:00051E 21AE00            MOVE              B1,A
1779      P:00051F P:00051F 0140C6            AND     #$F01FFF,A                        ; Just to be sure
                            F01FFF
1780      P:000521 P:000521 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1781      P:000522 P:000522 0D047C            JSR     <PAL_DLY                          ; Delay for all this to happen
1782      P:000523 P:000523 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1783      P:000524 P:000524 0C008F            JMP     <FINISH
1784      P:000525 P:000525 56DB00  ERR_SM1   MOVE              X:(R3)+,A               ; Throw off the last argument
1785      P:000526 P:000526 012F03  ERR_SM2   BCLR    #3,X:PCRD                         ; Turn the serial clock off
1786      P:000527 P:000527 0C008D            JMP     <ERROR
1787   
1788   
1789                                CORRELATED_DOUBLE_SAMPLE
1790      P:000528 P:000528 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
1791      P:000529 P:000529 0AC420            JSET    #0,X0,CDS_SET
                            00052D
1792      P:00052B P:00052B 0A0011            BCLR    #ST_CDS,X:STATUS
1793      P:00052C P:00052C 0C008F            JMP     <FINISH
1794      P:00052D P:00052D 0A0031  CDS_SET   BSET    #ST_CDS,X:STATUS
1795      P:00052E P:00052E 0C008F            JMP     <FINISH
1796   
1797                                SELECT_ROW_BY_ROW_RESET
1798      P:00052F P:00052F 44DB00            MOVE              X:(R3)+,X0              ; Get the command argument
1799      P:000530 P:000530 0AC420            JSET    #0,X0,RR_SET
                            000534
1800      P:000532 P:000532 0A0012            BCLR    #ST_RRR,X:STATUS
1801      P:000533 P:000533 0C008F            JMP     <FINISH
1802      P:000534 P:000534 0A0032  RR_SET    BSET    #ST_RRR,X:STATUS
1803      P:000535 P:000535 0C008F            JMP     <FINISH
1804   
1805                                ;******************************************************************************
1806                                ; Set number of Fowler samples per frame
1807                                SET_NUMBER_OF_FOWLER_SAMPLES
1808      P:000536 P:000536 44DB00            MOVE              X:(R3)+,X0
1809      P:000537 P:000537 4C0A00            MOVE                          X0,Y:<NFS   ; Number of Fowler samples
1810      P:000538 P:000538 0C008F            JMP     <FINISH
1811   
1812                                ;******************************************************************************
1813                                ; Set the number of RESET frame.
1814                                ;SET_NUMBER_OF_RESET
1815                                ;       MOVE    X:(R3)+,X0
1816                                ;       MOVE    X0,Y:<NRESET
1817                                ;       JMP     <FINISH
1818   
1819   
1820                                ; Continuous readout commands
1821                                SET_NUMBER_OF_FRAMES                                ; Number of frames to obtain
1822      P:000539 P:000539 44DB00            MOVE              X:(R3)+,X0              ;   in an exposure sequence
1823      P:00053A P:00053A 4C0B00            MOVE                          X0,Y:<N_FRAMES
1824      P:00053B P:00053B 0C008F            JMP     <FINISH
1825   
1826                                SET_NUMBER_OF_FRAMES_PER_BUFFER                     ; Number of frames in each image
1827      P:00053C P:00053C 44DB00            MOVE              X:(R3)+,X0              ;   buffer in the host computer
1828      P:00053D P:00053D 4C0E00            MOVE                          X0,Y:<N_FPB ;   system memory
1829      P:00053E P:00053E 0C008F            JMP     <FINISH
1830   
1831   
1832                                 TIMBOOT_X_MEMORY
1833      00053F                              EQU     @LCV(L)
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 33



1834   
1835                                ;  ****************  Setup memory tables in X: space ********************
1836   
1837                                ; Define the address in P: space where the table of constants begins
1838   
1839                                          IF      @SCP("HOST","HOST")
1840      X:000036 X:000036                   ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
1841                                          ENDIF
1842   
1843                                          IF      @SCP("HOST","ROM")
1845                                          ENDIF
1846   
1847                                ; Application commands
1848      X:000036 X:000036                   DC      'PON',POWER_ON
1849      X:000038 X:000038                   DC      'POF',POWER_OFF
1850      X:00003A X:00003A                   DC      'SBV',SET_BIAS_VOLTAGES
1851      X:00003C X:00003C                   DC      'IDL',FINISH
1852      X:00003E X:00003E                   DC      'CLR',CLEAR
1853   
1854                                ; Exposure and readout control routines
1855      X:000040 X:000040                   DC      'SET',SET_EXPOSURE_TIME
1856      X:000042 X:000042                   DC      'RET',READ_EXPOSURE_TIME
1857      X:000044 X:000044                   DC      'SEX',START_EXPOSURE
1858      X:000046 X:000046                   DC      'PEX',PAUSE_EXPOSURE
1859      X:000048 X:000048                   DC      'REX',RESUME_EXPOSURE
1860      X:00004A X:00004A                   DC      'AEX',ABORT_EXPOSURE
1861      X:00004C X:00004C                   DC      'ABR',ABORT_EXPOSURE
1862      X:00004E X:00004E                   DC      'CDS',CORRELATED_DOUBLE_SAMPLE
1863      X:000050 X:000050                   DC      'RRR',SELECT_ROW_BY_ROW_RESET
1864      X:000052 X:000052                   DC      'SFS',SET_NUMBER_OF_FOWLER_SAMPLES
1865   
1866                                ; Support routines
1867      X:000054 X:000054                   DC      'SBN',SET_BIAS_NUMBER
1868      X:000056 X:000056                   DC      'SMX',SET_MUX
1869      X:000058 X:000058                   DC      'CSW',CLR_SWS
1870      X:00005A X:00005A                   DC      'RCC',READ_CONTROLLER_CONFIGURATION
1871   
1872                                ; Continuous readout commands
1873      X:00005C X:00005C                   DC      'SNF',SET_NUMBER_OF_FRAMES
1874      X:00005E X:00005E                   DC      'FPB',SET_NUMBER_OF_FRAMES_PER_BUFFER
1875   
1876                                 END_APPLICATON_COMMAND_TABLE
1877      000060                              EQU     @LCV(L)
1878   
1879                                          IF      @SCP("HOST","HOST")
1880      00001C                    NUM_COM   EQU     (@LCV(R)-COM_TBL_R)/2             ; Number of boot +
1881                                                                                    ;  application commands
1882      0003C0                    EXPOSING  EQU     CHK_TIM                           ; Address if exposing
1883                                 CONTINUE_READING
1884      100000                              EQU     CONT_RD                           ; Address if reading out
1885                                          ENDIF
1886   
1887                                          IF      @SCP("HOST","ROM")
1889                                          ENDIF
1890   
1891                                ; Now let's go for the timing waveform tables
1892                                          IF      @SCP("HOST","HOST")
1893      Y:000000 Y:000000                   ORG     Y:0,Y:0
1894                                          ENDIF
1895   
1896      Y:000000 Y:000000         GAIN      DC      END_APPLICATON_Y_MEMORY-@LCV(L)-1
1897   
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  tim.asm  Page 34



1898      Y:000001 Y:000001         NSR       DC      2048                              ; 2048 4 Quadrants multiplexed
1899      Y:000002 Y:000002         NPR       DC      1024                              ; 2048 = 2(CDS) x NFS(2) x 512
1900      Y:000003 Y:000003         NSCLR     DC      0                                 ; Not used
1901      Y:000004 Y:000004         NPCLR     DC      0                                 ; Not used
1902      Y:000005 Y:000005         DUMMY     DC      0,0                               ; Binning parameters (reserved)
1903      Y:000007 Y:000007         TST_DAT   DC      0                                 ; Temporary definition for test images
1904      Y:000008 Y:000008         CONFIG    DC      CC                                ; Controller configuration
1905      Y:000009 Y:000009         TRM_ADR   DC      0                                 ; Test RAM memory error address
1906      Y:00000A Y:00000A         NFS       DC      1                                 ; Number of Fowler samples
1907   
1908                                ; Continuous readout parameters
1909      Y:00000B Y:00000B         N_FRAMES  DC      1                                 ; Total number of frames to read out
1910      Y:00000C Y:00000C         I_FRAME   DC      0                                 ; Number of frames read out so far
1911      Y:00000D Y:00000D         IBUFFER   DC      0                                 ; Number of frames read into the PCI buffer
1912      Y:00000E Y:00000E         N_FPB     DC      0                                 ; Number of frames per PCI image buffer
1913   
1914                                ; Include the waveform table for the designated IR array
1915                                          INCLUDE "AladdinIII.waveforms"            ; Readout and clocking waveform file
1916                                       COMMENT *
1917   
1918                                Waveform tables for Aladdin III IR array to be used with one ARC-46 =
1919                                        8-channel video processor boards and Gen III = ARC22 = 250 MHz
1920                                        timing board and ARC-32 clock driver board.
1921                                Modified Feb. 2009 for row-by-row reset for high flux observations
1922   
1923                                        *
1924   
1925      000001                    AD        EQU     $000001                           ; Bit to start A/D conversion
1926      000002                    XFER      EQU     $000002                           ; Bit to transfer A/D counts into the A/D FI
FO
1927      00F7C0                    SXMIT     EQU     $00F7C0                           ; Transmit 32 pixels = 4 Aladdin quadrant
1928   
1929                                ; Definitions of readout variables
1930      002000                    CLK2      EQU     $002000                           ; Clock driver board lower half
1931      003000                    CLK3      EQU     $003000                           ; Clock driver board upper half
1932      000000                    VIDEO     EQU     $000000                           ; Video processor board switches
1933   
1934                                ; Various delay parameters
1935      100000                    DLY0      EQU     $100000
1936      180000                    DLY1      EQU     $180000                           ; 1.0 microsec
1937      320000                    DLY2      EQU     $320000                           ; 2.0 microsec
1938      640000                    DLY4      EQU     $640000                           ; 4.0 microsec
1939      930000                    DLY6      EQU     $930000                           ; 6.0 microsec
1940   
1941      130000                    DLYA      EQU     $130000                           ; Pixel readout delay parameters
1942      040000                    DLYB      EQU     $040000
1943      C00000                    DLYG      EQU     $C00000
1944   
1945      0C0000                    XMT_DLY   EQU     $0C0000                           ; Delay per SXMIT for the fiber optic transm
itter
1946   
1947                                ; Voltages for operating the Aladdin III focal plane array. The clock driver
1948                                ;   needs to be jumpered for bipolar operation because of the output source
1949                                ;   load resistor driver, VSSOUT = +1.0
1950   
1951   
1952                                ; Voltages for operating the Aladdin III focal plane array ORIGINAL
1953                                ;CLK_HI         EQU     +0.0    ; Clock voltage low
1954                                ;CLK_LO         EQU     -5.0    ; Clock voltage low
1955                                ;VRW_LO         EQU     -4.0    ; VrowON low voltage
1956                                ;VRST_HI                EQU     -3.5    ; VrstG high voltage
1957                                ;VRST_LO                EQU     -5.8    ; VrstG low voltage
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 35



1958                                ;ZERO           EQU      0.0    ; Unused clock driver voltage
1959      000002                    ADREF     EQU     +2                                ; A/D converter voltage reference
1960      00000D                    Vmax      EQU     13                                ; Maximum clock driver voltage, clock board
1961      2.600000E+001             Vmax1     EQU     2.0*Vmax
1962      7.500000E+000             Vmax2     EQU     7.5                               ; 2 x Maximum clock driver voltage
1963      1.500000E+001             Vmax3     EQU     2.0*Vmax2
1964   
1965                                ; Voltages for operating the Aladdin III focal plane array TWEAKED BY LUC AS NASA IRTF
1966      -5.000000E-001            CLK_HI    EQU     -0.5                              ; Clock voltage high
1967      -5.800000E+000            CLK_LO    EQU     -5.8                              ; Clock voltage low
1968      -4.000000E+000            VRW_LO    EQU     -4.0                              ; VrowON low voltage
1969      -3.500000E+000            VRST_HI   EQU     -3.5                              ; VrstG high voltage
1970      -5.800000E+000            VRST_LO   EQU     -5.8                              ; VrstG low voltage
1971      0.000000E+000             ZERO      EQU     0.0                               ; Unused clock driver voltage
1972   
1973   
1974                                ; Define switch state bits for CLK2 = bottom of clock board
1975      000001                    SSYNC     EQU     1                                 ; Slow Sync             Pin #1
1976      000002                    S1        EQU     2                                 ; Slow phase 1          Pin #2
1977      000004                    S2        EQU     4                                 ; Slow phase 2          Pin #3
1978      000008                    SOE       EQU     8                                 ; Odd/Even row select   Pin #4
1979      000010                    RDES      EQU     $10                               ; Row deselect          Pin #5
1980      000020                    VRSTOFF   EQU     $20                               ; Global reset = VrstG  Pin #6
1981      000040                    VRSTR     EQU     $40                               ; Row reset bias        Pin #7
1982      000080                    VROWON    EQU     $80                               ; Bias to row enable    Pin #8
1983   
1984                                ; Define switch state bits for CLK3 = top of clock board
1985      000001                    FSYNC     EQU     1                                 ; Fast sync             Pin #13
1986      000002                    F1        EQU     2                                 ; Fast phase 1          Pin #14
1987      000004                    F2        EQU     4                                 ; Fast phase 2          Pin #15
1988   
1989                                ; Aladdin III DC bias voltage definition
1990                                ; Per Peter Onaka, "you shouldn't forward bias the InSb = VDDUC should always be more negative t
han VDET."
1991                                ; FIXME
1992      -2.800000E+000            VGGCL     EQU     -2.8                              ; Column Clamp Clock, was -3.1V but UIST set
s it to 0V and IRTF defines it at -3.1V but never switches it
1993      -2.800000E+000            VDDCL     EQU     -2.8                              ; Column Clamp Bias     was -3.6V now as UIS
T
1994      -4.000000E+000            VDDUC     EQU     -4.0                              ; Negative Unit Cell Bias set to same as Vde
tCom for warm testing else -4V
1995      -5.950000E+000            VNROW     EQU     -5.95                             ; Negative row supply
1996      -5.950000E+000            VNCOL     EQU     -5.95                             ; Negative column supply
1997      -1.500000E+000            VDDOUT    EQU     -1.5                              ; Drain voltage for drivers     was -1.2 now
 as UIST
1998      -3.400000E+000            VDETCOM   EQU     -3.4                              ; Detector Common not for MUX should be same
 as VdduC for warm testing else -3.4V
1999      -2.000000E+000            IREF      EQU     -2.0                              ; Reference current for Iidle and Islew
2000      4.500000E+000             VSSOUT    EQU     +4.5                              ; Source follower load voltage
2001      -5.000000E-001            VROWOFF   EQU     -0.5                              ; Applied to SF transistor gate M2 when row 
is not selected
2002   
2003                                ;V1             EQU -0.8                ; Voltages to test the video boards and firmware
2004                                ;V2             EQU     -0.9            ; Set in conjunction with offset and gain settings
2005                                ;V3             EQU     -1                      ; for testing of each video board with the jumpe
r connector
2006                                ;V4             EQU     -1.2
2007                                ;V5             EQU     -1.4
2008                                ;V6             EQU     -1.5
2009                                ;V7             EQU     +5.0
2010   
2011                                ; Video offset variable
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 36



2012                                ;OFFSET EQU     $760            ; for operation of the Aladdin III array -
2013                                                                                    ;   64k DN at -1.0 volts input => full well
2014                                                                                    ;    0k DN at -2.0 volts input => dark
2015                                                                                    ; Increase offset to lower image counts
2016   
2017      0007B0                    OFFSETB1  EQU     $7B0                              ; with slow int gain $760 gives 4kADU dark w
ith fast 8A0
2018      0007B0                    OFFSETB2  EQU     $7B0                              ; with fast int gain
2019      0007B0                    OFFSETB3  EQU     $7B0                              ; with fast int gain
2020      0007B0                    OFFSETB4  EQU     $7B0                              ; with fast int gain
2021   
2022      0007B0                    OFFSET0   EQU     OFFSETB1
2023      0007B0                    OFFSET1   EQU     OFFSETB1
2024      0007B0                    OFFSET2   EQU     OFFSETB1
2025      0007B0                    OFFSET3   EQU     OFFSETB1
2026      0007B0                    OFFSET4   EQU     OFFSETB1
2027      0007B0                    OFFSET5   EQU     OFFSETB1
2028      0007B0                    OFFSET6   EQU     OFFSETB1
2029      0007B0                    OFFSET7   EQU     OFFSETB1
2030   
2031      0007B0                    OFFSET8   EQU     OFFSETB2
2032      0007B0                    OFFSET9   EQU     OFFSETB2
2033      0007B0                    OFFSET10  EQU     OFFSETB2
2034      0007B0                    OFFSET11  EQU     OFFSETB2
2035      0007B0                    OFFSET12  EQU     OFFSETB2
2036      0007B0                    OFFSET13  EQU     OFFSETB2
2037      0007B0                    OFFSET14  EQU     OFFSETB2
2038      0007B0                    OFFSET15  EQU     OFFSETB2
2039   
2040      0007B0                    OFFSET16  EQU     OFFSETB3
2041      0007B0                    OFFSET17  EQU     OFFSETB3
2042      0007B0                    OFFSET18  EQU     OFFSETB3
2043      0007B0                    OFFSET19  EQU     OFFSETB3
2044      0007B0                    OFFSET20  EQU     OFFSETB3
2045      0007B0                    OFFSET21  EQU     OFFSETB3
2046      0007B0                    OFFSET22  EQU     OFFSETB3
2047      0007B0                    OFFSET23  EQU     OFFSETB3
2048   
2049      0007B0                    OFFSET24  EQU     OFFSETB4
2050      0007B0                    OFFSET25  EQU     OFFSETB4
2051      0007B0                    OFFSET26  EQU     OFFSETB4
2052      0007B0                    OFFSET27  EQU     OFFSETB4
2053      0007B0                    OFFSET28  EQU     OFFSETB4
2054      0007B0                    OFFSET29  EQU     OFFSETB4
2055      0007B0                    OFFSET30  EQU     OFFSETB4
2056      0007B0                    OFFSET31  EQU     OFFSETB4
2057   
2058                                ; Copy of the clocking bit definition for easy reference
2059                                ;       DC      CLK2+DELAY+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2060                                ;       DC      CLK3+DELAY+FSYNC+F1+F2
2061   
2062                                FRAME_INIT
2063      Y:00000F Y:00000F                   DC      END_FRAME_INIT-FRAME_INIT-1
2064      Y:000010 Y:000010                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2065      Y:000011 Y:000011                   DC      CLK2+DLY4+00000+S1+S2+SOE+0000+VRSTOFF+VRSTR+000000
2066      Y:000012 Y:000012                   DC      CLK2+DLY4+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2067      Y:000013 Y:000013                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2068      Y:000014 Y:000014                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2069      Y:000015 Y:000015                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2070                                END_FRAME_INIT
2071   
2072                                FRAME_RESET
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 37



2073      Y:000016 Y:000016                   DC      END_FRAME_RESET-FRAME_RESET-1
2074      Y:000017 Y:000017                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2075      Y:000018 Y:000018                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2076      Y:000019 Y:000019                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2077      Y:00001A Y:00001A                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2078      Y:00001B Y:00001B                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2079      Y:00001C Y:00001C                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2080      Y:00001D Y:00001D                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2081      Y:00001E Y:00001E                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2082      Y:00001F Y:00001F                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2083      Y:000020 Y:000020                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2084      Y:000021 Y:000021                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2085      Y:000022 Y:000022                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2086      Y:000023 Y:000023                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2087      Y:000024 Y:000024                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2088      Y:000025 Y:000025                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2089      Y:000026 Y:000026                   DC      CLK2+DLY1+00000+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2090      Y:000027 Y:000027                   DC      CLK2+DLYG+00000+S1+S2+SOE+RDES+0000000+VRSTR+000000
2091      Y:000028 Y:000028                   DC      CLK2+DLYG+SSYNC+S1+S2+SOE+RDES+0000000+VRSTR+000000
2092      Y:000029 Y:000029                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2093      Y:00002A Y:00002A                   DC      CLK2+DLY1+SSYNC+S1+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2094                                END_FRAME_RESET
2095   
2096                                CLOCK_ROW_1
2097      Y:00002B Y:00002B                   DC      END_CLOCK_ROW_1-CLOCK_ROW_1-1
2098      Y:00002C Y:00002C                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2099      Y:00002D Y:00002D                   DC      CLK3+DLY2+00000+F1+F2
2100      Y:00002E Y:00002E                   DC      CLK3+DLY1+FSYNC+F1+F2
2101      Y:00002F Y:00002F                   DC      CLK3+DLY2+FSYNC+00+F2
2102      Y:000030 Y:000030                   DC      CLK3+DLY0+FSYNC+F1+F2
2103                                END_CLOCK_ROW_1
2104   
2105                                CLOCK_ROW_2
2106      Y:000031 Y:000031                   DC      END_CLOCK_ROW_2-CLOCK_ROW_2-1
2107      Y:000032 Y:000032                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+000000
2108      Y:000033 Y:000033                   DC      CLK3+DLY2+00000+F1+F2
2109      Y:000034 Y:000034                   DC      CLK3+DLY1+FSYNC+F1+F2
2110      Y:000035 Y:000035                   DC      CLK3+DLY2+FSYNC+00+F2
2111      Y:000036 Y:000036                   DC      CLK3+DLY0+FSYNC+F1+F2
2112                                END_CLOCK_ROW_2
2113   
2114                                CLOCK_ROW_3
2115      Y:000037 Y:000037                   DC      END_CLOCK_ROW_3-CLOCK_ROW_3-1
2116      Y:000038 Y:000038                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2117      Y:000039 Y:000039                   DC      CLK3+DLY2+00000+F1+F2
2118      Y:00003A Y:00003A                   DC      CLK3+DLY1+FSYNC+F1+F2
2119      Y:00003B Y:00003B                   DC      CLK3+DLY2+FSYNC+00+F2
2120      Y:00003C Y:00003C                   DC      CLK3+DLY0+FSYNC+F1+F2
2121                                END_CLOCK_ROW_3
2122   
2123                                CLOCK_ROW_4
2124      Y:00003D Y:00003D                   DC      END_CLOCK_ROW_4-CLOCK_ROW_4-1
2125      Y:00003E Y:00003E                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+000000
2126      Y:00003F Y:00003F                   DC      CLK3+DLY2+00000+F1+F2
2127      Y:000040 Y:000040                   DC      CLK3+DLY1+FSYNC+F1+F2
2128      Y:000041 Y:000041                   DC      CLK3+DLY2+FSYNC+00+F2
2129      Y:000042 Y:000042                   DC      CLK3+DLY0+FSYNC+F1+F2
2130                                END_CLOCK_ROW_4
2131   
2132                                CLOCK_RR_ROW_1
2133      Y:000043 Y:000043                   DC      END_CLOCK_RR_ROW_1-CLOCK_RR_ROW_1-1
2134      Y:000044 Y:000044                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 38



2135      Y:000045 Y:000045                   DC      CLK3+DLY2+00000+F1+F2
2136      Y:000046 Y:000046                   DC      CLK3+DLY1+FSYNC+F1+F2
2137      Y:000047 Y:000047                   DC      CLK3+DLY2+FSYNC+00+F2
2138      Y:000048 Y:000048                   DC      CLK3+DLY0+FSYNC+F1+F2
2139                                END_CLOCK_RR_ROW_1
2140   
2141                                CLOCK_RR_ROW_2
2142      Y:000049 Y:000049                   DC      END_CLOCK_RR_ROW_2-CLOCK_RR_ROW_2-1
2143      Y:00004A Y:00004A                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2144      Y:00004B Y:00004B                   DC      CLK3+DLY2+00000+F1+F2
2145      Y:00004C Y:00004C                   DC      CLK3+DLY1+FSYNC+F1+F2
2146      Y:00004D Y:00004D                   DC      CLK3+DLY2+FSYNC+00+F2
2147      Y:00004E Y:00004E                   DC      CLK3+DLY0+FSYNC+F1+F2
2148                                END_CLOCK_RR_ROW_2
2149   
2150                                CLOCK_RR_ROW_3
2151      Y:00004F Y:00004F                   DC      END_CLOCK_RR_ROW_3-CLOCK_RR_ROW_3-1
2152      Y:000050 Y:000050                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2153      Y:000051 Y:000051                   DC      CLK3+DLY2+00000+F1+F2
2154      Y:000052 Y:000052                   DC      CLK3+DLY1+FSYNC+F1+F2
2155      Y:000053 Y:000053                   DC      CLK3+DLY2+FSYNC+00+F2
2156      Y:000054 Y:000054                   DC      CLK3+DLY0+FSYNC+F1+F2
2157                                END_CLOCK_RR_ROW_3
2158   
2159                                CLOCK_RR_ROW_4
2160      Y:000055 Y:000055                   DC      END_CLOCK_RR_ROW_4-CLOCK_RR_ROW_4-1
2161      Y:000056 Y:000056                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2162      Y:000057 Y:000057                   DC      CLK3+DLY2+00000+F1+F2
2163      Y:000058 Y:000058                   DC      CLK3+DLY1+FSYNC+F1+F2
2164      Y:000059 Y:000059                   DC      CLK3+DLY2+FSYNC+00+F2
2165      Y:00005A Y:00005A                   DC      CLK3+DLY0+FSYNC+F1+F2
2166                                END_CLOCK_RR_ROW_4
2167   
2168                                CLOCK_RESET_ROW_1
2169      Y:00005B Y:00005B                   DC      END_CLOCK_RESET_ROW_1-CLOCK_RESET_ROW_1-1
2170      Y:00005C Y:00005C                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2171      Y:00005D Y:00005D                   DC      CLK3+DLY0+00000+F1+F2
2172      Y:00005E Y:00005E                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2173      Y:00005F Y:00005F                   DC      CLK3+DLY4+FSYNC+F1+F2
2174      Y:000060 Y:000060                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2175      Y:000061 Y:000061                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2176      Y:000062 Y:000062                   DC      CLK3+DLY2+FSYNC+00+F2
2177      Y:000063 Y:000063                   DC      CLK3+DLY0+FSYNC+F1+F2
2178                                END_CLOCK_RESET_ROW_1
2179   
2180                                CLOCK_RESET_ROW_2
2181      Y:000064 Y:000064                   DC      END_CLOCK_RESET_ROW_2-CLOCK_RESET_ROW_2-1
2182      Y:000065 Y:000065                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2183      Y:000066 Y:000066                   DC      CLK3+DLY0+00000+F1+F2
2184      Y:000067 Y:000067                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2185      Y:000068 Y:000068                   DC      CLK3+DLY4+FSYNC+F1+F2
2186      Y:000069 Y:000069                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2187      Y:00006A Y:00006A                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2188      Y:00006B Y:00006B                   DC      CLK3+DLY2+FSYNC+00+F2
2189      Y:00006C Y:00006C                   DC      CLK3+DLY0+FSYNC+F1+F2
2190                                END_CLOCK_RESET_ROW_2
2191   
2192                                CLOCK_RESET_ROW_3
2193      Y:00006D Y:00006D                   DC      END_CLOCK_RESET_ROW_3-CLOCK_RESET_ROW_3-1
2194      Y:00006E Y:00006E                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2195      Y:00006F Y:00006F                   DC      CLK3+DLY0+00000+F1+F2
2196      Y:000070 Y:000070                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 39



2197      Y:000071 Y:000071                   DC      CLK3+DLY4+FSYNC+F1+F2
2198      Y:000072 Y:000072                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2199      Y:000073 Y:000073                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2200      Y:000074 Y:000074                   DC      CLK3+DLY2+FSYNC+00+F2
2201      Y:000075 Y:000075                   DC      CLK3+DLY0+FSYNC+F1+F2
2202                                END_CLOCK_RESET_ROW_3
2203   
2204                                CLOCK_RESET_ROW_4
2205      Y:000076 Y:000076                   DC      END_CLOCK_RESET_ROW_4-CLOCK_RESET_ROW_4-1
2206      Y:000077 Y:000077                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2207      Y:000078 Y:000078                   DC      CLK3+DLY0+00000+F1+F2
2208      Y:000079 Y:000079                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2209      Y:00007A Y:00007A                   DC      CLK3+DLY4+FSYNC+F1+F2
2210      Y:00007B Y:00007B                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2211      Y:00007C Y:00007C                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2212      Y:00007D Y:00007D                   DC      CLK3+DLY2+FSYNC+00+F2
2213      Y:00007E Y:00007E                   DC      CLK3+DLY0+FSYNC+F1+F2
2214                                END_CLOCK_RESET_ROW_4
2215   
2216                                CLOCK_CDS_RESET_ROW_1
2217      Y:00007F Y:00007F                   DC      END_CLOCK_CDS_RESET_ROW_1-CLOCK_CDS_RESET_ROW_1-1
2218      Y:000080 Y:000080                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2219      Y:000081 Y:000081                   DC      CLK3+DLY0+00000+F1+F2
2220      Y:000082 Y:000082                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2221      Y:000083 Y:000083                   DC      CLK3+DLY4+FSYNC+F1+F2
2222      Y:000084 Y:000084                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2223      Y:000085 Y:000085                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2224      Y:000086 Y:000086                   DC      CLK3+DLY2+FSYNC+00+F2
2225      Y:000087 Y:000087                   DC      CLK3+DLY0+FSYNC+F1+F2
2226                                END_CLOCK_CDS_RESET_ROW_1
2227   
2228                                CLOCK_CDS_RESET_ROW_2
2229      Y:000088 Y:000088                   DC      END_CLOCK_CDS_RESET_ROW_2-CLOCK_CDS_RESET_ROW_2-1
2230      Y:000089 Y:000089                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2231      Y:00008A Y:00008A                   DC      CLK3+DLY0+00000+F1+F2
2232      Y:00008B Y:00008B                   DC      CLK2+DLY2+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2233      Y:00008C Y:00008C                   DC      CLK3+DLY4+FSYNC+F1+F2
2234      Y:00008D Y:00008D                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2235      Y:00008E Y:00008E                   DC      CLK2+DLY1+SSYNC+S1+00+000+RDES+VRSTOFF+VRSTR+VROWON
2236      Y:00008F Y:00008F                   DC      CLK3+DLY2+FSYNC+00+F2
2237      Y:000090 Y:000090                   DC      CLK3+DLY0+FSYNC+F1+F2
2238                                END_CLOCK_CDS_RESET_ROW_2
2239   
2240                                CLOCK_CDS_RESET_ROW_3
2241      Y:000091 Y:000091                   DC      END_CLOCK_CDS_RESET_ROW_3-CLOCK_CDS_RESET_ROW_3-1
2242      Y:000092 Y:000092                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2243      Y:000093 Y:000093                   DC      CLK3+DLY0+00000+F1+F2
2244      Y:000094 Y:000094                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
2245      Y:000095 Y:000095                   DC      CLK3+DLY4+FSYNC+F1+F2
2246      Y:000096 Y:000096                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2247      Y:000097 Y:000097                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2248      Y:000098 Y:000098                   DC      CLK3+DLY2+FSYNC+00+F2
2249      Y:000099 Y:000099                   DC      CLK3+DLY0+FSYNC+F1+F2
2250                                END_CLOCK_CDS_RESET_ROW_3
2251   
2252                                CLOCK_CDS_RESET_ROW_4
2253      Y:00009A Y:00009A                   DC      END_CLOCK_CDS_RESET_ROW_4-CLOCK_CDS_RESET_ROW_4-1
2254      Y:00009B Y:00009B                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2255      Y:00009C Y:00009C                   DC      CLK3+DLY0+00000+F1+F2
2256      Y:00009D Y:00009D                   DC      CLK2+DLY2+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2257      Y:00009E Y:00009E                   DC      CLK3+DLY4+FSYNC+F1+F2
2258      Y:00009F Y:00009F                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 40



2259      Y:0000A0 Y:0000A0                   DC      CLK2+DLY1+SSYNC+00+S2+000+RDES+VRSTOFF+VRSTR+VROWON
2260      Y:0000A1 Y:0000A1                   DC      CLK3+DLY2+FSYNC+00+F2
2261      Y:0000A2 Y:0000A2                   DC      CLK3+DLY0+FSYNC+F1+F2
2262                                END_CLOCK_CDS_RESET_ROW_4
2263   
2264                                RESET_ROW_12
2265      Y:0000A3 Y:0000A3                   DC      END_RESET_ROW_12-RESET_ROW_12-1
2266      Y:0000A4 Y:0000A4                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2267      Y:0000A5 Y:0000A5                   DC      CLK3+DLY0+00000+F1+F2
2268      Y:0000A6 Y:0000A6                   DC      CLK2+DLY2+SSYNC+S1+00+SOE+RDES+VRSTOFF+00000+000000
2269      Y:0000A7 Y:0000A7                   DC      CLK3+DLY4+FSYNC+F1+F2
2270      Y:0000A8 Y:0000A8                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+000000
2271      Y:0000A9 Y:0000A9                   DC      CLK2+DLY1+SSYNC+S1+00+SOE+RDES+VRSTOFF+VRSTR+VROWON
2272                                END_RESET_ROW_12
2273   
2274                                RESET_ROW_34
2275      Y:0000AA Y:0000AA                   DC      END_RESET_ROW_34-RESET_ROW_34-1
2276      Y:0000AB Y:0000AB                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2277      Y:0000AC Y:0000AC                   DC      CLK3+DLY0+00000+F1+F2
2278      Y:0000AD Y:0000AD                   DC      CLK2+DLY2+SSYNC+00+S2+SOE+RDES+VRSTOFF+00000+000000
2279      Y:0000AE Y:0000AE                   DC      CLK3+DLY4+FSYNC+F1+F2
2280      Y:0000AF Y:0000AF                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+000000
2281      Y:0000B0 Y:0000B0                   DC      CLK2+DLY1+SSYNC+00+S2+SOE+RDES+VRSTOFF+VRSTR+VROWON
2282                                END_RESET_ROW_34
2283   
2284                                CLOCK_COLUMN
2285      Y:0000B1 Y:0000B1                   DC      END_CLOCK_COLUMN-CLOCK_COLUMN-1
2286      Y:0000B2 Y:0000B2                   DC      CLK3+DLYA+FSYNC+F1+00
2287      Y:0000B3 Y:0000B3                   DC      CLK3+DLYB+FSYNC+F1+F2
2288      Y:0000B4 Y:0000B4                   DC      CLK3+DLYA+FSYNC+00+F2
2289      Y:0000B5 Y:0000B5                   DC      CLK3+DLYB+FSYNC+F1+F2
2290                                END_CLOCK_COLUMN
2291   
2292                                ; Video processor bit definitions
2293   
2294                                ;       Bit #3 = Move A/D data to FIFO  (high going edge)
2295                                ;       Bit #2 = A/D Convert            (low going edge to start conversion)
2296                                ;       Bit #1 = Reset Integrator       (=0 to reset)
2297                                ;       Bit #0 = Integrate              (=0 to integrate)
2298   
2299      080000                    DTW       EQU     $080000                           ;  Tw Fast Sync Time (200ns + 40ns exec = 24
0ns)
2300      0F0000                    PAD_TIM   EQU     $0F0000                           ;  Pixel PAD Time               (600ns)
2301      180000                    INT_TIM   EQU     $180000                           ;  Pixel Sample Time            (960ns)
2302      180000                    ADC_TIM   EQU     $180000                           ;  ADC Hold/Conversion Time     (960ns)
2303      8C0000                    SXM_TIM   EQU     $8C0000                           ;  Pixel Transmit Delay         (3840ns)
2304      000000                    ADC_CNV   EQU     $000000                           ;  ADC Sample Time              (0ns)
2305      000000                    STL_TIM   EQU     $000000                           ;  A Generic Settling time      (0ns)
2306      040000                    RST_TIM   EQU     $040000                           ;  Stop                         (160ns)
2307      000000                    STP_TIM   EQU     $000000                           ;  Stop Reseting
2308   
2309                                ; This code initiates the pipeline for each row - no image transmission yet
2310                                RD_COL_PIPELINE
2311      Y:0000B6 Y:0000B6                   DC      END_RD_COL_PIPELINE-RD_COL_PIPELINE-1
2312      Y:0000B7 Y:0000B7                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1                40ns
2313      Y:0000B8 Y:0000B8                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -                   640ns
2314      Y:0000B9 Y:0000B9                   DC      VIDEO+ADC_TIM+%0111               ; Hold No Pixel         1000ns
2315      Y:0000BA Y:0000BA                   DC      VIDEO+STL_TIM+%0101               ; Move No Pixel                 40ns
2316      Y:0000BB Y:0000BB                   DC      VIDEO+$000000+%0101               ; Place for SXMIT               40ns
2317      Y:0000BC Y:0000BC                   DC      VIDEO+SXM_TIM+%0101               ; Settling time             3880ns
2318      Y:0000BD Y:0000BD                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting         40ns
2319      Y:0000BE Y:0000BE                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1         1000ns
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 41



2320      Y:0000BF Y:0000BF                   DC      VIDEO+$000000+%0111               ; Stop Integration      40ns
2321      Y:0000C0 Y:0000C0                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D cnv Pix 1   40ns
2322      Y:0000C1 Y:0000C1                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1              360ns
2323      Y:0000C2 Y:0000C2                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2                40ns
2324      Y:0000C3 Y:0000C3                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
2325      Y:0000C4 Y:0000C4                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert      1000ns
2326      Y:0000C5 Y:0000C5                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data FIFO    40ns
2327      Y:0000C6 Y:0000C6                   DC      SXMIT                             ; SXMIT the Previous    40ns
2328      Y:0000C7 Y:0000C7                   DC      VIDEO+SXM_TIM+%0101               ; Settling time             3880ns
2329      Y:0000C8 Y:0000C8                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting                 40ns
2330      Y:0000C9 Y:0000C9                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3         1000ns
2331      Y:0000CA Y:0000CA                   DC      VIDEO+$000000+%0111               ; Stop Integration      40ns
2332      Y:0000CB Y:0000CB                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert     40ns
2333      Y:0000CC Y:0000CC                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3              360ns
2334                                END_RD_COL_PIPELINE
2335   
2336                                ; This code reads out most of the array, with full image transmission
2337                                RD_COLS
2338      Y:0000CD Y:0000CD                   DC      END_RD_COLS-RD_COLS-1             ;
2339      Y:0000CE Y:0000CE                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2340      Y:0000CF Y:0000CF                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2341      Y:0000D0 Y:0000D0                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2342      Y:0000D1 Y:0000D1                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2343      Y:0000D2 Y:0000D2                   DC      SXMIT                             ; SXMIT the Previous Pixel 1 - X32 (40ns)
2344      Y:0000D3 Y:0000D3                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (3880ns)
2345      Y:0000D4 Y:0000D4                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2346      Y:0000D5 Y:0000D5                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2347      Y:0000D6 Y:0000D6                   DC      VIDEO+$000000+%0111               ; Stop Integration
2348      Y:0000D7 Y:0000D7                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (400ns)
2349      Y:0000D8 Y:0000D8                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2350      Y:0000D9 Y:0000D9                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 3 (40ns)
2351      Y:0000DA Y:0000DA                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2352      Y:0000DB Y:0000DB                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 2 (1us)
2353      Y:0000DC Y:0000DC                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 2 (40ns)
2354      Y:0000DD Y:0000DD                   DC      SXMIT                             ; SXMIT the Previous Pixel 2 - X32 (40ns)
2355      Y:0000DE Y:0000DE                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2356      Y:0000DF Y:0000DF                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2357      Y:0000E0 Y:0000E0                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3 (760ns)
2358      Y:0000E1 Y:0000E1                   DC      VIDEO+$000000+%0111               ; Stop Integration
2359      Y:0000E2 Y:0000E2                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 3 (400ns)
2360      Y:0000E3 Y:0000E3                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3 (240ns)
2361                                END_RD_COLS
2362   
2363                                ; This transmits the last pixels in each row, emptying the pipeline
2364                                LAST_8INROW
2365      Y:0000E4 Y:0000E4                   DC      END_LAST_8INROW-LAST_8INROW
2366      Y:0000E5 Y:0000E5                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2367      Y:0000E6 Y:0000E6                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2368      Y:0000E7 Y:0000E7                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2369      Y:0000E8 Y:0000E8                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2370      Y:0000E9 Y:0000E9                   DC      SXMIT                             ; SXMIT the Previous Pixel 1 - X32 (40ns)
2371      Y:0000EA Y:0000EA                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2372      Y:0000EB Y:0000EB                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2373      Y:0000EC Y:0000EC                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2374      Y:0000ED Y:0000ED                   DC      VIDEO+$000000+%0111               ; Stop Integration
2375      Y:0000EE Y:0000EE                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (40+40ns)
2376      Y:0000EF Y:0000EF                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2377                                END_LAST_8INROW
2378   
2379   
2380                                ; This code intiates the pipeline of pixels for each row
2381                                RD_NTX_PIPELINE
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 42



2382      Y:0000F0 Y:0000F0                   DC      END_RD_NTX_PIPELINE-RD_NTX_PIPELINE-1
2383      Y:0000F1 Y:0000F1                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 1        40ns
2384      Y:0000F2 Y:0000F2                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
2385      Y:0000F3 Y:0000F3                   DC      VIDEO+ADC_TIM+%0111               ; Hold No Pixel        1000ns
2386      Y:0000F4 Y:0000F4                   DC      VIDEO+STL_TIM+%0101               ; Move No Pixel          400ns
2387      Y:0000F5 Y:0000F5                   DC      VIDEO+$000000+%0101               ; Place for SXMIT        40ns
2388      Y:0000F6 Y:0000F6                   DC      VIDEO+SXM_TIM+%0101               ; Settling time            3880ns
2389      Y:0000F7 Y:0000F7                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting          40ns
2390      Y:0000F8 Y:0000F8                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 1    1000ns
2391      Y:0000F9 Y:0000F9                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
2392      Y:0000FA Y:0000FA                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D cnv Pix 1    40ns
2393      Y:0000FB Y:0000FB                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1      360ns
2394      Y:0000FC Y:0000FC                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 2         40ns
2395      Y:0000FD Y:0000FD                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay -           640ns
2396      Y:0000FE Y:0000FE                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert     1000ns
2397      Y:0000FF Y:0000FF                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data FIFO     40ns
2398      Y:000100 Y:000100                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2399      Y:000101 Y:000101                   DC      VIDEO+SXM_TIM+%0101               ; Settling time            3880ns
2400      Y:000102 Y:000102                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting          40ns
2401      Y:000103 Y:000103                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3    1000ns
2402      Y:000104 Y:000104                   DC      VIDEO+$000000+%0111               ; Stop Integration       40ns
2403      Y:000105 Y:000105                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert      40ns
2404      Y:000106 Y:000106                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3      360ns
2405                                END_RD_NTX_PIPELINE
2406   
2407                                RD_NTX
2408      Y:000107 Y:000107                   DC      END_RD_NTX-RD_NTX-1
2409      Y:000108 Y:000108                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2410      Y:000109 Y:000109                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2411      Y:00010A Y:00010A                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2412      Y:00010B Y:00010B                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2413      Y:00010C Y:00010C                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2414      Y:00010D Y:00010D                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2415      Y:00010E Y:00010E                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2416      Y:00010F Y:00010F                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2417      Y:000110 Y:000110                   DC      VIDEO+$000000+%0111               ; Stop Integration
2418      Y:000111 Y:000111                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (400ns)
2419      Y:000112 Y:000112                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2420      Y:000113 Y:000113                   DC      CLK3+000+FSYNC+00+F2              ; Select Pixel 3 (40ns)
2421      Y:000114 Y:000114                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2422      Y:000115 Y:000115                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 2 (1us)
2423      Y:000116 Y:000116                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 2 (40ns)
2424      Y:000117 Y:000117                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2425      Y:000118 Y:000118                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2426      Y:000119 Y:000119                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2427      Y:00011A Y:00011A                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 3 (760ns)
2428      Y:00011B Y:00011B                   DC      VIDEO+$000000+%0111               ; Stop Integration
2429      Y:00011C Y:00011C                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 3 (400ns)
2430      Y:00011D Y:00011D                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 3 (240ns)
2431                                END_RD_NTX
2432   
2433                                LAST_NTX_8INROW
2434      Y:00011E Y:00011E                   DC      END_LAST_NTX_8INROW-LAST_NTX_8INROW
2435      Y:00011F Y:00011F                   DC      CLK3+000+FSYNC+F1+00              ; Select Pixel 2 (40ns)
2436      Y:000120 Y:000120                   DC      VIDEO+PAD_TIM+%0111               ; Pad Delay - 40ns
2437      Y:000121 Y:000121                   DC      VIDEO+ADC_TIM+%0111               ; Hold A/D convert sig Pixel 1 (1us)
2438      Y:000122 Y:000122                   DC      VIDEO+STL_TIM+%1101               ; Move A/D data to FIFO Pixel 1 (40ns)
2439      Y:000123 Y:000123                   DC      VIDEO+0000000+%0101               ; Settling time          40ns
2440      Y:000124 Y:000124                   DC      VIDEO+SXM_TIM+%0101               ; Settling time (480ns)
2441      Y:000125 Y:000125                   DC      VIDEO+STP_TIM+%0111               ; Stop Reseting
2442      Y:000126 Y:000126                   DC      VIDEO+INT_TIM+%0110               ; Integrate Pixel 2 (760ns)
2443      Y:000127 Y:000127                   DC      VIDEO+$000000+%0111               ; Stop Integration
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 43



2444      Y:000128 Y:000128                   DC      VIDEO+ADC_CNV+%0011               ; Start A/D convert Pixel 2 (40+40ns)
2445      Y:000129 Y:000129                   DC      CLK3+DTW+FSYNC+F1+F2              ; Deselect Pixel 1 (240ns)
2446                                END_LAST_NTX_8INROW
2447   
2448      Y:00012A Y:00012A         CLOCKS    DC      END_CLOCKS-CLOCKS-1
2449      Y:00012B Y:00012B                   DC      $2A0080                           ; DAC = unbuffered mode
2450      Y:00012C Y:00012C                   DC      $200100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #1, SSYNC
2451      Y:00012D Y:00012D                   DC      $200200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2452      Y:00012E Y:00012E                   DC      $200400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #2, S1
2453      Y:00012F Y:00012F                   DC      $200800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2454      Y:000130 Y:000130                   DC      $202000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #3, S2
2455      Y:000131 Y:000131                   DC      $204000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2456      Y:000132 Y:000132                   DC      $208000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #4, SOE
2457      Y:000133 Y:000133                   DC      $210000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2458      Y:000134 Y:000134                   DC      $220100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #5, RDES
2459      Y:000135 Y:000135                   DC      $220200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2460      Y:000136 Y:000136                   DC      $220400+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #6, VRSTOFF
2461      Y:000137 Y:000137                   DC      $220800+@CVI(((VRST_LO+Vmax)/Vmax)*255) ;   = VrstG
2462      Y:000138 Y:000138                   DC      $222000+@CVI(((VRST_HI+Vmax)/Vmax)*255) ; Pin #7, VRSTR
2463      Y:000139 Y:000139                   DC      $224000+@CVI(((VRST_LO+Vmax)/Vmax)*255)
2464      Y:00013A Y:00013A                   DC      $228000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #8, VROWON
2465      Y:00013B Y:00013B                   DC      $230000+@CVI(((VRW_LO+Vmax)/Vmax)*255)
2466      Y:00013C Y:00013C                   DC      $240100+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #9, Unused
2467      Y:00013D Y:00013D                   DC      $240200+@CVI(((ZERO+Vmax)/Vmax)*255)
2468      Y:00013E Y:00013E                   DC      $240400+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #10, Unused
2469      Y:00013F Y:00013F                   DC      $240800+@CVI(((ZERO+Vmax)/Vmax)*255)
2470      Y:000140 Y:000140                   DC      $242000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #11, Unused
2471      Y:000141 Y:000141                   DC      $244000+@CVI(((ZERO+Vmax)/Vmax)*255)
2472      Y:000142 Y:000142                   DC      $248000+@CVI(((ZERO+Vmax)/Vmax)*255) ; Pin #12, Unused
2473      Y:000143 Y:000143                   DC      $250000+@CVI(((ZERO+Vmax)/Vmax)*255)
2474   
2475                                ; Upper bank
2476      Y:000144 Y:000144                   DC      $260100+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #13, FSYNC
2477      Y:000145 Y:000145                   DC      $260200+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2478      Y:000146 Y:000146                   DC      $260400+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #14, F1
2479      Y:000147 Y:000147                   DC      $260800+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2480      Y:000148 Y:000148                   DC      $262000+@CVI(((CLK_HI+Vmax)/Vmax)*255) ; Pin #15, F2
2481      Y:000149 Y:000149                   DC      $264000+@CVI(((CLK_LO+Vmax)/Vmax)*255)
2482      Y:00014A Y:00014A                   DC      $268000+@CVI(((ZERO+Vmax)/Vmax)*255)
2483      Y:00014B Y:00014B                   DC      $270000+@CVI(((ZERO+Vmax)/Vmax)*255)
2484      Y:00014C Y:00014C                   DC      $280100+@CVI(((ZERO+Vmax)/Vmax)*255)
2485      Y:00014D Y:00014D                   DC      $280200+@CVI(((ZERO+Vmax)/Vmax)*255)
2486      Y:00014E Y:00014E                   DC      $280400+@CVI(((ZERO+Vmax)/Vmax)*255)
2487      Y:00014F Y:00014F                   DC      $280800+@CVI(((ZERO+Vmax)/Vmax)*255)
2488      Y:000150 Y:000150                   DC      $282000+@CVI(((ZERO+Vmax)/Vmax)*255)
2489      Y:000151 Y:000151                   DC      $284000+@CVI(((ZERO+Vmax)/Vmax)*255)
2490      Y:000152 Y:000152                   DC      $288000+@CVI(((ZERO+Vmax)/Vmax)*255)
2491      Y:000153 Y:000153                   DC      $290000+@CVI(((ZERO+Vmax)/Vmax)*255)
2492      Y:000154 Y:000154                   DC      $2A0100+@CVI(((ZERO+Vmax)/Vmax)*255)
2493      Y:000155 Y:000155                   DC      $2A0200+@CVI(((ZERO+Vmax)/Vmax)*255)
2494      Y:000156 Y:000156                   DC      $2A0400+@CVI(((ZERO+Vmax)/Vmax)*255)
2495      Y:000157 Y:000157                   DC      $2A0800+@CVI(((ZERO+Vmax)/Vmax)*255)
2496      Y:000158 Y:000158                   DC      $2A2000+@CVI(((ZERO+Vmax)/Vmax)*255)
2497      Y:000159 Y:000159                   DC      $2A4000+@CVI(((ZERO+Vmax)/Vmax)*255)
2498      Y:00015A Y:00015A                   DC      $2A8000+@CVI(((ZERO+Vmax)/Vmax)*255)
2499      Y:00015B Y:00015B                   DC      $2B0000+@CVI(((ZERO+Vmax)/Vmax)*255)
2500                                END_CLOCKS
2501   
2502                                ; Video offset assignments
2503      Y:00015C Y:00015C         BIASES    DC      END_BIASES-BIASES-1
2504   
2505                                ; Integrator gain and a few other things
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 44



2506                                ;       DC      $0c3001                 ; Integrate 1, R = 4k, Low gain, Slow
2507                                ;       DC      $0c3000                 ; Integrate 2, High gain
2508      Y:00015D Y:00015D                   DC      $0c3000                           ; Integrate 2, High gain
2509      Y:00015E Y:00015E                   DC      $1c3000                           ; Integrate 2, High gain
2510      Y:00015F Y:00015F                   DC      $2c3000                           ; Integrate 2, High gain
2511      Y:000160 Y:000160                   DC      $3c3000                           ; Integrate 2, High gain
2512      Y:000161 Y:000161                   DC      $0c1000                           ; Reset image data FIFOs
2513      Y:000162 Y:000162                   DC      $0c0000+@CVI((ADREF+5.0)/10.0*4095)
2514      Y:000163 Y:000163                   DC      $1c0000+@CVI((ADREF+5.0)/10.0*4095)
2515      Y:000164 Y:000164                   DC      $2c0000+@CVI((ADREF+5.0)/10.0*4095)
2516      Y:000165 Y:000165                   DC      $3c0000+@CVI((ADREF+5.0)/10.0*4095)
2517   
2518                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#1
2519      Y:000166 Y:000166                   DC      $0e0000+OFFSET0                   ; Output #0
2520      Y:000167 Y:000167                   DC      $0e4000+OFFSET1                   ; Output #1
2521      Y:000168 Y:000168                   DC      $0e8000+OFFSET2                   ; Output #2
2522      Y:000169 Y:000169                   DC      $0ec000+OFFSET3                   ; Output #3
2523      Y:00016A Y:00016A                   DC      $0f0000+OFFSET4                   ; Output #4
2524      Y:00016B Y:00016B                   DC      $0f4000+OFFSET5                   ; Output #5
2525      Y:00016C Y:00016C                   DC      $0f8000+OFFSET6                   ; Output #6
2526      Y:00016D Y:00016D                   DC      $0fc000+OFFSET7                   ; Output #7
2527   
2528                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#2
2529      Y:00016E Y:00016E                   DC      $1e0000+OFFSET8                   ; Output #0
2530      Y:00016F Y:00016F                   DC      $1e4000+OFFSET9                   ; Output #1
2531      Y:000170 Y:000170                   DC      $1e8000+OFFSET10                  ; Output #2
2532      Y:000171 Y:000171                   DC      $1ec000+OFFSET11                  ; Output #3
2533      Y:000172 Y:000172                   DC      $1f0000+OFFSET12                  ; Output #4
2534      Y:000173 Y:000173                   DC      $1f4000+OFFSET13                  ; Output #5
2535      Y:000174 Y:000174                   DC      $1f8000+OFFSET14                  ; Output #6
2536      Y:000175 Y:000175                   DC      $1fc000+OFFSET15                  ; Output #7
2537   
2538                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#3
2539      Y:000176 Y:000176                   DC      $2e0000+OFFSET16                  ; Output #0
2540      Y:000177 Y:000177                   DC      $2e4000+OFFSET17                  ; Output #1
2541      Y:000178 Y:000178                   DC      $2e8000+OFFSET18                  ; Output #2
2542      Y:000179 Y:000179                   DC      $2ec000+OFFSET19                  ; Output #3
2543      Y:00017A Y:00017A                   DC      $2f0000+OFFSET20                  ; Output #4
2544      Y:00017B Y:00017B                   DC      $2f4000+OFFSET21                  ; Output #5
2545      Y:00017C Y:00017C                   DC      $2f8000+OFFSET22                  ; Output #6
2546      Y:00017D Y:00017D                   DC      $2fc000+OFFSET23                  ; Output #7
2547   
2548                                ; Video processor offset voltages to bring the video withing range of the A/D ARC46#4
2549      Y:00017E Y:00017E                   DC      $3e0000+OFFSET24                  ; Output #0
2550      Y:00017F Y:00017F                   DC      $3e4000+OFFSET25                  ; Output #1
2551      Y:000180 Y:000180                   DC      $3e8000+OFFSET26                  ; Output #2
2552      Y:000181 Y:000181                   DC      $3ec000+OFFSET27                  ; Output #3
2553      Y:000182 Y:000182                   DC      $3f0000+OFFSET28                  ; Output #4
2554      Y:000183 Y:000183                   DC      $3f4000+OFFSET29                  ; Output #5
2555      Y:000184 Y:000184                   DC      $3f8000+OFFSET30                  ; Output #6
2556      Y:000185 Y:000185                   DC      $3fc000+OFFSET31                  ; Output #7
2557   
2558   
2559                                ; Note that BIAS BO1(p17) and BO2(p33) should be used for higher currents biasses because
2560                                ; they have 100 ohm filtering resistors (R345/350) , versus 1k on the other pins.
2561                                ; Video board #1, Bipolar -7.5 to +7.5 volts supplies
2562      Y:000186 Y:000186                   DC      $0c4000+@CVI((VDDOUT+Vmax2)/Vmax3*4095) ; Pin #17 VDDOUT
2563      Y:000187 Y:000187                   DC      $0c8000+@CVI((VDDUC+Vmax2)/Vmax3*4095) ; Pin #33 VDDUC
2564      Y:000188 Y:000188                   DC      $0cc000+@CVI((IREF+Vmax2)/Vmax3*4095) ; Pin #16 IREF
2565      Y:000189 Y:000189                   DC      $0d0000+@CVI((VDETCOM+Vmax2)/Vmax3*4095) ; Pin #32 VDETCOM
2566      Y:00018A Y:00018A                   DC      $0d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2567      Y:00018B Y:00018B                   DC      $0d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
Motorola DSP56300 Assembler  Version 6.3.4   20-12-24  11:53:17  AladdinIII.waveforms  Page 45



2568      Y:00018C Y:00018C                   DC      $0dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2569   
2570                                ; Video board #2
2571      Y:00018D Y:00018D                   DC      $1c4000+@CVI((VDDCL+Vmax2)/Vmax3*4095) ; Pin #17 VDDCL
2572      Y:00018E Y:00018E                   DC      $1c8000+@CVI((VROWOFF+Vmax2)/Vmax3*4095) ; Pin #33 VROWOFF
2573      Y:00018F Y:00018F                   DC      $1cc000+@CVI((VGGCL+Vmax2)/Vmax3*4095) ; Pin #16 VGGCL
2574      Y:000190 Y:000190                   DC      $1d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2575      Y:000191 Y:000191                   DC      $1d4000+@CVI((VNCOL+Vmax2)/Vmax3*4095) ; Pin #15 VNCOL
2576      Y:000192 Y:000192                   DC      $1d8000+@CVI((VNROW+Vmax2)/Vmax3*4095) ; Pin #31 VNROW
2577      Y:000193 Y:000193                   DC      $1dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2578   
2579                                ; Video board #3, Bipolar -7.5 to +7.5 volts supplies
2580      Y:000194 Y:000194                   DC      $2c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2581      Y:000195 Y:000195                   DC      $2c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2582      Y:000196 Y:000196                   DC      $2cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2583      Y:000197 Y:000197                   DC      $2d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2584      Y:000198 Y:000198                   DC      $2d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2585      Y:000199 Y:000199                   DC      $2d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2586      Y:00019A Y:00019A                   DC      $2dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2587   
2588                                ; Video board #4
2589      Y:00019B Y:00019B                   DC      $3c4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #17 NC
2590      Y:00019C Y:00019C                   DC      $3c8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #33 NC
2591      Y:00019D Y:00019D                   DC      $3cc000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #16 NC
2592      Y:00019E Y:00019E                   DC      $3d0000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #32 NC
2593      Y:00019F Y:00019F                   DC      $3d4000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #15 NC
2594      Y:0001A0 Y:0001A0                   DC      $3d8000+@CVI((ZERO+Vmax2)/Vmax3*4095) ; Pin #31 NC
2595      Y:0001A1 Y:0001A1                   DC      $3dc000+@CVI((VSSOUT+Vmax2)/Vmax3*4095) ; Pin #14 NC but provides output sourc
e follower source voltage = 5V
2596                                END_BIASES
2597   
2598                                 END_APPLICATON_Y_MEMORY
2599      0001A2                              EQU     @LCV(L)
2600   
2601                                ; End of program
2602                                          END

0    Errors
0    Warnings


