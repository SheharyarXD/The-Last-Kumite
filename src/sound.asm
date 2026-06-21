; THE LAST KUMITE — APU Sound Driver
; Simple square wave SFX, no music engine (scope-limited)
; ============================================================================

.segment "CODE"

; =============================================================================
; INIT SOUND — Setup APU channels
; =============================================================================
.export InitSound
InitSound:
    lda #0
    sta sfx_timer
    sta sfx_channel
    sta sfx_priority
    sta music_timer
    sta music_note_idx
    sta sfx_queue_type
    sta sfx_queue_timer

    ; Enable pulse 1, pulse 2, noise
    lda #%00001111
    sta APU_CTRL
    rts

; =============================================================================
; UPDATE SOUND — Process SFX queue
; =============================================================================
.export UpdateSound
UpdateSound:
    ; Process queued SFX
    lda sfx_queue_type
    beq @update_active_sfx

    ; Start new SFX
    jsr StartSFX
    lda #0
    sta sfx_queue_type

@update_active_sfx:
    lda sfx_timer
    beq @sound_done
    dec sfx_timer
    bne @sound_done
    ; SFX ended, silence channel
    jsr SilenceSFX
@sound_done:
    rts

; =============================================================================
; START SFX — Begin playing a sound effect
; =============================================================================
StartSFX:
    lda sfx_queue_type
    cmp #SFX_PUNCH
    beq @sfx_punch
    cmp #SFX_KICK
    beq @sfx_kick
    cmp #SFX_HIT
    beq @sfx_hit
    cmp #SFX_BLOCK
    beq @sfx_block
    cmp #SFX_SPECIAL
    beq @sfx_special
    cmp #SFX_SPECIAL_HIT
    beq @sfx_special_hit
    cmp #SFX_JUMP
    beq @sfx_jump
    cmp #SFX_LAND
    beq @sfx_land
    cmp #SFX_KO_DOWN
    beq @sfx_ko_down
    cmp #SFX_START
    beq @sfx_start
    rts

; ---- Punch: Short noise burst ----
@sfx_punch:
    lda #%00001000          ; Volume 8, no decay
    sta APU_NOISE_VOL
    lda #$0C                ; Medium-high frequency
    sta APU_NOISE_PERIOD
    lda #8                  ; Short duration
    sta APU_NOISE_LEN
    lda #4
    sta sfx_timer
    lda #3                  ; Noise channel
    sta sfx_channel
    rts

; ---- Kick: Deeper noise burst ----
@sfx_kick:
    lda #%00001100          ; Volume 12
    sta APU_NOISE_VOL
    lda #$08                ; Lower frequency
    sta APU_NOISE_PERIOD
    lda #10
    sta APU_NOISE_LEN
    lda #6
    sta sfx_timer
    lda #3
    sta sfx_channel
    rts

; ---- Hit: Sharp pulse tone ----
@sfx_hit:
    lda #%10011111          ; Duty 50%, volume 15, decay
    sta APU_SQ1_VOL
    lda #$08                ; Sweep down
    sta APU_SQ1_SWEEP
    lda #$85                ; Frequency (C#5)
    sta APU_SQ1_TIMER
    lda #8
    sta APU_SQ1_LEN
    lda #6
    sta sfx_timer
    lda #0
    sta sfx_channel
    rts

; ---- Block: Dull thud ----
@sfx_block:
    lda #%10000110
    sta APU_SQ2_VOL
    lda #$00
    sta APU_SQ2_SWEEP
    lda #$40                ; Low frequency
    sta APU_SQ2_TIMER
    lda #6
    sta APU_SQ2_LEN
    lda #4
    sta sfx_timer
    lda #1
    sta sfx_channel
    rts

; ---- Special: Rising tone ----
@sfx_special:
    lda #%10101111          ; Duty 75%, volume 15
    sta APU_SQ1_VOL
    lda #$09                ; Sweep up
    sta APU_SQ1_SWEEP
    lda #$60
    sta APU_SQ1_TIMER
    lda #20
    sta APU_SQ1_LEN
    lda #15
    sta sfx_timer
    lda #0
    sta sfx_channel
    rts

; ---- Special Hit: Impact chord ----
@sfx_special_hit:
    ; Pulse 1: high ping
    lda #%10011111
    sta APU_SQ1_VOL
    lda #$0A
    sta APU_SQ1_SWEEP
    lda #$A0
    sta APU_SQ1_TIMER
    lda #15
    sta APU_SQ1_LEN
    ; Pulse 2: lower harmony
    lda #%10101111
    sta APU_SQ2_VOL
    lda #$00
    sta APU_SQ2_SWEEP
    lda #$50
    sta APU_SQ2_TIMER
    lda #15
    sta APU_SQ2_LEN
    lda #20
    sta sfx_timer
    lda #0
    sta sfx_channel
    rts

; ---- Jump: Short blip ----
@sfx_jump:
    lda #%10000101
    sta APU_SQ2_VOL
    lda #$00
    sta APU_SQ2_SWEEP
    lda #$C0
    sta APU_SQ2_TIMER
    lda #3
    sta APU_SQ2_LEN
    lda #3
    sta sfx_timer
    lda #1
    sta sfx_channel
    rts

; ---- Land: Soft thud ----
@sfx_land:
    lda #%00000100
    sta APU_NOISE_VOL
    lda #$10
    sta APU_NOISE_PERIOD
    lda #3
    sta APU_NOISE_LEN
    lda #3
    sta sfx_timer
    lda #3
    sta sfx_channel
    rts

; ---- KO Down: Descending tone ----
@sfx_ko_down:
    lda #%10011111
    sta APU_SQ1_VOL
    lda #%10000101          ; Sweep down fast
    sta APU_SQ1_SWEEP
    lda #$80
    sta APU_SQ1_TIMER
    lda #30
    sta APU_SQ1_LEN
    lda #25
    sta sfx_timer
    lda #0
    sta sfx_channel
    rts

; ---- Start: Confirmation beep ----
@sfx_start:
    lda #%10001111
    sta APU_SQ1_VOL
    lda #$00
    sta APU_SQ1_SWEEP
    lda #$B0
    sta APU_SQ1_TIMER
    lda #10
    sta APU_SQ1_LEN
    lda #8
    sta sfx_timer
    lda #0
    sta sfx_channel
    rts

; =============================================================================
; SILENCE SFX — Turn off current SFX channel
; =============================================================================
SilenceSFX:
    lda sfx_channel
    beq @silence_sq1
    cmp #1
    beq @silence_sq2
    ; Noise
    lda #0
    sta APU_NOISE_VOL
    rts
@silence_sq1:
    lda #0
    sta APU_SQ1_VOL
    rts
@silence_sq2:
    lda #0
    sta APU_SQ2_VOL
    rts

; =============================================================================
; SFX PLAY HELPERS — Called from gameplay code
; =============================================================================
.export PlaySFXPunch
PlaySFXPunch:
    lda #SFX_PUNCH
    sta sfx_queue_type
    rts

.export PlaySFXKick
PlaySFXKick:
    lda #SFX_KICK
    sta sfx_queue_type
    rts

.export PlaySFXHit
PlaySFXHit:
    lda #SFX_HIT
    sta sfx_queue_type
    rts

.export PlaySFXBlock
PlaySFXBlock:
    lda #SFX_BLOCK
    sta sfx_queue_type
    rts

.export PlaySFXSpecial
PlaySFXSpecial:
    lda #SFX_SPECIAL
    sta sfx_queue_type
    rts

.export PlaySFXSpecialHit
PlaySFXSpecialHit:
    lda #SFX_SPECIAL_HIT
    sta sfx_queue_type
    rts

.export PlaySFXJump
PlaySFXJump:
    lda #SFX_JUMP
    sta sfx_queue_type
    rts

.export PlaySFXLand
PlaySFXLand:
    lda #SFX_LAND
    sta sfx_queue_type
    rts

.export PlaySFXKODown
PlaySFXKODown:
    lda #SFX_KO_DOWN
    sta sfx_queue_type
    rts

.export PlaySFXStart
PlaySFXStart:
    lda #SFX_START
    sta sfx_queue_type
    rts

; =============================================================================
; SFX ID CONSTANTS
; =============================================================================
SFX_PUNCH       = 1
SFX_KICK        = 2
SFX_HIT         = 3
SFX_BLOCK       = 4
SFX_SPECIAL     = 5
SFX_SPECIAL_HIT = 6
SFX_JUMP        = 7
SFX_LAND        = 8
SFX_KO_DOWN     = 9
SFX_START       = 10
