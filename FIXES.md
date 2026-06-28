# THE LAST KUMITE — Bug Fix Report
## Problem: Background & HUD Completely Black

### Root Cause Analysis

Two separate bugs caused the all-black rendering:

---

## FIX 1: Palette Colors Too Dark (`src/init.asm`)

**File:** `src/init.asm` — `default_palette` table  
**Problem:** Several NES palette entries used colors near `$0F` (blacker-than-black) and
very dark indices that rendered as near-invisible against the black background.

### Changes:

| Entry | Old Value | New Value | Effect |
|-------|-----------|-----------|--------|
| `$3F00` (BG universal) | `$0F` (black) | `$0C` (dark grey) | Tiles now have visible background |
| `$3F01` (BG0 sky 1) | `$11` (dark blue) | `$21` (mid blue) | Sky visible |
| `$3F02` (BG0 sky 2) | `$21` (mid blue) | `$31` (light blue) | Sky brighter |
| `$3F03` (BG0 sky 3) | `$31` (light blue) | `$3C` (pale) | Sky highlight |
| `$3F05` (BG1 earth 1) | `$08` (very dark) | `$17` (orange-dark) | Ground visible |
| `$3F06` (BG1 earth 2) | `$18` (dark tan) | `$27` (tan/gold) | Ground color |
| `$3F07` (BG1 earth 3) | `$28` (mid tan) | `$37` (light cream) | Ground highlight |
| `$3F0D` (BG3 HUD 1) | `$00` (dark grey) | `$26` (orange-red) | Health bars colored |
| `$3F0E` (BG3 HUD 2) | `$10` (grey) | `$30` (white) | Text bright white |
| `$3F0F` (BG3 HUD 3) | `$30` (white) | `$3D` (pale green) | HUD accent |

---

## FIX 2: Attribute Table Rows 0-1 All Zero (`src/stage_bg.inc`)

**File:** `src/stage_bg.inc` — `stage_attribute_table`  
**Problem:** The NES attribute table controls which palette is applied to each 32x32px
region of the nametable. The original table had rows 0-1 (the HUD area at the top of
the screen) set to `%00000000` = **palette 0 (sky blues)**.

This meant health bars, player names, and the VS text were all rendered with sky-blue
colors on a sky-blue background — **completely invisible**.

### Fix:
Changed attribute table rows 0 and 1 from `%00000000` to `%11111111` (palette 3 = HUD
palette with red/white/orange colors). The stage area (rows 2-7) remains:
- Rows 2-3: `%00000000` = palette 0 (sky)  
- Rows 4-7: `%01010101` = palette 1 (earth tones)

### Visual result:
- `MICHAEL` / `LIGHTNING` names: now white
- Health bars: red (player) and blue (enemy)  
- Timer: white digits on dark background
- Stage sky: mid-blue to light-blue gradient visible
- Stage ground: warm orange/tan tones visible

---

## How to Rebuild

```bash
# Install toolchain (Ubuntu/Debian)
apt-get install cc65 python3-pillow

# Rebuild CHR data from sprites
make chr

# Rebuild stage background
make bg

# Build ROM
make

# Run in emulator
make run
```

The `.nes` file in `build/TheLastKumite.nes` needs to be rebuilt from source after
these fixes — the pre-built binary in the zip still uses old palettes.

---

## Files Changed

| File | Change |
|------|--------|
| `src/init.asm` | Palette entries brightened (see table above) |
| `src/stage_bg.inc` | Attribute table rows 0-1 changed to `%11111111` (palette 3) |
| `src/hud.asm` | Added documentation comments explaining palette/attribute dependency |

