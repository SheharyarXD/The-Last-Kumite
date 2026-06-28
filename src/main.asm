; THE LAST KUMITE — Main Game Loop
; Central execution flow: NMI wait → Input → Update → Render
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "CODE"

; =============================================================================
; MAIN LOOP — Heart of the game
; =============================================================================
.export MainLoop
MainLoop:
    ; -------------------------------------------------------------------------
    ; Wait for NMI (vertical blank) — locks to 60 FPS
    ; -------------------------------------------------------------------------
    WAIT_NMI

    ; -------------------------------------------------------------------------
    ; Clear OAM buffer for this frame
    ; -------------------------------------------------------------------------
    lda #0
    sta oam_index
    CLEAR_OAM

    ; -------------------------------------------------------------------------
    ; If hit freeze active, skip most updates but still render
    ; -------------------------------------------------------------------------
    lda hit_freeze
    beq @no_freeze
    dec hit_freeze
    jmp @render_frame
@no_freeze:

    ; -------------------------------------------------------------------------
    ; Read controller input
    ; -------------------------------------------------------------------------
    jsr ReadControllers
    jsr UpdateComboBuffer

    ; -------------------------------------------------------------------------
    ; Process game state
    ; -------------------------------------------------------------------------
    jsr ProcessState

    ; -------------------------------------------------------------------------
    ; Render frame
    ; -------------------------------------------------------------------------
@render_frame:
    jsr RenderFrame

    ; -------------------------------------------------------------------------
    ; Sound update
    ; -------------------------------------------------------------------------
    jsr UpdateSound

    ; Loop forever
    jmp MainLoop

; =============================================================================
; PROCESS STATE — Main state machine dispatcher
; =============================================================================
ProcessState:
    ; Check for pending state change
    lda next_gamestate
    cmp gamestate
    beq @state_same

    ; State transition!
    lda next_gamestate
    sta gamestate
    lda #0
    sta state_initialized   ; New state needs initialization
    sta state_timer
@state_same:

    ; Initialize state if needed
    lda state_initialized
    bne @state_ready
    jsr InitCurrentState
    lda #1
    sta state_initialized
@state_ready:

    ; Dispatch to state handler
    lda gamestate
    asl                     ; ×2 for jump table
    tax
    lda state_jump_table, x
    sta temp1
    lda state_jump_table + 1, x
    sta temp2
    jmp (temp1)

; =============================================================================
; STATE JUMP TABLE
; =============================================================================
state_jump_table:
    .word HandleTitle       ; 0
    .word HandleIntro       ; 1
    .word HandleVS          ; 2
    .word HandleFight       ; 3
    .word HandleWin         ; 4
    .word HandleLose        ; 5
    .word HandleGameOver    ; 6
    .word HandleMenu        ; 7

; =============================================================================
; INIT CURRENT STATE — One-time setup for each state
; =============================================================================
InitCurrentState:
    lda gamestate
    asl
    tax
    lda init_jump_table, x
    sta temp1
    lda init_jump_table + 1, x
    sta temp2
    jmp (temp1)

init_jump_table:
    .word InitTitle
    .word InitIntro
    .word InitVS
    .word InitFight
    .word InitWin
    .word InitLose
    .word InitGameOver
    .word InitMenu

; =============================================================================
; RENDER FRAME — Top-level render dispatcher
; =============================================================================
RenderFrame:
    lda gamestate
    cmp #STATE_FIGHT
    beq @render_fight
    cmp #STATE_VS
    beq @render_vs
    cmp #STATE_TITLE
    beq @render_title
    cmp #STATE_GAMEOVER
    beq @render_gameover
    ; Default: basic sprite render for all states
@render_basic:
    jsr RenderBasicSprites
    jmp @render_done
@render_fight:
    jsr RenderFight
    jmp @render_done
@render_vs:
    jsr RenderVS
    jmp @render_done
@render_title:
    jsr RenderTitle
    jmp @render_done
@render_gameover:
    jsr RenderGameOver
@render_done:
    ; Apply fade level
    jsr FadeUpdate
    rts

; =============================================================================
; RENDER BASIC SPRITES — Fallback for states without special rendering
; =============================================================================
RenderBasicSprites:
    ; Update OAM DMA is done in NMI
    rts

; =============================================================================
; VSYNC WAIT HELPER
; =============================================================================
.export WaitFrames
WaitFrames:
    sta temp1
@wait_loop:
    WAIT_NMI
    dec temp1
    bne @wait_loop
    rts
