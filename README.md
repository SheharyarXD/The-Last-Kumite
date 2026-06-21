# THE LAST KUMITE — NES 1-Level Demo

A complete NES-compatible fighting game ROM featuring Michael Rivers vs Lightning.

## ROM Details

| Property | Value |
|----------|-------|
| **File** | `build/last_kumite.nes` |
| **Size** | 40,976 bytes (40 KB) |
| **Mapper** | 0 (NROM-256) |
| **PRG-ROM** | 32 KB (2 × 16KB banks) |
| **CHR-ROM** | 8 KB (1 × 8KB bank) |
| **Mirroring** | Vertical |
| **Region** | NTSC (60 FPS) |

## Project Structure

```
last_kumite_nes/
├── build/
│   └── last_kumite.nes          ← Final ROM file
├── chr/
│   └── tiles.chr                ← Pattern table data (8KB)
├── docs/
│   └── architecture.md          ← Technical architecture document
├── src/
│   ├── constants.asm            ← Game constants & enums
│   ├── zeropage.asm             ← Zero page memory map
│   ├── macros.asm               ← Assembly macros
│   ├── init.asm                 ← RESET / hardware init
│   ├── ppu.asm                  ← PPU driver & OAM system
│   ├── input.asm                ← Controller polling & combos
│   ├── sound.asm                ← APU sound driver
│   ├── state_machine.asm        ← Game state management
│   ├── title.asm                ← Title screen renderer
│   ├── intro.asm                ← Story text renderer
│   ├── vs_screen.asm            ← VS screen display
│   ├── player.asm               ← Michael Rivers logic
│   ├── enemy.asm                ← Lightning AI system
│   ├── combat.asm               ← Hit detection & damage
│   ├── special.asm              ← Special move system
│   ├── hud.asm                  ← Health bars & timer
│   ├── fight_state.asm          ← Main fight gameplay
│   ├── gameover.asm             ← Game over screen
│   ├── main.asm                 ← Main game loop
│   ├── chr_data.asm             ← CHR data definitions
│   └── vectors.asm              ← NMI/RESET/IRQ vectors
├── build_rom.py                 ← Python ROM builder
├── last_kumite.cfg              ← ld65 linker script
└── Makefile                     ← ca65/ld65 build system
```

## Game Features

### Included in Demo
- [x] Title screen with "THE LAST KUMITE" and "PRESS START"
- [x] 1 playable fight: Michael Rivers vs Lightning
- [x] Player movement (left/right)
- [x] Punch attack (A button) — 5 damage
- [x] Kick attack (B button) — 10 damage
- [x] Enemy AI with approach/attack behavior
- [x] Collision detection (distance-based hitboxes)
- [x] Damage system with HP (Player: 100, Enemy: 80)
- [x] Hit freeze (6 frames) and screen shake effects
- [x] Hit flash (white palette swap on damage)
- [x] Win/lose state detection
- [x] 60-second match timer
- [x] OAM sprite rendering for both characters
- [x] Background tile rendering (stage + ground)
- [x] CHR-ROM with character sprites, alphabet, UI tiles

### Control Mapping
| Button | Action |
|--------|--------|
| **D-Pad Left** | Move left |
| **D-Pad Right** | Move right |
| **A Button** | Punch |
| **B Button** | Kick |
| **Start** | Start game (title) / Pause |

## Technical Architecture

### Memory Map
```
$0000-$000F   NMI flags, frame counter, temp vars
$0010-$001F   Input system (pad1, combos)
$0020-$002F   Game state variables
$0030-$003F   Match timer, screen shake
$0040-$005F   Player state (Michael Rivers)
$0060-$007F   Enemy state (Lightning)
$0200-$02FF   OAM sprite buffer (64 sprites)
$2000-$2007   PPU registers
$4016-$4017   Controller ports
```

### Game State Machine
```
STATE_TITLE (0)  → Press START → STATE_FIGHT
STATE_FIGHT (3)  → Player/Enemy HP=0 → STATE_WIN/LOSE
STATE_WIN   (4)  → Timer → Return
STATE_LOSE  (5)  → Timer → Return
```

### CPU Vectors
| Vector | Address | Purpose |
|--------|---------|---------|
| NMI | $C000 | VBlank interrupt (60Hz) |
| RESET | $8000 | Power-on initialization |
| IRQ | $C020 | Unused (RTI) |

### CHR-ROM Layout
| Range | Content |
|-------|---------|
| $0000-$0FFF | Background tiles (stage, UI, text) |
| $1000-$13FF | Michael Rivers sprites |
| $1400-$17FF | Lightning sprites |
| $1800-$18FF | Hit effect tiles |
| $1900-$19FF | Special effect tiles |
| $1FC0-$1FFF | Solid tiles (VS portraits) |

## Build Instructions

### Option 1: Python Builder (Recommended)
```bash
cd last_kumite_nes
python3 build_rom.py
```

### Option 2: ca65/ld65 Toolchain
```bash
cd last_kumite_nes
make
```

### Option 3: Manual Assembly
```bash
ca65 -g -t nes src/main.asm -o build/main.o
ld65 -C last_kumite.cfg build/main.o -o build/rom.bin
# Then prepend iNES header and append CHR data
```

## Running the ROM

Use any NES emulator:
```bash
# FCEUX
fceux build/last_kumite.nes

# Mesen
mesen build/last_kumite.nes

# Nestopia
nestopia build/last_kumite.nes
```

## 6502 Code Statistics

| Component | Size (bytes) | Location |
|-----------|-------------|----------|
| RESET handler | 104 | $8000-$8067 |
| Main game loop | 529 | $8100-$8310 |
| Title renderer | ~80 | $8300-$8350 |
| NMI handler | 17 | $C000-$C010 |
| Palette data | 32 | $8200-$821F |
| Text data | 28 | $8280-$829B |
| **Total used** | **~790** | of 32,768 bytes |

## License

This is a demo project for educational purposes based on "The Last Kumite" concept.
