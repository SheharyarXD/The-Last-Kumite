# THE LAST KUMITE — NES Architecture Document

## 1. Project Overview

**Game:** The Last Kumite — 1-Level NES Demo
**Platform:** Nintendo Entertainment System (NTSC NES)
**Mapper:** NROM-256 (Mapper 0)
**PRG-ROM:** 32KB (2 banks × 16KB)
**CHR-ROM:** 8KB (1 bank × 8KB)
**Output:** `last_kumite.nes` (iNES format)

## 2. Memory Map

### 2.1 CPU Memory Map (NROM-256)

```
$0000-$00FF   Zero Page (256 bytes) — Fast variables, pointers
$0100-$01FF   Stack (256 bytes)
$0200-$02FF   Sprite OAM buffer (256 bytes, DMA'd to PPU each frame)
$0300-$03FF   Audio engine buffers & temporary storage
$0400-$04FF   Game state variables, flags
$0500-$05FF   Player state (Michael Rivers)
$0600-$06FF   Enemy state (Lightning)
$0700-$07FF   Combat system, input buffer, scratch
$0800-$1FFF   Unused (mirrors $0000-$07FF)
$2000-$2007   PPU I/O Registers
$4000-$4015   APU I/O Registers
$4016-$4017   Controller registers
$6000-$7FFF   Unused (no PRG-RAM)
$8000-$BFFF   PRG-ROM Bank 0 (fixed)
$C000-$FFFF   PRG-ROM Bank 1 (fixed, contains vectors)
```

### 2.2 Zero Page Layout ($0000-$00FF)

```
$0000-$000F   NMI / Frame variables
  $0000  nmiflag          ; Set to 1 during NMI, game loop waits on it
  $0001  framecounter     ; Increments every NMI (60Hz)
  $0002  framecounter_hi  ; Upper byte for longer timing
  $0003  scroll_x         ; BG scroll X position
  $0004  scroll_y         ; BG scroll Y position
  $0005  ppu_ctrl         ; Cached PPUCTRL value
  $0006  ppu_mask         ; Cached PPUMASK value
  $0007  gamestate        ; Current game state ID
  $0008  next_gamestate   ; Pending state transition
  $0009  state_timer      ; State-local timer
  $000A  state_initialized; Flag: 1 if current state was initialized
  $000B  pause_flag       ; 1 = paused
  $000C  temp1            ; General temp
  $000D  temp2            ; General temp
  $000E  temp3            ; General temp
  $000F  temp4            ; General temp

$0010-$001F   Input system
  $0010  pad1_prev        ; Previous frame buttons
  $0011  pad1_new         ; Newly pressed buttons this frame
  $0011  pad1_held        ; Currently held buttons (alias for work)
  $0012  pad2_prev        ; Controller 2 (unused but read)
  $0013  pad2_new
  $0014  combo_buffer     ; Combo input buffer index
  $0015  combo_timer      ; Frames remaining in combo window
  $0016  special_cooldown ; Frames until special can be used again
  $0017  input_buffer[8]  ; Circular buffer for combo detection ($17-$1E)
  $001F  block_timer      ; Block recovery frames

$0020-$002F   Rendering / PPU
  $0020  oam_index        ; Next free OAM slot
  $0021  nametable        ; Current nametable (0 or 1)
  $0022  render_flag      ; 1 = rendering enabled this frame
  $0023  bg_update_ptr    ; Pointer to pending BG update data
  $0024  bg_update_count  ; Number of BG tiles to update
  $0025-$002F  reserved

$0030-$004F   Global game
  $0030  match_timer      ; Match countdown timer (seconds)
  $0031  match_timer_sub  ; Sub-frames for timer
  $0032  screen_shake_x   ; Screen shake offset X
  $0033  screen_shake_y   ; Screen shake offset Y
  $0034  shake_timer      ; Screen shake duration
  $0035  vs_screen_timer  ; VS intro display timer
  $0036  death_type       ; Random death type (0-3) for game over
  $0037-$003F  reserved

$0040-$005F   Player state (Michael Rivers)
  $0040  plr_x            ; X position (pixel, 0-255)
  $0041  plr_y            ; Y position (pixel, 0-239)
  $0042  plr_state        ; Animation/action state
  $0043  plr_frame        ; Current animation frame
  $0044  plr_frametimer   ; Frames until next anim frame
  $0045  plr_dir          ; Facing direction (0=right, 1=left)
  $0046  plr_hp           ; Health (0-100)
  $0047  plr_hp_disp      ; Displayed health (for bar animation)
  $0048  plr_vel_x        ; X velocity (signed, subpixel in lower nibble)
  $0049  plr_vel_y        ; Y velocity (signed, for jumps)
  $004A  plr_grounded     ; 1 = on ground
  $004B  plr_block        ; 1 = blocking
  $004C  plr_hitstun      ; Frames remaining in hit stun
  $004D  plr_atk_active   ; 1 = attack hitbox active
  $004E  plr_atk_type     ; Current attack type (punch/kick/jump)
  $004F  plr_atk_timer    ; Frames remaining in attack
  $0050  plr_atk_hit      ; 1 = attack already connected (no double hits)
  $0051  plr_stunned      ; 1 = stunned by special
  $0052  plr_stun_timer   ; Stun duration remaining
  $0053  plr_cooldown     ; Attack cooldown frames
  $0054-$005F  reserved

$0060-$007F   Enemy state (Lightning)
  $0060  en_x             ; X position
  $0061  en_y             ; Y position
  $0062  en_state         ; Animation/action state
  $0063  en_frame         ; Current animation frame
  $0064  en_frametimer    ; Frames until next anim frame
  $0065  en_dir           ; Facing direction
  $0066  en_hp            ; Health (0-80)
  $0067  en_hp_disp       ; Displayed health
  $0068  en_vel_x         ; X velocity
  $0069  en_vel_y         ; Y velocity
  $006A  en_grounded      ; 1 = on ground
  $006B  en_block         ; 1 = blocking
  $006C  en_hitstun       ; Frames remaining in hit stun
  $006D  en_atk_active    ; 1 = attack hitbox active
  $006E  en_atk_type      ; Current attack type
  $006F  en_atk_timer     ; Frames remaining in attack
  $0070  en_atk_hit       ; 1 = attack already connected
  $0071  en_stunned       ; 1 = stunned
  $0072  en_stun_timer    ; Stun duration remaining
  $0073  en_cooldown      ; Attack cooldown
  $0074  en_ai_state      ; AI behavioral state
  $0075  en_ai_timer      ; AI decision timer
  $0076  en_aggro         ; 1 = aggressive mode (HP < 30%)
  $0077  en_dash_timer    ; Dash duration / cooldown
  $0078  en_react_timer   ; Reaction delay timer
  $0079-$007F  reserved

$0080-$009F   Combat system
  $0080  plr_hitbox_x1    ; Player attack hitbox left
  $0081  plr_hitbox_x2    ; Player attack hitbox right
  $0082  plr_hitbox_y1    ; Player attack hitbox top
  $0083  plr_hitbox_y2    ; Player attack hitbox bottom
  $0084  en_hitbox_x1     ; Enemy attack hitbox left
  $0085  en_hitbox_x2     ; Enemy attack hitbox right
  $0086  en_hitbox_y1     ; Enemy attack hitbox top
  $0087  en_hitbox_y2     ; Enemy attack hitbox bottom
  $0088  plr_body_x1      ; Player hurtbox left
  $0089  plr_body_x2      ; Player hurtbox right
  $008A  plr_body_y1      ; Player hurtbox top
  $008B  plr_body_y2      ; Player hurtbox bottom
  $008C  en_body_x1       ; Enemy hurtbox left
  $008D  en_body_x2       ; Enemy hurtbox right
  $008E  en_body_y1       ; Enemy hurtbox top
  $008F  en_body_y2       ; Enemy hurtbox bottom
  $0090  combo_count      ; Current combo hit counter
  $0091  combo_display_t  ; Combo text display timer
  $0092  knockback_x      ; Shared knockback value
  $0093  hit_freeze       ; Hitstop frames remaining
  $0094  hit_flash_timer  ; White flash on hit
  $0095  special_effect_t ; Special move visual effect timer
  $0096-$009F  reserved

$00A0-$00CF  Text / Story rendering
  $00A0  text_ptr_lo      ; Current text pointer (16-bit)
  $00A1  text_ptr_hi
  $00A2  text_x           ; Text cursor X position
  $00A3  text_y           ; Text cursor Y position
  $00A4  text_delay       ; Frames between characters
  $00A5  text_timer       ; Countdown to next character
  $00A6  text_state       ; 0=waiting, 1=typing, 2=done, 3=waiting_advance
  $00A7  text_page        ; Current page of story text
  $00A8  text_total_pages ; Total pages for current scene
  $00A9-$00AF  reserved

$00B0-$00CF  Sound engine
  $00B0  sfx_timer        ; SFX duration timer
  $00B1  sfx_channel      ; Current SFX channel
  $00B2  music_beat       ; Music beat counter
  $00B3  music_tempo      ; Frames per beat
  $00B4-$00CF  reserved

$00D0-$00FF  Reserved for future / stack safety
```

## 3. Game State Machine

```
STATE_TITLE     (0)  → Title screen with "THE LAST KUMITE" / "PRESS START"
                         → START pressed → STATE_INTRO

STATE_INTRO     (1)  → Story text scroll sequence
                         → All text complete + START → STATE_FIGHT (after VS screen)

STATE_FIGHT     (2)  → Main combat gameplay
                         → Player HP = 0 → STATE_LOSE
                         → Enemy HP = 0 → STATE_WIN
                         → TIME = 0 → Compare HP → STATE_WIN or STATE_LOSE

STATE_VS        (3)  → VS screen display ("MICHAEL RIVERS vs LIGHTNING")
                         → Timer expires → STATE_FIGHT

STATE_WIN       (4)  → "LIGHTNING DEFEATED. ENTRY GRANTED."
                         → START pressed → STATE_GAMEOVER (demo ends)

STATE_LOSE      (5)  → Brief KO message
                         → Timer expires → STATE_GAMEOVER

STATE_GAMEOVER  (6)  → Ron Hall cutscene + death text
                         → START pressed → STATE_TITLE
```

## 4. Player Character States (Michael Rivers)

```
PLR_IDLE        (0)  → Standing, can do anything
PLR_WALK        (1)  → Moving left/right
PLR_CROUCH      (2)  → Holding down, crouched
PLR_JUMP        (3)  → Rising/falling
PLR_PUNCH       (4)  → Punch attack
PLR_KICK        (5)  → Kick attack
PLR_BLOCK       (6)  → Blocking (hold back)
PLR_HIT         (7)  → Hit reaction/taking damage
PLR_KO          (8)  → Knocked out
PLR_SPECIAL     (9)  → Performing special move
```

## 5. Enemy AI States (Lightning)

```
AI_IDLE         (0)  → Brief pause between actions
AI_APPROACH     (1)  → Move toward player (dash when far)
AI_ATTACK       (2)  → Execute attack (punch/kick)
AI_RETREAT      (3)  → Move away to create distance
AI_ANTIAIR      (4)  → Anti-air attack (when player jumps)
AI_BLOCK        (5)  → Blocking
AI_STUNNED      (6)  → Stunned by special move
AI_DASH         (7)  → Fast dash attack
AI_KO           (8)  → Knocked out
```

## 6. AI Decision Logic (Lightning)

```
Every 8-15 frames (varies by difficulty context):

1. If stunned → AI_STUNNED (no action)
2. If player just jumped AND random < 60% → AI_ANTIAIR
3. If distance > 80 pixels → AI_APPROACH (dash)
4. If distance < 40 pixels → AI_ATTACK (70%) or AI_BLOCK (30%)
5. If HP < 30% (24 HP):
   - Approach faster
   - Attack more frequently
   - Less blocking
   - AI_DASH probability increases
6. After any action, set random recovery timer (4-12 frames)
```

## 7. Combat System

### 7.1 Hit Detection
- Each active attack defines a hitbox (4 bytes: x1, x2, y1, y2)
- Each character has a hurtbox (body box)
- Collision = rectangle overlap test
- Performed only when `atk_active = 1` and `atk_hit = 0`

### 7.2 Damage Values
```
Attack          Damage    Hitstop    Knockback
─────────────────────────────────────────────
Punch           5         6 frames   2 pixels
Kick           10         8 frames   4 pixels
Jump Attack    12        10 frames   6 pixels
Special Stun    0        12 frames   0 pixels (stun 90 frames)
Blocked         /3        4 frames   1 pixel
```

### 7.3 Blocking
- Player: hold LEFT when facing RIGHT, or hold RIGHT when facing LEFT
- Block reduces damage to 1/3 (rounded up: punch=2, kick=4, jump=4)
- Block still causes small knockback and brief hitstop
- Cannot block special stun (it bypasses block)

### 7.4 Knockback
- On hit: velocity set to knockback value in opposite direction
- Character enters PLR_HIT / EN_HIT state for hitstun duration
- Hitstun: punch=15f, kick=20f, jump=25f, blocked=8f
- During hitstun: cannot act, no collision

### 7.5 Special Move: Perfect Guard Counter
- Input: ↓ + B + A (within 8-frame window)
- Cooldown: 180 frames (3 seconds)
- Effect: If enemy is in attack range, stuns them for 90 frames (1.5s)
- Visual: Flash effect on both characters
- During stun: Enemy cannot move or attack, takes double damage

## 8. Input System

### 8.1 Button Layout
```
D-Pad Left:   Move left / Block (when facing right)
D-Pad Right:  Move right / Block (when facing left)
D-Pad Up:     Jump
D-Pad Down:   Crouch
A Button:     Punch
B Button:     Kick
Start:        Pause / Advance text / Start game
```

### 8.2 Combo Detection
```
Input buffer: 8 entries, circular
Each entry: (button_byte, direction_byte, framestamp)
Special detection:
  Look for DOWN in last 8 frames + B pressed + A pressed
  Window: within 8 frames total
  On match: trigger special if cooldown <= 0 and state allows
```

## 9. CHR-ROM Layout (8KB)

```
Pattern Table 0 ($0000-$0FFF) — Background tiles
$0000-$007F   Blank / space tiles
$0080-$00FF   Alphabet tiles (A-Z)
$0100-$017F   Numbers and punctuation
$0180-$01FF   Title screen decorative elements
$0200-$02FF   Background stage tiles (outdoor fighting area)
$0300-$03FF   HUD elements (health bar, timer, VS)
$0400-$04FF   UI borders, panels, text boxes
$0500-$05FF   Ron Hall cutscene tiles
$0600-$06FF   Reserved
$0700-$07FF   Reserved

Pattern Table 1 ($1000-$1FFF) — Sprite tiles
$1000-$10FF   Michael Rivers: idle frames
$1100-$11FF   Michael Rivers: walk frames
$1200-$12FF   Michael Rivers: punch/kick frames
$1300-$13FF   Michael Rivers: jump, crouch, hit frames
$1400-$14FF   Lightning: idle frames
$1500-$15FF   Lightning: walk/dash frames
$1600-$16FF   Lightning: attack frames
$1700-$17FF   Lightning: hit, block, KO frames
$1800-$18FF   Hit effects (impact stars, flash)
$1900-$19FF   Special effects (stun aura, counter flash)
$1A00-$1AFF   Reserved
$1B00-$1BFF   Reserved
$1C00-$1CFF   Reserved
$1D00-$1DFF   Reserved
$1E00-$1EFF   Reserved
$1F00-$1FFF   Reserved
```

## 10. Build System

```
Toolchain: ca65 (assembler) + ld65 (linker)
Configuration: last_kumite.cfg (ld65 linker script)
Output: last_kumite.nes (iNES format)

Build steps:
1. Assemble each .asm file to .o object files
2. Link all objects with .cfg file
3. Add iNES header (16 bytes) to final binary

Makefile targets:
  make          → Build ROM
  make clean    → Remove build artifacts
  make run      → Launch in emulator (Mesen)
```

## 11. Optimization Strategy for NES

1. **Sprite Limit:** Max 64 sprites, 8 per scanline. Characters use 4×4 metasprites (16 sprites each). Effects use 1-2 sprites.
2. **CHR Constraints:** 256 tiles per pattern table. Characters share frames where possible (walking mirrored).
3. **CPU Budget:** Target < 2000 cycles per frame for logic (≈30% of available 2273 cycles during VBlank + rendering).
4. **No MMC needed:** NROM is sufficient for 1-level demo. All data fits in 32KB PRG.
5. **Background updates:** Only update changed tiles (health bar changes), not full screen.
6. **Fixed-point math:** Subpixel positions use 8.8 format (1 byte pixel + 1 byte subpixel where needed).
7. **Look-up tables:** Sin/cos for jumps, damage values, AI probabilities — all table-based.
8. **State coherency:** Single-byte state variables, clear state entry/exit functions.
