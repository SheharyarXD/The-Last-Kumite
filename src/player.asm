; THE LAST KUMITE — Player Character: Michael Rivers
; Physics, state management, animation, rendering
; ============================================================================

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
    bne @apply_knockback    ; Still in hitstun, apply knockback
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
    bne @y_store
    lda #PLR_IDLE
    sta plr_state
    jsr PlaySFXLand
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
    lda plr_state
    asl
    tax
    lda anim_table_lo, x
    sta temp1
    lda anim_table_hi, x
    sta temp2
    jmp (temp1)

anim_table_lo:
    .word AnimIdle      ; PLR_IDLE
    .word AnimWalk      ; PLR_WALK
    .word AnimCrouch    ; PLR_CROUCH
    .word AnimJump      ; PLR_JUMP
    .word AnimPunch     ; PLR_PUNCH
    .word AnimKick      ; PLR_KICK
    .word AnimBlock     ; PLR_BLOCK
    .word AnimHit       ; PLR_HIT
    .word AnimKO        ; PLR_KO
    .word AnimSpecial   ; PLR_SPECIAL
    .word AnimJumpKick  ; PLR_JUMPKICK
    .word AnimCPunch    ; PLR_CROUCH_PUNCH
    .word AnimCKick     ; PLR_CROUCH_KICK

anim_table_hi:
    .word 0

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

    lda plr_state
    cmp #PLR_PUNCH
    beq @punch_hitbox
    cmp #PLR_KICK
    beq @kick_hitbox
    cmp #PLR_JUMP
    beq @jump_hitbox
    cmp #PLR_JUMPKICK
    beq @jump_hitbox
    cmp #PLR_SPECIAL
    beq @special_hitbox
    cmp #PLR_CROUCH_PUNCH
    beq @cpunch_hitbox
    cmp #PLR_CROUCH_KICK
    beq @ckick_hitbox
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
    ; Calculate base sprite tile from state + frame
    lda plr_state
    asl
    asl
    clc
    adc plr_frame
    tax
    lda player_spritemap, x
    sta temp3               ; Base tile index

    ; Get position
    ldx plr_x
    ldy plr_y

    ; Apply hit flash
    lda hit_flash_timer
    and #2
    beq @no_flash
    ; White flash: use palette 3
    lda #$43                ; Tile with palette 3
    jmp @draw_sprite
@no_flash:
    lda temp3
@draw_sprite:
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
; PLAYER SPRITE MAP
; Maps (state × 4 + frame) → tile index in CHR
; =============================================================================
player_spritemap:
    ; PLR_IDLE (0): frames 0-1
    .byte $00, $04, $00, $00
    ; PLR_WALK (1): frames 0-3
    .byte $08, $0C, $10, $14
    ; PLR_CROUCH (2): frame 0
    .byte $18, $00, $00, $00
    ; PLR_JUMP (3): frames 0-1
    .byte $1C, $20, $00, $00
    ; PLR_PUNCH (4): frames 0-1
    .byte $24, $28, $00, $00
    ; PLR_KICK (5): frames 0-2
    .byte $2C, $30, $34, $00
    ; PLR_BLOCK (6): frame 0
    .byte $38, $00, $00, $00
    ; PLR_HIT (7): frame 0
    .byte $3C, $00, $00, $00
    ; PLR_KO (8): frame 0
    .byte $40, $00, $00, $00
    ; PLR_SPECIAL (9): frames 0-3
    .byte $44, $48, $4C, $50
    ; PLR_JUMPKICK (10)
    .byte $54, $58, $00, $00
    ; PLR_CROUCH_PUNCH (11)
    .byte $5C, $60, $00, $00
    ; PLR_CROUCH_KICK (12)
    .byte $64, $68, $00, $00
