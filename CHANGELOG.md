# Changelog — Real Sprites, VS Portraits, Game Over Thumbs-Down, HUD Fixes

This pass replaced the placeholder art with real character sprites and
fixed several bugs found by actually running the ROM in FCEUX (not just
reading the source), including the one that mattered most: **the Game
Over thumbs-down screen could never appear at all.**

## Critical bug fixes

1. **GAMEOVER state was unreachable.** `HandleLose` (src/state_machine.asm)
   jumped straight to the post-game menu, skipping `STATE_GAMEOVER`
   entirely, even though `InitGameOver`/`HandleGameOver`/`RenderGameOver`
   were fully implemented. Fixed: LOSE now correctly transitions to
   GAMEOVER, which waits for Start before going to the menu.

2. **`RenderFrame` never called `RenderGameOver`.** The top-level render
   dispatcher (src/main.asm) only special-cased FIGHT/VS/TITLE; GAMEOVER
   fell through to a no-op. This meant even after fixing bug #1, the
   thumbs-down sprite and the blinking "PRESS START" text still wouldn't
   draw. Added the missing dispatch case.

3. **VS screen "VS" text was being silently overwritten.** "MICHAEL
   RIVERS" (14 characters, drawn at column 2) was drawn *after* "VS"
   (drawn at column 14) on the same text row, and 2+14-1=15 overlaps
   column 14 -- so the name text clobbered the V of VS every time. Moved
   VS to its own row.

4. **Sprite palette bug:** Michael's and Lightning's pants/hair rendered
   as pale cream instead of dark/black, because the in-game sprite
   palette's 3rd color slot was a light skin tone, but the quantizer
   routed all near-black source pixels into that slot. Re-pointed slot 3
   at black ($0F) in init.asm and adjusted the art pipeline to match.

5. **VS screen used the wrong palettes entirely** -- Michael's portrait
   was drawn in Lightning's blue palette, and Lightning's was drawn in
   the yellow effects palette. Fixed to use each fighter's own palette.

6. **`temp_mul_result` (gameover.asm) was declared in the CODE segment**,
   which is ROM on NES -- writes to it silently went nowhere, so the
   thumbs-down portrait's row-multiply always returned the same baked-in
   value and every row of the image repeated the same 7 tiles. Moved it
   to a real zero-page byte (declared in zeropage.asm).

## Art replaced

- **Fighter sprites** (`tools/author_sprites.py`): rebuilt from bare
  color-block rectangles into recognizable gi-wearing fighters --
  headband, gi top, sash, dark pants, gold hands/feet -- following the
  pose language and palette of the two reference sheets you provided
  (`assets/sprites char (1).png`, `assets/Design2-juanjuanh-BC802-
  IMAGE1-1.png`).
- **VS screen portraits** (`tools/author_vs_portraits.py`, new): real
  bust portraits for both fighters replace the old solid-color blocks.
- **Game Over thumbs-down art** (`tools/author_gameover.py`, new): a
  56x56px sprite portrait of Ron Hall giving the thumbs-down, guided by
  your `assets/thumbs.png` reference, replacing what used to be text-only.
- **Fight stage background** (`tools/bg_convert.py`): the castle
  background was converting into dithered visual noise that competed
  with the HUD and characters for visibility. Added a blur pre-pass and a
  pattern-similarity fallback (instead of average-brightness snapping)
  for tiles that exceed the 96-tile hardware budget -- same source art,
  far cleaner result.

## HUD robustness

Added an overflow guard (`SKIP_IF_BG_QUEUE_FULL` macro in macros.asm) at
every site that queues a background-tile update, so a frame that happens
to need more than 32 queued updates drops the excess instead of
overflowing into adjacent zero-page memory and corrupting unrelated
state. This was a latent risk, not something reproduced in normal play,
but it's the kind of bug that would show up as "HUD glitches sometimes"
without an obvious cause.

## How to rebuild

```
make clean && make
```
produces `build/TheLastKumite.nes`. Requires `cc65`/`ca65`/`ld65` and
Python 3 with Pillow (`pip install Pillow`). If you change any of the
`chr/src_frames/*.png` art, re-run `python3 tools/chr_convert.py` (and
`tools/bg_convert.py` if you change `assets/32732.png`) before `make`.

## Tested

Built and run end-to-end in FCEUX (headless, via Lua test scripts) through:
TITLE -> INTRO -> VS -> FIGHT -> WIN, and separately TITLE -> INTRO -> VS
-> FIGHT -> LOSE -> GAMEOVER -> MENU, confirming the HUD, VS portraits,
and thumbs-down screen all render correctly at multiple points after each
state transition (not just the transition frame, which can show a
one-frame render artifact in any NES game due to PPU/DMA timing).
