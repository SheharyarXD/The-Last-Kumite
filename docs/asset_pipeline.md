# Asset Pipeline

How client reference art becomes the CHR data the NES actually displays,
and how to re-run or extend each stage.

## Overview

```
assets/ (client reference art, full color, non-NES resolution)
   |
   |-- pose/color reference --> tools/author_sprites.py --> chr/src_frames/*.png
   |                                                              |
   |                                                              v
   |                                                    tools/chr_convert.py
   |                                                              |
   |-- 32732.png (castle bg) --> tools/bg_convert.py             |
              |                        |                          |
              v                        v                          v
      chr/tiles_bg.chr  <--------------+                          |
              |                                                   |
              +----------------------> chr/tiles.chr <------------+
                                              |
                                              v
                                      build/TheLastKumite.nes
```

Two independent things get merged into the final `chr/tiles.chr`:

- **Pattern table 0** (`chr/tiles_bg.chr`, background/UI/font/stage tiles)
- **Pattern table 1** (sprite tiles, written directly by `chr_convert.py`)

`chr_convert.py` is the final merge step and always reads
`chr/tiles_bg.chr` as-is, so background changes (`bg_convert.py`) and
sprite changes (`author_sprites.py`) can be made independently and then
combined with one `chr_convert.py` run.

## Character sprites

**Why not pixel-trace the reference photos/illustrations directly?**
`assets/sprites char (1).png` and `assets/Design2-*.png` are reference
sheets at roughly 40-60px-tall figures with full-color shading and
photographic proportions. An NES sprite frame is 16x16 pixels with at most
4 colors (one of which must be transparent). There is no way to losslessly
downsample detailed reference art to that resolution -- any conversion
necessarily becomes a fresh, simplified drawing that's *informed by* the
reference (pose, silhouette, color scheme) rather than a literal scaled
copy of it. `tools/author_sprites.py` does this explicitly and
procedurally: it draws clean NES-proportioned limbs/torso/head using simple
rectangles, with poses (idle, walk, punch, kick, jump, crouch, block, hit,
KO) and colors (red gi for Michael, blue gi for Lightning, matching the
client sheets' fighter/opponent color coding) chosen to match what the
reference sheets establish.

**Regenerating:**
```bash
python3 tools/author_sprites.py      # chr/src_frames/{michael,lightning}_sheet.png
python3 tools/chr_convert.py         # merges into chr/tiles.chr, writes
                                      # src/sprite_tiles_{const,player,enemy}.inc
```

**To use different/better art** (e.g. hand-drawn replacements for the
procedural frames): replace `chr/src_frames/michael_sheet.png` and/or
`lightning_sheet.png` directly -- each is a horizontal strip of 16x16
frames, one per pose, in the order listed in the matching `*_frames.txt`
file -- then run `python3 tools/chr_convert.py` (no need to re-run
`author_sprites.py`, which would overwrite your replacement art). The
converter quantizes whatever it finds in those PNGs to 4 colors per
character (transparent, gi color, white trim, skin/dark), so replacement
art should stick to a similarly small color count for predictable results.

**Why generate `sprite_tiles_*.inc` instead of hand-writing the tile
tables?** The previous version of this codebase had hand-maintained
`player_spritemap`/`enemy_spritemap` tables that referenced specific CHR
tile numbers by hex literal. When the CHR layout changed (different art,
different tile ordering), those tables silently went stale -- this was
directly responsible for one of the more serious bugs found during the
rewrite (sprites pointing at unrelated alphabet tiles). Generating the
table from the same script that lays out the CHR data makes that class of
bug structurally impossible: the tile indices in `sprite_tiles_player.inc`
are computed from the literal positions `chr_convert.py` just wrote.

## Fight stage background

`tools/bg_convert.py` converts `assets/32732.png` (256x224, exactly NES
screen resolution) into a deduplicated set of up to 96 unique 8x8
background tiles plus the nametable layout, using luminance-based
quantization: each pixel is bucketed into 1 of 4 indices by brightness
rather than by nearest-RGB-match, because the source art's blue-gray/green
coloring doesn't correspond to any single existing NES background palette.
Luminance bucketing preserves the image's shading and silhouette (you can
still clearly see the castle towers, clouds, and tree line) while letting
the in-game attribute table assign whichever palette looks best -- currently
BG1 (`$08/$18/$28`, genuinely olive/brown on real hardware) for a stone-
ruins look.

96 tiles is a hard budget: the free tile range in pattern table 0 is local
32-127 (tiles 0-31 are existing UI border art, 128-191 are the font/
alphabet). A 256x224 photographic image has far more than 96 *unique* 8x8
blocks, so tiles beyond the budget snap to the closest already-chosen tile
by average brightness -- this is why large flat regions (sky, water)
compress cleanly but fine detail (individual leaves, stonework texture)
gets smoothed out. This is an inherent resolution/budget trade-off, not a
bug.

**Regenerating:**
```bash
python3 tools/bg_convert.py      # chr/tiles_bg.chr (background half) +
                                  # src/stage_bg.inc (nametable data)
python3 tools/chr_convert.py     # re-merge into chr/tiles.chr
```

**To use a different background image:** replace `assets/32732.png` with
another 256x224 (or any size -- it will be resized) image and re-run both
commands above.

## One-time setup helper

`tools/extract_bg_bank.py` pulls pattern table 0 out of an existing
`tiles.chr` into `chr/tiles_bg.chr`. This was used once, when this pipeline
was first built, to seed `tiles_bg.chr` from the project's original
(working) CHR data so the existing UI border tiles and font didn't need to
be re-authored. You should not need to run it again unless you are
starting the background/UI bank over from a different source `.chr` file.

## Verifying changes

After any art change, rebuild and re-run the FCEUX test harness:

```bash
make clean && make
fceux --loadlua tools/test_rom.lua build/TheLastKumite.nes
```

`tools/test_rom.lua` drives the ROM through Title -> Intro -> VS -> Fight
-> Win/Lose -> Game Over under FCEUX with live memory inspection and
screenshots at every state transition; it was the primary verification
tool used throughout development (run headless under Xvfb in the sandboxed
environment this project was built in, but works the same under a normal
windowed FCEUX session).
