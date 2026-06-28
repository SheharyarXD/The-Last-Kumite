; THE LAST KUMITE — VS Screen Renderer
; "MICHAEL RIVERS vs LIGHTNING" display before fight
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "sprite_tiles_const.inc"

.segment "CODE"

; =============================================================================
; RENDER VS — Draw VS screen character portraits
; =============================================================================
; Each portrait is a 4x4 grid of 8x8 sprites (32x32px) built from the
; fighter's own authored portrait art (tools/author_vs_portraits.py),
; using each fighter's real in-game sprite palette so the portrait reads
; as that character rather than a generic colored block:
;   Michael (left)   -> palette 0 (init.asm SPR0, red-orange gi)
;   Lightning (right)-> palette 1 (init.asm SPR1, blue gi)
; This used to draw a flat solid-color tile ($FC) for both fighters, and
; used the WRONG palette bits for both (Michael in Lightning's blue
; palette, Lightning in the yellow effects palette) -- fixed here.
.export RenderVS
RenderVS:
    lda oam_index
    tax

    ; Michael portrait (4x4 grid, palette 0)
    ldy #0
@mspr_loop:
    lda vs_michael_y, y
    sta OAM_BUF, x
    inx
    tya
    clc
    adc #VS_MICHAEL_BASE
    sta OAM_BUF, x
    inx
    lda #%00000000          ; Palette 0 (Michael, red-orange gi)
    sta OAM_BUF, x
    inx
    lda vs_michael_x, y
    sta OAM_BUF, x
    inx
    iny
    cpy #16
    bcc @mspr_loop

    ; Lightning portrait (4x4 grid, palette 1)
    ldy #0
@lspr_loop:
    lda vs_lightning_y, y
    sta OAM_BUF, x
    inx
    tya
    clc
    adc #VS_LIGHTNING_BASE
    sta OAM_BUF, x
    inx
    lda #%00000001          ; Palette 1 (Lightning, blue gi)
    sta OAM_BUF, x
    inx
    lda vs_lightning_x, y
    sta OAM_BUF, x
    inx
    iny
    cpy #16
    bcc @lspr_loop

    stx oam_index
    rts

; =============================================================================
; VS SCREEN SPRITE POSITIONS
; =============================================================================
; Each portrait is 4 columns x 4 rows of 8px sprites = 32x32px. Tile index
; for OAM entry y is (y's row*4 + col), which must match the raster order
; build_static_tile_block in tools/chr_convert.py writes the source PNG in
; (left-to-right, top-to-bottom) -- so the y-th sprite here always uses
; tile VS_MICHAEL_BASE+y / VS_LIGHTNING_BASE+y, computed above.
vs_michael_x:
    .byte 36, 44, 52, 60
    .byte 36, 44, 52, 60
    .byte 36, 44, 52, 60
    .byte 36, 44, 52, 60
vs_michael_y:
    .byte 28, 28, 28, 28
    .byte 36, 36, 36, 36
    .byte 44, 44, 44, 44
    .byte 52, 52, 52, 52

vs_lightning_x:
    .byte 168, 176, 184, 192
    .byte 168, 176, 184, 192
    .byte 168, 176, 184, 192
    .byte 168, 176, 184, 192
vs_lightning_y:
    .byte 28, 28, 28, 28
    .byte 36, 36, 36, 36
    .byte 44, 44, 44, 44
    .byte 52, 52, 52, 52
