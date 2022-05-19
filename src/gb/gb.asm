INCLUDE "hardware.inc"

; interrupt vectors
SECTION "vblank",ROM0[$40]
    jp VBlank
SECTION "lcdstat",ROM0[$48]
    jp LCDInterrupt
SECTION "timer",ROM0[$50]
    reti
SECTION "serial",ROM0[$58]
    reti
SECTION "joypad",ROM0[$60]
    reti

SECTION "Header", ROM0[$100]
    di ; Boot ROM already disabled interrupts, so this is kinda pointless
    jp EntryPoint

    ; Make sure to allocate some space for the header, so no important
    ; code gets put there and later overwritten by RGBFIX.
    ; RGBFIX is designed to operate over a zero-filled header, so make
    ; sure to put zeros regardless of the padding value. (This feature
    ; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
    ; introduced in that version.)
    DS $150 - @, 0

SECTION "Stack", WRAM0
    DS $7F ; 128 bytes for stack

SECTION "Code", ROM0

MACRO PAL24
    DW (((\1 & $F80000) >> 19) | ((\1 & $00F800) >> 6) | ((\1 & $0000F8) << 7))
ENDM

MACRO DEFPALETTE
    PAL24 \1
    PAL24 \2
    PAL24 \3
    PAL24 \4
ENDM

BGPalTemp:
    DEFPALETTE $FFFFFF, $888888, $555555, $000000

; Sets all 8 of the CGB background palettes.
; Input - HL = Address of palette data.
; Trashes - A E H L
SetBGPalettes:
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ld e, 8*4*2 ; 8 palettes, 4 colours per palette, 2 bytes per colour
:   ld a, [hli]
    ldh [rBCPD], a
    dec e
    jr nz, :-
    ret

EntryPoint:
    ld sp, STARTOF("Stack") + SIZEOF("Stack")
    ; Disable LCD
:   ldh a, [rLY]
    cp 144 ; Check if the LCD is past VBlank
    jr c, :-
    xor a ; turn off the LCD
    ldh [rLCDC], a

;    ldh a, [rKEY1]
;    bit 7, a ; Check if we're already in double-speed mode
;    jr nz, .skipSpeedSwitch
;    ld a, $30
;    ldh [rP1], a
;    xor a
;    ldh [rIE], a
;    inc a
;    ldh [rKEY1], a
;    stop ; Perform switch to CGB double-speed mode
;.skipSpeedSwitch:

    ; Shut sound down
    xor a
    ldh [rNR52], a

    ld a, %11100100
    ldh [rBGP], a ; set BG palette
    xor a
    ldh [rSCX], a
    ldh [rSCY], a ; reset scroll

    ; Set tilemap
    ld hl, _SCRN0
    ld de, 12
    ld b, 18
    xor a
.cpyMapY:
    ld c, 20
.cpyMapX:
    ld [hli], a
    inc a
    dec c
    jr nz, .cpyMapX
    add hl, de ; go to next line
    dec b
    jr nz, .cpyMapY

    ; Setup palettes
    ld hl, BGPalTemp
    call SetBGPalettes

    ; Init mid-screen interrupt
    ld a, 96 ; Scanline to interrupt on
    ldh [rLYC], a
    ld a, STATF_LYC ; Enable LY=LYC interrupt source
    ldh [rSTAT], a

    ld a, LCDCF_ON | LCDCF_WIN9800 | LCDCF_WINOFF | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_BGON
    ldh [rLCDC], a

    ; Disable all interrupts except VBlank and LCDC
	ld a, IEF_VBLANK | IEF_LCDC
	ldh [rIE], a
    xor a
    ldh [rIF], a ; Discard all pending interrupts (there would normally be a VBlank pending)
	ei

    xor a
    ld [wCtr], a

MainLoop:
    ld hl, rHDMA1
    ld a, [wCtr]
    bit 6, a
    jr z, .usePat2
    ld a, HIGH(TestPattern)
    ld [hli], a
    ld a, LOW(TestPattern)
    ld [hli], a ; Set DMA source
    jr .patdone
.usePat2:
    ld a, HIGH(tp2)
    ld [hli], a
    ld a, LOW(tp2)
    ld [hli], a ; Set DMA source
.patdone:
    ld a, HIGH($8000)
    ld [hli], a
    xor a ; ld a, LOW($8000)
    ld [hli], a ; Set DMA destination

    di ; this part is timing sensitive - no interrupts allowed!
    ; According to pan docs timing, I think I should be able to get 8 tiles per line
    ; but this causes artifacts on a real GBC. Works on emulator, though. Guess their timing isn't accurate enough.
    ld b, 51 ;  360 tiles for full framebuffer / 7 tiles copied per line
    ld d, %11
    ld c, LOW(rSTAT)
    ld e, HDMA5F_MODE_GP | 6 ; Number of tiles to copy - 1
.copyFramebufferLp
    ; Wait for HBlank
:   ldh a, [c]
    and d
    jr nz, :-
    ld [hl], e ; This starts the transfer
    dec b
    jr nz, .copyFramebufferLp
    ; 7 doesn't divide into 360 cleanly, so we have 3 tiles left over
    ld e, HDMA5F_MODE_GP | 2 ; Number of tiles to copy - 1
    ; Wait for HBlank
:   ldh a, [c]
    and d
    jr nz, :-
    ld [hl], e ; This starts the transfer
    ei

    ld hl, wCtr
    inc [hl]

    xor a
    ldh [hVblankDone], a
:   halt
    ldh a, [hVblankDone]
    and a
    jr z, :-
    jr MainLoop

SECTION "Vars", WRAM0
wCtr: DS 1

SECTION "VblankDone", HRAM
hVblankDone: DS 1

SECTION "InterruptHandlers", ROM0
VBlank:
    push af
    ldh a, [rLCDC]
    set 4, a ; set background tileset to LCDCF_BG8000
    ldh [rLCDC], a
    ld a, 1
    ldh [hVblankDone], a
    pop af
    reti

LCDInterrupt:
    push af
    ldh a, [rLCDC]
    res 4, a ; set background tileset to LCDCF_BG8800
    ldh [rLCDC], a
    pop af
    reti

SECTION "TempVidTestPattern", ROM0, ALIGN[4] ; must be aligned to 4 bits for HDMA
TestPattern:
REPT 18
REPT 20
DW `30000000
DW `03000000
DW `00300000
DW `00030000
DW `00003000
DW `00000300
DW `00000030
DW `00000003
ENDR
ENDR
tp2:
REPT 18
REPT 20
DW `00112233
DW `00112233
DW `00112233
DW `00112233
DW `00112233
DW `00112233
DW `00112233
DW `00112233
ENDR
ENDR
