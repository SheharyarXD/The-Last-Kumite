; THE LAST KUMITE — HUD System
; Health bars, match timer, VS display, character names
; ============================================================================

.segment "CODE"

; =============================================================================
; INIT HUD — Setup initial HUD display
; =============================================================================
.export InitHUD
InitHUD:
    ; Draw player name: "MICHAEL"
    SET_PTR text_ptr_lo, hud_michael
    lda #2
    sta text_x_pos
    lda #2
    sta text_y_pos
    jsr DrawText

    ; Draw enemy name: "LIGHTNING"
    SET_PTR text_ptr_lo, hud_lightning
    lda #19
    sta text_x_pos
    lda #2
    sta text_y_pos
    jsr DrawText

    ; Draw initial health bars (both full)
    jsr DrawHealthBars

    ; Draw "VS" between health bars
    SET_PTR text_ptr_lo, hud_vs
    lda #14
    sta text_x_pos
    lda #3
    sta text_y_pos
    jsr DrawText

    ; Draw timer display
    jsr DrawTimer
    rts

; =============================================================================
; UPDATE HUD — Per-frame HUD updates (health bars, timer)
; =============================================================================
.export UpdateHUD
UpdateHUD:
    ; Update match timer
    dec match_timer_sub
    bne @check_bars
    lda #60                 ; 60 frames = 1 second
    sta match_timer_sub
    dec match_timer_sec
    bne @update_timer_disp
    ; Time's up!
    rts
@update_timer_disp:
    jsr DrawTimer

@check_bars:
    ; Smooth health bar animation (displayed HP approaches actual HP)
    ; Player health bar
    lda plr_hp_disp
    cmp plr_hp
    beq @check_en_bar
    bcc @plr_bar_up
    dec plr_hp_disp         ; Animated drain
    jsr DrawPlayerBar
    jmp @check_en_bar
@plr_bar_up:
    ; (Shouldn't happen normally, but handle it)
    lda plr_hp
    sta plr_hp_disp

@check_en_bar:
    ; Enemy health bar
    lda en_hp_disp
    cmp en_hp
    beq @hud_done
    bcc @en_bar_up
    dec en_hp_disp
    jsr DrawEnemyBar
    jmp @hud_done
@en_bar_up:
    lda en_hp
    sta en_hp_disp

@hud_done:
    rts

; =============================================================================
; DRAW HEALTH BARS — Full bar redraw
; =============================================================================
DrawHealthBars:
    jsr DrawPlayerBar
    jsr DrawEnemyBar
    rts

; =============================================================================
; DRAW PLAYER HEALTH BAR
; =============================================================================
DrawPlayerBar:
    ; Player bar at nametable position (3, 3) to (12, 3)
    ; 10 tiles = 100 HP / 10 per tile
    lda plr_hp_disp
    jsr CalcBarTiles

    ; Write to BG update buffer
    ldx bg_update_count
    lda #$20
    sta bg_update_buf, x
    inx
    lda #$83                ; Row 3, col 3 ($2083)
    sta bg_update_buf, x
    inx

    ; Write 10 tiles
    ldy #0
@plr_bar_loop:
    cpy temp1               ; Filled tiles
    bcc @plr_fill
    lda #$02                ; Empty bar tile
    jmp @plr_tile
@plr_fill:
    lda #$03                ; Full bar tile (red)
@plr_tile:
    sta bg_update_buf, x
    inx
    iny
    cpy #10
    bcc @plr_bar_loop
    stx bg_update_count
    inc bg_update_count
    inc bg_update_count
    rts

; =============================================================================
; DRAW ENEMY HEALTH BAR
; =============================================================================
DrawEnemyBar:
    ; Enemy bar at nametable position (19, 3) to (28, 3)
    lda en_hp_disp
    jsr CalcBarTiles

    ldx bg_update_count
    lda #$20
    sta bg_update_buf, x
    inx
    lda #$93                ; Row 3, col 19 ($2093)
    sta bg_update_buf, x
    inx

    ldy #0
@en_bar_loop:
    cpy temp1
    bcc @en_fill
    lda #$02
    jmp @en_tile
@en_fill:
    lda #$04                ; Full bar tile (blue for enemy)
@en_tile:
    sta bg_update_buf, x
    inx
    iny
    cpy #10
    bcc @en_bar_loop
    stx bg_update_count
    inc bg_update_count
    inc bg_update_count
    rts

; =============================================================================
; CALC BAR TILES — Convert HP to number of filled tiles
; Input: A = HP value
; Output: temp1 = number of filled tiles (0-10)
; =============================================================================
CalcBarTiles:
    ldx #0
@div_loop:
    cmp #10
    bcc @div_done
    sec
    sbc #10
    inx
    jmp @div_loop
@div_done:
    stx temp1
    rts

; =============================================================================
; DRAW TIMER — Match countdown display
; =============================================================================
DrawTimer:
    ; Timer at position (14, 5) — center top
    ; Convert seconds to BCD-like display
    lda match_timer_sec
    ldx #0
@tens_loop:
    cmp #10
    bcc @timer_tens_done
    sec
    sbc #10
    inx
    jmp @tens_loop
@timer_tens_done:
    sta temp2               ; Ones digit
    stx temp1               ; Tens digit

    ; Queue BG update
    ldx bg_update_count
    lda #$20
    sta bg_update_buf, x
    inx
    lda #$AE                ; Row 5, col 14 ($20AE)
    sta bg_update_buf, x
    inx

    ; Tens digit tile
    lda temp1
    clc
    adc #$A0                ; Number tile base
    sta bg_update_buf, x
    inx

    ; Ones digit tile
    lda temp2
    clc
    adc #$A0
    sta bg_update_buf, x
    inx

    stx bg_update_count
    inc bg_update_count
    inc bg_update_count
    rts

; =============================================================================
; DRAW COMBO COUNTER — Show current combo hits
; =============================================================================
.export DrawComboCounter
DrawComboCounter:
    lda combo_count
    beq @no_combo
    cmp #2                  ; Only show for 2+ hits
    bcc @no_combo

    lda combo_display_t
    beq @no_combo

    ; Draw combo text at bottom center
    SET_PTR text_ptr_lo, combo_text
    lda #11
    sta text_x_pos
    lda #26
    sta text_y_pos
    jsr DrawTextBuffered
@no_combo:
    rts

; =============================================================================
; HUD TEXT DATA
; =============================================================================
hud_michael:
    .asciiz "MICHAEL"
hud_lightning:
    .asciiz "LIGHTNING"
hud_vs:
    .asciiz "VS"
combo_text:
    .asciiz "COMBO"
