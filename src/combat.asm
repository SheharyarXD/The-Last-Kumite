; THE LAST KUMITE — Combat System
; Hit detection, damage, knockback, blocking, combo counting
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; UPDATE COMBAT — Main combat update per frame
; Checks collisions, applies damage, handles knockback
; =============================================================================
.export UpdateCombat
UpdateCombat:
    ; Skip if either character is KO'd
    lda plr_state
    cmp #PLR_KO
    beq @combat_done
    lda en_state
    cmp #EN_STATE_KO
    beq @combat_done

    ; --- Check player hit on enemy ---
    jsr CheckPlayerHitEnemy

    ; --- Check enemy hit on player ---
    jsr CheckEnemyHitPlayer

    ; --- Update combo display timer ---
    lda combo_display_t
    beq @combat_done
    dec combo_display_t
    bne @combat_done
    lda #0
    sta combo_count

    ; --- Update hit flash timer ---
    lda hit_flash_timer
    beq @combat_done
    dec hit_flash_timer

@combat_done:
    rts

; =============================================================================
; CHECK PLAYER HIT ON ENEMY — Does player's attack connect?
; =============================================================================
CheckPlayerHitEnemy:
    ; Player must have active hitbox
    lda plr_atk_active
    bne @plr_active
    jmp @plr_miss
@plr_active:
    lda plr_atk_hit
    beq @plr_not_yet_hit    ; Already hit this attack
    jmp @plr_miss
@plr_not_yet_hit:

    ; Check if hitbox overlaps enemy hurtbox
    jsr CheckHitboxOverlap
    bcs @plr_overlap         ; Overlap confirmed
    jmp @plr_miss
@plr_overlap:

    ; HIT! Mark attack as connected
    lda #1
    sta plr_atk_hit

    ; Check if enemy is blocking
    lda en_block
    beq @plr_not_blocked
    jmp @en_blocked
@plr_not_blocked:

    ; --- Apply damage ---
    lda plr_atk_type
    cmp #ATK_SPECIAL
    bne @plr_normal_hit
    jmp @plr_special_hit
@plr_normal_hit:

    ; Normal damage
    lda plr_dmg_accum
    sta temp1
    ; Double damage if enemy stunned
    lda en_stunned
    beq @normal_dmg
    asl temp1               ; ×2 damage on stunned enemy
@normal_dmg:
    lda en_hp
    sec
    sbc temp1
    bcs @en_hp_ok
    lda #0
@en_hp_ok:
    sta en_hp

    ; Set hitstop
    lda plr_atk_type
    cmp #ATK_PUNCH
    beq @hs_punch
    cmp #ATK_KICK
    beq @hs_kick
    cmp #ATK_JUMP
    beq @hs_jump
    lda #HITSTOP_PUNCH
    jmp @hs_set
@hs_punch:
    lda #HITSTOP_PUNCH
    jmp @hs_set
@hs_kick:
    lda #HITSTOP_KICK
    jmp @hs_set
@hs_jump:
    lda #HITSTOP_JUMP
@hs_set:
    sta hit_freeze

    ; Set hit flash
    lda #6
    sta hit_flash_timer

    ; Knockback
    lda plr_atk_type
    cmp #ATK_PUNCH
    beq @kb_punch
    cmp #ATK_KICK
    beq @kb_kick
    cmp #ATK_JUMP
    beq @kb_jump
    lda #KNOCKBACK_PUNCH
    jmp @kb_set
@kb_punch:
    lda #KNOCKBACK_PUNCH
    jmp @kb_set
@kb_kick:
    lda #KNOCKBACK_KICK
    jmp @kb_set
@kb_jump:
    lda #KNOCKBACK_JUMP
@kb_set:
    sta knockback_val

    ; Apply knockback to enemy (opposite of player's facing)
    lda plr_dir
    bne @kb_en_left
    lda en_x
    clc
    adc knockback_val
    cmp #SCREEN_RIGHT
    bcc @kb_en_store
    lda #SCREEN_RIGHT
    jmp @kb_en_store
@kb_en_left:
    lda en_x
    sec
    sbc knockback_val
    cmp #SCREEN_LEFT
    bcs @kb_en_store
    lda #SCREEN_LEFT
@kb_en_store:
    sta en_x

    ; Set enemy hitstun
    lda plr_atk_type
    cmp #ATK_PUNCH
    beq @st_punch
    cmp #ATK_KICK
    beq @st_kick
    lda #HITSTUN_JUMP
    jmp @st_set
@st_punch:
    lda #HITSTUN_PUNCH
    jmp @st_set
@st_kick:
    lda #HITSTUN_KICK
@st_set:
    sta en_hitstun
    lda #EN_STATE_HIT
    sta en_state
    lda #AI_IDLE
    sta en_ai_state
    lda #0
    sta en_vel_x

    ; Combo counter
    inc combo_count
    lda #60
    sta combo_display_t

    ; Screen shake
    lda #8
    sta shake_timer

    ; Hit effect
    ldx en_x
    ldy en_y
    jsr DrawHitEffect

    ; SFX
    jsr PlaySFXHit

    ; Check win
    lda en_hp
    bne @plr_miss
    ; Enemy KO!
    lda #EN_STATE_KO
    sta en_state
    lda #0
    sta en_vel_x
    lda #PLR_IDLE
    sta plr_state
    jsr PlaySFXKODown
    rts

@plr_special_hit:
    ; Special move: stun enemy (no damage, but stun)
    lda #1
    sta en_stunned
    lda #STUN_DURATION      ; 90 frames stun
    sta en_stun_timer
    lda #AI_STUNNED
    sta en_ai_state
    lda #HITSTOP_SPECIAL
    sta hit_freeze
    lda #90
    sta special_effect_t
    lda #12
    sta hit_flash_timer
    jsr PlaySFXSpecialHit
    rts

@en_blocked:
    ; Enemy blocked the attack
    lda plr_atk_type
    cmp #ATK_JUMP
    beq @blk_jump
    lda plr_dmg_accum
    lsr                     ; Divide damage by 3
    lsr
    clc
    adc #1                  ; Minimum 1 damage on block
    sta temp1
    lda en_hp
    sec
    sbc temp1
    bcs @blk_hp_ok
    lda #0
@blk_hp_ok:
    sta en_hp
    lda #HITSTOP_BLOCKED
    sta hit_freeze
    ; Small knockback
    lda plr_dir
    bne @blk_left
    lda en_x
    clc
    adc #KNOCKBACK_BLOCKED
    sta en_x
    jmp @blk_shake
@blk_left:
    lda en_x
    sec
    sbc #KNOCKBACK_BLOCKED
    sta en_x
@blk_jump:
@blk_shake:
    lda #4
    sta shake_timer
    jsr PlaySFXBlock
    rts

@plr_miss:
    rts

; =============================================================================
; CHECK ENEMY HIT ON PLAYER — Does enemy's attack connect?
; =============================================================================
CheckEnemyHitPlayer:
    ; Enemy must have active hitbox
    lda en_atk_active
    bne @en_active
    jmp @en_miss
@en_active:
    lda en_atk_hit
    beq @en_not_yet_hit
    jmp @en_miss
@en_not_yet_hit:

    ; Check if hitbox overlaps player hurtbox
    jsr CheckEnemyHitboxOverlap
    bcs @en_overlap
    jmp @en_miss
@en_overlap:

    ; HIT!
    lda #1
    sta en_atk_hit

    ; Check if player is blocking
    lda plr_block
    beq @en_not_blocked
    jmp @plr_blocked
@en_not_blocked:

    ; --- Apply damage ---
    lda en_atk_type
    cmp #ATK_DASH
    beq @en_dash_dmg
    cmp #ATK_JUMP
    beq @en_jump_dmg
    cmp #ATK_KICK
    beq @en_kick_dmg
    ; Punch default
    lda #DMG_PUNCH
    jmp @en_dmg_set
@en_dash_dmg:
    lda #DMG_DASH
    jmp @en_dmg_set
@en_jump_dmg:
    lda #DMG_JUMP
    jmp @en_dmg_set
@en_kick_dmg:
    lda #DMG_KICK
@en_dmg_set:
    sta temp1

    lda plr_hp
    sec
    sbc temp1
    bcs @plr_hp_ok
    lda #0
@plr_hp_ok:
    sta plr_hp

    ; Hitstop
    lda en_atk_type
    cmp #ATK_DASH
    beq @en_hs_dash
    cmp #ATK_JUMP
    beq @en_hs_jump
    cmp #ATK_KICK
    beq @en_hs_kick
    lda #HITSTOP_PUNCH
    jmp @en_hs_set
@en_hs_dash:
    lda #HITSTOP_KICK
    jmp @en_hs_set
@en_hs_jump:
    lda #HITSTOP_JUMP
    jmp @en_hs_set
@en_hs_kick:
    lda #HITSTOP_KICK
@en_hs_set:
    sta hit_freeze

    ; Hit flash
    lda #6
    sta hit_flash_timer

    ; Knockback (opposite of enemy facing)
    lda en_atk_type
    cmp #ATK_DASH
    beq @en_kb_dash
    cmp #ATK_JUMP
    beq @en_kb_jump
    cmp #ATK_KICK
    beq @en_kb_kick
    lda #KNOCKBACK_PUNCH
    jmp @en_kb_set
@en_kb_dash:
    lda #KNOCKBACK_KICK
    jmp @en_kb_set
@en_kb_jump:
    lda #KNOCKBACK_JUMP
    jmp @en_kb_set
@en_kb_kick:
    lda #KNOCKBACK_KICK
@en_kb_set:
    sta knockback_val

    lda en_dir
    bne @kb_plr_left
    lda plr_x
    clc
    adc knockback_val
    cmp #SCREEN_RIGHT
    bcc @kb_plr_store
    lda #SCREEN_RIGHT
    jmp @kb_plr_store
@kb_plr_left:
    lda plr_x
    sec
    sbc knockback_val
    cmp #SCREEN_LEFT
    bcs @kb_plr_store
    lda #SCREEN_LEFT
@kb_plr_store:
    sta plr_x

    ; Hitstun
    lda en_atk_type
    cmp #ATK_DASH
    beq @en_st_dash
    cmp #ATK_JUMP
    beq @en_st_jump
    cmp #ATK_KICK
    beq @en_st_kick
    lda #HITSTUN_PUNCH
    jmp @en_st_set
@en_st_dash:
    lda #HITSTUN_KICK
    jmp @en_st_set
@en_st_jump:
    lda #HITSTUN_JUMP
    jmp @en_st_set
@en_st_kick:
    lda #HITSTUN_KICK
@en_st_set:
    sta plr_hitstun
    lda #PLR_HIT
    sta plr_state
    lda #0
    sta plr_vel_x
    sta plr_block

    ; Screen shake
    lda #10
    sta shake_timer

    ; Hit effect
    ldx plr_x
    ldy plr_y
    jsr DrawHitEffect

    ; SFX
    jsr PlaySFXHit

    ; Check lose
    lda plr_hp
    bne @en_miss
    ; Player KO!
    lda #PLR_KO
    sta plr_state
    lda #0
    sta plr_vel_x
    jsr PlaySFXKODown
    rts

@plr_blocked:
    ; Player blocked
    lda en_atk_type
    cmp #ATK_JUMP
    beq @plr_blk_jump
    lda #DMG_KICK
    lsr
    lsr
    clc
    adc #1
    sta temp1
    lda plr_hp
    sec
    sbc temp1
    bcs @plr_blk_hp
    lda #0
@plr_blk_hp:
    sta plr_hp
    lda #HITSTOP_BLOCKED
    sta hit_freeze
    lda en_dir
    bne @plr_blk_left
    lda plr_x
    clc
    adc #KNOCKBACK_BLOCKED
    sta plr_x
    jmp @plr_blk_shake
@plr_blk_left:
    lda plr_x
    sec
    sbc #KNOCKBACK_BLOCKED
    sta plr_x
@plr_blk_jump:
@plr_blk_shake:
    lda #4
    sta shake_timer
    jsr PlaySFXBlock
    rts

@en_miss:
    rts

; =============================================================================
; CHECK HITBOX OVERLAP — Rectangle collision test
; Player hitbox vs Enemy hurtbox
; Output: Carry set if overlapping
; =============================================================================
CheckHitboxOverlap:
    ; X overlap: plr_hitbox_x1 < en_body_x2 AND plr_hitbox_x2 > en_body_x1
    lda plr_hitbox_x1
    cmp en_body_x2
    bcs @no_overlap
    lda plr_hitbox_x2
    cmp en_body_x1
    bcc @no_overlap

    ; Y overlap: plr_hitbox_y1 < en_body_y2 AND plr_hitbox_y2 > en_body_y1
    lda plr_hitbox_y1
    cmp en_body_y2
    bcs @no_overlap
    lda plr_hitbox_y2
    cmp en_body_y1
    bcc @no_overlap

    sec                     ; Overlap!
    rts
@no_overlap:
    clc
    rts

; =============================================================================
; CHECK ENEMY HITBOX OVERLAP — Enemy hitbox vs Player hurtbox
; Output: Carry set if overlapping
; =============================================================================
CheckEnemyHitboxOverlap:
    ; X overlap: en_hitbox_x1 < plr_body_x2 AND en_hitbox_x2 > plr_body_x1
    lda en_hitbox_x1
    cmp plr_body_x2
    bcs @en_no_overlap
    lda en_hitbox_x2
    cmp plr_body_x1
    bcc @en_no_overlap

    ; Y overlap
    lda en_hitbox_y1
    cmp plr_body_y2
    bcs @en_no_overlap
    lda en_hitbox_y2
    cmp plr_body_y1
    bcc @en_no_overlap

    sec
    rts
@en_no_overlap:
    clc
    rts

; =============================================================================
; CHECK MATCH END — Win/lose conditions
; =============================================================================
.export CheckMatchEnd
CheckMatchEnd:
    ; Check player KO
    lda plr_hp
    bne @check_enemy_ko
    ; Player lost
    lda #STATE_LOSE
    sta next_gamestate
    rts

@check_enemy_ko:
    lda en_hp
    bne @check_timer
    ; Enemy defeated
    lda #STATE_WIN
    sta next_gamestate
    rts

@check_timer:
    ; Check time
    lda match_timer_sec
    bne @match_continue
    ; Time over — compare HP
    lda plr_hp
    cmp en_hp
    bcc @time_lose          ; Player has less HP
    beq @time_draw          ; Equal = player wins by default
    ; Player wins by time
    lda #STATE_WIN
    sta next_gamestate
    rts
@time_lose:
    lda #STATE_LOSE
    sta next_gamestate
    rts
@time_draw:
    lda #STATE_WIN          ; Default win on draw
    sta next_gamestate
@match_continue:
    rts
