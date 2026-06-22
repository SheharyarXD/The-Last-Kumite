; THE LAST KUMITE — Game Over Screen Renderer
; Ron Hall thumbs-down cutscene + death text
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; RENDER GAME OVER — Draw game over visual
; =============================================================================
.export RenderGameOver
RenderGameOver:
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

continue_text_go:
    .asciiz "PRESS START TO CONTINUE"
blank_continue:
    .asciiz "                    "
