; THE LAST KUMITE — State Machine Core
; State transition management and shared state logic
; ============================================================================

.segment "CODE"

; =============================================================================
; STATE: TITLE SCREEN
; =============================================================================

; ---- Init ----
.export InitTitle
InitTitle:
    ; Clear screen
    lda #0
    sta nametable
    jsr ClearNametable

    ; Set background color to black
    lda #$0F
    sta PPU_DATA

    ; Draw "THE LAST KUMITE" title
    SET_PTR text_ptr_lo, title_text
    lda #8
    sta text_x_pos
    lda #10
    sta text_y_pos
    jsr DrawText

    ; Draw "PRESS START"
    SET_PTR text_ptr_lo, press_start_text
    lda #10
    sta text_x_pos
    lda #20
    sta text_y_pos
    jsr DrawText

    ; Reset scroll
    lda #0
    sta scroll_x
    sta scroll_y
    sta fade_level

    ; Turn rendering on
    RENDER_ON
    rts

; ---- Handler ----
.export HandleTitle
HandleTitle:
    ; Blink "PRESS START" text
    lda framecounter
    and #32
    beq @show_press

    ; Hide PRESS START (draw spaces)
    SET_PTR text_ptr_lo, blank_press_text
    lda #10
    sta text_x_pos
    lda #20
    sta text_y_pos
    jsr DrawTextBuffered
    jmp @check_start

@show_press:
    ; Show PRESS START
    SET_PTR text_ptr_lo, press_start_text
    lda #10
    sta text_x_pos
    lda #20
    sta text_y_pos
    jsr DrawTextBuffered

@check_start:
    ; Check for START press
    lda pad1_new
    and #BTN_START
    beq @title_done
    ; Start game! Go to intro
    PLAY_SFX #SFX_START
    STATE_CHANGE STATE_INTRO
@title_done:
    rts

; ---- Render ----
.export RenderTitle
RenderTitle:
    ; Title uses background text, no sprites needed
    rts

; =============================================================================
; STATE: INTRO STORY TEXT
; =============================================================================

; ---- Init ----
.export InitIntro
InitIntro:
    lda #0
    sta text_page
    sta text_scroll_y
    lda #4                  ; 4 pages of story text
    sta text_total_pages
    sta text_state          ; Start typing
    lda #TEXT_SPEED
    sta text_delay
    sta text_timer

    ; Clear nametable
    jsr ClearNametable

    ; Load first page
    jsr LoadStoryPage
    rts

; ---- Handler ----
.export HandleIntro
HandleIntro:
    ; Handle text typing
    lda text_state
    cmp #1                  ; Typing?
    bne @check_advance

    ; Type next character
    dec text_timer
    bne @intro_done
    lda text_delay
    sta text_timer

    ; Read next character from text
    ldy #0
    lda (text_ptr_lo), y
    beq @page_done          ; Null = end of page

    ; Display character (buffered BG update)
    jsr TypeNextChar

    ; Advance pointer
    inc text_ptr_lo
    bne @intro_done
    inc text_ptr_hi
    jmp @intro_done

@page_done:
    lda #3                  ; State: waiting for advance
    sta text_state
    jmp @intro_done

@check_advance:
    cmp #3                  ; Waiting for START?
    bne @intro_done

    ; Blink cursor
    lda framecounter
    and #16
    bne @show_cursor
    jsr HideCursor
    jmp @check_start_intro
@show_cursor:
    jsr ShowCursor

@check_start_intro:
    lda pad1_new
    and #BTN_START
    beq @intro_done

    ; Advance to next page
    inc text_page
    lda text_page
    cmp text_total_pages
    bcs @intro_complete

    ; Load next page
    jsr LoadStoryPage
    lda #1                  ; Back to typing
    sta text_state
    jmp @intro_done

@intro_complete:
    ; All text shown, go to VS screen
    PLAY_SFX #SFX_START
    STATE_CHANGE STATE_VS
@intro_done:
    rts

; ---- Render ----
.export RenderIntro
RenderIntro:
    ; Intro uses background text rendering
    rts

; =============================================================================
; STATE: VS SCREEN
; =============================================================================

; ---- Init ----
.export InitVS
InitVS:
    ; Clear screen
    jsr ClearNametable

    ; Draw "VS" in center
    SET_PTR text_ptr_lo, vs_big_text
    lda #14
    sta text_x_pos
    lda #12
    sta text_y_pos
    jsr DrawText

    ; Draw "MICHAEL RIVERS"
    SET_PTR text_ptr_lo, name_michael
    lda #2
    sta text_x_pos
    lda #12
    sta text_y_pos
    jsr DrawText

    ; Draw "LIGHTNING"
    SET_PTR text_ptr_lo, name_lightning
    lda #20
    sta text_x_pos
    lda #12
    sta text_y_pos
    jsr DrawText

    ; Set VS display timer (3 seconds = 180 frames)
    lda #180
    sta vs_screen_timer

    ; Position VS sprites (character portraits or silhouettes)
    lda #0
    sta vs_scroll_pos
    rts

; ---- Handler ----
.export HandleVS
HandleVS:
    dec vs_screen_timer
    bne @vs_done
    ; Timer expired, start fight!
    STATE_CHANGE STATE_FIGHT
@vs_done:
    rts

; ---- Render ----
.export RenderVS
RenderVS:
    ; VS screen uses BG text + possible character sprites
    rts

; =============================================================================
; STATE: WIN
; =============================================================================

; ---- Init ----
.export InitWin
InitWin:
    ; Clear screen
    jsr ClearNametable

    ; Draw victory text
    SET_PTR text_ptr_lo, win_text
    lda #4
    sta text_x_pos
    lda #12
    sta text_y_pos
    jsr DrawText

    ; Draw "ENTRY GRANTED"
    SET_PTR text_ptr_lo, entry_granted_text
    lda #8
    sta text_x_pos
    lda #16
    sta text_y_pos
    jsr DrawText

    lda #0
    sta state_timer
    rts

; ---- Handler ----
.export HandleWin
HandleWin:
    inc state_timer
    lda state_timer
    cmp #60                 ; 1 second delay
    bcc @win_done

    ; Check for START to return to title
    lda pad1_new
    and #BTN_START
    beq @win_done
    STATE_CHANGE STATE_GAMEOVER   ; Demo ends with game over screen
@win_done:
    rts

; =============================================================================
; STATE: LOSE
; =============================================================================

; ---- Init ----
.export InitLose
InitLose:
    lda #0
    sta state_timer
    rts

; ---- Handler ----
.export HandleLose
HandleLose:
    inc state_timer
    lda state_timer
    cmp #120                ; 2 seconds of KO display
    bcc @lose_done
    ; Go to game over
    STATE_CHANGE STATE_GAMEOVER
@lose_done:
    rts

; =============================================================================
; STATE: GAME OVER
; =============================================================================

; ---- Init ----
.export InitGameOver
InitGameOver:
    ; Pick random death type (0-3)
    RANDOM_A
    and #3
    sta death_type

    ; Clear screen
    jsr ClearNametable

    ; Draw "GAME OVER"
    SET_PTR text_ptr_lo, gameover_text
    lda #11
    sta text_x_pos
    lda #8
    sta text_y_pos
    jsr DrawText

    ; Draw Ron Hall description
    SET_PTR text_ptr_lo, ronhall_text
    lda #4
    sta text_x_pos
    lda #12
    sta text_y_pos
    jsr DrawText

    ; Draw death description based on type
    lda death_type
    asl
    tax
    lda death_text_table, x
    sta text_ptr_lo
    lda death_text_table + 1, x
    sta text_ptr_hi

    lda #4
    sta text_x_pos
    lda #18
    sta text_y_pos
    jsr DrawText

    ; Draw "PRESS START TO CONTINUE"
    SET_PTR text_ptr_lo, continue_text
    lda #6
    sta text_x_pos
    lda #26
    sta text_y_pos
    jsr DrawText

    lda #0
    sta state_timer
    rts

; ---- Handler ----
.export HandleGameOver
HandleGameOver:
    ; Check for START
    lda pad1_new
    and #BTN_START
    beq @gameover_done
    STATE_CHANGE STATE_TITLE
@gameover_done:
    rts

; ---- Render ----
.export RenderGameOver
RenderGameOver:
    rts

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

; Load a story text page into the text pointer
LoadStoryPage:
    lda text_page
    asl
    tax
    lda story_text_table, x
    sta text_ptr_lo
    lda story_text_table + 1, x
    sta text_ptr_hi
    lda #STORY_X
    sta text_x_pos
    lda #STORY_Y
    sta text_y_pos
    rts

; Type next character (buffered BG update)
TypeNextChar:
    ; Calculate PPU address for text position
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

    ; Queue BG update
    ldx bg_update_count
    lda temp2
    sta bg_update_buf, x
    inx
    lda temp1
    sta bg_update_buf, x
    inx

    ; Convert character to tile
    ldy #0
    lda (text_ptr_lo), y
    cmp #$41                ; 'A'
    bcc @tc_num
    cmp #$5B
    bcs @tc_space
    sec
    sbc #$41
    clc
    adc #$80
    jmp @tc_store
@tc_num:
    cmp #$30
    bcc @tc_space
    cmp #$3A
    bcs @tc_space
    sec
    sbc #$30
    clc
    adc #$A0
    jmp @tc_store
@tc_space:
    lda #$00                ; Blank tile
@tc_store:
    sta bg_update_buf, x
    inx
    stx bg_update_count
    inc bg_update_count
    inc bg_update_count

    ; Advance X position
    inc text_x_pos
    lda text_x_pos
    cmp #28                 ; Right margin
    bcc @tc_done
    lda #STORY_X            ; Wrap to next line
    sta text_x_pos
    inc text_y_pos
@tc_done:
    rts

ShowCursor:
    SET_PTR text_ptr_lo, cursor_char
    lda text_x_pos
    sta temp1
    lda text_y_pos
    clc
    adc #1
    sta temp2
    rts

HideCursor:
    rts

; =============================================================================
; TEXT DATA TABLES
; =============================================================================

; Story text split into 4 pages
story_text_table:
    .word story_page1
    .word story_page2
    .word story_page3
    .word story_page4

story_page1:
    .asciiz "THE WORLD'S MOST DANGEROUS"
story_page2:
    .asciiz "FIGHTERS GATHER IN SECRET TO"
story_page3:
    .asciiz "COMPETE IN THE LEGENDARY"
story_page4:
    .asciiz "KUMITE TOURNAMENT."

; Death descriptions
death_text_table:
    .word death_neck
    .word death_spine
    .word death_strangle
    .word death_punches

death_neck:
    .asciiz "YOUR NECK WAS SNAPPED."
death_spine:
    .asciiz "YOUR SPINE WAS BROKEN."
death_strangle:
    .asciiz "YOU WERE STRANGLED."
death_punches:
    .asciiz "BEATEN TO DEATH."

; Title text
title_text:
    .asciiz "THE LAST KUMITE"
press_start_text:
    .asciiz "PRESS START"
blank_press_text:
    .asciiz "           "
vs_big_text:
    .asciiz "VS"
name_michael:
    .asciiz "MICHAEL RIVERS"
name_lightning:
    .asciiz "LIGHTNING"
win_text:
    .asciiz "LIGHTNING DEFEATED."
entry_granted_text:
    .asciiz "ENTRY GRANTED."
gameover_text:
    .asciiz "GAME OVER"
ronhall_text:
    .asciiz "RON HALL GIVES THUMBS DOWN"
continue_text:
    .asciiz "PRESS START TO CONTINUE"
cursor_char:
    .asciiz ">"
