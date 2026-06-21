; THE LAST KUMITE — Title Screen Renderer
; Background text rendering + decorative elements
; ============================================================================

.segment "CODE"

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
