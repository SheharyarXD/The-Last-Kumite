; THE LAST KUMITE — VS Screen Renderer
; "MICHAEL RIVERS vs LIGHTNING" display before fight
; ============================================================================

.segment "CODE"

; =============================================================================
; RENDER VS — Draw VS screen sprites and effects
; =============================================================================
.export RenderVS
RenderVS:
    ; Draw character portraits as colored blocks (placeholder)
    ; Left side: Michael (red tint sprites)
    lda oam_index
    tax

    ; Michael portrait block (4×4 sprite cluster)
    ldy #0
@mspr_loop:
    lda vs_michael_y, y
    sta OAM_BUF, x
    inx
    lda #$FC                ; Solid tile
    sta OAM_BUF, x
    inx
    lda #%00000001          ; Palette 1 (red)
    sta OAM_BUF, x
    inx
    lda vs_michael_x, y
    sta OAM_BUF, x
    inx
    iny
    cpy #16
    bcc @mspr_loop

    ; Lightning portrait block (blue tint sprites)
    ldy #0
@lspr_loop:
    lda vs_lightning_y, y
    sta OAM_BUF, x
    inx
    lda #$FC
    sta OAM_BUF, x
    inx
    lda #%00000010          ; Palette 2 (blue)
    sta OAM_BUF, x
    inx
    lda vs_lightning_x, y
    sta OAM_BUF, x
    inx
    iny
    cpy #16
    bcc @lspr_loop

    stx oam_index

    ; Draw "VS" letters as sprites in center
    ldx oam_index
    ; V
    lda #100
    sta OAM_BUF, x
    inx
    lda #$86                ; V tile
    sta OAM_BUF, x
    inx
    lda #%00000011          ; White
    sta OAM_BUF, x
    inx
    lda #118
    sta OAM_BUF, x
    inx
    ; S
    lda #100
    sta OAM_BUF, x
    inx
    lda #$93                ; S tile
    sta OAM_BUF, x
    inx
    lda #%00000011
    sta OAM_BUF, x
    inx
    lda #126
    sta OAM_BUF, x
    inx
    stx oam_index

    rts

; =============================================================================
; VS SCREEN SPRITE POSITIONS
; =============================================================================
vs_michael_x:
    .byte 32, 40, 48, 56
    .byte 32, 40, 48, 56
    .byte 32, 40, 48, 56
    .byte 32, 40, 48, 56
vs_michael_y:
    .byte 80, 80, 80, 80
    .byte 88, 88, 88, 88
    .byte 96, 96, 96, 96
    .byte 104, 104, 104, 104

vs_lightning_x:
    .byte 172, 180, 188, 196
    .byte 172, 180, 188, 196
    .byte 172, 180, 188, 196
    .byte 172, 180, 188, 196
vs_lightning_y:
    .byte 80, 80, 80, 80
    .byte 88, 88, 88, 88
    .byte 96, 96, 96, 96
    .byte 104, 104, 104, 104
