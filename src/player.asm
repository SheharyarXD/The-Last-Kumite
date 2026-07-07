; THE LAST KUMITE — Player Character: Michael Rivers
; Physics, state management, animation, rendering
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; INIT PLAYER — Set initial values for Michael Rivers
; =============================================================================
.export InitPlayer
InitPlayer:
    lda #PLAYER_START_X
    sta plr_x
    lda #GROUND_Y
    sta plr_y
    lda #DIR_RIGHT
    sta plr_dir
    lda #100
    sta plr_hp
    sta plr_hp_disp
    lda #PLR_IDLE
    sta plr_state
    lda #0
    sta plr_vel_x
    sta plr_vel_y
    sta plr_grounded
    sta plr_block
    sta plr_hitstun
    sta plr_atk_active
    sta plr_atk_type
    sta plr_atk_timer
    sta plr_atk_hit
    sta plr_stunned
    sta plr_stun_timer
    sta plr_cooldown
    sta plr_subx
    sta plr_suby
    lda #$10                ; Player palette 0 base
    sta plr_pal
    rts

; =============================================================================
; UPDATE PLAYER — Main player update per frame
; =============================================================================
.export UpdatePlayer
UpdatePlayer:
    ; --- Handle stun ---
    lda plr_stunned
    beq @no_stun
    dec plr_stun_timer
    bne @skip_update
    lda #0
    sta plr_stunned
    lda #PLR_IDLE
    sta plr_state
@no_stun:

    ; --- Handle hitstun ---
    lda plr_hitstun
    beq @no_hitstun
    dec plr_hitstun
    beq @hitstun_ended       ; Hitstun reached zero this frame
    jmp @update_physics      ; Still in hitstun: skip straight to physics
@hitstun_ended:
    ; Hitstun ended
    lda #PLR_IDLE
    sta plr_state
    lda #0
    sta plr_vel_x
@no_hitstun:

    ; --- Handle attack timer ---
    lda plr_atk_timer
    beq @no_atk_timer
    dec plr_atk_timer
    bne @check_atk_active
    ; Attack ended
    lda #0
    sta plr_atk_active
    sta plr_atk_type
    lda plr_state
    cmp #PLR_KO
    beq @no_atk_timer       ; Don't change state if KO
    lda #PLR_IDLE
    sta plr_state
    jmp @no_atk_timer
@check_atk_active:
    ; Activate hitbox mid-attack
    lda plr_atk_timer
    cmp #6                  ; Active for frames 6-0 of attack
    bcs @no_atk_active_set
    lda #1
    sta plr_atk_active
    jmp @update_physics
@no_atk_active_set:
    lda #0
    sta plr_atk_active
    jmp @update_physics
@no_atk_timer:

    ; --- Handle cooldown ---
    lda plr_cooldown
    beq @update_physics
    dec plr_cooldown

    ; --- Apply physics ---
@update_physics:
    jsr ApplyPlayerPhysics

    ; --- Update animation ---
    jsr UpdatePlayerAnim

    ; --- Build hurtbox ---
    jsr BuildPlayerHurtbox

    ; --- Build hitbox (if attacking) ---
    lda plr_atk_active
    beq @skip_update
    jsr BuildPlayerHitbox

@skip_update:
    rts

; =============================================================================
; APPLY PLAYER PHYSICS — Movement, gravity, collision
; =============================================================================
ApplyPlayerPhysics:
    ; --- Apply X velocity ---
    lda plr_vel_x
    beq @no_x_move
    bpl @x_positive

    ; Moving left (negative velocity)
    lda plr_x
    clc
    adc plr_vel_x           ; Add negative = subtract
    cmp #SCREEN_LEFT
    bcs @x_store
    lda #SCREEN_LEFT        ; Clamp to left edge
    jmp @x_store

@x_positive:
    ; Moving right
    lda plr_x
    clc
    adc plr_vel_x
    cmp #SCREEN_RIGHT
    bcc @x_store
    lda #SCREEN_RIGHT       ; Clamp to right edge
@x_store:
    sta plr_x

@no_x_move:
    ; --- Apply gravity if airborne ---
    lda plr_grounded
    bne @on_ground

    ; Apply Y velocity (gravity)
    lda plr_vel_y
    clc
    adc #GRAVITY
    sta plr_vel_y

    ; Apply velocity to position
    lda plr_y
    clc
    adc plr_vel_y
    cmp #GROUND_Y
    bcc @y_store
    ; Landed on ground
    lda #GROUND_Y
    sta plr_y
    lda #0
    sta plr_vel_y
    lda #1
    sta plr_grounded
    ; If was jumping, return to idle
    lda plr_state
    cmp #PLR_JUMP
    bne @landed_done
    lda #PLR_IDLE
    sta plr_state
    jsr PlaySFXLand
@landed_done:
    jmp @on_ground
@y_store:
    sta plr_y
    jmp @physics_done

@on_ground:
    ; --- Ground friction ---
    lda plr_state
    cmp #PLR_WALK
    beq @physics_done       ; Walking, keep velocity
    lda #0
    sta plr_vel_x           ; Stop when not walking

@physics_done:
    ; --- Facing direction (face enemy) ---
    lda plr_x
    cmp en_x
    bcc @face_right
    lda #DIR_LEFT
    sta plr_dir
    jmp @facing_done
@face_right:
    lda #DIR_RIGHT
    sta plr_dir
@facing_done:
    rts

; =============================================================================
; UPDATE PLAYER ANIMATION — Frame cycling based on state
; =============================================================================
UpdatePlayerAnim:
    ; Decrement frame timer
    lda plr_frametimer
    beq @cycle_frame
    dec plr_frametimer
    rts
@cycle_frame:
    ; Reset frame timer
    lda #8                  ; 8 frames per anim frame
    sta plr_frametimer

    ; Advance animation frame based on state
    ; NOTE: table holds full 16-bit addresses (.addr), so index = state * 2
    lda plr_state
    asl
    tax
    lda anim_table, x
    sta temp1
    lda anim_table+1, x
    sta temp2
    jmp (temp1)

anim_table:
    .addr AnimIdle      ; PLR_IDLE
    .addr AnimWalk      ; PLR_WALK
    .addr AnimCrouch    ; PLR_CROUCH
    .addr AnimJump      ; PLR_JUMP
    .addr AnimPunch     ; PLR_PUNCH
    .addr AnimKick      ; PLR_KICK
    .addr AnimBlock     ; PLR_BLOCK
    .addr AnimHit       ; PLR_HIT
    .addr AnimKO        ; PLR_KO
    .addr AnimSpecial   ; PLR_SPECIAL
    .addr AnimJumpKick  ; PLR_JUMPKICK
    .addr AnimCPunch    ; PLR_CROUCH_PUNCH
    .addr AnimCKick     ; PLR_CROUCH_KICK

; =============================================================================
; ANIMATION HANDLERS
; =============================================================================

AnimIdle:
    lda plr_frame
    eor #1                ; Toggle between 0 and 1
    sta plr_frame
    rts

AnimWalk:
    lda plr_frame
    clc
    adc #1
    and #3                ; 4 frame walk cycle
    sta plr_frame
    rts

AnimCrouch:
    lda #0
    sta plr_frame
    rts

AnimJump:
    ; Jump frame based on Y velocity
    lda plr_vel_y
    bpl @jump_down
    lda #0                ; Rising frame
    sta plr_frame
    rts
@jump_down:
    lda #1                ; Falling frame
    sta plr_frame
    rts

AnimPunch:
    lda plr_frame
    clc
    adc #1
    cmp #2
    bcc @punch_store
    lda #0
@punch_store:
    sta plr_frame
    rts

AnimKick:
    lda plr_frame
    clc
    adc #1
    cmp #3
    bcc @kick_store
    lda #0
@kick_store:
    sta plr_frame
    rts

AnimBlock:
    lda #0
    sta plr_frame
    rts

AnimHit:
    lda #0
    sta plr_frame
    rts

AnimKO:
    lda #0
    sta plr_frame
    rts

AnimSpecial:
    lda plr_frame
    clc
    adc #1
    cmp #4
    bcc @special_store
    lda #0
@special_store:
    sta plr_frame
    rts

AnimJumpKick:
    jmp AnimJump

AnimCPunch:
    jmp AnimPunch

AnimCKick:
    jmp AnimKick

; =============================================================================
; BUILD PLAYER HURTBOX — Character body collision box
; =============================================================================
BuildPlayerHurtbox:
    lda plr_x
    clc
    adc #2
    sta plr_body_x1
    lda plr_x
    clc
    adc #14
    sta plr_body_x2

    lda plr_y
    clc
    adc #2
    sta plr_body_y1
    lda plr_y
    clc
    adc #14
    sta plr_body_y2

    ; Adjust for crouch
    lda plr_state
    cmp #PLR_CROUCH
    bne @hurt_done
    lda plr_body_y2
    sec
    sbc #4
    sta plr_body_y2
@hurt_done:
    rts

; =============================================================================
; BUILD PLAYER HITBOX — Attack hit area based on state
; =============================================================================
BuildPlayerHitbox:
    ; Default: no hitbox
    lda #0
    sta plr_hitbox_x1
    sta plr_hitbox_x2
    sta plr_hitbox_y1
    sta plr_hitbox_y2

    ; Dispatch on state via jump table (state values 0-12, see constants.asm)
    lda plr_state
    asl
    tax
    lda hitbox_jump_table, x
    sta temp1
    lda hitbox_jump_table+1, x
    sta temp2
    jmp (temp1)

hitbox_jump_table:
    .addr @no_hitbox        ; PLR_IDLE         (0)
    .addr @no_hitbox        ; PLR_WALK         (1)
    .addr @no_hitbox        ; PLR_CROUCH       (2)
    .addr @jump_hitbox      ; PLR_JUMP         (3)
    .addr @punch_hitbox     ; PLR_PUNCH        (4)
    .addr @kick_hitbox      ; PLR_KICK         (5)
    .addr @no_hitbox        ; PLR_BLOCK        (6)
    .addr @no_hitbox        ; PLR_HIT          (7)
    .addr @no_hitbox        ; PLR_KO           (8)
    .addr @special_hitbox   ; PLR_SPECIAL      (9)
    .addr @jump_hitbox      ; PLR_JUMPKICK     (10)
    .addr @cpunch_hitbox    ; PLR_CROUCH_PUNCH (11)
    .addr @ckick_hitbox     ; PLR_CROUCH_KICK  (12)

@no_hitbox:
    rts

@punch_hitbox:
    lda plr_dir
    bne @punch_left
    ; Punch right
    lda plr_x
    clc
    adc #14
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #22
    sta plr_hitbox_x2
    jmp @punch_y
@punch_left:
    lda plr_x
    sec
    sbc #8
    sta plr_hitbox_x1
    lda plr_x
    sta plr_hitbox_x2
@punch_y:
    lda plr_y
    clc
    adc #4
    sta plr_hitbox_y1
    lda plr_y
    clc
    adc #12
    sta plr_hitbox_y2
    rts

@kick_hitbox:
    lda plr_dir
    bne @kick_left
    lda plr_x
    clc
    adc #12
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #24
    sta plr_hitbox_x2
    jmp @kick_y
@kick_left:
    lda plr_x
    sec
    sbc #10
    sta plr_hitbox_x1
    lda plr_x
    sec
    sbc #2
    sta plr_hitbox_x2
@kick_y:
    lda plr_y
    clc
    adc #6
    sta plr_hitbox_y1
    lda plr_y
    clc
    adc #14
    sta plr_hitbox_y2
    rts

@jump_hitbox:
    lda plr_dir
    bne @jump_left
    lda plr_x
    clc
    adc #10
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #20
    sta plr_hitbox_x2
    jmp @jump_y
@jump_left:
    lda plr_x
    sec
    sbc #6
    sta plr_hitbox_x1
    lda plr_x
    sec
    sbc #2
    sta plr_hitbox_x2
@jump_y:
    lda plr_y
    clc
    adc #4
    sta plr_hitbox_y1
    lda plr_y
    clc
    adc #14
    sta plr_hitbox_y2
    rts

@special_hitbox:
    ; Special move: close range stun hitbox
    lda plr_dir
    bne @spec_left
    lda plr_x
    clc
    adc #8
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #20
    sta plr_hitbox_x2
    jmp @spec_y
@spec_left:
    lda plr_x
    sec
    sbc #6
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #4
    sta plr_hitbox_x2
@spec_y:
    lda plr_y
    clc
    adc #2
    sta plr_hitbox_y1
    lda plr_y
    clc
    adc #14
    sta plr_hitbox_y2
    rts

@cpunch_hitbox:
    lda plr_dir
    bne @cpl
    lda plr_x
    clc
    adc #12
    sta plr_hitbox_x1
    lda plr_x
    clc
    adc #20
    jmp @cpy
@cpl:
    lda plr_x
    sec
    sbc #6
    sta plr_hitbox_x1
    lda plr_x
    sec
    sbc #2
@cpy:
    sta plr_hitbox_x2
    lda plr_y
    clc
    adc #8
    sta plr_hitbox_y1
    lda plr_y
    clc
    adc #14
    sta plr_hitbox_y2
    rts

@ckick_hitbox:
    jmp @kick_hitbox        ; Similar to standing kick

; =============================================================================
; RENDER PLAYER — Draw Michael Rivers sprite to OAM
; =============================================================================
.export RenderPlayer
RenderPlayer:
    ; Don't render if KO'd (flicker or lie down)
    lda plr_state
    cmp #PLR_KO
    bne @render_normal
    ; KO: draw lying down (offset sprite)
    jmp @render_normal

@render_normal:
    ; Calculate sprite tile from state + frame
    lda plr_state
    asl
    asl
    clc
    adc plr_frame
    tax
    lda player_spritemap, x
    sta temp3               ; Tile index

    ; Get position
    ldx plr_x
    ldy plr_y

    ; Build attribute byte: bit 6 = horizontal flip (face left), bits 0-1 = palette
    lda #0
    sta temp4
    lda plr_dir
    cmp #DIR_LEFT
    bne @no_hflip
    lda #%01000000
    sta temp4
@no_hflip:

    ; Apply hit flash (palette 3 = white flash)
    lda plr_hit_flash_timer
    and #2
    beq @no_flash
    lda temp4
    ora #%00000011           ; Force palette 3
    sta temp4
@no_flash:
    lda temp3
    jsr DrawMetasprite

    ; Draw stun effect if player stunned
    lda plr_stunned
    beq @no_stun_fx
    ldx plr_x
    ldy plr_y
    jsr DrawStunEffect
@no_stun_fx:
    rts

; =============================================================================
; PLAYER SPRITE MAP — auto-generated, see tools/chr_convert.py
; Maps (state x 4 + frame) -> BASE tile index (top-left of a 2x2 16x16
; metasprite), LOCAL to sprite pattern table 1. The other 3 quadrants are
; at base+1 (top-right), base+2 (bottom-left), base+3 (bottom-right).
; =============================================================================
.include "sprite_tiles_player.inc"