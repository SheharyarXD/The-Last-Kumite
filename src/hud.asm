; =============================================================================
; HEALTH BAR PALETTE NOTE (BUG FIX, historical):
; NES BG tile color comes from the attribute table, NOT from the tile index.
; The attribute table in stage_bg.inc rows 0-1 (top HUD area, rows 0-3 of
; nametable) were set to 0x00 = palette 0 (sky blues) which made health bars
; render as sky-blue-on-sky-blue = invisible.
;
; FIX APPLIED IN stage_bg.inc:
;   stage_attribute_table byte 0: changed to %11001100 so columns 0-7 and
;   16-23 (health bar columns) use palette 3 (HUD).
;   The center columns use palette 0 (sky) for the timer area.
;
; BG3 palette actually used by the health bar (init.asm default_palette):
;   $3F0C: $0F (black) — track/empty color (also universal backdrop)
;   $3F0D: $26 (orange-red) — player bar fill
;   $3F0E: $30 (white) — text color (names, VS, timer)
;   $3F0F: $11 (blue) — enemy bar fill (was $3D pale yellow-green,
;          unused; repurposed so player=red and enemy=blue are visually
;          distinct, per request, instead of red vs white)
; NOTE: the NES only exposes one BG3 palette for both HUD columns (attribute
; table works in 16x16px quadrants, and both bars share palette 3 here), so
; the two bars are differentiated by fill color (orange-red vs white) rather
; than a genuinely separate "blue" -- there is no spare BG palette slot for
; a distinct blue without stealing one of the three stage palettes (sky/
; stone/foliage), which would affect the background art. See CONTINUOUS
; HEALTH BAR note below for the current (single-bar, non-segmented) tile
; scheme.
; =============================================================================

; THE LAST KUMITE — HUD System
; Health bars, match timer, VS display, character names
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; INIT HUD — Setup initial HUD display
; =============================================================================
; Layout (rows 0-1 are a dedicated HUD strip, see LoadFightStage):
;   Row 0: [player bar: cols 1-10]        [timer: cols 15-16]   [enemy bar: cols 21-30]
;   Row 1: [player name: cols 1-7]        [VS: cols 15-16]      [enemy name: cols 21-29]
; =============================================================================
.export InitHUD
InitHUD:
    ; Draw player name: "MICHAEL" (row 1, under the player bar)
    SET_PTR text_ptr_lo, hud_michael
    lda #1
    sta text_x_pos
    lda #1
    sta text_y_pos
    jsr DrawText

    ; Draw enemy name: "LIGHTNING" (row 1, under the enemy bar)
    SET_PTR text_ptr_lo, hud_lightning
    lda #21
    sta text_x_pos
    lda #1
    sta text_y_pos
    jsr DrawText

    ; Draw initial health bars (both full) — top corners, row 0
    jsr DrawHealthBars

    ; Draw "VS" between the names (row 1, centered)
    SET_PTR text_ptr_lo, hud_vs
    lda #15
    sta text_x_pos
    lda #1
    sta text_y_pos
    jsr DrawText

    ; Draw timer display (row 0, centered, between the two bars)
    jsr DrawTimer
    rts


; =============================================================================
; UPDATE HUD — Per-frame HUD updates (health bars, timer)
; =============================================================================
.export UpdateHUD
UpdateHUD:
    ; Health bars are queued FIRST so they always get first claim on the
    ; shared bg_update_buf this frame -- if the timer or other HUD text
    ; filled the queue first, a same-frame collision could truncate a
    ; bar's redraw mid-column, which is what made the bars look like
    ; they were changing in uneven patches instead of draining smoothly.
    jsr @check_bars_entry

    ; Update match timer
    dec match_timer_sub
    bne @hud_done
    lda #60                 ; 60 frames = 1 second
    sta match_timer_sub
    dec match_timer_sec
    bne @update_timer_disp
    ; Time's up!
    rts
@update_timer_disp:
    jsr DrawTimer
@hud_done:
    rts

@check_bars_entry:
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
    beq @bars_done
    bcc @en_bar_up
    dec en_hp_disp
    jsr DrawEnemyBar
    jmp @bars_done
@en_bar_up:
    lda en_hp
    sta en_hp_disp

@bars_done:
    rts

; =============================================================================
; DRAW HEALTH BARS — Full bar redraw
; =============================================================================
DrawHealthBars:
    jsr DrawPlayerBar
    jsr DrawEnemyBar
    rts

; =============================================================================
; DRAW PLAYER HEALTH BAR — single continuous bar (borderless track + fill)
; =============================================================================
; The bar is still built from 10 background tiles (nametable columns 3-12),
; but each tile now has 8 sub-steps of fill resolution instead of being a
; single on/off block. Health logic (plr_hp / plr_hp_disp) is unchanged --
; only how HP is turned into tiles changed.
; =============================================================================
DrawPlayerBar:
    lda plr_hp_disp
    jsr CalcBarEighths       ; temp1 = total eighths filled (0-80)
    lda temp1
    sta temp2                ; temp2 = running remainder for this bar

    lda #1
    sta bg_queue_busy
    ldy #0
@plr_bar_loop:
    SKIP_IF_BG_QUEUE_FULL @plr_bar_done
    ldx bg_update_byte_idx
    lda #$20
    sta bg_update_buf, x
    inx
    tya
    clc
    adc #$01                ; Row 0, col 1 ($2001) + tile offset
    sta bg_update_buf, x
    inx

    jsr NextBarTile_Player    ; A = tile index for this column, updates temp2
    sta bg_update_buf, x
    inx
    stx bg_update_byte_idx
    inc bg_update_count      ; One more 3-byte entry queued

    iny
    cpy #10
    bcc @plr_bar_loop
@plr_bar_done:
    lda #0
    sta bg_queue_busy
    rts

; =============================================================================
; DRAW ENEMY HEALTH BAR — single continuous bar (borderless track + fill)
; =============================================================================
DrawEnemyBar:
    lda en_hp_disp
    jsr CalcBarEighths
    lda temp1
    sta temp2

    lda #1
    sta bg_queue_busy
    ldy #9                   ; start at the RIGHTMOST column (col 30, the
                              ; outer screen edge) and work left toward
                              ; center, so the bar fills/drains mirrored
                              ; relative to the player bar
@en_bar_loop:
    SKIP_IF_BG_QUEUE_FULL @en_bar_done
    ldx bg_update_byte_idx
    lda #$20
    sta bg_update_buf, x
    inx
    tya
    clc
    adc #$15                ; Row 0, col 21 ($2015) + tile offset
    sta bg_update_buf, x
    inx

    jsr NextBarTile_Enemy
    sta bg_update_buf, x
    inx
    stx bg_update_byte_idx
    inc bg_update_count

    dey
    bpl @en_bar_loop
@en_bar_done:
    lda #0
    sta bg_queue_busy
    rts

; =============================================================================
; NEXT BAR TILE (PLAYER) — consumes up to 8 eighths from temp2, returns tile
; Input:  temp2 = eighths remaining across the whole bar
; Output: A = tile index for this column; temp2 -= min(temp2, 8)
;   temp2 == 0      -> $02 track (empty)
;   temp2 >= 8       -> $03 full player tile, temp2 -= 8
;   1 <= temp2 <= 7  -> $05 + (temp2-1) partial tile, temp2 = 0 (remainder consumed)
; =============================================================================
NextBarTile_Player:
    lda temp2
    beq @empty
    cmp #8
    bcc @partial
    lda temp2
    sec
    sbc #8
    sta temp2
    lda #$03
    rts
@partial:
    sta temp3                ; temp3 = 1-7 eighths for this tile (X untouched --
                              ; caller has the bg_update_buf write offset in X
                              ; across this call, must not be clobbered)
    lda #0
    sta temp2                ; whole remainder consumed by this tile
    lda temp3
    clc
    adc #$04                 ; $05-1 base, +eighths(1-7) -> $05..$0B
    rts
@empty:
    lda #$02
    rts

; =============================================================================
; NEXT BAR TILE (ENEMY) — same as above, but the bar now fills right-to-
; left (see DrawEnemyBar), so partial tiles use the RIGHT-ALIGNED mirrored
; set ($0C-$0F, $1C-$1E) instead of the left-aligned $15-$1B originals.
; =============================================================================
NextBarTile_Enemy:
    lda temp2
    beq @empty
    cmp #8
    bcc @partial
    lda temp2
    sec
    sbc #8
    sta temp2
    lda #$04
    rts
@partial:
    sta temp3                ; temp3 = 1-7 eighths for this tile
    lda #0
    sta temp2
    stx temp4                ; save caller's bg_update_buf offset (X) --
                              ; must not clobber it, caller uses X after
                              ; this call returns
    ldx temp3
    lda en_bar_mirror_tiles - 1, x   ; index 1-7 -> mirrored tile number
    ldx temp4                ; restore caller's X
    rts
@empty:
    lda #$02
    rts

; Right-aligned mirrored partial tiles for the enemy bar, indexed by
; eighths-filled (1-7). See chr_data.asm CHR layout note.
en_bar_mirror_tiles:
    .byte $0C, $0D, $0E, $0F, $1C, $1D, $1E

; =============================================================================
; CALC BAR EIGHTHS — Convert HP (0-100) to total eighth-tile-steps (0-80)
; Input: A = HP value (0-100)
; Output: temp1 = floor(HP * 8 / 10), i.e. eighths of the 10-tile bar filled
; Implemented as a single table lookup (no runtime multiply/divide) --
; the cheapest possible 6502 implementation, avoids the old block-quantized
; HP/10 division.
; =============================================================================
CalcBarEighths:
    tax
    lda bar_eighths_table, x
    sta temp1
    rts

bar_eighths_table:
    .byte 0,0,1,2,3,4,4,5,6,7,8,8,9,10,11,12
    .byte 12,13,14,15,16,16,17,18,19,20,20,21,22,23,24,24
    .byte 25,26,27,28,28,29,30,31,32,32,33,34,35,36,36,37
    .byte 38,39,40,40,41,42,43,44,44,45,46,47,48,48,49,50
    .byte 51,52,52,53,54,55,56,56,57,58,59,60,60,61,62,63
    .byte 64,64,65,66,67,68,68,69,70,71,72,72,73,74,75,76
    .byte 76,77,78,79,80

; =============================================================================
; DRAW TIMER — Match countdown display
; =============================================================================
DrawTimer:
    ; Timer at row 0, cols 15-16 — center top, between the two bars
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

    ; Tens digit entry
    SKIP_IF_BG_QUEUE_FULL @timer_done
    ldx bg_update_byte_idx
    lda #$20
    sta bg_update_buf, x
    inx
    lda #$0F                ; Row 0, col 15 ($200F)
    sta bg_update_buf, x
    inx
    lda temp1
    clc
    adc #$A0                ; Number tile base
    sta bg_update_buf, x
    inx
    stx bg_update_byte_idx
    inc bg_update_count

    ; Ones digit entry
    SKIP_IF_BG_QUEUE_FULL @timer_done
    ldx bg_update_byte_idx
    lda #$20
    sta bg_update_buf, x
    inx
    lda #$10                ; Row 0, col 16 ($2010)
    sta bg_update_buf, x
    inx
    lda temp2
    clc
    adc #$A0
    sta bg_update_buf, x
    inx
    stx bg_update_byte_idx
    inc bg_update_count
@timer_done:
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
