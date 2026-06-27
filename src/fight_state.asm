; THE LAST KUMITE — Fight State Handler
; Main gameplay: initialization, update, and render for the fight scene
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "stage_bg.inc"

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

    ; Scroll position
    lda #0
    sta scroll_x
    sta scroll_y
    sta fade_level

    ; Wait for the next vblank before enabling rendering.
    ; Without this, RENDER_ON fires mid-frame: the top scanlines come out
    ; black (PPU_MASK was 0 during LoadFightStage) while the bottom
    ; scanlines show the fight stage, producing a visible black flash on
    ; every state transition into the fight.
    ; After WAIT_NMI the NMI handler has already run (OAM DMA, scroll=0,
    ; PPU_CTRL set), so RENDER_ON writes PPU_MASK during the remaining
    ; vblank window and the very first visible scanline begins with full
    ; rendering active.
    WAIT_NMI

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
    ; Clear nametable first (also resets attribute table to palette 0)
    lda #0
    sta nametable
    jsr ClearNametable

    ; Stream the converted background nametable (32x28 tiles = 896 bytes).
    ; X alone can't count to 896, so use a 16-bit counter in temp1:temp2
    ; (low:high) and index via (ptr),y-style indirect addressing instead.
    PPU_SETADDR $2000
    lda #<stage_nametable
    sta text_ptr_lo
    lda #>stage_nametable
    sta text_ptr_hi
    lda #0
    sta temp1                ; low byte of 896-byte counter
    sta temp2                ; high byte
@stage_loop:
    ldy #0
    lda (text_ptr_lo), y
    sta PPU_DATA
    ; advance pointer
    inc text_ptr_lo
    bne @stage_no_carry
    inc text_ptr_hi
@stage_no_carry:
    ; advance 16-bit byte counter, stop at 896 ($0380)
    inc temp1
    bne @stage_check
    inc temp2
@stage_check:
    lda temp2
    cmp #>896
    bcc @stage_loop
    bne @stage_done
    lda temp1
    cmp #<896
    bcc @stage_loop
@stage_done:

    ; Attribute table — 64 bytes, 8×8 grid, each byte covers a 4×4 tile block.
    ;
    ;   Attr rows 0-1  (tile rows  0-7,  upper sky area)   → palette 0
    ;                  BG0: $11/$21/$31 — dark/medium/light blue
    ;                  Fixes the "yellow sky" bug: all-palette-1 made the
    ;                  sky tiles render in olive/greenish-yellow earth tones.
    ;
    ;   Attr rows 2-7  (tile rows 8-27+, ground fighting area) → palette 1
    ;                  BG1: $08/$18/$28 — brown/tan/earth tones
    ;
    PPU_SETADDR $23C0
    ldx #0
@attr_sky_loop:
    lda #%00000000          ; All 4 quadrants = palette 0 (sky blues)
    sta PPU_DATA
    inx
    cpx #16                 ; 16 bytes = 2 attr rows × 8 columns
    bcc @attr_sky_loop
@attr_ground_loop:
    lda #%01010101          ; All 4 quadrants = palette 1 (earth tones)
    sta PPU_DATA
    inx
    cpx #64                 ; Bytes 16–63 = attr rows 2-7
    bcc @attr_ground_loop

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