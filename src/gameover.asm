; THE LAST KUMITE — Game Over Screen Renderer
; Ron Hall thumbs-down cutscene + death text
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "sprite_tiles_const.inc"

.segment "CODE"

GAMEOVER_PORTRAIT_X = 100   ; (256 - 56) / 2, horizontally centered
GAMEOVER_PORTRAIT_Y = 48    ; tile row 6; leaves room for "GAME OVER" above
                            ; and the caption/death text below (see
                            ; InitGameOver in state_machine.asm)

; =============================================================================
; RENDER GAME OVER — Draw game over visual
; =============================================================================
.export RenderGameOver
RenderGameOver:
    jsr DrawThumbsPortrait

    ; Blink the "PRESS START TO CONTINUE" text
    lda framecounter
    and #32
    beq @go_hide

    SET_PTR text_ptr_lo, continue_text_go
    lda #6
    sta text_x_pos
    lda #26
    sta text_y_pos
    jsr DrawTextBuffered
    jmp @go_done

@go_hide:
    SET_PTR text_ptr_lo, blank_continue
    lda #6
    sta text_x_pos
    lda #26
    sta text_y_pos
    jsr DrawTextBuffered
@go_done:
    rts

; -----------------------------------------------------------------------
; DrawThumbsPortrait — 7x7 grid of 8x8 sprites (56x56px), the Ron Hall
; thumbs-down art authored by tools/author_gameover.py. Positions are
; computed arithmetically (row*7+col) rather than stored in a table,
; since it's a uniform grid -- unlike the VS portraits' 4x4 grid in
; vs_screen.asm, which predates this and already had its position tables
; written out, this one is new code so it uses the more compact approach.
; Tile index for cell (row,col) is GAMEOVER_THUMBS_BASE + row*7 + col,
; matching the raster (left-to-right, top-to-bottom) order
; build_static_tile_block in tools/chr_convert.py writes the source PNG.
; Uses sprite palette 2 (effects palette in init.asm, $18/$28/$38 --
; close enough to this art's dark/gold/orange tones to read fine, and
; keeps the thumbs-down portrait visually distinct from both fighters'
; palettes 0/1 without needing a 5th hardware palette slot).
DrawThumbsPortrait:
    lda oam_index
    tax

    lda #0
    sta temp1               ; row
@row_loop:
    lda #0
    sta temp2                ; col
@col_loop:
    ; Y = GAMEOVER_PORTRAIT_Y + row*8
    lda temp1
    asl
    asl
    asl                      ; row * 8
    clc
    adc #GAMEOVER_PORTRAIT_Y
    sta OAM_BUF, x
    inx

    ; Tile = GAMEOVER_THUMBS_BASE + row*7 + col
    jsr ComputeRowTimes7      ; -> temp_mul_result = temp1 * 7
    lda temp_mul_result
    clc
    adc temp2
    clc
    adc #GAMEOVER_THUMBS_BASE
    sta OAM_BUF, x
    inx

    lda #%00000010           ; Palette 2
    sta OAM_BUF, x
    inx

    ; X = GAMEOVER_PORTRAIT_X + col*8
    lda temp2
    asl
    asl
    asl                      ; col * 8
    clc
    adc #GAMEOVER_PORTRAIT_X
    sta OAM_BUF, x
    inx

    inc temp2
    lda temp2
    cmp #7
    bcc @col_loop

    inc temp1
    lda temp1
    cmp #7
    bcc @row_loop

    stx oam_index
    rts

; -----------------------------------------------------------------------
; ComputeRowTimes7 — temp_mul_result = temp1 * 7 (temp1 is the row index,
; always 0-6 here). A small fixed-count add loop rather than a general
; multiply routine, since the one caller above only ever needs this one
; multiplicand.
ComputeRowTimes7:
    lda #0
    sta temp_mul_result
    ldy temp1
@mul7_loop:
    cpy #0
    beq @mul7_done
    lda temp_mul_result
    clc
    adc #7
    sta temp_mul_result
    dey
    jmp @mul7_loop
@mul7_done:
    rts

continue_text_go:
    .asciiz "PRESS START TO CONTINUE"
blank_continue:
    .asciiz "                       "
