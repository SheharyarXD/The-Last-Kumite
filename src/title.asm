; THE LAST KUMITE — Title Screen Renderer
; Background text rendering + decorative elements
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "title_logo.inc"

.segment "CODE"

; =============================================================================
; DRAW TITLE LOGO — Write the converted fist/ring emblem (assets/32730.png,
; see tools/title_logo_convert.py) into the title nametable + attribute
; table. Must be called from InitTitle BEFORE RENDER_ON -- same forced-blank
; direct PPU_ADDR/PPU_DATA writes that DrawText already relies on below.
; =============================================================================
LOGO_BASE_ADDR = $2000 + (LOGO_PLACE_Y * 32) + LOGO_PLACE_X

.export DrawTitleLogo
DrawTitleLogo:
    ; --- Tile data: an 8x8 block of background tiles ---
    ldy #0
.repeat LOGO_TILES_H, row
    PPU_SETADDR (LOGO_BASE_ADDR + (row * 32))
    .repeat LOGO_TILES_W
        lda title_logo_tiles, y
        sta PPU_DATA
        iny
    .endrep
.endrep

    ; --- Attribute table: point the emblem's tiles at BG palette 2, which
    ; LoadPalettes (init.asm) sets to red/gold/white for exactly this
    ; purpose -- BG2 is otherwise unused by any in-game background.
    ; Quadrant bits below only cover the 4x4-tile blocks the emblem actually
    ; occupies, so the blank row above it and the "THE LAST KUMITE" text row
    ; below it are untouched and stay on palette 0.
    PPU_SETADDR $23C3
    lda #%10100000          ; rows 2-3: bottom 2 quadrants -> palette 2
    sta PPU_DATA            ; attr column 3 (tile cols 12-15)
    sta PPU_DATA            ; attr column 4 (tile cols 16-19)

    PPU_SETADDR $23CB
    lda #%10101010          ; rows 4-7: full block -> palette 2
    sta PPU_DATA
    sta PPU_DATA

    PPU_SETADDR $23D3
    lda #%00001010          ; rows 8-9: top 2 quadrants -> palette 2
    sta PPU_DATA
    sta PPU_DATA
    rts

; =============================================================================
; RENDER TITLE — Draw title screen visual effects
; =============================================================================
.export RenderTitle
RenderTitle:
    ; Decorative: flash the border using palette cycling
    lda framecounter
    and #4
    beq @no_title_flash

    ; Add sparkle sprites around title
    lda oam_index
    cmp #240              ; Leave room for other sprites
    bcs @no_title_flash

    tax
    ; Small sparkle 1
    lda #60
    sta OAM_BUF, x
    inx
    lda #$F2              ; Sparkle tile
    sta OAM_BUF, x
    inx
    lda #%00000011        ; White palette
    sta OAM_BUF, x
    inx
    lda #40
    sta OAM_BUF, x
    inx

    ; Small sparkle 2
    lda #80
    sta OAM_BUF, x
    inx
    lda #$F2
    sta OAM_BUF, x
    inx
    lda #%00000011
    sta OAM_BUF, x
    inx
    lda #200
    sta OAM_BUF, x
    inx

    stx oam_index
@no_title_flash:
    rts