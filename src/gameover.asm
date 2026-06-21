; THE LAST KUMITE — Game Over Screen Renderer
; Ron Hall thumbs-down cutscene + death text
; ============================================================================

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

    SET_PTR text_ptr_lo, continue_text
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

blank_continue:
    .asciiz "                    "
