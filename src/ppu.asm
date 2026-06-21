; THE LAST KUMITE — PPU Driver
; Handles all rendering: sprite OAM, background tiles, nametable updates
; ============================================================================

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
    ldx bg_update_count
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
    stx bg_update_count
    inc bg_update_count
    inc bg_update_count

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

; =============================================================================
; UPDATE HEALTH BAR — Draw health bar tiles to nametable
; =============================================================================
; Input: A = health value (0-100), X = bar position (0=player, 1=enemy)
.export UpdateHealthBar
UpdateHealthBar:
    sta temp3               ; Save health value
    stx temp4               ; Save which bar

    ; Cap at 100
    cmp #101
    bcc @health_ok
    lda #100
    sta temp3
@health_ok:

    ; Calculate filled tiles (10 tiles max = 100 HP / 10)
    lda temp3
    lsr                     ; Divide by 10
    lsr
    ; Actually, let's do repeated subtraction for /10
    ldx #0
@div10:
    cmp #10
    bcc @div10_done
    sec
    sbc #10
    inx
    jmp @div10
@div10_done:
    stx temp1               ; Number of filled tiles
    sta temp2               ; Remainder (for partial tile)

    ; Determine bar screen position
    lda temp4
    bne @enemy_bar
    ; Player bar: tiles at (3, 3) to (12, 3)
    lda #$20
    sta bg_update_buf
    lda #$83                ; $2083 = row 3, col 3
    jmp @bar_pos_set
@enemy_bar:
    ; Enemy bar: tiles at (19, 3) to (28, 3)
    lda #$20
    sta bg_update_buf
    lda #$93                ; $2093 = row 3, col 19
@bar_pos_set:
    sta bg_update_buf + 1

    ; Write filled tiles ($03 = full bar segment)
    ldx temp1
    beq @no_fill
    ldy #0
@fill_loop:
    lda #$03                ; Full bar tile
    sta bg_update_buf + 2, y
    iny
    dex
    bne @fill_loop
@no_fill:

    ; Write empty tiles ($02 = empty bar segment)
    lda #10
    sec
    sbc temp1
    tax
    beq @no_empty
@empty_loop:
    lda #$02                ; Empty bar tile
    sta bg_update_buf + 2, y
    iny
    dex
    bne @empty_loop
@no_empty:

    ; Set update count: 10 tiles × 3 bytes each (addr_hi, addr_lo, tile)
    lda #10
    sta bg_update_count
    rts

; =============================================================================
; DRAW METASPRITE — Draw a 2×2 tile character sprite to OAM
; =============================================================================
; Input: A = base tile index, X = screen X, Y = screen Y
;        plr_dir = facing direction (affects horizontal flip)
.export DrawMetasprite
DrawMetasprite:
    stx temp1               ; X position
    sty temp2               ; Y position
    sta temp3               ; Base tile

    ; Palette bits in attributes
    lda #0
    sta temp4

    ; Check if OAM is full
    lda oam_index
    cmp #(64 * 4)
    bcs @ms_done            ; OAM full, skip

    ldx oam_index           ; X = OAM write index

    ; --- Row 0 ---
    ; Tile (0,0): top-left
    lda temp2
    sta OAM_BUF, x          ; Y
    inx
    lda temp3
    sta OAM_BUF, x          ; Tile
    inx
    lda temp4
    sta OAM_BUF, x          ; Attributes (palette 0, no flip)
    inx
    lda temp1
    sta OAM_BUF, x          ; X
    inx

    ; Tile (1,0): top-right
    lda temp2
    sta OAM_BUF, x
    inx
    lda temp3
    clc
    adc #1
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

    ; --- Row 1 ---
    ; Tile (0,1): bottom-left
    lda temp2
    clc
    adc #8
    sta OAM_BUF, x
    inx
    lda temp3
    clc
    adc #2
    sta OAM_BUF, x
    inx
    lda temp4
    sta OAM_BUF, x
    inx
    lda temp1
    sta OAM_BUF, x
    inx

    ; Tile (1,1): bottom-right
    lda temp2
    clc
    adc #8
    sta OAM_BUF, x
    inx
    lda temp3
    clc
    adc #3
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
    lda #$80                ; Impact tile (top)
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
    lda #$81
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
    lda #$82
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
    lda #$83
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
    lda #$90                ; Star tile
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
    lda #$91                ; Star tile 2
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
