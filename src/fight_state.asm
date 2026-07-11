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

    ; BG0/BG1/BG2 ($3F01-$3F0B) are shared palette RAM slots also used
    ; by other states (BG0 is the title/menu screens' bright text blue,
    ; BG2 is the title logo's red/gold/white). Re-point them at the
    ; stage's night-sky/stone/foliage ramps here so a fight entered
    ; after visiting the title screen doesn't inherit the wrong colors.
    PPU_SETADDR $3F01
    lda #$02
    sta PPU_DATA
    lda #$21
    sta PPU_DATA
    lda #$20
    sta PPU_DATA
    PPU_SETADDR $3F05
    lda #$0C
    sta PPU_DATA
    lda #$1C
    sta PPU_DATA
    lda #$2C
    sta PPU_DATA
    lda #$0F
    sta PPU_DATA
    lda #$0A
    sta PPU_DATA
    lda #$1A
    sta PPU_DATA
    lda #$2A
    sta PPU_DATA

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
    sta plr_hit_flash_timer
    sta en_hit_flash_timer
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
    ; Clear the PAUSED text immediately -- RenderPauseOverlay only runs
    ; while pause_flag is set, so without this the text would otherwise
    ; sit on screen forever after unpausing.
    SET_PTR text_ptr_lo, blank_paused
    lda #8
    sta text_x_pos
    lda #1
    sta text_y_pos
    jsr DrawTextBuffered
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
    ; Static "PAUSED" text -- in the HUD strip (row 1, cols 8-13, the gap
    ; between the player name and "VS"), not center-screen over the
    ; fight stage where it used to block the view of the action.
    SET_PTR text_ptr_lo, paused_text
    lda #8
    sta text_x_pos
    lda #1
    sta text_y_pos
    jsr DrawTextBuffered
    rts
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

    ; Attribute table — 64 bytes streamed straight from the converter's
    ; computed stage_attribute_table (src/stage_bg.inc), which assigns
    ; BG0 (sky)/BG1 (stone)/BG2 (foliage) per 16x16px quadrant based on
    ; the source art.
    ;
    ; HUD REDESIGN: the HUD (names, VS, timer, both health bars) now
    ; lives entirely in nametable rows 0-1, and those two rows are
    ; blanked out full-width below before InitHUD draws into them. Since
    ; no background art tile is ever visible in rows 0-1 anymore, it's
    ; safe to force the ENTIRE top quadrant of every attribute byte in
    ; row-group 0 to palette 3 (HUD) -- there's no background content
    ; left there to bleed into or clip. (Earlier versions of this fix
    ; tried to mask only the exact HUD element columns while background
    ; art was still showing through the gaps, which produced a blocky
    ; pink patchwork -- reserving the whole strip is both simpler and
    ; correct.) Rows 2-27 (attribute bytes 8-63, and the bottom quadrant
    ; of bytes 0-7) are untouched real background art.
    PPU_SETADDR $23C0
    ldx #0
@attr_loop:
    lda stage_attribute_table, x
    cpx #8
    bcs @attr_store           ; x >= 8: below the HUD strip, not touched
    ora #%00001111             ; force both top quadrants to palette 3
@attr_store:
    sta PPU_DATA
    inx
    cpx #64
    bcc @attr_loop

    ; Blank nametable rows 0-1 full-width (64 tiles) so no background
    ; art shows through the HUD strip -- InitHUD draws names/bars/timer
    ; into this space right after LoadFightStage returns.
    PPU_SETADDR $2000
    lda #0
    ldx #0
@blank_hud_loop:
    sta PPU_DATA
    inx
    cpx #64
    bcc @blank_hud_loop

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