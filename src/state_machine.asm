; THE LAST KUMITE — State Machine Core
; State transition management and shared state logic
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; STATE: TITLE SCREEN
; =============================================================================

; ---- Init ----
.export InitTitle
InitTitle:
    ; Turn off rendering BEFORE any PPU writes.
    ; Without this, direct PPU_ADDR/PPU_DATA writes that follow (ClearNametable,
    ; DrawTitleLogo, DrawText) race the active renderer and produce text overlap
    ; or garbage tiles on every transition back from GAMEOVER or MENU.
    RENDER_OFF

    ; BG2 ($3F09-$3F0B) is shared with the fight stage's foliage ramp
    ; (green, set in init.asm's default_palette) since palette RAM
    ; persists across state changes. Re-point it at the logo's
    ; red/gold/white here so returning to the title from GAMEOVER/MENU
    ; after a fight doesn't show a green emblem.
    PPU_SETADDR $3F09
    lda #$16
    sta PPU_DATA
    lda #$27
    sta PPU_DATA
    lda #$30
    sta PPU_DATA

    ; BG0 ($3F01-$3F03) is shared with the fight stage's sky, which is
    ; a dark navy tuned for night-stage art (see init.asm). Title/menu
    ; text is drawn on BG0 too (see DrawText calls below), so a dark
    ; navy fill would make the black-outlined text nearly unreadable
    ; against it. Re-point BG0 at a bright, high-contrast blue here --
    ; readability, not matching the fight stage's sky, is what matters
    ; on a text-only menu screen.
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Clear screen
    lda #0
    sta nametable
    jsr ClearNametable

    ; Draw the fist/ring emblem converted from assets/32730.png
    ; (see src/title_logo.inc + src/title.asm:DrawTitleLogo)
    jsr DrawTitleLogo

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
; (RenderTitle implementation lives in title.asm)

; =============================================================================
; STATE: INTRO STORY TEXT
; =============================================================================

; ---- Init ----
.export InitIntro
InitIntro:
    RENDER_OFF

    ; BG0 ($3F01-$3F03) — same fix as InitTitle/InitMenu: this is a
    ; text-only story screen drawn on BG0, so it needs the bright blue/
    ; white ramp instead of whatever was left behind (the fight stage's
    ; dark navy sky, which reads as a dull purplish color behind text).
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Clear nametable (fills with blank tile $00)
    lda #0
    sta nametable
    jsr ClearNametable

    ; Draw all 4 story lines at once — no paging, no typewriter.
    ; The previous paged typewriter approach left ghost text on screen
    ; because LoadStoryPage never cleared the nametable between pages.

    ; Line 1: "THE WORLD'S MOST DANGEROUS"
    SET_PTR text_ptr_lo, story_page1
    lda #3
    sta text_x_pos
    lda #8
    sta text_y_pos
    jsr DrawText

    ; Line 2: "FIGHTERS GATHER IN SECRET TO"
    SET_PTR text_ptr_lo, story_page2
    lda #2
    sta text_x_pos
    lda #11
    sta text_y_pos
    jsr DrawText

    ; Line 3: "COMPETE IN THE LEGENDARY"
    SET_PTR text_ptr_lo, story_page3
    lda #4
    sta text_x_pos
    lda #14
    sta text_y_pos
    jsr DrawText

    ; Line 4: "KUMITE TOURNAMENT."
    SET_PTR text_ptr_lo, story_page4
    lda #6
    sta text_x_pos
    lda #17
    sta text_y_pos
    jsr DrawText

    ; "PRESS START" prompt
    SET_PTR text_ptr_lo, press_start_text
    lda #10
    sta text_x_pos
    lda #22
    sta text_y_pos
    jsr DrawText

    ; Mark text as done — HandleIntro just waits for START
    lda #3
    sta text_state

    lda #0
    sta scroll_x
    sta scroll_y
    sta fade_level

    RENDER_ON
    rts

; ---- Handler ----
.export HandleIntro
HandleIntro:
    ; Blink "PRESS START"
    lda framecounter
    and #32
    beq @hide_prompt

    SET_PTR text_ptr_lo, press_start_text
    lda #10
    sta text_x_pos
    lda #22
    sta text_y_pos
    jsr DrawTextBuffered
    jmp @check_start_intro

@hide_prompt:
    SET_PTR text_ptr_lo, blank_press_text
    lda #10
    sta text_x_pos
    lda #22
    sta text_y_pos
    jsr DrawTextBuffered

@check_start_intro:
    lda pad1_new
    and #BTN_START
    beq @intro_done
    ; All text shown, go to VS screen
    PLAY_SFX #SFX_START
    STATE_CHANGE STATE_VS
@intro_done:
    rts

; ---- Render ----
; (RenderIntro implementation lives in intro.asm)

; =============================================================================
; STATE: VS SCREEN
; =============================================================================

; ---- Init ----
.export InitVS
InitVS:
    RENDER_OFF

    ; BG0 ($3F01-$3F03) — same fix as InitTitle/InitMenu: names/VS text
    ; here is drawn on BG0, so it needs the bright blue/white ramp
    ; instead of the fight stage's dark navy sky left over from a
    ; previous match (which reads as a dull purplish color).
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Clear screen
    lda #0
    sta nametable
    jsr ClearNametable

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

    ; Draw "VS" centered, on its own row below both names. (This used to
    ; share row 12 with "MICHAEL RIVERS", which occupies columns 2-15 --
    ; directly overlapping VS's columns 14-15 -- so drawing the name
    ; afterward silently overwrote the V of VS. Giving it a separate row
    ; avoids the collision entirely.)
    SET_PTR text_ptr_lo, vs_big_text
    lda #15
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawText

    ; Set VS display timer (3 seconds = 180 frames)
    lda #180
    sta vs_screen_timer

    ; Position VS sprites (character portraits or silhouettes)
    lda #0
    sta vs_scroll_pos

    RENDER_ON
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
; (RenderVS implementation lives in vs_screen.asm)

; =============================================================================
; STATE: WIN
; =============================================================================

; ---- Init ----
.export InitWin
InitWin:
    RENDER_OFF

    ; BG0 ($3F01-$3F03) — same fix as InitTitle/InitMenu: "YOU WIN" /
    ; "ENTRY GRANTED" text is drawn on BG0, so it needs the bright blue/
    ; white ramp instead of the fight stage's dark navy sky (which is
    ; what was active during the match and reads as a dull purplish
    ; color behind text instead of the light blue the title screen uses).
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Clear screen
    lda #0
    sta nametable
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

    RENDER_ON
    rts

; ---- Handler ----
.export HandleWin
HandleWin:
    inc state_timer
    lda state_timer
    cmp #60                 ; 1 second delay
    bcc @win_done

    ; Check for START to go to post-game menu
    lda pad1_new
    and #BTN_START
    beq @win_done
    STATE_CHANGE STATE_MENU   ; Continue / Start New Game menu
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
    ; Go to the Game Over screen (Ron Hall thumbs-down + death text).
    ; NOTE: this used to jump straight to STATE_MENU, which skipped
    ; STATE_GAMEOVER entirely -- it was defined, fully implemented in
    ; gameover.asm, and wired into both jump tables, but nothing ever
    ; transitioned into it, so the thumbs-down screen could never appear.
    STATE_CHANGE STATE_GAMEOVER
@lose_done:
    rts

; =============================================================================
; STATE: GAME OVER
; =============================================================================

; ---- Init ----
.export InitGameOver
InitGameOver:
    RENDER_OFF

    ; BG0 ($3F01-$3F03) — same fix as InitTitle/InitMenu: the GAME OVER
    ; text is drawn on BG0, so it needs the bright blue/white ramp
    ; instead of the fight stage's dark navy sky (dull purplish look).
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Pick random death type (0-3)
    RANDOM_A
    and #3
    sta death_type

    ; Clear screen
    lda #0
    sta nametable
    jsr ClearNametable

    ; Draw "GAME OVER"
    SET_PTR text_ptr_lo, gameover_text
    lda #11
    sta text_x_pos
    lda #2
    sta text_y_pos
    jsr DrawText

    ; (Ron Hall thumbs-down portrait sprite drawn by RenderGameOver,
    ; tile rows 6-13 -- see gameover.asm)

    ; Draw Ron Hall description
    SET_PTR text_ptr_lo, ronhall_text
    lda #4
    sta text_x_pos
    lda #15
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
    lda #19
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

    RENDER_ON
    rts

; ---- Handler ----
.export HandleGameOver
HandleGameOver:
    ; Check for START
    lda pad1_new
    and #BTN_START
    beq @gameover_done
    STATE_CHANGE STATE_MENU   ; Post-game menu: Continue or Start New Game
@gameover_done:
    rts

; ---- Render ----
; (RenderGameOver implementation lives in gameover.asm)

; =============================================================================
; STATE: POST-GAME MENU
; Shown after WIN, LOSE, or GAME OVER.
; UP/DOWN to move cursor.  START or A to confirm.
;   0 = CONTINUE  → STATE_VS  (rematch from VS intro)
;   1 = START     → STATE_TITLE
; =============================================================================

; ---- Init ----
.export InitMenu
InitMenu:
    RENDER_OFF

    ; BG0 ($3F01-$3F03) — see InitTitle's identical fix above: menu text
    ; is drawn on BG0, so it needs the bright blue, not the fight
    ; stage's dark navy sky color.
    PPU_SETADDR $3F01
    lda #$21
    sta PPU_DATA
    lda #$31
    sta PPU_DATA
    lda #$20
    sta PPU_DATA

    ; Default cursor to CONTINUE
    lda #0
    sta menu_cursor

    ; Clear screen
    lda #0
    sta nametable
    jsr ClearNametable

    ; "THE LAST KUMITE" header (same position as title screen)
    SET_PTR text_ptr_lo, title_text
    lda #8
    sta text_x_pos
    lda #6
    sta text_y_pos
    jsr DrawText

    ; Divider prompt
    SET_PTR text_ptr_lo, menu_header_text
    lda #8
    sta text_x_pos
    lda #10
    sta text_y_pos
    jsr DrawText

    ; Option 0 — CONTINUE (initially selected, so arrow on this line)
    SET_PTR text_ptr_lo, menu_arrow_text
    lda #6
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawText

    SET_PTR text_ptr_lo, menu_continue_text
    lda #8
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawText

    ; Option 1 — START (no arrow)
    SET_PTR text_ptr_lo, menu_blank_arrow
    lda #6
    sta text_x_pos
    lda #18
    sta text_y_pos
    jsr DrawText

    SET_PTR text_ptr_lo, menu_start_text
    lda #8
    sta text_x_pos
    lda #18
    sta text_y_pos
    jsr DrawText

    ; Reset scroll
    lda #0
    sta scroll_x
    sta scroll_y
    sta fade_level

    RENDER_ON
    rts

; ---- Handler ----
.export HandleMenu
HandleMenu:
    ; --- DOWN: move cursor from 0→1 ---
    lda pad1_new
    and #BTN_DOWN
    beq @check_up
    lda menu_cursor
    cmp #1
    beq @check_up          ; Already at bottom
    lda #1
    sta menu_cursor
    jsr DrawMenuArrows
    jmp @check_confirm

@check_up:
    ; --- UP: move cursor from 1→0 ---
    lda pad1_new
    and #BTN_UP
    beq @check_confirm
    lda menu_cursor
    cmp #0
    beq @check_confirm     ; Already at top
    lda #0
    sta menu_cursor
    jsr DrawMenuArrows

@check_confirm:
    ; --- START or A to confirm ---
    lda pad1_new
    and #(BTN_START | BTN_A)
    beq @menu_done

    lda menu_cursor
    bne @select_title
    ; CONTINUE → go to VS screen (full rematch)
    PLAY_SFX #SFX_START
    STATE_CHANGE STATE_VS
    jmp @menu_done

@select_title:
    ; START NEW GAME → title screen
    PLAY_SFX #SFX_START
    STATE_CHANGE STATE_TITLE

@menu_done:
    rts

; DrawMenuArrows — update the two arrow columns via BG update buffer.
; Row 15 = option 0, Row 18 = option 1.  Puts ">" on the selected row, " " on the other.
DrawMenuArrows:
    lda menu_cursor
    beq @cursor_top

    ; Cursor on option 1 (row 18): blank top, arrow bottom
    SET_PTR text_ptr_lo, menu_blank_arrow
    lda #6
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawTextBuffered

    SET_PTR text_ptr_lo, menu_arrow_text
    lda #6
    sta text_x_pos
    lda #18
    sta text_y_pos
    jsr DrawTextBuffered
    rts

@cursor_top:
    ; Cursor on option 0 (row 15): arrow top, blank bottom
    SET_PTR text_ptr_lo, menu_arrow_text
    lda #6
    sta text_x_pos
    lda #15
    sta text_y_pos
    jsr DrawTextBuffered

    SET_PTR text_ptr_lo, menu_blank_arrow
    lda #6
    sta text_x_pos
    lda #18
    sta text_y_pos
    jsr DrawTextBuffered
    rts

; ---- Menu Text Data ----
menu_header_text:
    .asciiz "SELECT ACTION"
menu_continue_text:
    .asciiz "CONTINUE"
menu_start_text:
    .asciiz "START NEW GAME"
menu_arrow_text:
    .asciiz ">"
menu_blank_arrow:
    .asciiz " "

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
    SKIP_IF_BG_QUEUE_FULL @tc_skip
    ldx bg_update_byte_idx
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
    stx bg_update_byte_idx
    inc bg_update_count      ; One more 3-byte entry queued

    ; Advance X position
    inc text_x_pos
    lda text_x_pos
    cmp #28                 ; Right margin
    bcc @tc_done
    lda #STORY_X            ; Wrap to next line
    sta text_x_pos
    inc text_y_pos
@tc_done:
@tc_skip:
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