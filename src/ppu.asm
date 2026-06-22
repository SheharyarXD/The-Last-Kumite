; THE LAST KUMITE — PPU Driver
; Handles all rendering: sprite OAM, background tiles, nametable updates
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"
.include "sprite_tiles_const.inc"

.segment "CODE"

; =============================================================================
; NMI — Non-Maskable Interrupt (Vertical Blank)
; Called 60 times per second (NTSC) by the PPU
; =============================================================================
.export NMI
NMI:
    ; Save registers
    pha
    txa
    pha
    tya
    pha

    ; Set NMI flag so game loop knows frame started
    lda #1
    sta nmiflag
    inc framecounter
    bne @no_carry
    inc framecounter_hi
@no_carry:

    ; -------------------------------------------------------------------------
    ; OAM DMA Transfer — Send sprite data to PPU
    ; -------------------------------------------------------------------------
    OAM_DMA_TRANSFER

    ; -------------------------------------------------------------------------
    ; Apply screen shake if active
    ; -------------------------------------------------------------------------
    lda shake_timer
    beq @no_shake
    dec shake_timer
    RANDOM_A
    and #3
    sec
    sbc #1
    sta screen_shake_x
    RANDOM_A
    and #3
    sec
    sbc #1
    sta screen_shake_y
    jmp @apply_scroll
@no_shake:
    lda #0
    sta screen_shake_x
    sta screen_shake_y

@apply_scroll:
    ; -------------------------------------------------------------------------
    ; Set scroll position (with shake offset)
    ; -------------------------------------------------------------------------
    lda scroll_x
    clc
    adc screen_shake_x
    sta PPU_SCROLL
    lda scroll_y
    clc
    adc screen_shake_y
    sta PPU_SCROLL

    ; -------------------------------------------------------------------------
    ; Update PPU control register
    ; -------------------------------------------------------------------------
    lda ppu_ctrl_cache
    sta PPU_CTRL

    ; -------------------------------------------------------------------------
    ; Background tile updates (if any queued)
    ; -------------------------------------------------------------------------
    lda bg_update_count
    beq @no_bg_update
    jsr ProcessBGUpdates
@no_bg_update:

    ; -------------------------------------------------------------------------
    ; Restore registers and return
    ; -------------------------------------------------------------------------
    pla
    tay
    pla
    tax
    pla
    rti                     ; Return from interrupt

; =============================================================================
; PROCESS BG UPDATES — Write pending background tiles to PPU
; =============================================================================
ProcessBGUpdates:
    ldx #0
@bg_update_loop:
    lda bg_update_buf, x    ; PPU address high
    sta PPU_ADDR
    inx
    lda bg_update_buf, x    ; PPU address low
    sta PPU_ADDR
    inx
    lda bg_update_buf, x    ; Tile data
    sta PPU_DATA
    inx
    dec bg_update_count
    bne @bg_update_loop
    lda #0
    sta bg_update_byte_idx  ; Reset write offset for next frame's queue
    rts

; =============================================================================
; CLEAR NAMETABLE — Fill a full nametable with a tile
; =============================================================================
; Input: nametable (0 or 1), A = fill tile
.export ClearNametable
ClearNametable:
    sta temp1               ; Save fill tile

    ; Calculate nametable base address
    lda nametable
    bne @nt1
    PPU_SETADDR $2000       ; Nametable 0
    jmp @do_clear
@nt1:
    PPU_SETADDR $2400       ; Nametable 1
@do_clear:
    lda temp1
    ldx #0
    ldy #4                  ; 4 × 256 = 1024 bytes per nametable
@clear_loop:
    sta PPU_DATA
    inx
    bne @clear_loop
    dey
    bne @clear_loop
    rts

; =============================================================================
; LOAD NAMETABLE — Copy prepared nametable data to PPU
; =============================================================================
; Input: ptr (16-bit) points to 1024 bytes of nametable data
;        nametable (0 or 1) selects target
.export LoadNametable
LoadNametable:
    lda nametable
    bne @nt1
    PPU_SETADDR $2000
    jmp @do_load
@nt1:
    PPU_SETADDR $2400
@do_load:
    LD16 work_ptr_lo, $2000
    ldy #0
    ldx #4                  ; 4 pages of 256 bytes
@load_loop:
    lda (work_ptr_lo), y
    sta PPU_DATA
    iny
    bne @load_loop
    inc work_ptr_hi
    dex
    bne @load_loop
    rts

; =============================================================================
; DRAW TEXT — Write ASCII text to background nametable
; =============================================================================
; Input: text_ptr points to null-terminated string
;        text_x_pos, text_y_pos = position in tiles (0-31, 0-29)
.export DrawText
DrawText:
    ; Calculate PPU address = $2000 + y*32 + x
    lda text_y_pos
    sta temp1
    lda #0
    sta temp2
    ; Multiply Y by 32
    ldx #5                  ; 5 left shifts = ×32
@mul32:
    asl temp1
    rol temp2
    dex
    bne @mul32
    ; Add X offset
    lda text_x_pos
    clc
    adc temp1
    sta temp1
    lda #0
    adc temp2
    clc
    adc #$20                ; High byte of $2000
    sta temp2

    ; Set PPU address
    bit PPU_STATUS
    lda temp2
    sta PPU_ADDR
    lda temp1
    sta PPU_ADDR

@text_loop:
    ldy #0
    lda (text_ptr_lo), y
    beq @text_done          ; Null terminator

    ; Convert ASCII to tile index (simple: A=letter_tile_base)
    cmp #$41                ; 'A'
    bcc @check_numbers
    cmp #$5B                ; '[' (past 'Z')
    bcs @check_numbers
    ; It's A-Z
    sec
    sbc #$41                ; A=0, B=1, ...
    clc
    adc #$80                ; Tile offset for alphabet ($80-$9F in CHR)
    jmp @write_char

@check_numbers:
    cmp #$30                ; '0'
    bcc @check_space
    cmp #$3A                ; ':' (past '9')
    bcs @check_space
    ; It's 0-9
    sec
    sbc #$30                ; 0=0, 1=1, ...
    clc
    adc #$A0                ; Tile offset for numbers
    jmp @write_char

@check_space:
    lda #$00                ; Space tile (blank)

@write_char:
    sta PPU_DATA

    ; Advance text pointer
    inc text_ptr_lo
    bne @no_carry
    inc text_ptr_hi
@no_carry:
    jmp @text_loop

@text_done:
    rts

; =============================================================================
; DRAW TEXT TO BUFFER — Queue text as BG update instead of direct PPU write
; =============================================================================
; Use during gameplay when PPU is active
.export DrawTextBuffered
DrawTextBuffered:
    ; Calculate nametable address
    lda text_y_pos
    sta temp1
    lda #0
    sta temp2
    ldx #5
@mul32:
    asl temp1
    rol temp2
    dex
    bne @mul32
    lda text_x_pos
    clc
    adc temp1
    sta temp1
    lda #0
    adc temp2
    clc
    adc #$20
    sta temp2

    ldy #0
@buf_loop:
    lda (text_ptr_lo), y
    beq @buf_done

    ; Store PPU address (high then low)
    ldx bg_update_byte_idx
    lda temp2
    sta bg_update_buf, x
    inx
    lda temp1
    sta bg_update_buf, x
    inx

    ; Convert and store tile
    sty temp3               ; Save Y (string index)
    lda (text_ptr_lo), y
    cmp #$41
    bcc @bn_check_num
    cmp #$5B
    bcs @bn_check_num
    sec
    sbc #$41
    clc
    adc #$80
    jmp @bn_store
@bn_check_num:
    cmp #$30
    bcc @bn_space
    cmp #$3A
    bcs @bn_space
    sec
    sbc #$30
    clc
    adc #$A0
    jmp @bn_store
@bn_space:
    lda #$00
@bn_store:
    sta bg_update_buf, x
    inx
    stx bg_update_byte_idx
    inc bg_update_count      ; One more 3-byte entry queued

    ldy temp3
    iny
    inc temp1               ; Increment X tile position
    bne @bn_no_carry
    inc temp2
@bn_no_carry:
    cpy #20                 ; Max 20 chars per buffered write
    bcc @buf_loop
@buf_done:
    rts

; (UpdateHealthBar removed: it was dead code, never called, and used an
;  incompatible buffer format. See DrawPlayerBar/DrawEnemyBar in hud.asm.)

; =============================================================================
; DRAW METASPRITE — Draw a 2x2 (16x16) character sprite to OAM
; =============================================================================
; Input: A = BASE tile index (top-left quadrant, LOCAL to sprite pattern
;        table 1), X = screen X (left edge), Y = screen Y (top edge),
;        temp4 = OAM attribute byte (palette bits + flip bits). Caller sets
;        temp4 before calling — see RenderPlayer/RenderEnemy for the
;        horizontal-flip convention (bit 6 of temp4 set = facing left).
; Tile layout (consecutive from the base index): +0 top-left, +1 top-right,
; +2 bottom-left, +3 bottom-right — see tools/chr_convert.py.
.export DrawMetasprite
DrawMetasprite:
    stx temp1               ; X position (left edge)
    sty temp2                ; Y position (top edge)
    sta temp3                ; Base tile index

    ; Check if OAM has room for 4 more sprites (16 bytes) without wrapping
    lda oam_index
    cmp #240                ; 256 - 16 = 240
    bcc @ms_room
    rts
@ms_room:

    ldx oam_index

    ; Determine left/right quadrant order: normally TL=+0/TR=+1 on the
    ; left/right respectively; horizontally flipped, swap which tile goes
    ; on which side (the hardware flip bit mirrors each tile's own pixels,
    ; but the two halves must also swap positions or the sprite would show
    ; its right-side art on the left and vice versa).
    lda temp4
    and #%01000000
    beq @ms_not_flipped
    ; Flipped: left column shows tile +1/+3, right column shows tile +0/+2
    lda temp3
    clc
    adc #1
    sta temp_quad_left_top
    lda temp3
    sta temp_quad_right_top
    lda temp3
    clc
    adc #3
    sta temp_quad_left_bot
    lda temp3
    clc
    adc #2
    sta temp_quad_right_bot
    jmp @ms_quads_set
@ms_not_flipped:
    lda temp3
    sta temp_quad_left_top
    lda temp3
    clc
    adc #1
    sta temp_quad_right_top
    lda temp3
    clc
    adc #2
    sta temp_quad_left_bot
    lda temp3
    clc
    adc #3
    sta temp_quad_right_bot
@ms_quads_set:

    ; --- Top-left ---
    lda temp2
    sta OAM_BUF, x
    inx
    lda temp_quad_left_top
    sta OAM_BUF, x
    inx
    lda temp4
    sta OAM_BUF, x
    inx
    lda temp1
    sta OAM_BUF, x
    inx

    ; --- Top-right ---
    lda temp2
    sta OAM_BUF, x
    inx
    lda temp_quad_right_top
    sta OAM_BUF, x
    inx
    lda temp4
    sta OAM_BUF, x
    inx
    lda temp1
    clc
    adc #8
    sta OAM_BUF, x
    inx

    ; --- Bottom-left ---
    lda temp2
    clc
    adc #8
    sta OAM_BUF, x
    inx
    lda temp_quad_left_bot
    sta OAM_BUF, x
    inx
    lda temp4
    sta OAM_BUF, x
    inx
    lda temp1
    sta OAM_BUF, x
    inx

    ; --- Bottom-right ---
    lda temp2
    clc
    adc #8
    sta OAM_BUF, x
    inx
    lda temp_quad_right_bot
    sta OAM_BUF, x
    inx
    lda temp4
    sta OAM_BUF, x
    inx
    lda temp1
    clc
    adc #8
    sta OAM_BUF, x
    inx

    stx oam_index
@ms_done:
    rts

; =============================================================================
; DRAW HIT EFFECT — Visual feedback for attack landing
; =============================================================================
; Input: X = screen X, Y = screen Y
.export DrawHitEffect
DrawHitEffect:
    sty temp1               ; Y position
    stx temp2               ; X position

    ; Use sprite palette 2 (yellow/white flash)
    lda oam_index
    cmp #(60 * 4)
    bcs @fx_done            ; Don't overflow OAM

    tax                     ; X = oam_index

    ; 4 small impact sprites in a star pattern
    lda temp1
    sec
    sbc #4
    sta OAM_BUF, x          ; Y (top)
    inx
    lda #EFFECT_TILE_BASE+0 ; Impact tile (top)
    sta OAM_BUF, x
    inx
    lda #%00000010          ; Palette 2
    sta OAM_BUF, x
    inx
    lda temp2
    sta OAM_BUF, x          ; X (center)
    inx

    lda temp1
    clc
    adc #4
    sta OAM_BUF, x          ; Y (bottom)
    inx
    lda #EFFECT_TILE_BASE+1
    sta OAM_BUF, x
    inx
    lda #%10000010          ; Palette 2, flip V
    sta OAM_BUF, x
    inx
    lda temp2
    sta OAM_BUF, x
    inx

    lda temp1
    sta OAM_BUF, x          ; Y (center)
    inx
    lda #EFFECT_TILE_BASE+2
    sta OAM_BUF, x
    inx
    lda #%00000010          ; Palette 2
    sta OAM_BUF, x
    inx
    lda temp2
    sec
    sbc #4
    sta OAM_BUF, x          ; X (left)
    inx

    lda temp1
    sta OAM_BUF, x
    inx
    lda #EFFECT_TILE_BASE+3
    sta OAM_BUF, x
    inx
    lda #%01000010          ; Palette 2, flip H
    sta OAM_BUF, x
    inx
    lda temp2
    clc
    adc #4
    sta OAM_BUF, x
    inx

    stx oam_index
@fx_done:
    rts

; =============================================================================
; DRAW STUN EFFECT — Visual indicator that enemy is stunned
; =============================================================================
; Input: X = screen X, Y = screen Y
.export DrawStunEffect
DrawStunEffect:
    sty temp1
    stx temp2

    lda special_effect_t
    beq @stun_done
    dec special_effect_t

    lda oam_index
    cmp #(62 * 4)
    bcs @stun_done

    tax

    ; Rotating stars above stunned character
    lda temp1
    sec
    sbc #12
    clc
    adc special_effect_t    ; Bobbing motion
    and #7
    sta OAM_BUF, x
    inx
    lda #EFFECT_TILE_BASE+16       ; Star tile
    sta OAM_BUF, x
    inx
    lda #%00000011          ; Palette 3 (white/silver)
    sta OAM_BUF, x
    inx
    lda temp2
    sec
    sbc #4
    sta OAM_BUF, x
    inx

    lda temp1
    sec
    sbc #12
    sta OAM_BUF, x
    inx
    lda #EFFECT_TILE_BASE+17       ; Star tile 2
    sta OAM_BUF, x
    inx
    lda #%01000011          ; Palette 3, flip H
    sta OAM_BUF, x
    inx
    lda temp2
    clc
    adc #4
    sta OAM_BUF, x
    inx

    stx oam_index
@stun_done:
    rts

; =============================================================================
; FADE IN / FADE OUT
; =============================================================================
; Uses grayscale emphasis bits in PPUMASK
.export FadeUpdate
FadeUpdate:
    lda fade_level
    cmp #0
    bne @check_1
    ; Level 0: Full color
    lda #%00011110
    sta ppu_mask_cache
    rts
@check_1:
    cmp #1
    bne @check_2
    ; Level 1: Slight dim (emphasis blue)
    lda #%10011110
    sta ppu_mask_cache
    rts
@check_2:
    cmp #2
    bne @check_3
    ; Level 2: Medium dim (emphasis red + blue)
    lda #%11011110
    sta ppu_mask_cache
    rts
@check_3:
    cmp #3
    bne @check_4
    ; Level 3: Heavy dim (all emphasis)
    lda #%11111110
    sta ppu_mask_cache
    rts
@check_4:
    ; Level 4+: Black screen (render off except bg)
    lda #%11100000
    sta ppu_mask_cache
    rts
