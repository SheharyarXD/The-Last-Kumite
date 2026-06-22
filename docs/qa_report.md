# THE LAST KUMITE — Final QA Report

## ROM builds successfully

```
$ make clean && make
[AS] src/init.asm ... [AS] src/vectors.asm   (17 files, zero errors/warnings)
[LD] Linking ROM...                          (zero errors/warnings)
[HEADER] Building final .nes...
ROM written: build/TheLastKumite.nes (40976 bytes)
```

Output: `build/TheLastKumite.nes`, 40,976 bytes = 16-byte iNES header +
32,768-byte PRG-ROM (2x16KB) + 8,192-byte CHR-ROM (1x8KB), exactly matching
the declared header values. Verified byte-for-byte identical between the
build directory and the packaged deliverable.

## Tested in emulator

FCEUX, run headless under Xvfb and driven by a Lua test script
(`tools/test_rom.lua`) that presses Start to advance game states, feeds
scripted movement/attack/block/special inputs during the fight, reads
zero-page game-state memory every frame, sets write-watchpoints to catch
specific value corruption, and captures PNG screenshots at every state
transition. This is the same methodology used throughout development, not
a separate lighter-weight check.

Two full scripted runs were executed against the final build: one tuned
toward a player win, one toward a player loss, to exercise both branches
of the match-end logic.

## Controls working

Verified via scripted input during the Fight state:

| Input | Confirmed |
|---|---|
| D-Pad Left/Right | Player X position updates, clamps at screen edges |
| D-Pad Down | Crouch entered, hurtbox shrinks |
| D-Pad Up | Jump entered, gravity + landing returns to idle correctly |
| A (Punch) | 5 damage applied to enemy on hit |
| B (Kick) | 10 damage applied to enemy on hit |
| Down+B+A | Special move triggers, cooldown enforced from both input paths |
| Start | Title->Intro, Intro page advance, Game Over->Title all confirmed |

Block was exercised indirectly (player holds back while enemy attacks)
and reduces damage taken.

## Fight flow working

Both full match outcomes confirmed end-to-end with screenshots:

- **Win:** Lightning's HP reduced to 0 -> WIN state -> "LIGHTNING
  DEFEATED" / "ENTRY GRANTED" rendered correctly.
- **Lose:** Michael's HP reduced to 0 -> LOSE state (frozen KO pose,
  ~2s) -> GAMEOVER state -> "GAME OVER" / "RON HALL GIVES THUMBS DOWN"
  / randomized death line / "PRESS START TO CONTINUE" all rendered
  correctly -> Start returns to Title.
- Match timer counts down from 60 in real time; HUD (names, both health
  bars, timer) updates correctly as HP changes throughout.
- Full Title -> Intro (4-page scrolling story text) -> VS screen -> Fight
  sequence confirmed on every run.

## Assets displaying correctly

- **Character sprites:** Michael Rivers and Lightning both render as
  real, color-distinguished 16x16 (2x2 metasprite) figures — red gi for
  Michael, blue gi for Lightning — built from the client's reference pose
  sheets via tools/author_sprites.py + tools/chr_convert.py. Verified
  visually in multiple screenshots across idle, walk, and attack frames.
- **Background:** The fight stage uses a converted version of the
  client's castle-ruins reference image (assets/32732.png), recognizable
  as a castle silhouette with towers, clouds, and a tree line, in a
  brown/olive palette. Replaces the prior single-color placeholder bands.
- **UI/HUD:** Fighter names, "VS", health bars (10 segments each), and
  the match timer all render and update correctly.
- **Title/Intro/VS/Win/GameOver text:** All confirmed legible and correct
  against the GDD's specified copy ("THE LAST KUMITE", "PRESS START",
  the intro story text, "MICHAEL RIVERS"/"LIGHTNING"/"VS", "LIGHTNING
  DEFEATED"/"ENTRY GRANTED", "GAME OVER"/"RON HALL GIVES THUMBS DOWN").

Not independently/audibly verified: sound effects (correct assembly,
linkage, and APU register usage confirmed; the test environment runs
FCEUX with audio disabled — see README "Known limitations").

## No crashes

- Zero assembler or linker errors/warnings on a clean build.
- Two full scripted runs (3,600+ frames / 60+ seconds of real-time
  gameplay each) completed without a hang, freeze, or unexpected state.
- FCEUX's own lag-frame counter was used during development specifically
  to catch a now-fixed startup deadlock (see docs/testing_report.md,
  bug #14) — confirmed not present in the current build (NMI fires every
  frame from boot, no lag frames after the initial setup).
- No "error", "crash", "invalid", or "illegal" messages in FCEUX's log
  output across either test run.

## Where to look for more detail

- docs/testing_report.md — full bug list (31 distinct issues found and
  fixed across both work sessions) with root cause and fix for each, plus
  the verification methodology in full.
- docs/architecture.md — memory map, state machine, CHR layout.
- docs/asset_pipeline.md — how the sprite/background conversion
  pipeline works and how to extend or replace the art.
- README.md — build instructions, controls, known limitations.
