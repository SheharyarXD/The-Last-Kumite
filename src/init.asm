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
    ; Universal backdrop is true black ($0F): the fight stage's stone
    ; mortar lines / window shadows are genuinely black in the source
    ; art, and bg_convert.py now nearest-color-matches per pixel instead
    ; of forcing a fixed fraction of the image into this slot, so a rare,
    ; intentional black no longer means "erase a quarter of the screen".
    .byte $0F               ; $3F00 Universal background (black)
    .byte $02, $21, $20     ; $3F01-$3F03 BG0: Sky — dark navy/mid-blue/cloud-white
    ; (FIX: was $21/$31/$20 -- no dark color meant this night sky's dominant
    ; near-black-navy pixels were nearest-matching to Stone's dark teal
    ; instead, which is why the sky rendered greenish-teal instead of blue.
    ; $02 is a close match (RGB (8,16,144) vs the art's dominant (0,11,139))
    ; and $31 was barely used, so nothing else changes.)
    .byte $0F
    ; BG1 recolored from earth-tone orange to a teal-grey stone ramp to
    ; match the castle/ground masonry in assets/32732.png.
    .byte $0C, $1C, $2C     ; $3F05-$3F07 BG1: Stone — dark/mid/light teal
    .byte $0F
    ; BG2 recolored from the title-logo red/gold/white to a green ramp,
    ; used by the fight stage for foliage quadrants (tree line, bushes).
    ; NOTE: title.asm's logo emblem used to ride on this same slot; since
    ; palette RAM persists across states, title now needs its own reload
    ; (see title.asm) instead of relying on this boot-time default.
    .byte $0A, $1A, $2A     ; $3F09-$3F0B BG2: Foliage — dark/mid/light green
    .byte $0F
    ; FIX: HUD palette — $26=orange-red for health bar borders, $30=white for text
    ; was $00/$10/$30 which produced dark-grey/grey/white — health bars barely visible
    .byte $26, $30, $11     ; $3F0D-$3F0F BG3: HUD -- player bar=red($26),
    ; text=white($30), enemy bar=blue($11) (was $3D pale yellow-green,
    ; unused -- repurposed so the two health bars are clearly red vs blue)

    ; Sprite palettes ($3F10-$3F1F)
    .byte $0F               ; $3F10 Sprite 0 transparent
    .byte $16, $27, $0F     ; $3F11-$3F13 SPR0: Michael (red-orange gi, gold trim, black hair/pants)
    .byte $0F               ; $3F14 (transparent slot for SPR1 group)
    .byte $12, $27, $0F     ; $3F15-$3F17 SPR1: Lightning (blue gi, gold trim, black hair/pants)
    .byte $0F
    ; FIX: was $18/$28/$38 (3 shades of yellow) -- recolored to dark
    ; navy/orange/gold so the Game Over thumbs-down portrait (gameover.asm,
    ; which draws with this palette) actually shows its intended
    ; navy-robe/orange-skin/gold-trim colors instead of an all-yellow
    ; wash. This palette is also still used for hit-spark/impact-flash
    ; effects (ppu.asm, EFFECT_TILE_BASE tiles) -- those flashes will now
    ; render navy/orange/gold instead of yellow.
    .byte $0C, $17, $28     ; $3F19-$3F1B SPR2: Effects + Game Over portrait
    .byte $0F
    .byte $12, $22, $32     ; $3F1D-$3F1F SPR3: White/silver