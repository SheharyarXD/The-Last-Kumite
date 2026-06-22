; THE LAST KUMITE — Enemy AI: Lightning
; Fast, aggressive, rush-based combat AI with anti-air and dash mechanics
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; INIT ENEMY — Set initial values for Lightning
; =============================================================================
.export InitEnemy
InitEnemy:
    lda #ENEMY_START_X
    sta en_x
    lda #GROUND_Y
    sta en_y
    lda #DIR_LEFT           ; Face player (player starts left)
    sta en_dir
    lda #80
    sta en_hp
    sta en_hp_disp
    lda #AI_IDLE
    sta en_ai_state
    lda #0
    sta en_vel_x
    sta en_vel_y
    sta en_grounded
    sta en_block
    sta en_hitstun
    sta en_atk_active
    sta en_atk_type
    sta en_atk_timer
    sta en_atk_hit
    sta en_stunned
    sta en_stun_timer
    sta en_cooldown
    sta en_aggro
    sta en_dash_timer
    sta en_react_timer
    sta en_subx
    sta en_suby
    lda #$14                ; Enemy palette 1 base
    sta en_pal

    ; Set initial AI decision timer
    lda #20
    sta en_ai_timer
    rts

; =============================================================================
; UPDATE ENEMY — Main enemy update per frame
; =============================================================================
.export UpdateEnemy
UpdateEnemy:
    ; --- Handle stun (from special move) ---
    lda en_stunned
    beq @no_stun
    lda #AI_STUNNED
    sta en_ai_state
    dec en_stun_timer
    bne @apply_enemy_physics
    lda #0
    sta en_stunned
    sta en_state
    lda #AI_IDLE
    sta en_ai_state
    lda #10
    sta en_ai_timer
    jmp @no_stun
@no_stun:

    ; --- Handle hitstun ---
    lda en_hitstun
    beq @no_hitstun
    dec en_hitstun
    bne @apply_enemy_physics
    ; Hitstun ended
    lda #EN_STATE_IDLE
    sta en_state
    lda #AI_IDLE
    sta en_ai_state
    lda #0
    sta en_vel_x
@no_hitstun:

    ; --- Handle attack timer ---
    lda en_atk_timer
    beq @no_atk
    dec en_atk_timer
    bne @check_en_atk_active
    ; Attack ended
    lda #0
    sta en_atk_active
    sta en_atk_type
    lda #AI_IDLE
    sta en_ai_state
    lda #EN_STATE_IDLE
    sta en_state
    jmp @no_atk
@check_en_atk_active:
    lda en_atk_timer
    cmp #5
    bcs @no_atk_active_set
    lda #1
    sta en_atk_active
    jmp @run_ai
@no_atk_active_set:
    lda #0
    sta en_atk_active
    jmp @run_ai
@no_atk:

    ; --- Handle cooldown ---
    lda en_cooldown
    beq @run_ai
    dec en_cooldown
    jmp @apply_enemy_physics

    ; --- Run AI decision ---
@run_ai:
    jsr RunLightningAI

    ; --- Apply physics ---
@apply_enemy_physics:
    jsr ApplyEnemyPhysics

    ; --- Update animation ---
    jsr UpdateEnemyAnim

    ; --- Build hurtbox ---
    jsr BuildEnemyHurtbox

    ; --- Build hitbox if attacking ---
    lda en_atk_active
    beq @enemy_done
    jsr BuildEnemyHitbox

@enemy_done:
    rts

; =============================================================================
; RUN LIGHTNING AI — Decision-making system
; =============================================================================
RunLightningAI:
    ; Decrement AI timer
    dec en_ai_timer
    bne @ai_skip_decision

    ; --- Make new decision ---
    jsr LightningDecision

    ; Set new timer (randomized)
    RANDOM_A
    and #7                  ; 0-7
    clc
    adc #AI_DECISION_MIN    ; 8-15
    sta en_ai_timer

@ai_skip_decision:
    ; Execute current AI state
    ; NOTE: table holds full 16-bit addresses (.addr), so index = state * 2
    lda en_ai_state
    asl
    tax
    lda ai_handler_table, x
    sta temp1
    lda ai_handler_table+1, x
    sta temp2
    jmp (temp1)

ai_handler_table:
    .addr AIHIdle
    .addr AIHApproach
    .addr AIHAttack
    .addr AIHRetreat
    .addr AIHAntiAir
    .addr AIHBlock
    .addr AIHStunned
    .addr AIHDash
    .addr AIHKO

; =============================================================================
; LIGHTNING DECISION — Choose next AI behavior
; =============================================================================
LightningDecision:
    ; If KO'd, do nothing
    lda en_state
    cmp #EN_STATE_KO
    bne @not_ko
    jmp @decision_done
@not_ko:

    ; Check aggro mode (HP < 30% = 24)
    lda en_hp
    cmp #AI_AGGRO_HP
    bcs @check_normal
    lda #1
    sta en_aggro
@check_normal:

    ; Priority 1: Player just jumped → anti-air
    lda plr_state
    cmp #PLR_JUMP
    bne @check_distance
    lda plr_vel_y
    bmi @check_distance     ; Only if rising (not falling)
    RANDOM_A
    cmp #153                ; 60% chance (153/256)
    bcc @do_antiair

@check_distance:
    ; Calculate distance to player
    lda en_x
    sec
    sbc plr_x
    bpl @dist_positive
    eor #$FF
    clc
    adc #1
@dist_positive:
    sta temp1               ; |en_x - plr_x|

    ; Priority 2: Far away → approach
    lda temp1
    cmp #AI_APPROACH_DIST
    bcc @check_close
    jmp @do_approach

@check_close:
    ; Priority 3: Close range → attack or block
    lda temp1
    cmp #AI_ATTACK_DIST
    bcs @do_retreat

    ; Very close: attack most of the time
    RANDOM_A
    cmp #64                 ; 25% chance to block
    bcc @do_block
    jmp @do_attack

@do_retreat:
    ; Medium distance: retreat to reset
    RANDOM_A
    cmp #128                ; 50% retreat
    bcc @do_retreat_actual
    jmp @do_approach
@do_retreat_actual:
    lda #AI_RETREAT
    sta en_ai_state
    rts

@do_antiair:
    lda #AI_ANTIAIR
    sta en_ai_state
    lda #15
    sta en_react_timer
    rts

@do_approach:
    lda #AI_APPROACH
    sta en_ai_state
    rts

@do_attack:
    lda #AI_ATTACK
    sta en_ai_state
    rts

@do_block:
    lda #AI_BLOCK
    sta en_ai_state
    lda #20                 ; Block for 20 frames
    sta en_react_timer
    rts

@decision_done:
    rts

; =============================================================================
; AI STATE HANDLERS
; =============================================================================

; ---- AI_IDLE ----
AIHIdle:
    lda #EN_STATE_IDLE
    sta en_state
    lda #0
    sta en_vel_x
    rts

; ---- AI_APPROACH ----
AIHApproach:
    lda #EN_STATE_WALK
    sta en_state

    ; Move toward player
    lda en_x
    cmp plr_x
    beq @approach_done
    bcc @approach_right

    ; Player is to the left
    lda en_dir
    cmp #DIR_LEFT
    beq @al_ok
    lda #DIR_LEFT
    sta en_dir
@al_ok:
    lda en_aggro
    beq @approach_normal_l
    lda #<-AI_DASH_SPEED
    sta en_vel_x
    jmp @approach_done
@approach_normal_l:
    lda #<-WALK_SPEED
    sta en_vel_x
    jmp @approach_done

@approach_right:
    lda en_dir
    cmp #DIR_RIGHT
    beq @ar_ok
    lda #DIR_RIGHT
    sta en_dir
@ar_ok:
    lda en_aggro
    beq @approach_normal_r
    lda #AI_DASH_SPEED
    sta en_vel_x
    jmp @approach_done
@approach_normal_r:
    lda #WALK_SPEED
    sta en_vel_x
@approach_done:
    rts

; ---- AI_ATTACK ----
AIHAttack:
    ; Only attack if not already attacking
    lda en_atk_timer
    bne @atk_done

    ; Choose attack type
    RANDOM_A
    cmp #85                 ; 33% kick
    bcc @do_kick
    cmp #170                ; 33% punch
    bcc @do_punch
    ; 33% dash attack
    jmp @do_dash_atk

@do_punch:
    lda #AI_ATTACK
    sta en_ai_state
    lda #EN_STATE_PUNCH
    sta en_state
    lda #ATK_PUNCH
    sta en_atk_type
    lda #12                 ; 12 frame punch
    sta en_atk_timer
    lda #DMG_PUNCH
    sta plr_dmg_accum       ; Damage for when player is hit
    lda #0
    sta en_atk_hit
    jsr PlaySFXPunch
    rts

@do_kick:
    lda #AI_ATTACK
    sta en_ai_state
    lda #EN_STATE_KICK
    sta en_state
    lda #ATK_KICK
    sta en_atk_type
    lda #16                 ; 16 frame kick
    sta en_atk_timer
    lda #DMG_KICK
    sta plr_dmg_accum
    lda #0
    sta en_atk_hit
    jsr PlaySFXKick
    rts

@do_dash_atk:
    lda #AI_DASH
    sta en_ai_state
    lda #EN_STATE_DASH
    sta en_state
    lda #ATK_DASH
    sta en_atk_type
    lda #20
    sta en_atk_timer
    lda #DMG_DASH
    sta plr_dmg_accum
    lda #AI_DASH_SPEED
    sta en_vel_x            ; Dash forward
    lda #0
    sta en_atk_hit
    rts

@atk_done:
    rts

; ---- AI_RETREAT ----
AIHRetreat:
    lda #EN_STATE_WALK
    sta en_state
    ; Move away from player
    lda en_x
    cmp plr_x
    bcc @retreat_left
    ; Retreat right
    lda #WALK_SPEED
    sta en_vel_x
    rts
@retreat_left:
    lda #<-WALK_SPEED
    sta en_vel_x
    rts

; ---- AI_ANTIAIR ----
AIHAntiAir:
    dec en_react_timer
    bne @aa_wait

    ; Execute anti-air attack
    lda #EN_STATE_KICK
    sta en_state
    lda #ATK_JUMP
    sta en_atk_type
    lda #18
    sta en_atk_timer
    lda #DMG_JUMP
    sta plr_dmg_accum
    lda #0
    sta en_atk_hit
    jsr PlaySFXKick
    rts
@aa_wait:
    ; Track player in air
    lda #EN_STATE_BLOCK     ; Prepare stance
    sta en_state
    rts

; ---- AI_BLOCK ----
AIHBlock:
    dec en_react_timer
    bne @block_continue
    ; Block done
    lda #AI_IDLE
    sta en_ai_state
    lda #0
    sta en_block
    rts
@block_continue:
    lda #1
    sta en_block
    lda #EN_STATE_BLOCK
    sta en_state
    lda #0
    sta en_vel_x
    rts

; ---- AI_STUNNED ----
AIHStunned:
    lda #EN_STATE_HIT
    sta en_state
    lda #0
    sta en_vel_x
    sta en_atk_active
    rts

; ---- AI_DASH ----
AIHDash:
    ; Continue dashing forward
    lda en_atk_timer
    bne @dash_continue
    ; Dash attack ended
    lda #AI_IDLE
    sta en_ai_state
    lda #0
    sta en_vel_x
    rts
@dash_continue:
    lda en_dir
    bne @dash_left
    lda #AI_DASH_SPEED
    sta en_vel_x
    rts
@dash_left:
    lda #<-AI_DASH_SPEED
    sta en_vel_x
    rts

; ---- AI_KO ----
AIHKO:
    lda #EN_STATE_KO
    sta en_state
    lda #0
    sta en_vel_x
    rts

; =============================================================================
; APPLY ENEMY PHYSICS
; =============================================================================
ApplyEnemyPhysics:
    ; Apply X velocity
    lda en_vel_x
    beq @en_no_x
    bpl @en_x_pos

    ; Moving left
    lda en_x
    clc
    adc en_vel_x
    cmp #SCREEN_LEFT
    bcs @en_x_store
    lda #SCREEN_LEFT
    jmp @en_x_store

@en_x_pos:
    lda en_x
    clc
    adc en_vel_x
    cmp #SCREEN_RIGHT
    bcc @en_x_store
    lda #SCREEN_RIGHT
@en_x_store:
    sta en_x
@en_no_x:

    ; Apply gravity
    lda en_grounded
    bne @en_on_ground
    lda en_vel_y
    clc
    adc #GRAVITY
    sta en_vel_y
    lda en_y
    clc
    adc en_vel_y
    cmp #GROUND_Y
    bcc @en_y_store
    lda #GROUND_Y
    sta en_y
    lda #0
    sta en_vel_y
    lda #1
    sta en_grounded
    jmp @en_phys_done
@en_y_store:
    sta en_y
    jmp @en_phys_done

@en_on_ground:
    lda en_state
    cmp #EN_STATE_WALK
    beq @en_phys_done
    cmp #EN_STATE_DASH
    beq @en_phys_done
    lda #0
    sta en_vel_x
@en_phys_done:
    rts

; =============================================================================
; UPDATE ENEMY ANIMATION
; =============================================================================
UpdateEnemyAnim:
    dec en_frametimer
    bne @en_anim_done
    lda #8
    sta en_frametimer

    ; Advance frame based on state
    lda en_state
    cmp #EN_STATE_IDLE
    beq @en_anim_idle
    cmp #EN_STATE_WALK
    beq @en_anim_walk
    cmp #EN_STATE_PUNCH
    beq @en_anim_punch
    cmp #EN_STATE_KICK
    beq @en_anim_kick
    jmp @en_anim_done

@en_anim_idle:
    lda en_frame
    eor #1
    sta en_frame
    rts

@en_anim_walk:
    lda en_frame
    clc
    adc #1
    and #3
    sta en_frame
    rts

@en_anim_punch:
    lda en_frame
    clc
    adc #1
    cmp #2
    bcc @en_p_store
    lda #0
@en_p_store:
    sta en_frame
    rts

@en_anim_kick:
    lda en_frame
    clc
    adc #1
    cmp #3
    bcc @en_k_store
    lda #0
@en_k_store:
    sta en_frame
    rts

@en_anim_done:
    rts

; =============================================================================
; BUILD ENEMY HURTBOX
; =============================================================================
BuildEnemyHurtbox:
    lda en_x
    clc
    adc #2
    sta en_body_x1
    lda en_x
    clc
    adc #14
    sta en_body_x2
    lda en_y
    clc
    adc #2
    sta en_body_y1
    lda en_y
    clc
    adc #14
    sta en_body_y2
    rts

; =============================================================================
; BUILD ENEMY HITBOX
; =============================================================================
BuildEnemyHitbox:
    lda #0
    sta en_hitbox_x1
    sta en_hitbox_x2
    sta en_hitbox_y1
    sta en_hitbox_y2

    ; Dispatch on attack type via jump table (ATK_* values 0-5, see constants.asm)
    lda en_atk_type
    asl
    tax
    lda en_hitbox_jump_table, x
    sta temp1
    lda en_hitbox_jump_table+1, x
    sta temp2
    jmp (temp1)

en_hitbox_jump_table:
    .addr @en_no_box        ; ATK_NONE    (0)
    .addr @en_punch_box     ; ATK_PUNCH   (1)
    .addr @en_kick_box      ; ATK_KICK    (2)
    .addr @en_antiair_box   ; ATK_JUMP    (3)
    .addr @en_no_box        ; ATK_SPECIAL (4) — Lightning has no special
    .addr @en_dash_box      ; ATK_DASH    (5)

@en_no_box:
    rts

@en_punch_box:
    lda en_dir
    bne @enpl
    lda en_x
    clc
    adc #12
    sta en_hitbox_x1
    lda en_x
    clc
    adc #20
    jmp @enpy
@enpl:
    lda en_x
    sec
    sbc #6
    sta en_hitbox_x1
    lda en_x
@enpy:
    sta en_hitbox_x2
    lda en_y
    clc
    adc #4
    sta en_hitbox_y1
    lda en_y
    clc
    adc #12
    sta en_hitbox_y2
    rts

@en_kick_box:
    lda en_dir
    bne @enkl
    lda en_x
    clc
    adc #12
    sta en_hitbox_x1
    lda en_x
    clc
    adc #22
    jmp @enky
@enkl:
    lda en_x
    sec
    sbc #8
    sta en_hitbox_x1
    lda en_x
    sec
    sbc #2
@enky:
    sta en_hitbox_x2
    lda en_y
    clc
    adc #6
    sta en_hitbox_y1
    lda en_y
    clc
    adc #14
    sta en_hitbox_y2
    rts

@en_dash_box:
    lda en_dir
    bne @endal
    lda en_x
    clc
    adc #14
    sta en_hitbox_x1
    lda en_x
    clc
    adc #24
    jmp @enday
@endal:
    lda en_x
    sec
    sbc #10
    sta en_hitbox_x1
    lda en_x
@enday:
    sta en_hitbox_x2
    lda en_y
    clc
    adc #4
    sta en_hitbox_y1
    lda en_y
    clc
    adc #12
    sta en_hitbox_y2
    rts

@en_antiair_box:
    ; Tall hitbox for anti-air
    lda en_x
    sec
    sbc #6
    sta en_hitbox_x1
    lda en_x
    clc
    adc #14
    sta en_hitbox_x2
    lda en_y
    sec
    sbc #8
    sta en_hitbox_y1
    lda en_y
    clc
    adc #8
    sta en_hitbox_y2
    rts

; =============================================================================
; RENDER ENEMY — Draw Lightning to OAM
; =============================================================================
.export RenderEnemy
RenderEnemy:
    lda en_state
    cmp #EN_STATE_KO
    bne @en_render_normal
@en_render_normal:
    ; Calculate tile from state + frame
    lda en_state
    asl
    asl
    clc
    adc en_frame
    tax
    lda enemy_spritemap, x
    sta temp3

    ldx en_x
    ldy en_y

    ; Build attribute byte: bit 6 = horizontal flip (face left), bits 0-1 =
    ; palette (1 = Lightning's blue palette, see init.asm sprite palette 1)
    lda #%00000001
    sta temp4
    lda en_dir
    cmp #DIR_LEFT
    bne @en_no_hflip
    lda temp4
    ora #%01000000
    sta temp4
@en_no_hflip:

    ; Hit flash (palette 3 = white flash)
    lda hit_flash_timer
    and #2
    beq @en_no_flash
    lda temp4
    ora #%00000011
    sta temp4
@en_no_flash:
    lda temp3
    jsr DrawMetasprite

    ; Draw stun effect if stunned
    lda en_stunned
    beq @en_no_stun_fx
    ldx en_x
    ldy en_y
    jsr DrawStunEffect
@en_no_stun_fx:
    rts

; =============================================================================
; ENEMY SPRITE MAP — auto-generated, see tools/chr_convert.py
; Maps (state x 4 + frame) -> BASE tile index (top-left of a 2x2 16x16
; metasprite), LOCAL to sprite pattern table 1.
; =============================================================================
.include "sprite_tiles_enemy.inc"
; (EN_STATE_* constants live in constants.asm for cross-module visibility)
