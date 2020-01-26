***********************************************
* JUKEBOX MENU DRUM CONTROLLER
* JUKE.ASM - Code to run on MC68HC705J1A to control
* title strip drum and credit/selection lights
* 3-14-10     D. Durbin
***********************************************
*
* Operational Description
* The STEP UP/DN switches will move the menu drum for easier
* title strip exchanges when the juke lid is open. Also, the
* drum will not move via the select switches with the lid open.
* The PROGRAM switch is used to set the position of the
* menu drum. When the switch is set, the Program LED will
* light. At this time the STEP UP and DOWN switches can be
* used to position the drum so rows 1 & 2 are correctly
* viewed in the window area with the left most Selection
* switch pressed in. When the Program switch is turned
* off, this value is stored in the EEPROM.
* Then the Program LED is turned off.
*
* If programming is required, the STEP switches work as
* follows.
*  Pressing the UP switch moves the drum at a slow rate upward
*  	Movement stops when the switch is released.
*  Pressing the DWN switch moves the drum at a slow rate downward
*  	Movement stops when the switch is released.
*
*  ** DO NOT RUN THE DRUM CONTINUOSLY FOR FUN, the position
*       switches only have fifty thousand rotations of life. The
*       motor switch turns at 5 times the rate of the drum switch.
*
* Normal operation on powerup is to turn on all 4 pricing lights
* and sequence through the 5 selection lights for 250 msec each.
* Then lights off. Then the EEPROM data for drum position is read.
* The value from the EEPROM is used, correct or not. If things
* appear erratic, follow the setup procedure above.
* The drum position is checked against the EEPROM position
* contents and selection switches and adjusted if
* neccessary.
* A 4MHz crystal is used with the CPU. This lets the HC05
* operate at 2MHz. The internal counter range is then from
* 1/2 msec to 128 msec. An 8-bit counter increments
* every 1/2 msec. While interrupts exist in the hardware,
* they are not used and the program runs continuously in
* the MAIN routine.
* The SPI interface is contained in the Xilinx CPLD. The
* position switches output a grey code. This is converted
* to straight binary code inside a pair of EPROMS, so the two
* position switch registers read as direct binary sequences.
* These switches are not sync'd mechanically with the drum
* position, for instance '00h' is not any given drum position.
* That is why the Program function exists.
* When a selection switch is pressed, the drum will be rotated
* in whichever direction is closest to the new switch position.
*
* Address Map
*       Port A is the data bus, PA0 is the LSB, PA7 is the MSB
*       Port B is the address and control port
*               PB0 is Register address A0
*               PB1 is Register address A1
*               PB2 is Register address A2
*               PB3 is Register address A3
*               PB4 is REG_SEL_ENB (acts as a chip select, active high)
*               PB5 is RD_WR_L (selects RD - '1' or WR - '0')
*
*       PB3 downto PB0 select the register to be accessed
*       0000 = Register 0 - Drum, Motor Position, Read Only
*               Motor position, a 360 degree 7-bit binary readout.
*               This is actually an 8-bit gray code that is converted by
*               EPROM to straight 7-bit binary.
*               Count decreases as the menu drum rolls upward.
*               The count rolls over from 00h to 7Fh.
*               A new two-row section appears with each 360 degree rotation.
*               This is used to position the selected menu section.
*
*       0001 = Register 1 - Drum, Drum Position, Read Only
*               Menu drum position, a 360 degree 7-bit binary readout.
*               This is actually an 8-bit gray code that is converted by
*               EPROM to straight 7-bit binary.
*               Count increases as the menu drum rolls upward.
*               The count rolls over from 7Fh to 00h.
*               All five menu sections rotate through with each 360 degree rotation.
*               This is used to go to the selected menu section.
*
*       0010 = Register 2 - Selector Switches, Read Only
*               Selector switch inputs.
*               Bits 0 to 4 are mutually exclusive. Active low signals.
*               Bit 0 is menu section 1 (left most switch on the jukebox, rows 1&2)
*               Bit 1 is menu section 2, rows 3&4
*               Bit 2 is menu section 3, rows 5&6
*               Bit 3 is menu section 4, rows 7&8
*               Bit 4 is menu section 5 (right most switch on the jukebox, rows 9&0)
*               Bit 5 is the top lid open signal. Active high.
*               Bit 6 is the EEPROM Program switch. Active low.
*               Bit 7 is the Step Change switch. Active high.
*
*       0011 = Register 3 - Interrupt Mask, Write Only
*               Selector switch input interrupt mask.
*               This register's bits are defined the same as Register 2.
*                   However, the complement of REG2 is put in Reg3.
*                   The respective bits of each register are exclusive OR'd and
*                   AND'd together to drive the interrupt input.
*               Anytime this register's value is the same as register 2, an
*               interrupt will be generated to the CPU.
*               The normal way to use this register is to copy the complemented
*               contents of register 2 into it. This will remove any interrupt. As
*               an input is switched, two input bits will be the same and an interrupt
*               will be generated. Setting register 3 to the complemented value of
*               register 2 will remove the interrupt again.
*
*       0100 = Register 4 - Selector Lights, Write Only
*               Bits 7 downto 3 are Selector Light outputs.
*               Bit 0 is EEPROM command is of short length, (EE_SHORT),'1'= 9-bit, '0'= 25-bit
*               Bit 1 is not used
*               Bit 2 is EEPROM ('1') or DAC ('0') Chip Select (EE_DA_L)
*               Bit 3 is Select Light 1 (for left most switch on the jukebox), Active high.
*               Bit 4 is Select Light 2  Active high.
*               Bit 5 is Select Light 3  Active high.
*               Bit 6 is Select Light 4  Active high.
*               Bit 7 is Select Light 5 (for right most switch on the jukebox), Active high.
*
*       0101 = Register 5 - Pricing Switches, Read Only
*               Pricing switch inputs, '1' = 15 cents, '0' = 10 cents.
*               Bit 0 is row 1
*               Bit 1 is row 2
*               Bit 2 is row 3
*               Bit 3 is row 4
*               Bit 4 is row 5
*               Bit 5 is row 6
*               Bit 6 is row 7
*               Bit 7 is row 8
*
*       0110 = Register 6 - Pricing and Programming Switches, Read Only
*               Pricing switch inputs, '1' = 15 cents, '0' = 10 cents.
*               Bit 0 is row 9
*               Bit 1 is row 0
*               Bit 2 is not used, reads a '1'
*               Bit 3 is not used, reads a '1'
*               Bit 4 is not used, reads a '1'
*               Bit 5 is not used, reads a '1'
*               Bit 6 is the Step Up Switch input, STEP_UP_L, active low
*               Bit 7 is the Step Down Switch input, STEP_DOWN_L, active low
*
*       0111 = Register 7 - Pricing Lights, Programming LED and  , Write Only
*               Bits 7 downto 3 are Selector Light outputs.
*               Bit 0 is the Bottom Row 10 cent light, '1' = ON
*               Bit 1 is the Bottom Row 15 cent light, '1' = ON
*               Bit 2 is the Top Row 10 cent light, '1' = ON
*               Bit 3 is the Top Row 15 cent light, '1' = ON
*               Bit 4 is not used
*               Bit 5 is the Programming LED, active low (PROG_LED_L)
*               Bit 6 is the Menu Drum Enable, active high, (DRUM_ENB)
*               Bit 7 is the Menu Drum Direction, '1' = Down, '0' = Up
*
*       1000 = Register 8 - SPI TX_LO, write only, low byte of 24-bit
*                       transfer to the EEPROM, don't care for DAC
*
*       1001 = Register 9 - SPI TX_MID, write only, middle byte of 24-bit
*                       transfer to the EEPROM or DAC, this is the high data byte
*                       for the EEPROM and the only data byte for the DAC
*
*       1010 = Register 10 - SPI TX_HI, write only, high byte of 24-bit
*                       transfer to the EEPROM or DAC, this is the command
*                       byte for the EEPROM and the DAC
*               ***** NOTE: The start bit for the EEPROM is done in hardware,
*                               do not put it in the command register.
*                               The command for reading address 32 would be 10110010 (B2)
*
*       1011 = Register 11 - SPI RX_LO, read only, low byte of 16-bit
*                       transfer from the EEPROM
*
*       1100 = Register 12 - SPI RX_HI, read only, high byte of 16-bit
*                       transfer from the EEPROM
*
*       1101 = Register 13 - SPI CNTL, read/write, Control and Status for
*               the SPI transfer (Reads as 80h after reset)
*               Bit 0 is TRANSFER, writing '1' to this bit starts an SPI transfer.
*               Writing bits 1 to 7 has no effect.
*               Bit 7 is DONE when read, '1' indicates the transfer is complete.
*               Bits 0 to 6 all read as '0'.
*
*       IRQ_L is an interrupt driven by any change to one of the five menu
*               select buttons, the top lid openning, the program switch being
*               set or a step change caused by pressing the up or down buttons.
*               This is an active low input.
*****************************************************************************

 org $7f1
 db $2a    ;MOR set for:
 ;No watchdog
 ;LEVEL interrupts
 ;No PortA IRQ
 ;No Port Pulldowns
 ;Stop Mode
 ;Enable Osc Parallel Resistor
 ;No EPROM security
 ;No short osc delay cnt

 org $7f8
 dw tim_int
 dw irq_int
 dw sw_int
 dw init
 org ram

reg0: equ $20 ; address for register 0, set for read
reg1: equ $21 ; address for register 1, set for read
reg2: equ $22 ; address for register 2, set for read
reg3: equ $03 ; address for register 3, set for write
reg4: equ $04 ; address for register 4, set for write
reg5: equ $25 ; address for register 5, set for read
reg6: equ $26 ; address for register 6, set for read
reg7: equ $07 ; address for register 7, set for write
reg8: equ $08 ; address for register 8, set for write
reg9: equ $09 ; address for register 9, set for write
reg10: equ $0A ; address for register 10, set for write
reg11: equ $2B ; address for register 11, set for read
reg12: equ $2C ; address for register 12, set for read
reg13rd: equ $2D ; address for register 13, set for read
reg13wr: equ $0D ; address for register 13, set for write

REG0_MP rmb 1 ;storage for data read from Reg 0
REG1_DP rmb 1 ;storage for data read from Reg 1
REG2_SPSW rmb 1 ;storage for data read from Reg 2
REG3_IM rmb 1 ;Ram mirror for data written to Reg 3
REG4_EESL rmb 1 ;Ram mirror for data written to Reg 4
REG5_PSW rmb 1 ;storage for data read from Reg 5
REG6_PSSW rmb 1 ;storage for data read from Reg 6
REG7_PPLD rmb 1 ;Ram mirror for data written to Reg 7
SPI_TX_LO rmb 1 ;Ram mirror for data written to Reg 8
SPI_TX_MID rmb 1 ;Ram mirror for data written to Reg 9
SPI_TX_HI rmb 1 ;Ram mirror for data written to Reg 10
SPI_RX_LO rmb 1 ;storage for data read from Reg 11
SPI_RX_HI rmb 1 ;storage for data read from Reg 12
; SPI Reg 13 has no storage, it is only one bit each way
temp1 rmb 1 ;general storage 1
temp2 rmb 1 ;general storage 2
temp3 rmb 1 ;general storage 3
temp4 rmb 1 ;general storage 4
xaddr rmb 1 ;address of register to be accessed
xdata rmb 1 ;data written to or read from a register
drmos rmb 1 ;menu drum position offset
motos rmb 1 ;motor position offset
prgsw rmb 1 ;set non-zero when program switch is enabled
drmup rmb 1 ;set non-zero when drum last moved up, zero when last down
drmon rmb 1 ;set non-zero when drum is moving
dadac rmb 1 ;used to store data sent to DAC
drpos rmb 1 ;current drum position,1=rows 1&2, 2=rows 3&4,.., 5=rows 9&0
swsel rmb 1 ;current selection switch flag, 1=rows 1&2, .., 5=rows 9&0
rd2xs rmb 1 ;register used to hold values read the same twice for debounce
lopct rmb 1 ;loop count value for SPI transfer completions
xplus rmb 1 ;used as extended counter beyond x-register

        org rom
init:   clrx        	;clear X register
        stx prgsw       ;make sure program switch flag is initially clear
        stx drmon       ;make sure flag indicates motor off
;set up ports
        lda #$20;
        sta portb   ;make PortB(PB0-PB4) outputs low and PB5 output high
        lda #$3F
        sta ddrb  ;make pins PB0-PB5 outputs
        clra
        sta ddra  ;make portA inputs (data bus)
;set interrupt mask register
        jsr rdsps       ;read register 2
        lda REG2_SPSW
        coma
        sta REG3_IM
        jsr wrint       ;write complemented reg 2 value to reg 3
;set selector lights OFF, EE_SHORT to 25-bit and select EEPROM
        lda #$04
        sta REG4_EESL
        jsr wrsle       ;write register 4
;set Programming LED and Pricing Lights OFF and drum direction UP
; with drum movement disabled
	  lda #$20
        sta REG7_PPLD
        jsr wrppl
;also send FFh to DAC to set its level to zero
        lda #$FF      ;this stops the motor
        sta dadac
        jsr wrdac
;SPI interface is already stable

;sequence the selection lights for 1/4 second each
;leave all 4 pricing lights on for the duration
LON     lda REG7_PPLD   ;turn on pricing lights and program LED
        and #$F0        ;clear lowest 4 bits
        and #$DF        ;turn on program LED (active low enable)
        ora #$0F        ;turn on pricing lights and program LED
        sta REG7_PPLD
        jsr wrppl       ;write pricing lights, program LED
        nop
        lda #$08        ;use to cycle thru lights
        sta temp1
        lda REG4_EESL   ;save off eeprom control bits
        and #$07
        sta temp3       ;save eeprom control bits in temp3 to be added back later
        ;sequence the selection lights
        lda tscr
        and #$FC
        sta tscr        ;set RTI for 8msec
sequ    lda temp1
        ora temp3       ;add back in eeprom control bits
        sta REG4_EESL
        jsr wrsle
        lda #$20        ;counts 8msec RTIs to get ~250msec
        sta temp2
looplts brclr 6,tscr,looplts    ;wait for RTI flag
        bset 2,tscr             ;reset RTI flag
        dec temp2
        bne looplts
        lsl temp1
        bcc sequ        ;exit loop when sequence complete

;turn off all lights
LOFF    lda REG7_PPLD
        and #$F0        ;turn off pricing lights
        ora #$20        ;turn off program LED
        sta REG7_PPLD   ;leave drum control intact
        jsr wrppl       ;write pricing lights, program LED and drum control
        lda REG4_EESL
        and #$07
        sta REG4_EESL   ;turn off selector lights, leave EE control intact
        jsr wrsle

;before main, update position offsets from EEPROM
	  jsr eerd
	  lda SPI_RX_LO
	  sta motos
	  lda SPI_RX_HI
	  sta drmos

main ;bra LOFF

;check for lid open as switch functions change when top is raised
          jsr rdsps     ;check register 2 for open lid
          brset 5,REG2_SPSW,lidopen
          jmp lidclosed
lidopen ;up/down step switches work to position drum
          ;program switch works to update position offset values in EEPROM
          jsr rdpss
          brset 6,REG6_PSSW,ckdwn       ;check for step up sw pressed
          ;step up sw is pressed
          jsr drumup    ;sets up for upward drum movement
          lda #$C0      ;this runs the motor at low speed
          sta dadac
          jsr wrdac
          lda #$FF
          sta drmup     ;indicates drum has been going upward
          sta drmon 	;indicates drum is moving
          bra swdun
ckdwn     brset 7,REG6_PSSW,nosw        ;check for step down sw pressed
          jsr drumdwn   ;sets up for downward drum movement
          lda #$C0      ;this runs the motor at low speed
          sta dadac
          jsr wrdac
          clr drmup     ;indicates drum has been going downward
          lda #$FF
          sta drmon     ;indicates drum is moving
          bra swdun
nosw      clr drmon     ;indicates motor off
          lda #$FF      ;this stops the motor
          sta dadac
          jsr wrdac
          jsr drumoff   ;this disables motor select

swdun     ;done with step switches
          ;check program switch if drum stopped, else bypass
          lda drmon
          bne progdun
          jsr rdsps
          brset 6,REG2_SPSW,noprog
          lda #$FF
          sta prgsw             ;set prgsw if switch asserted
          ;turn on program LED
          bclr 5,REG7_PPLD
          jsr wrppl
          bra progdun
noprog    lda prgsw
          beq progdun   ;exit if program switch was never asserted
          clr prgsw       ;clear progsw flag
          ;compute motor and drum offsets and write to EEPROM
          lda drmup
          beq   ddwn
          ;drum was last moving in the upward direction
          ;compute offset to position motor at 7Fh (upward drum movement)
          jsr rdmp
          lda #$7F
          sub REG0_MP     ;subtract motor position from 7Fh to get offset for 7Fh
          sta motos       ;motos holds the motor offset for upward drum movement
          bra dros
ddwn      ;drum was last moving in the downward direction
          ;compute offset to position motor at 7Fh (downward drum movement)
          jsr rdmp
          lda #$7F     	  ;motor real position
          sub REG0_MP     ;offset to 7Fh
          add #$06        ;increase value so that stored offset is for upward drum movement
	    and #$7F	  ;zero upper bit
          sta motos       ;motos holds the motor offset for upward drum movement
dros      jsr rddp        ;compute drum position offset
          lda #$0C
          sub REG1_DP     ;offset to center of rows 1&2
          sta drmos       ;drmos holds the drum offset
          ;write offsets to EEPROM
          lda motos
          sta SPI_TX_LO
          lda drmos
          sta SPI_TX_MID
          jsr eewr
          ;turn off program LED
          bset 5,REG7_PPLD
          jsr wrppl
progdun
	    jmp main

lidclosed ;set up lights based on drum position

	    ;clear selection light register in preparation
	    lda REG4_EESL
	    and #$07
	    sta REG4_EESL	;clears all lights in register
	    ;clear pricing lights register in preparation
	    lda REG7_PPLD
	    and #$F0
	    sta REG7_PPLD	;clears all lights in register
	    ;update pricing switch registers
	    jsr rdps	;updates REG5_PSW
	    jsr rdpss	;updates REG6_PSSW 
	    ;set lights based on drum position
          jsr rddp
          lda REG1_DP
          add drmos
          and #$7F      ;mask off upper bit
          sta temp1     ;now holds current usable drum position
	    ;keep in mind usable drum position values will be 0 
	    ;to 7Fh, all values will be positive
          ;check if drum is in 1-2 range (0h-19h)
          lda #$19      ;hi limit for 1-2
          sub temp1
          bcs dp_3_4
	    lda #$01
	    sta drpos	;currently in rows 1&2 position
          ;adjust lights
	    bset 3,REG4_EESL	;sets select light 1-2
	    ;set pricing lights
	    brset 0,REG5_PSW,dp1_15c	;check top row
	    bset 2,REG7_PPLD
	    bra dp12_br 
dp1_15c   bset 3,REG7_PPLD
dp12_br   brset 1,REG5_PSW,dp2_15c	;check bottom row
	    bset 0,REG7_PPLD
	    bra dp12_wrl 
dp2_15c   bset 1,REG7_PPLD
dp12_wrl  bra enb_prl
dp_3_4    ;check if drum is in 3-4 range (1Ah-32h)
          lda #$32      ;hi limit for 3-4
          sub temp1
          bcs dp_5_6
	    lda #$02
	    sta drpos	;currently in rows 3&4 position
          ;adjust lights
	    bset 4,REG4_EESL	;sets select light 3-4
	    ;set pricing lights
	    brset 2,REG5_PSW,dp3_15c	;check top row
	    bset 2,REG7_PPLD
	    bra dp34_br 
dp3_15c   bset 3,REG7_PPLD
dp34_br   brset 3,REG5_PSW,dp4_15c	;check bottom row
	    bset 0,REG7_PPLD
	    bra dp34_wrl 
dp4_15c   bset 1,REG7_PPLD
dp34_wrl  bra enb_prl
dp_5_6    ;check if drum is in 5-6 range
          lda #$4C
          sub temp1      ;hi limit for 5-6
          bcs dp_7_8
	    lda #$03
	    sta drpos	;currently in rows 5&6 position
          ;adjust lights
	    bset 5,REG4_EESL	;sets select light 5-6
	    ;set pricing lights
	    brset 4,REG5_PSW,dp5_15c	;check top row
	    bset 2,REG7_PPLD
	    bra dp56_br 
dp5_15c   bset 3,REG7_PPLD
dp56_br   brset 5,REG5_PSW,dp6_15c	;check bottom row
	    bset 0,REG7_PPLD
	    bra dp56_wrl 
dp6_15c   bset 1,REG7_PPLD
dp56_wrl  bra enb_prl
dp_7_8    ;check if drum is in 7-8 range
          lda #$65
          sub temp1      ;hi limit for 7-8
          bcs dp_9_0
	    lda #$04
	    sta drpos	;currently in rows 7&8 position
          ;adjust lights
	    bset 6,REG4_EESL	;sets select light 7-8
	    ;set pricing lights
	    brset 6,REG5_PSW,dp7_15c	;check top row
	    bset 2,REG7_PPLD
	    bra dp78_br 
dp7_15c   bset 3,REG7_PPLD
dp78_br   brset 7,REG5_PSW,dp8_15c	;check bottom row
	    bset 0,REG7_PPLD
	    bra dp78_wrl 
dp8_15c   bset 1,REG7_PPLD
dp78_wrl  bra enb_prl
dp_9_0    ;drum must be in 9-0 range
          ;adjust lights
	    bset 7,REG4_EESL	;sets select light 9-0
	    lda #$05
	    sta drpos	;currently in rows 9&0 position
	    ;set pricing lights
	    brset 0,REG6_PSSW,dp9_15c	;check top row
	    bset 2,REG7_PPLD
	    bra dp90_br 
dp9_15c   bset 3,REG7_PPLD
dp90_br   brset 1,REG6_PSSW,dp0_15c	;check bottom row
	    bset 0,REG7_PPLD
	    bra enb_prl 
dp0_15c   bset 1,REG7_PPLD
enb_prl   jsr wrppl	;write pricing lights
	    jsr wrsle	;write selection light

	    lda drmon
	    beq rdps12
	    jmp byps10	;bypass static drum position check if drum in motion
	    ;now check to see if drum is correctly positioned
	    ;see which selection switch is closed
rdps12    jsr rdsps	;updates REG2_SPSW
psw1_2    brset 0,REG2_SPSW,psw3_4
          ;position switch 1_2 is closed
	    lda #$01
	    sta swsel	;set up switch selection flag
	    lda drpos
	    cmp #$01
	    bra ckpos
psw3_4    brset 1,REG2_SPSW,psw5_6
          ;position switch 3_4 is closed
	    lda #$02
	    sta swsel	;set up switch selection flag
	    lda drpos
	    cmp #$02
	    bra ckpos
psw5_6    brset 2,REG2_SPSW,psw7_8
          ;position switch 5_6 is closed
	    lda #$03
	    sta swsel	;set up switch selection flag
	    lda drpos
	    cmp #$03
	    bra ckpos
psw7_8    brset 3,REG2_SPSW,psw9_0
          ;position switch 7_8 is closed
	    lda #$04
	    sta swsel	;set up switch selection flag
	    lda drpos
	    cmp #$04
	    bra ckpos
psw9_0    ;then position switch 9_0 must be closed
	    lda #$05
	    sta swsel	;set up switch selection flag
	    lda drpos
	    cmp #$05
	    bra ckpos
ckpos     beq mpgood
	    jsr movedrum
mpgood    jmp main      ;all is good

;check for correct stop drum section
byps10 jsr rdsps	;updates REG2_SPSW
	;update swsel
	brset 0,REG2_SPSW,sec2
	ldx #$01	;select sw 1
	bra swend
sec2	brset 1,REG2_SPSW,sec3
	ldx #$02	;select sw 2
	bra swend
sec3	brset 2,REG2_SPSW,sec4
	ldx #$03	;select sw 3
	bra swend
sec4	brset 3,REG2_SPSW,sec5
	ldx #$04	;select sw 4
	bra swend
sec5	ldx #$05	;select sw 5
swend stx swsel	;updates select switch flag
	lda drpos
	cmp swsel
	bne nostop
	jsr rampdn	;ramp down and stop the drum
	clr drmon	;reset drum in motion flag
nostop jmp main

;****************************************************************

;SUBROUTINES

movedrum  ;this is the major drum movement routine
	lda drmon	;check to see if drum is already moving
	bne dmvg	;bypass select direction if moving
; select direction - determine which way the drum must rotate
; if selection switch is greater than drum position
	lda swsel
	sub drpos
	bcs els1
; then
;   if selection switch - drum positon is < 3
	lda swsel
	sub drpos
	cmp #$03
	bcc els2
;   then move upward
	lda #$FF
	sta drmup	;set drum direction travel flag to up
	bra end2
;   else move downward
els2	clr drmup	;set drum direction travel flag to down
end2
;   end if
	bra end1
els1
; else selection switch is less than drum position
;   if drum position - selection switch is < 3
	lda drpos
	sub swsel
	cmp #$03
	bcc els3
;   then move downward
	clr drmup	;set drum direction travel flag to down
	bra end3
els3
;   else move upward
	lda #$FF
	sta drmup	;set drum direction travel flag to up
;   end if
end3
; end if
end1
;set drum movement direction
	lda drmup
	beq dmdwn
	jsr drumup
	bra ddend
dmdwn	jsr drumdwn
ddend
;start drum moving
	lda #$FF
	sta drmon	;set to indicate drum is now in motion
	jsr rampup
dmvg	rts

rampup	;start ramp_up of motor
        lda #$C0        ;value where the motor moves slowly
        sta temp1
;set up RTI for DAC countdown
        lda #$00        ;set up RTI for 8msec
        sta tscr
decmv   lda temp1       ;D0h value is start to motor
        sta dadac       ;transfer to DAC write
        jsr wrdac
	  ;is motor at full speed?
        lda temp1
	  cmp #$60
        beq xrmpup      ;exit rampup
	  ;else increase motor speed after 8msec
timeup  brclr 6,tscr,timeup
        bset 2,tscr     ;resets RTI flag
        lda temp1
        sub #$01        ;increase motor speed (DAC toward 00h, full speed)
        sta temp1
        bra decmv
xrmpup  rts

rampdn  ;ramp down and stop motor
        lda #$00        ;set up RTI for 8msec
        sta tscr
	  ;determine stop value based on direction
	  lda drmup
	  beq ddrdn
	  lda #$7F	;drum upward direction
	  sta temp4	;use temp4 as motor stop value
	  bra ddrend
ddrdn	  lda #$05	;drum downward direction
	  sta temp4	;use temp4 as motor stop value
ddrend
	  lda #$60
	  sta temp1	;use temp1 for motor speed value
newnd   lda temp1
        add #$08        ;slow down motor
        sta temp1
	  sta dadac
        jsr wrdac
;test for motor position equal to temp1 while slowing motor via RTI
        clr temp2       ;use temp2 as flag for twice in row read stop
ckmpi   jsr rdmp
        lda REG0_MP     ;motor real position
        add motos       ;offset to 7Fh
        and #$7F        ;zero out bit 7
        cmp temp4       ;test for exit    
        bne dnext
        inc temp2
        brclr 1,temp2,dnext   ;must see mp twice in a row
        bra bypasx      ;exit if at stop position
dnext   brclr 6,tscr,ckmpi    ;test for RTI timeout for DAC update
        bset 2,tscr     ;clr RTI flag
        lda temp1       ;test to see if DAC is at D0h, if so, then don't slow any more
        cmp #$C0
        beq ckmpi       ;keep checking for stop motor position (temp4)
        bra newnd       ;keep slowing motor down
bypasx
;now truly stop motor
        lda #$FF         ;FFh value to DAC is full stop to motor
        sta temp1        ;store motor speed
        sta xdata
        jsr wrdac
;disable drive to drum
        jsr drumoff
	  clr drmon
	  rts

drumup: lda REG7_PPLD   ;enable upward drive to drum
        and #$3F        ;clear top two bits
        ora #$40        ;enable motor and set drive direction
        sta REG7_PPLD   ;(0=up)
        jsr wrppl
          rts

drumdwn: lda REG7_PPLD  ;enable downward drive to drum
        and #$3F        ;clear top two bits
        ora #$C0        ;enable motor and set drive direction
        sta REG7_PPLD   ;(0=up)
        jsr wrppl
          rts

drumoff: lda REG7_PPLD  ;disable drive to drum
        and #$3F        ;clear top two bits
        sta REG7_PPLD   ;(0=up)
        jsr wrppl
          rts

wrdac:                          ;receives data in xdata location
        lda REG4_EESL
        and #$F8        ;selects DAC, leaving select lites intact
        sta REG4_EESL
        jsr wrsle
        lda #$03        ;set up to load both channels A & B
        sta SPI_TX_HI   ;wreg10 is now DAC command register
        jsr wrstxh
        lda dadac
        sta SPI_TX_MID  ;wreg9 is used for DAC data
        jsr wrstxm
	  ;transfer 16 bits at 0.5usec/bit, use count of 1Ch
	  lda #$1C
	  sta lopct
        jsr spi_start
        rts

wr_reg:           ;write register
      lda xaddr   ;RD_WR_L is already '0' due to xaddr contents
      sta portb   ;set up address and rd/wr for register write
      ora #$10
      sta portb   ;raise REG_SEL_ENB high to start register write
      lda xdata
      sta porta	;store data to be put on bus
      lda #$ff    ;make porta pins PA7-PA0 outputs &
      sta ddra    ;put data on bus
      lda portb
      and #$EF
      sta portb   ;lower REG_SEL_ENB low to write to register
      clra
      sta ddra    ;return porta to inputs
      rts

rd_reg:           ;read register
      clra
      sta ddra    ;set porta to inputs (should be already)
      lda xaddr   ;RD_WR_L is already '1' due to xaddr contents
      sta portb   ;set up address and rd/wr for register read
      ora #$10
      sta portb   ;read register while REG_SEL_ENB is pulsed high
	nop		;give some extra time for data to be valid
      lda porta
      sta xdata   ;save register contents in xdata
      lda portb
      and #$EF
      sta portb   ;lower REG_SEL_ENB to de-select register
      rts

rdmp:  lda #reg0        ;read motor position
      sta xaddr
      jsr rd_reg
      lda xdata
      sta REG0_MP               ;rreg0
        rts

rddp:  lda #reg1        ;read drum position
      sta xaddr
      jsr rd_reg
      lda xdata
      sta REG1_DP      ;rreg1
        rts

rdsps: lda #reg2        ;read selector & program switches
      sta xaddr
	jsr rd_reg
rd10  lda xdata
	sta rd2xs
	ldx #$FF		;~ 1msec
	lda #$32		;~ 50msec
	sta xplus
rd20	nop
	decx			;psuedo debounce for ~1 msec
	bne rd20
	decx			;rolls over to FFh
	dec xplus		;do it 50 times for ~50 msec
	bne rd20
	jsr rd_reg
	lda xdata
	cmp rd2xs
	bne rd10
      sta REG2_SPSW   ;rreg2
        rts

rdps:  lda #reg5        ;read pricing switches
      sta xaddr
      jsr rd_reg
      lda xdata
      sta REG5_PSW      ;rreg5
        rts

rdpss: lda #reg6        ;read pricing and step switches
      sta xaddr
      jsr rd_reg
      lda xdata
      sta REG6_PSSW ;rreg6
        rts

rdsrxl: lda #reg11        ;read SPI receive register (LO)
       sta xaddr
       jsr rd_reg
       lda xdata
       sta SPI_RX_LO    ;rreg11
       rts

rdsrxh: lda #reg12        ;read SPI receive register (HI)
       sta xaddr
       jsr rd_reg
       lda xdata
       sta SPI_RX_HI    ;rreg12
       rts

wrppl:   lda  #reg7      ;write pricing lights, program LED and drum control
      sta xaddr
      lda REG7_PPLD
      sta xdata
      jsr wr_reg
        rts

wrsle: lda #reg4 ;write selector lights and EEPROM/DAC control
      sta xaddr
      lda REG4_EESL
      sta xdata
      jsr wr_reg
      rts

wrint: lda #reg3 ;write interrupt mask
      sta xaddr
      lda REG3_IM
      sta xdata
      jsr wr_reg
      rts

wrstxl: lda  #reg8      ;write SPI_TX_LO register
       sta xaddr
       lda SPI_TX_LO
       sta xdata
       jsr wr_reg
       rts

wrstxm: lda  #reg9      ;write SPI_TX_MID register
       sta xaddr
       lda SPI_TX_MID
       sta xdata
       jsr wr_reg
       rts

wrstxh: lda  #reg10     ;write SPI_TX_HI register
       sta xaddr
       lda SPI_TX_HI
       sta xdata
       jsr wr_reg
       rts

eerd:
        lda REG4_EESL       ;set up to read EEPROM data
        and #$F8        ;clear lowest 3 bits
        ora #$04        ;select EEPROM and set for 25 bit transfer
        sta REG4_EESL
        jsr wrsle       ;write to register 4 (REG4_EESL)
        lda #$80        ;set up read EEPROM command for address 00h
        sta SPI_TX_HI
        jsr wrstxh
	  ;transfer 25 bits at 0.5usec/bit, use count of 2Bh
	  lda #$2B
	  sta lopct
        jsr spi_start   ;starts SPI transfer for read command
        jsr rdsrxh      ;Register SPI_RX_HI now holds msbyte (DRUM OFFSET)
        jsr rdsrxl      ;Register SPI_RX_LO now holds lsbyte (MOTOR OFFSET)
        rts

eewr:   ;Data should already be written in SPI_TX_MID and SPI_TX_LO
        ;SPI_TX_MID contains the Drum offset to be written
        ;SPI_TX_LO contains the Motor offset to be written
wen     ;send command to enable the EEPROM to be written
        lda REG4_EESL ;set up to write EEPROM short command
        and #$F8          ;clear lowest 3 bits
        ora #$05          ;select EEPROM and set for 9 bit transfer
        sta REG4_EESL
        jsr wrsle
        nop
        lda #$30
        sta SPI_TX_HI   ;set up EEPROM write_enable command
        jsr wrstxh      ;write enable command
	  ;transfer 9 bits at 0.5usec/bit, use count of 10h
	  lda #$10
	  sta lopct
        jsr spi_start   ;start transfer,send write enable to EEPROM
wrdatas lda REG4_EESL ;set up to write EEPROM data
        and #$F8        ;clear lowest 3 bits
        ora #$04        ;select EEPROM and set for 25 bit transfer
        sta REG4_EESL
        jsr wrsle
        ;SPI_TX_MID must already be valid, set up msbyte data (Drum)
        jsr wrstxm
        ;SPI_TX_LO must already be valid, set up lsbyte data (Motor)
        jsr wrstxl
        lda #$40        ;set up write EEPROM command for address 00h
        sta SPI_TX_HI
        jsr wrstxh
	  ;transfer 25 bits at 0.5usec/bit, use count of 2Bh
	  lda #$2B
	  sta lopct
        jsr spi_start
        ;wait for about 15msec, eeprom write should be done by then
        ldx #$20              ;use x to count down 16msec of TOF (500 usec)
timew   brclr 7,tscr,timew
        bset 3,tscr     ;resets TOF flag
        decx
        bne   timew
wrdiss  lda REG4_EESL       ;set up to write EEPROM short command
        and #$F8        ;clear lowest 3 bits, leave select lites intact
        ora #$05        ;select EEPROM and set for 9 bit transfer
        sta REG4_EESL
        jsr wrsle
        nop
        lda #$00         ;set up EEPROM write_disable command
        sta SPI_TX_HI
        jsr wrstxh
	  ;transfer 9 bits at 0.5usec/bit, use count of 10h
	  lda #$10
	  sta lopct
        jsr spi_start   ;send write disable to EEPROM, start transfer
        rts

spi_start:            ;initiates SPI transfer, assumes registers are set up
        lda #reg13wr     ;set start bit
        sta xaddr
        lda #$01
        sta xdata
        jsr wr_reg      ;starts SPI transfer
	  ;for transfer of 25 bits @ 5usec/bit, =125us, use 129/3 or 2Bh
	  ;for transfer of 16 bits @ 5usec/bit, = 80us, use  84/3 or 1Ch
	  ;for transfer of  9 bits @ 5usec/bit, = 45us, use  48/3 or 10h
	  lda lopct	;wait for loop count value (3usec/loop)
lpct1	  deca
	  bne lpct1
        rts

tim_int:
      rti                ;exit interrupt

irq_int:
      rti                ;exit interrupt

sw_int:
      rti                ;exit interrupt
