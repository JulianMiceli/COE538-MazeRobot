;****************************************************************************
;* Project                                                                  *
;****************************************************************************
;* export symbols
XDEF        Entry, _Startup    ; export ’Entry’ symbol
ABSENTRY    Entry              ; for absolute assembly: mark this as application entry point

;* Include derivative-specific definitions
INCLUDE     ’derivative.inc’

;* equates section
;* A/D Converter Equates (all these are done in the 9S12C32.inc file):
;* ----------------------
ATDCTL2     EQU     $0082       ; A/D Control Register 2

ATDCTL3     EQU     $0083       ; A/D Control Register 3

ATDCTL4     EQU     $0084       ; A/D Control Register 4

ATDCTL5     EQU     $0085       ; A/D Control Register 5

ATDSTAT0    EQU     $0086       ; A/D Status Register 0

;* The A/D converter automatically puts the 4 results in these registers.
ATDDR0L     EQU     $0091       ; A/D Result Register 0
ATDDR1L     EQU     $0093       ; A/D Result Register 1
ATDDR2L     EQU     $0095       ; A/D Result Register 2
ATDDR3L     EQU     $0097       ; A/D Result Register 3

;* PORTA Register
;* --------------------------------
;* This register selects which sensor is routed to AN1 of the A/D converter

PORTA       EQU     $0000       ; PORTA Register

;* Liquid Crystal Display Equates
;* -------------------------------
CLEAR_HOME      EQU     $01     ; Clear the display and home the cursor
INTERFACE       EQU     $38     ; 8 bit interface, two line display
CURSOR_OFF      EQU     $0C     ; Display on, cursor off
SHIFT_OFF       EQU     $06     ; Address increments, no character shift
LCD_SEC_LINE    EQU     64      ; Starting addr. of 2nd line of LCD (note decimal value!)

;* LCD Addresses
LCD_CNTR        EQU     PTJ     ; LCD Control Register: E = PJ7, RS = PJ6
LCD_DAT         EQU     PORTB   ; LCD Data Register: D7 = PB7, ... , D0 = PB0
LCD_E           EQU     $80     ; LCD E-signal pin
LCD_RS          EQU     $40     ; LCD RS-signal pin

;* Other codes
NULL            EQU     00      ; The string 'null terminator'
CR              EQU     $0D     ; 'Carriage Return' character
SPACE           EQU     ' '     ; The 'space' character
START           EQU   0         ; START state value
FWD             EQU   1         ; FORWARD state value
REVERSE         EQU   2         ; REVERSE state value
RIGHT_TURN      EQU   3         ; RIGHT TURN state value
LEFT_TURN       EQU   4         ; LEFT TURN state value
AWAIT_COMMAND	  EQU   5				  ; AWAIT COMMAND state value
JUNCTION        EQU   6         ; JUNCTION state value
STEER           EQU   7         ; STEER state value
U_TURN          EQU   8         ; U_TURN state value

FWD_INT         EQU 69          ;3 second delay (at 23Hz)
REV_INT         EQU 69          ;3 second delay (at 23Hz)
LEFT_TRN_INT    EQU 46          ;2 second delay (at 23Hz)
RIGHT_TRN_INT   EQU 46          ;2 second delay (at 23Hz)
U_TURN_TRN_INT  EQU 46          ;2 second delay (at 23Hz)

;* variable/data section
CRNT_STATE  dc.b 3 ; Current state register
T_FWD       ds.b 1              ; FWD time
T_REV       ds.b 1              ; REV time
T_LEFT      ds.b 1              ; FWD_TURN time
T_RIGHT     ds.b 1              ; REV_TURN time
T_UTURN     ds.b 1              ; U-turn time
                
                ORG $3800
;* ---------------------------------------------------------------------------
;* Storage Registers (9S12C32 RAM space: $3800 ... $3FFF)

SENSOR_LINE     FCB     $01     ; Storage for guider sensor readings
SENSOR_BOW      FCB     $23     ; Initialized to test values
SENSOR_PORT     FCB     $45
SENSOR_MID      FCB     $67
SENSOR_STBD     FCB     $89
    
SENSOR_NUM      RMB     1       ; The currently selected sensor

TOP_LINE        RMB     20      ; Top line of display
                FCB     NULL    ; terminated by null

BOT_LINE        RMB     20      ; Bottom line of display
                FCB     NULL    ; terminated by null

CLEAR_LINE      FCC     ’ ’
                FCB     NULL    ; terminated by null

TEMP            RMB     1       ; Temporary location

;* code section
            ORG     $4000   ; Start of program text (FLASH memory)
;* ---------------------------------------------------------------------------
;*           Initialization

Entry:
_Startup:
            LDS     #$4000          ; Initialize the stack pointer
            CLI                     ; Enable interrupts

            JSR     INIT_PORTS      ; Initialize ports
            JSR     openADC         ; Initialize the ATD
            JSR     openLCD         ; Initialize the LCD
            JSR     CLR_LCD_BUF     ; Write ’space’ characters to the LCD buffer

;* ---------------------------------------------------------------------------
;*           Display Sensors

MAIN        JSR     G_LEDS_ON       ; Enable the guider LEDs
            JSR     READ_SENSORS    ; Read the 5 guider sensors
            JSR     G_LEDS_OFF      ; Disable the guider LEDs
            JSR     DISPLAY_SENSORS ; and write them to the LCD
            LDY     #6000           ; 300 ms delay to avoid
            JSR     del_50us        ; display artifacts
            BRA     MAIN            ; Loop forever

;* subrotine section
;* ---------------------------------------------------------------------------
;*           Initialize ports
INIT_PORTS  BCLR    DDRAD,$FF       ; Make PORTAD an input (DDRAD @ $0272)
            BSET    DDRA,$FF        ; Make PORTA an output (DDRA @ $0002)
            BSET    DDRB,$FF        ; Make PORTB an output (DDRB @ $0003)
            BSET    DDRJ,$C0        ; Make pins 7,6 of PTJ outputs (DDRJ @ $026A)
            RTS

;* ---------------------------------------------------------------------------
;*           Initialize the ADC
openADC     MOVB    #$80,ATDCTL2    ; Turn on ADC (ATDCTL2 @ $0082)
            LDY     #1              ; Wait for 50 us for ADC to be ready
            JSR     del_50us        ; - " -
            MOVB    #$20,ATDCTL3    ; 4 conversions on channel AN1 (ATDCTL3 @ $0083)
            MOVB    #$97,ATDCTL4    ; 8-bit resolution, prescaler=48 (ATDCTL4 @ $0084)
            RTS

;* ---------------------------------------------------------------------------
;*           Clear LCD Buffer
;* This routine writes ’space’ characters (ascii 20) into the LCD display
;* buffer in order to prepare it for the building of a new display buffer.
;* This needs only to be done once at the start of the program. Thereafter the
;* display routine should maintain the buffer properly.

CLR_LCD_BUF LDX     #CLEAR_LINE
            LDY     #TOP_LINE
            JSR     STRCPY

CLB_SECOND  LDX     #CLEAR_LINE
            LDY     #BOT_LINE
            JSR     STRCPY

CLB_EXIT    RTS

;* ---------------------------------------------------------------------------
;*           String Copy
;* Copies a null-terminated string (including the null) from one location to
;* another
;* Passed: X contains starting address of null-terminated string
;* Y contains first address of destination
STRCPY      PSHX                    ; Protect the registers used
            PSHY
            PSHA
STRCPY_LOOP LDAA    0,X             ; Get a source character
            STAA    0,Y             ; Copy it to the destination
            BEQ     STRCPY_EXIT     ; If it was the null, then exit
            INX                     ; Else increment the pointers
            INY
            BRA     STRCPY_LOOP     ; and do it again
STRCPY_EXIT PULA                    ; Restore the registers
            PULY
            PULX
            RTS

;* ---------------------------------------------------------------------------
;*           Guider LEDs ON

;* This routine enables the guider LEDs so that readings of the sensor
;* correspond to the ’illuminated’ situation.

;* Passed: Nothing
;* Returns: Nothing
;* Side: PORTA bit 5 is changed

G_LEDS_ON   BSET    PORTA,%00100000 ; Set bit 5
            RTS

;*           Guider LEDs OFF
;* This routine disables the guider LEDs. Readings of the sensor
;* correspond to the ’ambient lighting’ situation.
;* Passed: Nothing
;* Returns: Nothing
;* Side: PORTA bit 5 is changed
G_LEDS_OFF  BCLR    PORTA,%00100000 ; Clear bit 5
            RTS

;* ---------------------------------------------------------------------------
;*           Read Sensors
;*
;* This routine reads the eebot guider sensors and puts the results in RAM
;*   registers.

;* Note: Do not confuse the analog multiplexer on the Guider board with the
;*   multiplexer in the HCS12. The guider board mux must be set to the
;*   appropriate channel using the SELECT_SENSOR routine. The HCS12 always
;*   reads the selected sensor on the HCS12 A/D channel AN1.

;* The A/D conversion mode used in this routine is to read the A/D channel
;*   AN1 four times into HCS12 data registers ATDDR0,1,2,3. The only result
;*   used in this routine is the value from AN1, read from ATDDR0. However,
;*   other routines may wish to use the results in ATDDR1, 2 and 3.
;* Consequently, Scan=0, Mult=0 and Channel=001 for the ATDCTL5 control word.

;* Passed:   None
;* Returns:  Sensor readings in:
;*           SENSOR_LINE (0) (Sensor E/F)
;*           SENSOR_BOW (1) (Sensor A)
;*           SENSOR_PORT (2) (Sensor B)
;*           SENSOR_MID (3) (Sensor C)
;*           SENSOR_STBD (4) (Sensor D)

;* Note:
;*   The sensor number is shown in brackets

;* Algorithm:
;*       Initialize the sensor number to 0
;*       Initialize a pointer into the RAM at the start of the Sensor Array storage
;* Loop  Store %10000001 to the ATDCTL5 (to select AN1 and start a conversion)
;*       Repeat
;*           Read ATDSTAT0
;*       Until Bit SCF of ATDSTAT0 == 1 (at which time the conversion is complete)
;*       Store the contents of ATDDR0L at the pointer
;*       If the pointer is at the last entry in Sensor Array, then
;*           Exit
;*       Else
;*           Increment the sensor number
;*           Increment the pointer
;*       Loop again.

READ_SENSORS    CLR     SENSOR_NUM          ; Select sensor number 0
                LDX     #SENSOR_LINE        ; Point at the start of the sensor array

RS_MAIN_LOOP    LDAA    SENSOR_NUM          ; Select the correct sensor input
                JSR     SELECT_SENSOR       ; on the hardware
                LDY     #400                ; 20 ms delay to allow the
                JSR     del_50us            ; sensor to stabilize

                LDAA    #%10000001          ; Start A/D conversion on AN1
                STAA    ATDCTL5
                BRCLR   ATDSTAT0,$80,*      ; Repeat until A/D signals done

                LDAA    ATDDR0L             ; A/D conversion is complete in ATDDR0L
                STAA    0,X                 ; so copy it to the sensor register
                CPX     #SENSOR_STBD        ; If this is the last reading
                BEQ     RS_EXIT             ; Then exit

                INC     SENSOR_NUM          ; Else, increment the sensor number
                INX                         ; and the pointer into the sensor array
                BRA     RS_MAIN_LOOP        ; and do it again

RS_EXIT         RTS

;*---------------------------------------------------------------------------
;*               Select Sensor
;
;* This routine selects the sensor number passed in ACCA. The motor direction
;*   bits 0, 1, the guider sensor select bit 5 and the unused bits 6,7 in the
;*   same machine register PORTA are not affected.
;* Bits PA2,PA3,PA4 are connected to a 74HC4051 analog mux on the guider board,
;*   which selects the guider sensor to be connected to AN1.
;
;* Passed: Sensor Number in ACCA
;* Returns: Nothing
;* Side Effects: ACCA is changed

;* Algorithm:
;* First, copy the contents of PORTA into a temporary location TEMP and clear
;*       the sensor bits 2,3,4 in the TEMP to zeros by ANDing it with the mask
;*       11100011. The zeros in the mask clear the corresponding bits in the
;*       TEMP. The 1’s have no effect.
;* Next, move the sensor selection number left two positions to align it
;*       with the correct bit positions for sensor selection.
;* Clear all the bits around the (shifted) sensor number by ANDing it with
;*   the mask 00011100. The zeros in the mask clear everything except
;*   the sensor number.
;* Now we can combine the sensor number with the TEMP using logical OR.
;*   The effect is that only bits 2,3,4 are changed in the TEMP, and these
;*   bits now correspond to the sensor number.
;* Finally, save the TEMP to the hardware.

SELECT_SENSOR   PSHA                ; Save the sensor number for the moment

                LDAA    PORTA       ; Clear the sensor selection bits to zeros
                ANDA    #%11100011  ;
                STAA    TEMP        ; and save it into TEMP

                PULA                ; Get the sensor number
                ASLA                ; Shift the selection number left, twice
                ASLA                ;
                ANDA    #%00011100  ; Clear irrelevant bit positions

                ORAA    TEMP        ; OR it into the sensor bit positions
                STAA    PORTA       ; Update the hardware
                RTS

;* ---------------------------------------------------------------------------
;* Display Sensor Readings
;
;* Passed: Sensor values in RAM locations SENSOR_LINE through SENSOR_STBD.
;* Returns: Nothing
;* Side: Everything
;
;* This routine writes the sensor values to the LCD. It uses the ’shadow buffer’ approach.
;*   The display buffer is built by the display controller routine and then copied in its
;*   entirety to the actual LCD display. Although simpler approaches will work in this
;*   application, we take that approach to make the code more re-useable.
;* It’s important that the display controller not write over other information on the
;*   LCD, so writing the LCD has to be centralized with a controller routine like this one.
;* In a more complex program with additional things to display on the LCD, this routine
;*   would be extended to read other variables and place them on the LCD. It might even
;*   read some ’display select’ variable to determine what should be on the LCD.
;
;* For the purposes of this routine, we’ll put the sensor values on the LCD
;*   in such a way that they (sort of) mimic the position of the sensors, so
;*   the display looks like this:
;*   01234567890123456789
;*   ___FF_______________
;*   PP_MM_SS_LL_________
;
;* Where FF is the front sensor, PP is port, MM is mid, SS is starboard and
;*   LL is the line sensor.
;
;* The corresponding addresses in the LCD buffer are defined in the following
;*   equates (In all cases, the display position is the MSDigit).

DP_FRONT_SENSOR     EQU     TOP_LINE+3
DP_PORT_SENSOR      EQU     BOT_LINE+0
DP_MID_SENSOR       EQU     BOT_LINE+3
DP_STBD_SENSOR      EQU     BOT_LINE+6
DP_LINE_SENSOR      EQU     BOT_LINE+9

DISPLAY_SENSORS     LDAA    SENSOR_BOW          ; Get the FRONT sensor value
                    JSR     BIN2ASC             ; Convert to ascii string in D
                    LDX     #DP_FRONT_SENSOR    ; Point to the LCD buffer position
                    STD     0,X                 ; and write the 2 ascii digits there

                    LDAA    SENSOR_PORT         ; Repeat for the PORT value
                    JSR     BIN2ASC
                    LDX     #DP_PORT_SENSOR
                    STD     0,X

                    LDAA    SENSOR_MID          ; Repeat for the MID value
                    JSR     BIN2ASC
                    LDX     #DP_MID_SENSOR
                    STD     0,X

                    LDAA    SENSOR_STBD         ; Repeat for the STARBOARD value
                    JSR     BIN2ASC
                    LDX     #DP_STBD_SENSOR
                    STD     0,X

                    LDAA    SENSOR_LINE         ; Repeat for the LINE value
                    JSR     BIN2ASC
                    LDX     #DP_LINE_SENSOR
                    STD     0,X

                    LDAA    #CLEAR_HOME         ; Clear the display and home the cursor
                    JSR     cmd2LCD             ; "

                    LDY     #40                 ; Wait 2 ms until "clear display" command is complete
                    JSR     del_50us

                    LDX     #TOP_LINE ; Now copy the buffer top line to the LCD
                    JSR     putsLCD

                    LDAA    #LCD_SEC_LINE ; Position the LCD cursor on the second line
                    JSR     LCD_POS_CRSR

                    LDX     #BOT_LINE ; Copy the buffer bottom line to the LCD
                    JSR     putsLCD
                    RTS

;* ---------------------------------------------------------------------------
;* Binary to ASCII
;
;* Converts an 8 bit binary value in ACCA to the equivalent ASCII character 2
;*   character string in accumulator D
;* Uses a table-driven method rather than various tricks.
;
;* Passed: Binary value in ACCA
;* Returns: ASCII Character string in D
;* Side Fx: ACCB is destroyed

HEX_TABLE   FCC     ’0123456789ABCDEF’  ; Table for converting values

BIN2ASC     PSHA                        ; Save a copy of the input number on the stack
            TAB                         ; and copy it into ACCB
            ANDB    #%00001111          ; Strip off the upper nibble of ACCB
            CLRA                        ; D now contains 000n where n is the LSnibble
            ADDD    #HEX_TABLE          ; Set up for indexed load
            XGDX
            LDAA    0,X                 ; Get the LSnibble character

            PULB                        ; Retrieve the input number into ACCB
            PSHA                        ; and push the LSnibble character in its place
            RORB                        ; Move the upper nibble of the input number
            RORB                        ; into the lower nibble position.
            RORB
            RORB
            ANDB    #%00001111          ; Strip off the upper nibble
            CLRA                        ; D now contains 000n where n is the MSnibble
            ADDD    #HEX_TABLE          ; Set up for indexed load
            XGDX
            LDAA    0,X                 ; Get the MSnibble character into ACCA
            PULB                        ; Retrieve the LSnibble character into ACCB
            RTS

;* ---------------------------------------------------------------------------
;*           Routines to control the Liquid Crystal Display
;* ---------------------------------------------------------------------------
;*           Initialize the LCD

openLCD     LDY     #2000       ; Wait 100 ms for LCD to be ready
            JSR     del_50us    ; "
            LDAA    #INTERFACE  ; Set 8-bit data, 2-line display, 5x8 font
            JSR     cmd2LCD     ; "
            LDAA    #CURSOR_OFF ; Display on, cursor off, blinking off
            JSR     cmd2LCD     ; "
            LDAA    #SHIFT_OFF  ; Move cursor right (address increments, no char. shift)
            JSR     cmd2LCD     ; "
            LDAA    #CLEAR_HOME ; Clear the display and home the cursor
            JSR     cmd2LCD     ; "
            LDY     #40         ; Wait 2 ms until "clear display" command is complete
            JSR     del_50us    ; "
            RTS

;* ---------------------------------------------------------------------------
;*           Send a command in accumulator A to the LCD

cmd2LCD     BCLR    LCD_CNTR,LCD_RS     ; Select the LCD Instruction register
            JSR     dataMov             ; Send data to IR or DR of the LCD
            RTS

;* ---------------------------------------------------------------------------
;*           Send a character in accumulator in A to LCD

putcLCD     BSET    LCD_CNTR,LCD_RS     ; select the LCD Data register
            JSR     dataMov             ; send data to IR or DR of the LCD
            RTS

;* ---------------------------------------------------------------------------
;*           Send a NULL-terminated string pointed to by X

putsLCD     LDAA    1,X+                ; get one character from the string
            BEQ     donePS              ; reach NULL character?
            JSR     putcLCD
            BRA     putsLCD
donePS      RTS

;* ---------------------------------------------------------------------------
;*           Send data to the LCD IR or DR depending on the RS signal

dataMov     BSET    LCD_CNTR,LCD_E      ; pull the LCD E-signal high
            STAA    LCD_DAT             ; send the 8 bits of data to LCD
            NOP
            NOP
            NOP
            BCLR    LCD_CNTR,LCD_E      ; pull the E signal low to complete the write operation
            
            LDY     #1                  ; adding this delay will complete the internal
            JSR     del_50us            ; operation for most instructions
            RTS

;* ---------------------------------------------------------------------------
;*           Position the Cursor
;
;* This routine positions the display cursor in preparation for the writing
;*   of a character or string.
;* For a 20x2 display:
;* The first line of the display runs from 0 .. 19.
;* The second line runs from 64 .. 83.
;
;* The control instruction to position the cursor has the format
;*           1aaaaaaa
;* where aaaaaaa is a 7 bit address.
;
;* Passed: 7 bit cursor Address in ACCA
;* Returns: Nothing
;* Side Effects: None

LCD_POS_CRSR    ORAA    #%10000000  ; Set the high bit of the control word
                JSR     cmd2LCD     ; and set the cursor address
                RTS

;* ---------------------------------------------------------------------------
;*               50 Microsecond Delay

del_50us        PSHX                ; (2 E-clk) Protect the X register
eloop           LDX     #300        ; (2 E-clk) Initialize the inner loop counter
iloop           NOP                 ; (1 E-clk) No operation
                DBNE    X,iloop     ; (3 E-clk) If the inner cntr not 0, loop again
                DBNE    Y,eloop     ; (3 E-clk) If the outer cntr not 0, loop again
                PULX                ; (3 E-clk) Restore the X register
                RTS                 ; (5 E-clk) Else return

;* ---------------------------------------------------------------------------
;*               Interrupt Vectors
                ORG     $FFFE
                DC.W Entry          ; Reset Vector


;* ---------------------------------------------------------------------------
;*               Junction Check
;* Robot performs a sensor read and if the pattern matches a junction, the robot 
;*   logs the junction and chooses the appropriate manouever.  Only junctions of type 3-5 are 
;*   logged for purposes of reverse pathing.  The robot approaches a solved maze differently.
;*       Junction type combination table
;*   Description Type#   A   B   C   D
;*   L_LEFT      1       0   1   1   0
;*   L_RIGHT     2       0   0   1   1
;*   T_SYM       3       0   1   1   1
;*   T_LEFT      4       1   1   1   0
;*   T_RIGHT     5       1   0   1   1

JUNC_L_LEFT     EQU     1               ; Junction type 1 (an L junction turning left)
JUNC_L_RIGHT    EQU     2               ; Junction type 2 (an L junction turning right)
JUNC_T_SYM      EQU     3               ; Junction type 3 (a T junction that is symmetric)
JUNC_T_LEFT     EQU     4               ; Junction type 4 (a T junction turning left)
JUNC_T_RIGHT    EQU     5               ; Junction type 5 (a T junction turning right)
JLL_COMBO       EQU     %00000110       ; sensor combo of junction type 1
JLR_COMBO       EQU     %00000011       ; sensor combo of junction type 2
JTS_COMBO       EQU     %00000111       ; sensor combo of junction type 3
JTL_COMBO       EQU     %00001110       ; sensor combo of junction type 4
JTR_COMBO       EQU     %00001011       ; sensor combo of junction type 5

CURRENT_JUNC    dc.b    3               ; The current junction type
JUNC_FLAG       ds.b    1               ; 3 LSB is a boolean flag.  
                                        ; bit 0:  0 = junc determined, 1 = exploring junc
                                        ; bit 1:  0 = no corrective action, 1 = corrective action
                                        ; bit 2:  0 = maze not solved (robot going forward through maze),
                                        ; 1 = maze is solved (robot going reverse through maze)

JUNC_CHECK      PSHA                    ; Protect AccA
                ANDA    #$00            ; clear A
                JSR     READ_SENSORS    ; Read the bow, port, stern, and starboard sensors
                JSR     PARSE_S_DATA    ; stores the results of READ_SENSORS in the LS nibble of A 

                CMPA    JLL_COMBO       ; compares parsed sensor data against junction type 1 combo
                BNE     NOT_JLL         ; branches if not type 1
                MOVB    #JUNC_L_LEFT,CURRENT_JUNC   ; sets the current junction to type 1
                JSR     EXP_JUNC_OFF    ; clear the exploration flag, as L junctions are not logged
                JSR     TURN_LEFT       ; executes a left turn, no junction logged

NOT_JLL         CMPA    JLR_COMBO       ; compares parsed sensor data against junction type 2 combo 
                BNE     NOT_JLR         ; branches if not type 2
                MOVB    #JUNC_L_RIGHT,CURRENT_JUNC   ; sets the current junction to type 2
                JSR     EXP_JUNC_OFF    ; clear the exploration flag, as L junctions are not logged
                JSR     TURN_RIGHT      ; executes a right turn, no junction logged

NOT_JLR         CMPA    JTS_COMBO       ; compares parsed sensor data against junction type 3 combo 
                BNE     NOT_JTS         ; branches if not type 3
                LDAA    #JUNC_FLAG      ; load Acc A with the junc flags for maze solution
                ANDA    #%00000100      ; bit mask to retrieve bit 2 (solution flag)
                BNE     JUNC_SOLN       ; robot uses the solution to the current junction
                MOVB    #JUNC_T_SYM,CURRENT_JUNC   ; sets the current junction to type 3
                JSR     EXP_JUNC_ON     ; turns on the EXPLORE_JUNC flag
                JSR     TURN_RIGHT      ; executes a right turn

NOT_JTS         CMPA    JTL_COMBO       ; compares parsed sensor data against junction type 4 combo 
                BNE     NOT_JTL         ; branches if not type 4
                LDAA    #JUNC_FLAG      ; load Acc A with the junc flags for maze solution
                ANDA    #%00000100      ; bit mask to retrieve bit 2 (solution flag)
                BNE     JUNC_SOLN       ; robot uses the solution to the current junction
                MOVB    #JUNC_T_LEFT,CURRENT_JUNC   ; sets the current junction to type 4
                JSR     EXP_JUNC_ON     ; turns on the EXPLORE_JUNC flag
                JSR     GO_STRT         ; goes straight

NOT_JTL         CMPA    JTR_COMBO       ; compares parsed sensor data against junction type 5 combo 
                BNE     NOT_JTR         ; branches if not type 5
                LDAA    #JUNC_FLAG      ; load Acc A with the junc flags for maze solution
                ANDA    #%00000100      ; bit mask to retrieve bit 2 (solution flag)
                BNE     JUNC_SOLN       ; robot uses the solution to the current junction
                MOVB    #JUNC_T_RIGHT,CURRENT_JUNC   ; sets the current junction to type 5
                JSR     EXP_JUNC_ON     ; turns on the EXPLORE_JUNC flag
                JSR     TURN_RIGHT      ; executes a right turn

NOT_JTR         RTS                     ; current sensor reading does not match junction patterns.  exit
;* ---------------------------------------------------------------------------
;*               Parse Sensor Data
;* Takes the A/D voltage results from the bow, port, stern, and starboard sensors and 
;*   converts them into 0 for 1.5 V (low) and 1 for 3.5 V (high) and stores the result
;*   in the LS nibble of A.

PARSE_S_DATA    PSHX                    ; Protect the X register
                LDX     #76             ; loads the X register with 76, which is 1.5 V converted by the ADC   
                LDAB    #4              ; sets a counter at 4 for each of the 4 sensors of interest
parseLoop       BEQ     doneParse       ; if AccB is 0, end the loop
                ROLA                    ; rotates AccA left
                CPX     SENSOR_STBD+1-B ; compares each sensor against 76
                BEQ     recordLow       ; if the sensor's digital voltage matched 76 (1.5 V)
                BRA     recordHigh      ; if the sensor's digital voltage did not match 76 
recordLow       ANDA    #%00000000      ; using bit mask, clear bit 0 
                DECB                    ; decrement AccB
                BRA     parseLoop       ; return to parse loop
recordHigh      ANDA    #%00000001      ; using bit mask, set bit 0
                DECB                    ; decrement AccB
                BRA     parseLoop       ; return to parse loop
doneParse       PULA                    ; restore the X register
                RTS                     ; exit subroutine


;********************************************************************************
;*               Turning subroutines
;* Executes left and right turns (90 degrees), u turns (180 degrees), and going straight
;
;*** Variable declaration
DEG90_TRN_INT   EQU     46              ; the time interval for a 90 degree turn

T_TRN           ds.b    1               ; records the time spent turning


;* ---------------------------------------------------------------------------
;*               Turn left
;* Executes a left turn by having the starboard motor go forward and port motor go
;*   in reverse for enough time to execute a 90 degree turn

TURN_LEFT       JSR     STARFWD         ; Set FWD dir. for STARBOARD (right) motor
                JSR     PORTREV         ; Set REV dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #DEG90_TRN_INT  ; Sets the end time for the 90 degree turn
                STAA    T_TRN           ; Store the end time in T_TRN
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is a correction
                ANDA    #%00000010      ; bit mask to retrieve bit 1 (correction flag)
                BEQ     CORR_JUNC_OFF   ; turns the correction flag off and pushes the wrong heading
L_TRN_loop      LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     L_TRN_loop      ; go through the loop again
                JSR     PORTFWD         ; Set FWD on the port (left) motor again, ending the left turn
                LDD     #90             ; update heading by passing 90 degrees ccw
                JSR     updateCompass   ; " "
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is an L or T junc 
                ANDA    #%00000001      ; bit mask to retrieve bit 0 (exploration flag)
                BNE     LOG_JUNC        ; if exploring, logs the new heading for maze solving
                RTS                     ; exit the subroutine

;* ---------------------------------------------------------------------------
;*               Turn right
;* Executes a right turn by having the starboard motor go in reverse and port 
;*   motor go forward for enough time to execute a 90 degree turn

TURN_RIGHT      JSR     STARREV         ; Set REV dir. for STARBOARD (right) motor
                JSR     PORTFWD         ; Set FWD dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #DEG90_TRN_INT  ; Sets the end time for the 90 degree turn
                STAA    T_TRN           ; Store the end time in T_TRN
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is a correction
                ANDA    #%00000010      ; bit mask to retrieve bit 1 (correction flag)
                BEQ     CORR_JUNC_OFF   ; turns the correction flag off and pushes the wrong heading
R_TRN_loop      LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     R_TRN_loop      ; go through the loop again
                JSR     STARFWD         ; Set FWD on the starboard (right) motor again, ending the right turn
                LDD     #270            ; update heading by passing 270 degrees ccw, which is 90 degrees cw
                JSR     updateCompass   ; " "
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is an L or T junc 
                ANDA    #%00000001      ; bit mask to retrieve bit 0 (exploration flag)
                BNE     LOG_JUNC        ; if exploring, logs the new heading for maze solving
                RTS                     ; exit the subroutine

;* ---------------------------------------------------------------------------
;*               Go straight
;* Robot has encountered a junction, and has decided to go straight

GO_STRT         JSR     STARFWD         ; Set FWD dir for starboard (right) motor
                JSR     PORTFWD         ; Set FWD dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #20             ; Sets the end time for going straight
                STAA    T_TRN           ; Store the end time in T_TRN
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is a correction
                ANDA    #%00000010      ; bit mask to retrieve bit 1 (correction flag)
                BEQ     CORR_JUNC_OFF   ; turns the correction flag off and pushes the wrong heading
GO_STRT_loop    LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     GO_STRT_loop    ; go through the loop again
                LDAA    JUNC_FLAG       ; load Acc A with the JUNC_FLAG to check if this is an L or T junc 
                ANDA    #%00000001      ; bit mask to retrieve bit 0 (exploration flag)
                BNE     LOG_JUNC        ; if exploring, logs the new heading for maze solving
                RTS                     ; exit the subroutine

;* ---------------------------------------------------------------------------
;*               U Turn
;* Executes a U turn by having the starboard motor go in reverse and port 
;*   motor go forward for enough time to execute a 180 degree turn

U_TURN          JSR     STARREV         ; Set REV dir. for STARBOARD (right) motor
                JSR     PORTFWD         ; Set FWD dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #DEG90_TRN_INT  ; Adds 2 intervals to set end time for the 180 degree turn
                ADDA    #DEG90_TRN_INT
                STAA    T_TRN           ; Store the end time in T_TRN
U_TRN_loop      LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     U_TRN_loop      ; go through the loop again
                JSR     STARFWD         ; Set FWD on the starboard (right) motor again, ending the right turn
                LDD     #180            ; update heading by passing 180 degrees ccw
                JSR     updateCompass   ; " "
                RTS                     ; exit the subroutine


;************************************************************
;*               Motor Control                              *
;************************************************************
                BSET    DDRA, %00000011
                BSET    DDRT, %00110000
                JSR     STARFWD
                JSR     PORTFWD
                JSR     STARON
                JSR     PORTON
                JSR     STARREV
                JSR     PORTREV
                JSR     STAROFF
                JSR     PORTOFF
                BRA     *

;* Turn Starboard motor on
STARON          LDAA    PTT             ; loads the current status of the on/off switches into Acc A
                ORAA    #%00100000      ; forces PT5 high, turning on the Starboard motor      
                STAA    PTT             ; executes the command to the eebot
                RTS

;* Turn Starboard motor off
STAROFF         LDAA    PTT             ; loads the current status of the on/off switches into Acc A
                ANDA    #%11011111      ; forces PT5 low, turning off the Starboard motor
                STAA    PTT             ; executes the command to the eebot
                RTS

;* Turn Port motor on
PORTON          LDAA    PTT             ; loads the current status of the on/off switches into Acc A
                ORAA    #%00010000      ; forces PT4 high, turning on the Port motor
                STAA    PTT             ; executes the command to the eebot
                RTS

;* Turn Port motor off
PORTOFF         LDAA    PTT             ; loads the current status of the on/off switches into Acc A
                ANDA    #%11101111      ; forces PT4 low, turning off the Port motor
                STAA    PTT             ; executes the command to the eebot
                RTS

;* Set Starboard motor to forward direction
STARFWD         LDAA    PORTA           ; loads the current status of direction into Acc A
                ANDA    #%11111101      ; forces PA1 low, setting forward direction for the Starboard motor 
                STAA    PORTA           ; executes the command to the eebot
                RTS

;* Set Starboard motor to reverse direction
STARREV         LDAA    PORTA           ; loads the current status of direction into Acc A
                ORAA    #%00000010      ; forces PA1 low, setting reverse direction for the Starboard motor
                STAA    PTH             ; executes the command to the eebot
                RTS

;* Set Port motor to forward direction
PORTFWD         LDAA    PORTA           ; loads the current status of direction into Acc A
                ANDA    #%11111110      ; forces PA0 low, setting forward direction for the Port motor 
                STAA    PORTA           ; executes the command to the eebot
                RTS

;* Set Port motor to reverse direction
PORTREV         LDAA    PORTA           ; loads the current status of direction into Acc A
                ORAA    #%00000001      ; forces PA0 high, setting reverse direction for the Port motor 
                STAA    PTH             ; executes the command to the eebot
                RTS

;******************************************************************************
;*               Junction exploration subroutines
;* Sets statuses for the exploration of junctions

;* ---------------------------------------------------------------------------
;*               Explore junction on
;* Sets bit 0 flag JUNC_FLAG, meaning the robot is currently solving a junction

EXP_JUNC_ON     PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ORA     #%00000001      ; bit mask set bit 0 high
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                RTS

;* ---------------------------------------------------------------------------
;*               Explore junction off
;* Clears bit 0 flag JUNC_FLAG, meaning the robot is not currently solving a junction

EXP_JUNC_OFF    PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ANDA    #%11111110      ; bit mask set bit 0 low
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                RTS

;* ---------------------------------------------------------------------------
;*               Corrective junction action on
;* Sets bit 1 flag JUNC_FLAG, meaning the robot took the wrong path and is trying to fix it

CORR_JUNC_ON    PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ORA     #%00000010      ; bit mask set bit 1 high
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                RTS

;* ---------------------------------------------------------------------------
;*               Corrective junction action off
;* Clears bit 1 flag JUNC_FLAG, meaning the robot is not trying to correct a wrong path

CORR_JUNC_OFF   PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ANDA    #%11111101      ; bit mask set bit 1 low
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                PULX                    ; pulls the wrong heading from the stack
                JSR     EXP_JUNC_OFF    ; because this is a corrective action, the robot is not exploring
                RTS

;* ---------------------------------------------------------------------------
;*               Solving maze forward on
;* Sets bit 2 flag JUNC_FLAG, meaning the robot is solving the maze forwards

JUNC_SOLVED_ON  PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ORA     #%00000100      ; bit mask set bit 2 high
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                RTS

;* ---------------------------------------------------------------------------
;*               Solving maze forward off
;* Clears bit 2 flag JUNC_FLAG, meaning the robot has the maze solution and is going in reverse

JUNC_SOLVED_OFF PSHA                    ; protects Acc A
                LDAA    #JUNC_FLAG      ; load into Acc A JUNC_FLAG
                ANDA    #%11111011      ; bit mask set bit 2 low
                STAA    JUNC_FLAG       ; update JUNC_FLAG
                PULA
                RTS

;* ---------------------------------------------------------------------------
;*               Log Junction
;* Takes the current heading after making a turn and pushes onto the stack 

LOG_JUNC        LDX     #HEADING        ; loads register X with the current heading
                PSHX                    ; pushes the heading onto the stack
                RTS

;* ---------------------------------------------------------------------------
;*               Junction solution
;* Takes the current heading of the robot and calculates the correct action of
;*   either left turn, right turn, or go straight based on what the opposite of the
;*   correct headings are in the stack.
;* e.g. the robot is facing West (heading 180), the stack pulls a heading of North (90).
;*   The opposite of North is South (270).  With current heading 180, and needed heading of 270
;*   the robot determines that a left turn is best.

JUNC_SOLN       PULD                    ; pulls the desired heading which needs to be reversed
                ADDD    #540            ; adds 180 + 360  degrees to the desired heading to 
                                        ; reverse the direction and ensure no negatives
                SUBD    #HEADING        ; subtracts the current heading from the desired heading
                PSHX                    ; protects register X
                LDX     #360            ; load 360 into X before we divide
                IDIV                    ; divides the desired heading by mod 360
                ADDD    #0              ; updates the Z flag to be the remainder held in D   

                BEQ     GO_STRT         ; the change in heading was 0, robot goes straight

                SUBD    #90             ; subtract 90 from the heading change to see if original was 90
                BEQ     TURN_LEFT       ; the original heading change was 90, robot turns left

                SUBD    #180            ; subtract 180, to see if the original heading change was 270
                BEQ     TURN_RIGHT      ; the original heading change was 270, robot turns right
                RTS                     ; exit subroutine                                     
            
;******************************************************************************
;*               Compass subroutines
;* Determines the compass direction of the robot and tracks this at all times.
;* Tracks direction using a variable heading, which is 0 pointing East, and goes counter-clockwise
;*   for 360 degrees. East = 0, North = 90, West = 180, South = 270.

;*** Variable declaration

EAST            EQU     0               ; East is a heading of 0
NORTH           EQU     90              ; North is a heading of 90
WEST            EQU     180             ; West is a heading of 180
SOUTH           EQU     270             ; South is a heading of 270 

HEADING         ds.b    1               ; records the current heading

;* ---------------------------------------------------------------------------
;*               Initialize Compass
;* Assumes a starting direction of East, but can be modified as need be

openCompass     PSHA                    ; protect Acc A
                LDAA    #EAST           ; loads a value of 0 (East) into Acc A
                STAA    HEADING         ; stores the initial heading
                PULA                    ; restores Acc A
                RTS

;* ---------------------------------------------------------------------------
;*               Update Compass
;* Updates the heading based on the number of degrees turned.  Uses division by 360 to
;*   find the remainder, which is the modular equivalent 
;* Passed: number of degrees in Acc D as a positive degree measurement (counter-clockwise rotation)

updateCompass   ADDD    #HEADING        ; adds the current heading to Acc D
                PSHX                    ; protect register X
                LDX     #360            ; load register X with the divisor of 360 (degrees)
                IDIV                    ; divides the sum of heading and D by 360 
                STD     HEADING         ; stores the remainder of the division
                PULX                    ; restores register X
                RTS


;*****************************************************************************
;*               Steering subroutines
;* The robot's sensors E and F create a voltage divider where 2.5 V indicates a 
;*   equilibrium between left and right.  Deviations from 2.5 V lead to corrective
;*   steering.  This system allows the robot to navigate non-junction tracks such
;*   as the S-curve.
;
;* --------------------------------------------------------------------------
;*               Steering check
;* Takes a current sensor reading and compares it against the baseline of 127 (2.5 V)
;*   Makes the appropriate steering correction based on the results.

STEER_CHECK     PSHX                    ; protect register X
                LDX     #127            ; loads register X with 127 which is the A/D of 2.5 V
                JSR     READ_SENSORS    ; take a current reading of the sensors
                LDD     #SENSOR_LINE    ; loads Acc D with the current digital voltage of sensor E-F
                SUBD    X               ; subtract 127 (2.5 V) from the E-F line sensor reading
                BMI     STEER_RIGHT     ; voltage is lower than 2.5 V, so robot needs to steer right
                BPL     STEER_LEFT      ; voltage is higher than 2.5 V, so robot needs to steer left
                PULX                    ; restore register X
                RTS                     ; exit subroutine
    
;* --------------------------------------------------------------------------
;*               Steer right
;* It takes a time interval of 46 to make a 90 degree turn, so use a time interval
;*   of 1 to achieve an approximately 2 degree steering manouever.

STEER_RIGHT     JSR     STARREV         ; Set REV dir. for STARBOARD (right) motor
                JSR     PORTFWD         ; Set FWD dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #1              ; Sets the end time for the 2 degree steer
                STAA    T_TRN           ; Store the end time in T_TRN
R_STR_loop      LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     R_STR_loop      ; go through the loop again
                JSR     STARFWD         ; Set FWD on the starboard (right) motor again, ending the right turn
                LDD     #358            ; update heading by passing 358 degrees ccw, which is 2 degrees cw
                JSR     updateCompass   ; " "
                RTS                     ; exit the subroutine   

;* --------------------------------------------------------------------------
;*               Steer left
;* It takes a time interval of 46 to make a 90 degree turn, so use a time interval
;*   of 1 to achieve an approximately 2 degree steering manouever.

STEER_LEFT      JSR     STARFWD         ; Set FWD dir. for STARBOARD (right) motor
                JSR     PORTREV         ; Set REV dir for port (left) motor
                LDAA    TOF_COUNTER     ; Mark the fwd time Tfwd
                ADDA    #1              ; Sets the end time for the 2 degree steer
                STAA    T_TRN           ; Store the end time in T_TRN
L_STR_loop      LDAA    TOF_COUNTER     ; load the current counter time
                CMPA    T_TRN           ; see if Tc>T_TRN
                BNE     L_STR_loop      ; go through the loop again
                JSR     PORTFWD         ; Set FWD on the port (left) motor again, ending the left turn
                LDD     #2              ; update heading by passing 2 degrees ccw
                JSR     updateCompass   ; " "
                RTS                     ; exit the subroutine
                
; State Dispatcher
DISPATCHER      CMPA #START             ; If it’s the START state
	            	BNE NOT_START
		            JSR START_STATE         ; then call the START routine
		            RTS                     ; and exit

NOT_START     	CMPA #FORWARD           ; Else if it’s the FORWARD state
		            BNE NOT_FORWARD
		            JSR FORWARD_ST          ; then call the FORWARD routine
		            RTS                     ; and exit

NOT_FORWARD 	  CMPA #JUNCTION          ; Else if it’s the RIGHT_TURN state
		            BNE NOT_JUNC
		            JSR JUNC_ST             ; then call the RIGHT_TURN_STATE routine
	            	RTS                     ; and exit

NOT_JUNC 	      CMPA #RIGHT_TURN        ; Else if it’s the RIGHT_TURN state
		            BNE RIGHT_TURN_STATE
		            JSR STEER_ST            ; then call the RIGHT_TURN_STATE routine
		            RTS                     ; and exit

NOT_RIGHT_TURN 	CMPA #LEFT_TURN         ; Else if it’s the LEFT_TURN state
		            BNE LEFT_TURN_STATE
		            JSR STEER_ST            ; then call the LEFT_TURN_STATE routine
		            RTS                     ; and exit

NOT_LEFT_TURN 	CMPA #REVERSE           ; Else if it’s the REVERSE state
		            BNE NOT_REVERSE
		            JSR REV_ST              ; then call the REVERSE_STATE routine
		            RTS                     ; and exit

NOT_REVERSE	    CMPA #AWAIT_COMMAND     ; Else if its the AWAIT_COMMAND state
		            BNE NOT_AWAIT
	            	JSR AWAIT_COMMAND_STATE ; then call the AWAIT_COMMAND_STATE routine
		            RTS                     ; and exit

NOT_AWAIT       NOP                     ; else
START_EXIT		  RTS                     ; return to the MAIN routine

;States Section
START_STATE 	  BRCLR PORTAD0,$04,NO_FORWARD  ; If /FWD_BUMP
		            JSR INIT_FWD                  ; Initialize the FORWARD state
		            MOVB #FORWARD,CURRENT_STATE   ; Go into the FORWARD state
		            BRA START_EXIT

NO_FORWARD 	    NOP                     ; Else
START_EXIT 	    RTS                     ; return to the MAIN routine

FORWARD_ST    	BRSET PORTAD0,$04,NO_FWD_BUMP   ; If FWD_BUMP then
		            JSR INIT_REVERSE                ; initialize the REVERSE routine
		            MOVB #REVERSE,CURRENT_STATE     ; set the state to REVERSE
		            JMP FWD_EXIT                    ; and return

NO_FWD_BUMP 	  BRSET PORTAD0,$08,NO_REAR_BUMP  ; If REAR_BUMP, then we should stop
		            JSR INIT_ALL_STOP               ; so initialize the ALL_STOP state
		            MOVB #ALL_STOP,CURRENT_STATE    ; and change state to ALL_STOP
		            JMP FWD_EXIT                    ; and return
                
NO_FWD_TURN 	  NOP                             ; Else
FWD_EXIT 	      RTS                             ; Return to the MAIN routine.
 	
REV_ST      	  LDAA TOF_COUNTER                 ;If Tc>Trev then
            	  BNE NO_REV                       ;so
            	  JSR INIT_U_TURN                  ;initialize the U_TURN state
            	  MOVB #U_TURN,CRNT_STATE          ;set state to U_TURN
            	  BRA REV_EXIT                     ;and return
NO_REV  	      NOP                              ;Else
REV_EXIT      	RTS

JUNC_ST      	  LDAA TOF_COUNTER                 ;If Tc>Trev then
            	  BNE NO_JUNC                      ;so
            	  JSR JUNC_CHECK                   ;initialize the JUNC_CHECK state
              	MOVB #JUNCTION,CRNT_STATE        ;set state to JUNCTION
            	  BRA JUNC_EXIT                     ;and return
NO_JUNC  	      NOP                              ;Else
JUNC_EXIT    	  RTS

STEER_ST      	LDAA TOF_COUNTER                 ;If Tc>Trev then
            	  BNE NO_STEER_CHECK               ;so
            	  JSR STEER_CHECK                  ;initialize the STERR_CHECK state
            	  MOVB #STEER,CRNT_STATE           ;set state to STEER
            	  BRA STEER_EXIT                    ;and return
NO_STEER_CHECK  NOP                              ;Else
STEER_EXIT    	RTS

; State Initialization Section
INIT_FORWARD    BCLR PORTA,%00000011              ;Set FWD direction for both motors
            	  BCLR PTT,%00110000                ;Turn on the drive motors
            	  LDAA TOF_COUNTER                  ;Mark the fwd time Tfwd
            	  ADDA #FWD_INT
            	  STAA T_FWD
            	  RTS

INIT_REVERSE    BSET PORTA,%00000011              ;Set REV direction for both motors
            	  BSET PTT,%00110000                ;Turn on the drive motors
            	  LDAA TOF_COUNTER                  ;Mark the fwd time Tfwd
              	ADDA #REV_INT
            	  STAA T_REV
            	  RTS

INIT_LEFT    	  BSET PORTA,%00000011              ;Set LEFT direction for both motors
            	  BSET PTT,%00110000                ;Turn on the drive motors
            	  LDAA TOF_COUNTER                  ;Mark the fwd time Tfwd
            	  ADDA #LEFT_INT
              	STAA T_LEFT
            	  RTS

INIT_RIGHT    	BSET PORTA,%00000011              ;Set RIGHT direction for both motors
            	  BSET PTT,%00110000                ;Turn on the drive motors
            	  LDAA TOF_COUNTER                  ;Mark the fwd time Tfwd
            	  ADDA #RIGHT_INT
            	  STAA T_RIGHT
              	RTS

INIT_U_TURN    	BSET PORTA,%00000011              ;Set RIGHT direction for both motors
            	  BSET PTT,%00110000                ;Turn on the drive motors
            	  LDAA TOF_COUNTER                  ;Mark the fwd time Tfwd
            	  ADDA #U_TURN_INT
            	  STAA T_U_TURN
            	  RTS
            	  
;* ---------------------------------------------------------------------------
;* Bumper Display
;* Displays the current status of the bumpers to the LCD.

BUMPER_DISPLAY	LDS #$4000  ;initialize the stack pointer
                JSR initAD  ;initialize ATD converter
                JSR initLCD ;initialize LCD
                JSR clrLCD  ;clear LCD & home cursor
                
                LDX #msg2   ;display Status
                JSR putsLCD ;"

;* ---------------------------------------------------------------------------
;* Bumper Check
;* Checks the bumpers status and makes calls to other subroutines based on the
;* status indicated.
           
BUMPER_CHECK    MOVB #$90,ATDCTL5     ;r.just., unsign., sing.conv., mult., ch0, start conv.
                BRCLR ATDSTAT0,$80,*  ;wait until the conversion sequence is complete
                             
                LDAA ATDDR4L          ; load the ch4 result into AccA 
                LDAB #39              ; Accb = 39
                MUL                   ; AccD = 1st result x 39
                ADDD #600             ; AccD = 1st result x 39 + 600
                             
                JSR int2BCD
                JSR BCD2ASC
                             
                LDAA #$8F             ;move LCD cursor to the 1st row, end of msg1
                JSR cmd2LCD           ;"
                LDAA TEN_THOUS        ;output the TEN_THOUS ASCII character
                JSR putcLCD           ;"
                LDAA THOUSANDS        ; same for THOUSANDS, ’.’ and HUNDREDS
                JSR putcLCD
                LDAA #'.'             ; Output the .
                JSR putcLCD           ; put to LCD monitor
                LDAA HUNDREDS
                JSR putcLCD
                LDAA #$CF             ;move LCD cursor to the 2nd row, end of msg2
                JSR cmd2LCD           ;"
                BRCLR PORTAD0,%00000100,bowON
                LDAA #$31             ;output ’1’ if bow sw OFF
                BRA bowOFF
                            
bowON           LDAA #$30             ;output ’0’ if bow sw ON
bowOFF          JSR putcLCD
                LDAA #' '             ;output a space character in ASCII
                JSR putcLCD;
                BRCLR PORTAD0,%00001000,sternON
		JSR U_TURN;
		JSR CORR_JUNC_ON;
                LDAA #$31             ;output ’1’ if stern sw OFF
                BRA sternOFF

sternON         LDAA #$30             ;output ’0’ if stern sw ON
sternOFF        JSR putcLCD
		JSR U_TURN;
		JSR JUNC_SOLVED_ON;
                JMP BUMPER_CHECK;
                          
msg2            dc.b "Sw status ",0 

;* ---------------------------------------------------------------------------
;* Alive Indicator
;* Runs the ALIVE Indicator program, in addition to displaying the status of 
;* sensors and the bumpers.

ALIVE_IND	LDAA PTT
		EORA #$40
		STAA PTT
		JSR DISPLAY_SENSORS
		JSR BUMPER_DISPLAY
		BRA ALIVE_IND 