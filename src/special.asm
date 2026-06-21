; THE LAST KUMITE — Special Move System
; Perfect Guard Counter: ↓ + B + A
; ============================================================================

.segment "CODE"

; =============================================================================
; INIT SPECIAL SYSTEM
; =============================================================================
.export InitSpecial
InitSpecial:
    lda #0
    sta special_effect_t
    sta special_cooldown
    sta stun_combo_active
    rts

; =============================================================================
; UPDATE SPECIAL EFFECTS — Visual updates for active special/stun
; =============================================================================
.export UpdateSpecialEffects
UpdateSpecialEffects:
    ; Decrement special effect timer
    lda special_effect_t
    beq @no_special_fx
    dec special_effect_t

    ; Flash screen border during special
    lda special_effect_t
    and #4
    beq @no_flash_border
    lda ppu_mask_cache
    ora #%00000001          ; Grayscale
    sta ppu_mask_cache
    jmp @no_special_fx
@no_flash_border:
    lda ppu_mask_cache
    and #%11111110          ; Restore color
    sta ppu_mask_cache
@no_special_fx:

    ; Check if stun combo window active
    lda en_stunned
    beq @no_stun_window
    lda #1
    sta stun_combo_active
    jmp @stun_fx_done
@no_stun_window:
    lda #0
    sta stun_combo_active
@stun_fx_done:
    rts

; =============================================================================
; GET STUN DAMAGE MULTIPLIER — Returns damage multiplier in A
; =============================================================================
.export GetStunMultiplier
GetStunMultiplier:
    lda stun_combo_active
    beq @normal_mult
    lda #2                  ; Double damage when stunned
    rts
@normal_mult:
    lda #1
    rts

; =============================================================================
; CHECK SPECIAL INPUT BUFFER — Detailed combo detection
; =============================================================================
.export CheckSpecialBuffer
CheckSpecialBuffer:
    ; Scan 8-frame buffer for:
    ; 1. DOWN direction pressed
    ; 2. B button pressed  
    ; 3. A button pressed
    ; All within 8 frames

    lda #0
    sta temp1               ; DOWN found
    sta temp2               ; B found
    sta temp3               ; A found

    ldx #0
@check_buf:
    ; Check directions
    lda input_buffer_dirs, x
    and #BTN_DOWN
    beq @no_down_buf
    inc temp1
@no_down_buf:

    ; Check buttons
    lda input_buffer_btns, x
    and #BTN_B
    beq @no_b_buf
    inc temp2
@no_b_buf:

    lda input_buffer_btns, x
    and #BTN_A
    beq @no_a_buf
    inc temp3
@no_a_buf:

    inx
    cpx #8
    bcc @check_buf

    ; Validate: need DOWN + (B or A) with at least 2 distinct inputs
    lda temp1               ; Need DOWN
    beq @special_fail
    lda temp2               ; Need B
    beq @special_fail
    lda temp3               ; Need A
    beq @special_fail

    ; Check cooldown
    lda special_cooldown
    bne @special_fail

    ; Valid special input!
    sec
    rts

@special_fail:
    clc
    rts

; =============================================================================
; EXECUTE SPECIAL MOVE — Michael's Perfect Guard Counter
; =============================================================================
.export ExecuteSpecial
ExecuteSpecial:
    ; Set cooldown
    lda #SPECIAL_COOLDOWN
    sta special_cooldown

    ; Change player state
    lda #PLR_SPECIAL
    sta plr_state
    lda #0
    sta plr_frame
    lda #30                 ; 0.5 second animation
    sta plr_atk_timer
    lda #ATK_SPECIAL
    sta plr_atk_type
    lda #0
    sta plr_atk_hit

    ; Visual effect
    lda #60
    sta special_effect_t

    ; SFX
    jsr PlaySFXSpecial
    rts

; =============================================================================
; FORCE STUN ENEMY — Direct stun for special move connect
; =============================================================================
.export ForceStunEnemy
ForceStunEnemy:
    lda #1
    sta en_stunned
    lda #STUN_DURATION
    sta en_stun_timer
    lda #AI_STUNNED
    sta en_ai_state
    lda #0
    sta en_vel_x
    sta en_atk_active
    rts

; =============================================================================
; INPUT BUFFER SYSTEM — Detailed recording and validation
; =============================================================================

; Record a single input frame
.export RecordInput
RecordInput:
    ldx combo_buffer_idx
    lda pad1_held
    sta input_buffer_btns, x
    lda pad1_held
    and #$0F                ; Direction nibble
    sta input_buffer_dirs, x
    inx
    txa
    and #$07                ; Wrap at 8
    sta combo_buffer_idx
    rts

; Clear the input buffer
.export ClearInputBuffer
ClearInputBuffer:
    lda #0
    ldx #0
@clear_buf:
    sta input_buffer_btns, x
    sta input_buffer_dirs, x
    inx
    cpx #8
    bcc @clear_buf
    sta combo_buffer_idx
    sta combo_timer
    rts

; Validate special move timing window
.export ValidateSpecialWindow
ValidateSpecialWindow:
    ; Player must be in neutral, walking, blocking, or crouching state
    lda plr_state
    cmp #PLR_IDLE
    beq @valid_state
    cmp #PLR_WALK
    beq @valid_state
    cmp #PLR_BLOCK
    beq @valid_state
    cmp #PLR_CROUCH
    beq @valid_state
    clc                     ; Invalid state
    rts
@valid_state:
    sec
    rts
