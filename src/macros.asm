; THE LAST KUMITE — Utility Macros
; ============================================================================

; =============================================================================
; WAIT FOR NMI — Halt until next frame
; =============================================================================
.macro WAIT_NMI
    lda #0
    sta nmiflag
:   lda nmiflag
    beq :-
.endmacro

; =============================================================================
; PPU REGISTER SHORTCUTS
; =============================================================================
.macro PPU_SETADDR addr
    bit PPU_STATUS          ; Reset address latch
    lda #>addr
    sta PPU_ADDR
    lda #<addr
    sta PPU_ADDR
.endmacro

.macro PPU_SETSCROLL scroll_x_val, scroll_y_val
    lda scroll_x_val
    sta PPU_SCROLL
    lda scroll_y_val
    sta PPU_SCROLL
.endmacro

; =============================================================================
; SPRITE OAM MACROS
; =============================================================================
; Write sprite data to OAM buffer at current oam_index
; Increments oam_index by 4
.macro SPRITE_OAM x_pos, y_pos, tile, attr
    ldx oam_index
    lda y_pos
    sta OAM_BUF, x
    inx
    lda tile
    sta OAM_BUF, x
    inx
    lda attr
    sta OAM_BUF, x
    inx
    lda x_pos
    sta OAM_BUF, x
    inx
    stx oam_index
.endmacro

; =============================================================================
; 16-BIT LOAD
; =============================================================================
.macro LD16 addr, val
    lda #<val
    sta addr
    lda #>val
    sta addr + 1
.endmacro

; =============================================================================
; 16-BIT POINTER FROM TABLE
; =============================================================================
.macro LD16_TBL addr, table, index
    lda table, index
    sta addr
    lda table + 1, index
    sta addr + 1
.endmacro

; =============================================================================
; BANKED DATA POINTER SETUP (for data in PRG)
; =============================================================================
.macro SET_PTR addr, label
    lda #<label
    sta addr
    lda #>label
    sta addr + 1
.endmacro

; =============================================================================
; PUSH/POP 16-BIT (for preserving pointers across calls)
; =============================================================================
.macro PHA16 addr
    lda addr + 1
    pha
    lda addr
    pha
.endmacro

.macro PLA16 addr
    pla
    sta addr
    pla
    sta addr + 1
.endmacro

; =============================================================================
; COMPARE AND BRANCH
; =============================================================================
.macro BEQ_DO label
    beq label
.endmacro

.macro BNE_DO label
    bne label
.endmacro

; =============================================================================
; ABSOLUTE VALUE (signed 8-bit in A → unsigned in A)
; =============================================================================
.macro ABS_A
    bpl :+
    eor #$FF
    clc
    adc #1
:
.endmacro

; =============================================================================
; MIN/MAX CLAMPING
; =============================================================================
.macro CLAMP_A min_val, max_val
    cmp #min_val
    bcs :+
    lda #min_val
    jmp :++
:   cmp #max_val + 1
    bcc :+
    lda #max_val
:
.endmacro

; =============================================================================
; DECREMENT WITH BRANCH IF NOT ZERO
; =============================================================================
.macro DEC_BNE addr, label
    dec addr
    bne label
.endmacro

; =============================================================================
; CLEAR OAM (hide all sprites by putting them offscreen)
; =============================================================================
.macro CLEAR_OAM
    ldx #0
    lda #$F8                ; Off-screen Y
:
    sta OAM_BUF, x
    inx
    inx
    inx
    inx
    bne :-
.endmacro

; =============================================================================
; PLAY SFX — Queue a sound effect
; =============================================================================
.macro PLAY_SFX sfx_id
    lda sfx_id
    sta sfx_queue_type
    lda #0
    sta sfx_queue_timer
.endmacro

; =============================================================================
; RANDOM NUMBER — Simple LFSR in A
; =============================================================================
.macro RANDOM_A
    lda rand_seed
    beq :+
    asl
    bcc :++
:   eor #$1D
:   sta rand_seed
.endmacro

; =============================================================================
; STATE TRANSITION
; =============================================================================
.macro STATE_CHANGE new_state
    lda #new_state
    sta next_gamestate
.endmacro

; =============================================================================
; ENABLE / DISABLE RENDERING
; =============================================================================
.macro RENDER_ON
    lda #%00011110          ; BG + SPR visible, no clip
    sta PPU_MASK
    sta ppu_mask_cache
.endmacro

.macro RENDER_OFF
    lda #0
    sta PPU_MASK
    sta ppu_mask_cache
.endmacro

; =============================================================================
; DMA TRANSFER — Send OAM buffer to PPU
; =============================================================================
.macro OAM_DMA_TRANSFER
    lda #0
    sta OAM_ADDR
    lda #>OAM_BUF
    sta OAM_DMA
.endmacro
