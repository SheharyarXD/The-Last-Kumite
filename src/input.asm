; THE LAST KUMITE — Input System
; Controller polling, debounce handling, combo detection
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; READ CONTROLLERS — Poll both joypads
; Output: pad1_new = buttons newly pressed this frame
;         pad1_held = buttons currently held
;         pad2_new, pad2_held for controller 2
; =============================================================================
.export ReadControllers
ReadControllers:
    ; Controller 1
    lda pad1_held
    sta pad1_prev           ; Save previous state

    ; Strobe controller
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1

    ; Read 8 buttons
    ldx #8
    lda #0
    sta pad1_held
@read_loop1:
    lda JOYPAD1
    lsr                     ; Bit 0 → C
    rol pad1_held           ; Roll into held byte
    dex
    bne @read_loop1

    ; Calculate newly pressed: new = held & ~prev
    lda pad1_prev
    eor #$FF                ; Invert previous
    and pad1_held           ; Mask with current
    sta pad1_new            ; = buttons that went from 0→1

    ; Controller 2 (not used but read for consistency)
    lda pad2_held
    sta pad2_prev
    lda #1
    sta JOYPAD2
    lda #0
    sta JOYPAD2
    ldx #8
    lda #0
    sta pad2_held
@read_loop2:
    lda JOYPAD2
    lsr
    rol pad2_held
    dex
    bne @read_loop2
    lda pad2_prev
    eor #$FF
    and pad2_held
    sta pad2_new

    rts

; =============================================================================
; UPDATE COMBO BUFFER — Record input history for special move detection
; =============================================================================
.export UpdateComboBuffer
UpdateComboBuffer:
    ; Store current input into circular buffer
    ldx combo_buffer_idx
    lda pad1_held           ; Store button state
    sta input_buffer_btns, x
    lda pad1_held           ; Store direction state
    and #$0F                ; Lower nibble = directions
    sta input_buffer_dirs, x

    ; Advance buffer index (wrap at 8)
    inx
    txa
    and #$07
    sta combo_buffer_idx

    ; Decrement combo timer if active
    lda combo_timer
    beq @no_timer
    dec combo_timer
@no_timer:

    ; Decrement special cooldown
    lda special_cooldown
    beq @no_cooldown
    dec special_cooldown
@no_cooldown:

    rts

; =============================================================================
; CHECK SPECIAL MOVE INPUT — Detect ↓ + B + A within window
; Output: Carry set if special move triggered
; =============================================================================
.export CheckSpecialMove
CheckSpecialMove:
    ; Check cooldown
    lda special_cooldown
    bne @no_special         ; Cooldown active

    ; Check if player can perform special (must be idle, walking, or blocking)
    lda plr_state
    cmp #PLR_IDLE
    beq @can_special
    cmp #PLR_WALK
    beq @can_special
    cmp #PLR_BLOCK
    beq @can_special
    cmp #PLR_CROUCH
    beq @can_special
    jmp @no_special

@can_special:
    ; Scan input buffer for ↓ + B + A pattern
    ; Pattern: DOWN direction present within last 8 frames,
    ;          AND B pressed, AND A pressed (can be same frame or sequential)

    ldx #0
    stx temp1               ; Found DOWN flag
    stx temp2               ; Found B flag
    stx temp3               ; Found A flag

@scan_loop:
    ; Get buffered input at index X
    lda input_buffer_dirs, x
    and #BTN_DOWN           ; Check if DOWN was pressed
    beq @no_down
    lda #1
    sta temp1
@no_down:

    lda input_buffer_btns, x
    and #BTN_B
    beq @no_b
    lda #1
    sta temp2
@no_b:

    lda input_buffer_btns, x
    and #BTN_A
    beq @no_a
    lda #1
    sta temp3
@no_a:

    inx
    cpx #8
    bcc @scan_loop

    ; Check if all three inputs were found
    lda temp1               ; DOWN?
    beq @no_special
    lda temp2               ; B?
    beq @no_special
    lda temp3               ; A?
    beq @no_special

    ; Special move detected!
    lda #SPECIAL_COOLDOWN
    sta special_cooldown
    sec                     ; Carry set = special triggered
    rts

@no_special:
    clc                     ; Carry clear = no special
    rts

; =============================================================================
; GET PLAYER INPUT STATE — Process current input for player movement/actions
; Output: Updates player intention variables
; =============================================================================
.export ProcessPlayerInput
ProcessPlayerInput:
    ; Skip if player is in hitstun, KO, or stunned
    lda plr_hitstun
    beq @not_hitstun
    jmp @input_done
@not_hitstun:
    lda plr_stunned
    beq @not_stunned
    jmp @input_done
@not_stunned:
    lda plr_state
    cmp #PLR_KO
    bne @not_ko
    jmp @input_done
@not_ko:

    ; --- Check special move first ---
    jsr CheckSpecialMove
    bcc @no_special_input

    ; Execute special move!
    lda #SPECIAL_COOLDOWN
    sta special_cooldown
    lda #PLR_SPECIAL
    sta plr_state
    lda #30                 ; 30 frames special animation
    sta plr_atk_timer
    lda #ATK_SPECIAL
    sta plr_atk_type
    lda #0
    sta plr_atk_hit
    jsr PlaySFXSpecial
    jmp @input_done

@no_special_input:

    ; --- Check pause ---
    lda pad1_new
    and #BTN_START
    beq @no_pause
    lda pause_flag
    eor #1
    sta pause_flag
@no_pause:

    ; If paused, ignore all other input
    lda pause_flag
    beq @not_paused
    jmp @input_done
@not_paused:

    ; --- Directional input ---
    lda pad1_held
    sta temp1               ; Save held state

    ; Check crouch (DOWN)
    and #BTN_DOWN
    beq @not_crouch_input
    jmp @do_crouch
@not_crouch_input:

    ; Check jump (UP)
    lda temp1
    and #BTN_UP
    beq @not_jump_input
    jmp @do_jump
@not_jump_input:

    ; Check left/right movement
    lda temp1
    and #(BTN_LEFT | BTN_RIGHT)
    beq @no_direction

    ; --- Left/Right movement ---
    lda temp1
    and #BTN_RIGHT
    beq @not_right

    ; Moving right
    lda #DIR_RIGHT
    sta plr_dir
    lda #WALK_SPEED
    sta plr_vel_x

    ; Check block (hold back = left when facing right)
    lda plr_dir
    bne @move_no_block      ; Facing left, right is forward
    ; Facing right, pressing left would be block... but we're pressing right
    jmp @set_walk

@not_right:
    lda temp1
    and #BTN_LEFT
    beq @no_direction

    ; Moving left
    lda #DIR_LEFT
    sta plr_dir
    lda #<-WALK_SPEED       ; Negative velocity
    sta plr_vel_x

    ; Check block (hold back = right when facing left)
    lda plr_dir
    beq @move_no_block      ; Facing right, left is forward
    ; Facing left, pressing right = block... but we're pressing left
    jmp @set_walk

@move_no_block:
    ; Check for block input: hold opposite of facing direction
    lda plr_dir
    bne @facing_left
    ; Facing right, check LEFT held
    lda temp1
    and #BTN_LEFT
    beq @set_walk
    jmp @do_block
@facing_left:
    ; Facing left, check RIGHT held
    lda temp1
    and #BTN_RIGHT
    beq @set_walk
    jmp @do_block

@set_walk:
    lda plr_state
    cmp #PLR_IDLE
    bne @check_attacks
    lda #PLR_WALK
    sta plr_state
    jmp @check_attacks

@no_direction:
    lda #0
    sta plr_vel_x
    lda plr_state
    cmp #PLR_WALK
    bne @check_attacks
    lda #PLR_IDLE
    sta plr_state
    jmp @check_attacks

    ; --- Jump ---
@do_jump:
    lda plr_grounded
    beq @check_attacks      ; Can't jump if airborne
    lda #PLR_JUMP
    sta plr_state
    lda #<JUMP_VELOCITY
    sta plr_vel_y
    lda #0
    sta plr_grounded
    jsr PlaySFXJump
    jmp @check_attacks

    ; --- Crouch ---
@do_crouch:
    lda plr_state
    cmp #PLR_CROUCH
    beq @check_attacks      ; Already crouching
    lda #PLR_CROUCH
    sta plr_state
    lda #0
    sta plr_vel_x
    jmp @check_attacks

    ; --- Block ---
@do_block:
    lda plr_state
    cmp #PLR_BLOCK
    bne @start_block
    jmp @input_done
@start_block:
    lda #PLR_BLOCK
    sta plr_state
    lda #0
    sta plr_vel_x
    jmp @input_done

    ; --- Attack buttons ---
@check_attacks:
    ; Check if already in an attack
    lda plr_cooldown
    beq @no_cooldown_block
    jmp @input_done
@no_cooldown_block:
    lda plr_atk_active
    beq @no_atk_active_block
    jmp @input_done
@no_atk_active_block:

    ; Check B button (Kick)
    lda pad1_new
    and #BTN_B
    bne @do_kick

    ; Check A button (Punch)
    lda pad1_new
    and #BTN_A
    bne @do_punch

    jmp @input_done

@do_punch:
    ; Determine punch type based on state
    lda plr_state
    cmp #PLR_CROUCH
    bne @check_jump_punch
    lda #PLR_CROUCH_PUNCH
    sta plr_state
    lda #ATK_PUNCH
    sta plr_atk_type
    lda #15                 ; 15 frame attack
    sta plr_atk_timer
    lda #DMG_PUNCH
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXPunch
    jmp @input_done

@check_jump_punch:
    cmp #PLR_JUMP
    bne @standing_punch
    lda #PLR_PUNCH
    sta plr_state
    lda #ATK_JUMP
    sta plr_atk_type
    lda #20
    sta plr_atk_timer
    lda #DMG_JUMP
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXKick
    jmp @input_done

@standing_punch:
    lda #PLR_PUNCH
    sta plr_state
    lda #ATK_PUNCH
    sta plr_atk_type
    lda #12                 ; 12 frame punch
    sta plr_atk_timer
    lda #DMG_PUNCH
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXPunch
    jmp @input_done

@do_kick:
    ; Determine kick type based on state
    lda plr_state
    cmp #PLR_CROUCH
    bne @check_jump_kick
    lda #PLR_CROUCH_KICK
    sta plr_state
    lda #ATK_KICK
    sta plr_atk_type
    lda #18                 ; 18 frame crouch kick
    sta plr_atk_timer
    lda #DMG_KICK
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXKick
    jmp @input_done

@check_jump_kick:
    cmp #PLR_JUMP
    bne @standing_kick
    lda #PLR_KICK
    sta plr_state
    lda #ATK_JUMP
    sta plr_atk_type
    lda #20
    sta plr_atk_timer
    lda #DMG_JUMP
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXKick
    jmp @input_done

@standing_kick:
    lda #PLR_KICK
    sta plr_state
    lda #ATK_KICK
    sta plr_atk_type
    lda #16                 ; 16 frame kick
    sta plr_atk_timer
    lda #DMG_KICK
    sta plr_dmg_accum
    lda #0
    sta plr_atk_hit
    jsr PlaySFXKick

@input_done:
    rts
