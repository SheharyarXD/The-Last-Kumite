; THE LAST KUMITE — Fight State Handler
; Main gameplay: initialization, update, and render for the fight scene
; ============================================================================

.segment "CODE"

; =============================================================================
; INIT FIGHT — One-time setup for combat
; =============================================================================
.export InitFight
InitFight:
    ; Clear rendering
    RENDER_OFF

    ; Load fight stage background
    jsr LoadFightStage

    ; Initialize player
    jsr InitPlayer

    ; Initialize enemy
    jsr InitEnemy

    ; Initialize combat
    lda #0
    sta combo_count
    sta combo_display_t
    sta hit_freeze
    sta hit_flash_timer
    sta special_effect_t
    sta stun_combo_active
    sta shake_timer
    sta screen_shake_x
    sta screen_shake_y

    ; Initialize match timer
    lda #MATCH_TIME_DEFAULT
    sta match_timer_sec
    lda #60
    sta match_timer_sub

    ; Initialize HUD
    jsr InitHUD

    ; Reset state
    lda #0
    sta state_timer
    sta pause_flag
    sta next_gamestate

    ; Scroll position
    lda #0
    sta scroll_x
    sta scroll_y
    sta fade_level

    ; Turn on rendering
    RENDER_ON
    rts

; =============================================================================
; HANDLE FIGHT — Per-frame fight update
; =============================================================================
.export HandleFight
HandleFight:
    ; Check pause
    lda pause_flag
    beq @fight_active
    ; Paused: check for unpause
    lda pad1_new
    and #BTN_START
    beq @fight_paused
    lda #0
    sta pause_flag
@fight_paused:
    rts

@fight_active:
    ; Process player input
    jsr ProcessPlayerInput

    ; Check special move input
    jsr CheckSpecialInput

    ; Update special effects
    jsr UpdateSpecialEffects

    ; Update player
    jsr UpdatePlayer

    ; Update enemy AI
    jsr UpdateEnemy

    ; Update combat (hit detection)
    jsr UpdateCombat

    ; Update HUD
    jsr UpdateHUD

    ; Check win/lose
    jsr CheckMatchEnd

    rts

; =============================================================================
; RENDER FIGHT — Draw all fight scene elements
; =============================================================================
.export RenderFight
RenderFight:
    ; Render player character
    jsr RenderPlayer

    ; Render enemy character
    jsr RenderEnemy

    ; Render combo counter
    jsr DrawComboCounter

    ; Render pause overlay if paused
    lda pause_flag
    beq @no_pause_overlay
    jsr RenderPauseOverlay
@no_pause_overlay:

    ; Render KO message if someone is KO'd
    lda plr_state
    cmp #PLR_KO
    beq @render_ko_msg
    lda en_state
    cmp #EN_STATE_KO
    beq @render_ko_msg
    jmp @fight_render_done

@render_ko_msg:
    lda en_state
    cmp #EN_STATE_KO
    bne @plr_ko_msg
    ; Enemy KO — show victory flash
    lda framecounter
    and #4
    beq @fight_render_done
    SET_PTR text_ptr_lo, ko_text
    lda #13
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawTextBuffered
    jmp @fight_render_done

@plr_ko_msg:
    ; Player KO
    lda framecounter
    and #4
    beq @fight_render_done
    SET_PTR text_ptr_lo, player_ko_text
    lda #11
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawTextBuffered

@fight_render_done:
    rts

; =============================================================================
; RENDER PAUSE OVERLAY
; =============================================================================
RenderPauseOverlay:
    ; Blink "PAUSED" text
    lda framecounter
    and #32
    beq @pause_hide
    SET_PTR text_ptr_lo, paused_text
    lda #12
    sta text_x_pos
    lda #14
    sta text_y_pos
    jsr DrawTextBuffered
    rts
@pause_hide:
    SET_PTR text_ptr_lo, blank_paused
    lda #12
    sta text_x_pos
    lda #14
    sta text_y_pos
    jsr DrawTextBuffered
    rts

; =============================================================================
; CHECK SPECIAL INPUT — Wrapper for special move detection
; =============================================================================
CheckSpecialInput:
    ; Only check if player can act
    lda plr_hitstun
    bne @no_special
    lda plr_stunned
    bne @no_special
    lda plr_state
    cmp #PLR_KO
    beq @no_special

    ; Validate state
    jsr ValidateSpecialWindow
    bcc @no_special

    ; Check input buffer
    jsr CheckSpecialBuffer
    bcc @no_special

    ; Execute!
    jsr ExecuteSpecial
@no_special:
    rts

; =============================================================================
; LOAD FIGHT STAGE — Setup background for outdoor fighting arena
; =============================================================================
LoadFightStage:
    ; Clear nametable
    lda #0
    sta nametable
    jsr ClearNametable

    ; Draw ground line (row 20-21 = tiles $40-$5F in nametable)
    PPU_SETADDR $2280       ; Row 20
    ldx #0
@ground_row1:
    lda #$10                ; Ground tile
    sta PPU_DATA
    inx
    cpx #32
    bcc @ground_row1

    PPU_SETADDR $22A0       ; Row 21
    ldx #0
@ground_row2:
    lda #$11                ; Ground detail tile
    sta PPU_DATA
    inx
    cpx #32
    bcc @ground_row2

    ; Draw sky gradient (rows 0-15)
    PPU_SETADDR $2000
    ldx #0
@sky_loop:
    lda #$12                ; Sky tile (varies for gradient effect)
    sta PPU_DATA
    inx
    cpx #192                ; 6 rows of sky
    bcc @sky_loop

    ; Draw some background details (simple wall/building)
    PPU_SETADDR $2100       ; Row 8
    ldx #8
@wall_top:
    lda #$13                ; Wall top tile
    sta PPU_DATA
    inx
    cpx #24
    bcc @wall_top

    PPU_SETADDR $2120       ; Row 9
    ldx #8
@wall_mid:
    lda #$14                ; Wall mid tile
    sta PPU_DATA
    inx
    cpx #24
    bcc @wall_mid

    rts

; =============================================================================
; FIGHT TEXT DATA
; =============================================================================
ko_text:
    .asciiz "KO!"
player_ko_text:
    .asciiz "K.O."
paused_text:
    .asciiz "PAUSED"
blank_paused:
    .asciiz "      "
