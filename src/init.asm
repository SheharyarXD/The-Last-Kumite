; THE LAST KUMITE — NES Hardware Initialization
; RESET handler — First code executed on power-on/reset
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; RESET — Power-on initialization
; =============================================================================
.export RESET
RESET:
    ; -------------------------------------------------------------------------
    ; Disable interrupts and set CPU binary mode
    ; -------------------------------------------------------------------------
    sei                     ; Disable IRQ interrupts
    cld                     ; Clear decimal mode (NES 6502 doesn't use it)

    ; -------------------------------------------------------------------------
    ; Wait for PPU to stabilize (2 vblanks)
    ; -------------------------------------------------------------------------
    ldx #2
@wait_vblank:
    bit PPU_STATUS          ; Read PPU STATUS ($2002) bit 7 = VBlank flag
    bpl @wait_vblank        ; Wait until bit 7 set (in vblank)
    dex
    bne @wait_vblank        ; Do this twice for safety

    ; -------------------------------------------------------------------------
    ; Initialize stack pointer
    ; -------------------------------------------------------------------------
    ldx #$FF
    txs                     ; Stack = $01FF

    ; -------------------------------------------------------------------------
    ; Clear all RAM ($0000-$07FF)
    ; -------------------------------------------------------------------------
    lda #0
    ldx #0
@clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clear_ram

    ; -------------------------------------------------------------------------
    ; Initialize APU (silence all channels)
    ; -------------------------------------------------------------------------
    lda #0
    sta APU_CTRL            ; Disable all sound channels ($4015)
    lda #$40
    sta APU_FRAME_COUNTER   ; Disable frame IRQ ($4017 bit 6)

    ; -------------------------------------------------------------------------
    ; Clear OAM buffer (hide all sprites)
    ; -------------------------------------------------------------------------
    CLEAR_OAM

    ; -------------------------------------------------------------------------
    ; Set default PPU registers
    ; -------------------------------------------------------------------------
    lda #PPUCTRL_SPR_PT     ; NMI off, sprites from $1000, BG from $0000
    sta PPU_CTRL
    sta ppu_ctrl_cache
    lda #0
    sta PPU_MASK            ; Rendering off
    sta ppu_mask_cache
    sta PPU_SCROLL          ; Scroll X = 0
    sta PPU_SCROLL          ; Scroll Y = 0

    ; -------------------------------------------------------------------------
    ; Load palettes
    ; -------------------------------------------------------------------------
    jsr LoadPalettes

    ; -------------------------------------------------------------------------
    ; Initialize zero page variables
    ; -------------------------------------------------------------------------
    lda #STATE_TITLE
    sta gamestate
    sta next_gamestate
    lda #0
    sta state_initialized   ; Force InitCurrentState (InitTitle) to run on first frame
    sta pause_flag
    sta framecounter
    sta framecounter_hi
    sta special_cooldown
    sta shake_timer
    sta hit_freeze

    ; Random seed initialization
    lda #$42                ; Arbitrary seed (could use frame counter)
    sta rand_seed

    ; -------------------------------------------------------------------------
    ; Enable NMI generation BEFORE waiting for it, otherwise the CPU would
    ; spin forever waiting for an interrupt that can never fire.
    ; Rendering itself is turned on later by each state's Init handler,
    ; once it has finished writing to the PPU safely.
    ; -------------------------------------------------------------------------
    lda #(PPUCTRL_NMI | PPUCTRL_SPR_PT)
    sta PPU_CTRL
    sta ppu_ctrl_cache

    WAIT_NMI

    ; Jump to main game loop (never returns)
    jmp MainLoop

; =============================================================================
; LOAD PALETTES — Copy color data to PPU palette RAM
; =============================================================================
LoadPalettes:
    PPU_SETADDR $3F00       ; Palette RAM starts at $3F00

    ldx #0
@load_pal_loop:
    lda default_palette, x
    sta PPU_DATA
    inx
    cpx #32                 ; 32 bytes = 2 sets of 16 colors
    bne @load_pal_loop
    rts

; =============================================================================
; DEFAULT PALETTES
; BG Palette:    Outdoor fighting stage colors
; SPR Palette:   Character + effect colors
; =============================================================================
default_palette:
    ; Background palettes ($3F00-$3F0F)
    ; FIX: $0C (dark grey) instead of $0F (blacker-than-black) so tiles
    ; render visible even with sub-optimal tile data in chr/tiles.chr.
    .byte $0C               ; $3F00 Universal background (very dark grey)
    ; FIX: BG0 sky blues boosted — $21=mid-blue, $31=light-blue, $3C=pale
    .byte $21, $31, $3C     ; $3F01-$3F03 BG0: Sky blues (FIXED: was $11/$21/$31, too dark)
    .byte $0F
    ; FIX: BG1 earth tones made warmer/lighter — $17=dark-orange, $27=tan, $37=cream
    .byte $17, $27, $37     ; $3F05-$3F07 BG1: Ground earth tones (FIXED: was $08/$18/$28, too dark)
    .byte $0F
    ; BG2 repurposed for title-screen logo emblem.
    .byte $16, $27, $30     ; $3F09-$3F0B BG2: Title logo (red/gold/white)
    .byte $0F
    ; FIX: HUD palette — $26=orange-red for health bar borders, $30=white for text
    ; was $00/$10/$30 which produced dark-grey/grey/white — health bars barely visible
    .byte $26, $30, $3D     ; $3F0D-$3F0F BG3: HUD/UI (FIXED: was $00/$10/$30)

    ; Sprite palettes ($3F10-$3F1F)
    .byte $0F               ; $3F10 Sprite 0 transparent
    .byte $16, $27, $0F     ; $3F11-$3F13 SPR0: Michael (red-orange gi, gold trim, black hair/pants)
    .byte $0F               ; $3F14 (transparent slot for SPR1 group)
    .byte $12, $27, $0F     ; $3F15-$3F17 SPR1: Lightning (blue gi, gold trim, black hair/pants)
    .byte $0F
    .byte $18, $28, $38     ; $3F19-$3F1B SPR2: Effects (yellow)
    .byte $0F
    .byte $12, $22, $32     ; $3F1D-$3F1F SPR3: White/silver