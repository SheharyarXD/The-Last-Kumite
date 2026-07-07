# 16x32 Sprite Size Change

Player (Michael Rivers) and enemy (Lightning) sprites have been changed from
16x16 (2x2 tiles) to 16x32 (2x4 tiles).

## Code changes made

- `src/constants.asm`
  - `METASPRITE_W/H` and `SPRITES_PER_CHAR` updated to 2x4 (8 tiles).
  - `GROUND_Y` raised from 200 to 184 so feet still land on the same floor
    row now that the sprite is 16px taller (top-left Y anchor moves up).
- `src/ppu.asm`
  - `DrawMetasprite` rewritten to draw 8 tiles (4 rows x 2 cols, 32px tall)
    instead of 4 tiles. OAM headroom check updated (224 instead of 240).
- `src/player.asm` / `src/enemy.asm`
  - Hurtbox and every attack hitbox (punch/kick/jump/special/crouch-punch/
    crouch-kick/dash/anti-air) had their Y ranges rescaled to fit the taller
    body. X ranges are untouched since sprite width is still 16px.
- `src/zeropage.asm`
  - Repurposed unused DrawMetasprite scratch bytes into the new row-loop
    counters (`ms_row_y`, `ms_row_tile`, `ms_row_count`).
- `tools/chr_convert.py`
  - `sprite16_to_tiles` -> `sprite16x32_to_tiles`, slicing each authored
    frame into 8 tiles (2 wide x 4 tall) in the row-major order
    `DrawMetasprite` expects.
  - `load_frames` now hard-errors if a source sheet's frames aren't 16x32.
- `tools/author_sprites.py`
  - Canvas constant updated to 16x32.

## What you still need to do

1. **New art required.** `tools/author_sprites.py`'s pose-drawing functions
   still place pixels using the OLD 16x16 coordinate space, so right now it
   will produce 16x32 canvases with art squashed into the top half. Every
   pose (idle, walk, punch, kick, jump, crouch, block, hit, KO, etc.) needs
   its pixel coordinates re-authored for the taller canvas, OR you supply
   your own hand-drawn 16x32 sprite sheets directly (skipping
   author_sprites.py) as long as they match the `chr/src_frames/*_sheet.png`
   + `*_frames.txt` format `chr_convert.py` expects.
2. **Re-run the build pipeline** (`tools/author_sprites.py` if you use it,
   then `tools/chr_convert.py`, then your normal `build.bat`/`build_rom.py`)
   once new art is in place, so `chr/tiles.chr` and the `sprite_tiles_*.inc`
   files regenerate at the new size.
3. **Hitbox tuning.** The new hitbox Y ranges were scaled proportionally
   (roughly 2x) from the old 16px-tall values as a reasonable starting
   point, but you'll likely want to nudge them once you can see the actual
   32px-tall art in motion (e.g. exact reach of punches/kicks, anti-air
   coverage).
4. **OAM budget.** Each character now uses 8 OAM sprites instead of 4 (16
   total for both fighters instead of 8). This is well within the NES's
   64-sprite limit but leaves less headroom for simultaneous hit effects,
   stun effects, etc. if you add more visual effects later.

## Update: tile budget fix (9→8 frames) + build verified end-to-end

After the initial 16x32 change, `make chr`/`make bg` failed with a real
capacity problem: doubling tiles/frame (4→8) meant 17 animation frames per
character no longer fit in the 256-tile sprite pattern table alongside the
VS-portraits, gameover thumbs, and hit/stun effect tiles.

- Trimmed each character from 17 to **8 unique poses**: idle, walk, crouch,
  jump, punch, kick, hit, KO. `BLOCK` now reuses the `crouch` pose (both
  are low defensive stances) instead of having its own art.
- Every state now shows a single static pose — no more in-place animation
  cycling. `UpdatePlayerAnim`/`UpdateEnemyAnim` in `player.asm`/`enemy.asm`
  were simplified accordingly (the old per-state frame-cycling handlers
  are gone, since there's nothing left to cycle).
- `tools/chr_convert.py`'s reserved-tile handling (tile 242, hardcoded by
  `title.asm` for its sparkle sprite) was fixed to skip the *whole* gap
  before a static image starts, instead of only nudging by one tile mid-image
  (which caused a "fragmented" error once the fighter tile savings shifted
  where the static portraits land).
- Rebuilt `linker/nrom256.cfg` from scratch — the uploaded `.rar` was
  truncated and this file (plus a couple of build artifacts) came out
  empty/corrupted on extraction. Standard NROM-256 layout: flat 32KB PRG
  region padded to size, 6-byte vector table pinned at `$FFFA`.
- **Full build verified in this environment**: `make clean && make bg &&
  make` completes with no errors and produces a 40,976-byte `.nes` file
  (16-byte header + 32KB PRG + 8KB CHR — exactly right for NROM).

If you want smoother animation back later (e.g. a 2-frame walk cycle),
you'll need to free up more tile budget first — either drop one of the
static images from this pattern table, shrink `gameover_thumbs.png` (it's
the biggest single cost at 49 tiles), or move background/UI assets around.
