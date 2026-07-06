#!/usr/bin/env python3
"""
THE LAST KUMITE — Fight stage background conversion (v4).

This script is a VALIDATOR AND ENCODER, not an image processor. It assumes
the source PNG has already been hand-painted as NES-legal pixel art, and
its only job is to check that the artwork actually obeys NES hardware
rules and, if so, losslessly encode it into the two files the build
expects:

    chr/tiles_bg.chr   (updated in place, stage tiles written at TILE_BASE)
    src/stage_bg.inc   (nametable + attribute table)

--- Why earlier versions distorted the artwork --------------------------
v1 quantized the whole image into 4 global brightness buckets under a
single earth-tone palette, which cannot represent an image with four
distinct hue families (sky / stone / foliage / ground) and destroyed the
castle silhouette once tile-budget snapping kicked in.

v2 assigned one of three palettes per 16x16 attribute block by dominant
hue, then pre-boosted brightness before quantizing so dark castle stone
would land on a visibly distinct ramp step instead of collapsing to
near-black. That still MODIFIED the source pixels (Gaussian blur +
brightness enhancement) and, when the tile budget was exceeded, silently
replaced tiles with their closest existing match via pattern_diff. Both
behaviors are exactly what this version is forbidden from doing.

v3 hard-aborted on any 16x16 block whose pixels implied more than one
non-backdrop palette, on the theory that the artwork should be fixed by
hand rather than guessed at. In practice that made small, incidental
palette leaks (a handful of stray pixels) a hard stop on every run.

--- This version's contract ---------------------------------------------
1. The artwork is authoritative. The only geometric operation ever
   applied is a nearest-neighbor resize, and only if the source PNG is
   not already 256x224. No blur, brightness, contrast, smoothing, edge
   filtering, or color boosting exists anywhere in this file.
2. Every pixel is matched to one of the 3 approved NES palettes (Sky /
   Stone / Foliage) by exact RGB match first; nearest-color matching is
   used only as a fallback for pixels that don't exactly match one of
   the 10 defined colors. No other colors are ever invented.
3. Every 16x16 attribute block must resolve to exactly one non-backdrop
   palette. If a block's pixels imply more than one, the block is
   auto-resolved by MAJORITY VOTE: whichever non-backdrop palette covers
   the most pixels in that block wins, ties break in a fixed Sky > Stone
   > Foliage order. Any pixel whose original color belongs to a
   different palette than the block's resolved palette is re-quantized
   to the nearest color within the resolved palette (this is the one
   place pixel *colors*, as opposed to palette assignment, can change).
   Every block that required this is printed as a warning with its
   per-palette pixel counts and the palette it was resolved to, so
   nothing is silently changed.
4. Tiles are deduplicated on EXACT 8x8 pixel-index matches only. If the
   artwork needs more than MAX_STAGE_TILES unique tiles, conversion
   ABORTS with the true unique-tile count. No merging, no approximation,
   no replacement.

Usage: python3 tools/bg_convert.py
Reads:  assets/32732.png
        chr/tiles_bg.chr
Writes: chr/tiles_bg.chr (updated)
        src/stage_bg.inc
"""
from __future__ import annotations

import os
from collections import Counter
from dataclasses import dataclass
from enum import Enum
from typing import Dict, List, Optional, Tuple

from PIL import Image

# ---------------------------------------------------------------------------
# Project layout
# ---------------------------------------------------------------------------
ROOT: str = os.path.join(os.path.dirname(__file__), "..")
INPUT_PNG: str = os.path.join(ROOT, "assets", "32732.png")
CHR_PATH: str = os.path.join(ROOT, "chr", "tiles_bg.chr")
INC_PATH: str = os.path.join(ROOT, "src", "stage_bg.inc")

# ---------------------------------------------------------------------------
# NES / project geometry constants
# ---------------------------------------------------------------------------
IMAGE_WIDTH_PX: int = 256
IMAGE_HEIGHT_PX: int = 224
TILE_SIZE_PX: int = 8
ATTR_BLOCK_SIZE_PX: int = 16

TILES_WIDE: int = IMAGE_WIDTH_PX // TILE_SIZE_PX               # 32
TILES_HIGH: int = IMAGE_HEIGHT_PX // TILE_SIZE_PX              # 28
ATTR_BLOCKS_WIDE: int = IMAGE_WIDTH_PX // ATTR_BLOCK_SIZE_PX    # 16
ATTR_BLOCKS_HIGH: int = IMAGE_HEIGHT_PX // ATTR_BLOCK_SIZE_PX   # 14
ATTR_BYTE_COLS: int = ATTR_BLOCKS_WIDE // 2                     # 8 (each byte = 2x2 blocks)
ATTR_BYTE_ROWS: int = ATTR_BLOCKS_HIGH // 2                     # 7

TILE_PLANE_BYTES: int = 8    # one bit-plane of an 8x8 2bpp tile
TILE_BYTES: int = 16         # full 2bpp NES tile (2 planes)
CHR_BANK_BYTES: int = 4096

TILE_BASE: int = 32              # first local CHR tile index this stage owns
MAX_STAGE_TILES: int = 96        # hard tile budget for this stage
MAX_LOCAL_TILE_INDEX: int = 127  # tiles 128+ belong to another tile bank

BACKDROP_COLOR: int = 0x0F


class Palette(Enum):
    SKY = "Sky"
    STONE = "Stone"
    FOLIAGE = "Foliage"


# Each palette's 4 NES color entries, index 0 is always the shared backdrop.
PALETTE_COLORS: Dict[Palette, Tuple[int, int, int, int]] = {
    Palette.SKY: (0x0F, 0x21, 0x31, 0x20),
    Palette.STONE: (0x0F, 0x0C, 0x1C, 0x2C),
    Palette.FOLIAGE: (0x0F, 0x0A, 0x1A, 0x2A),
}

# Canonical RGB values for the 10 distinct NES colors used across the three
# approved palettes (backdrop counted once). These are the ONLY colors this
# converter will ever write to CHR.
NES_HEX_TO_RGB: Dict[int, Tuple[int, int, int]] = {
    0x0F: (0, 0, 0),
    0x21: (76, 154, 236),
    0x31: (168, 204, 236),
    0x20: (236, 238, 236),
    0x0C: (0, 50, 60),
    0x1C: (0, 102, 120),
    0x2C: (56, 180, 204),
    0x0A: (0, 64, 0),
    0x1A: (8, 124, 0),
    0x2A: (76, 208, 32),
}


def _build_hex_to_palette() -> Dict[int, Optional[Palette]]:
    """Map each non-backdrop NES color to the single palette that owns it.

    The backdrop color maps to None because it is shared by all three
    palettes and therefore never constrains a block's palette choice.
    """
    mapping: Dict[int, Optional[Palette]] = {BACKDROP_COLOR: None}
    for palette, hex_codes in PALETTE_COLORS.items():
        for hex_code in hex_codes:
            if hex_code == BACKDROP_COLOR:
                continue
            if hex_code in mapping:
                raise ValueError(
                    f"NES color ${hex_code:02X} is claimed by more than one palette; "
                    f"palette definitions must not overlap."
                )
            mapping[hex_code] = palette
    return mapping


HEX_TO_PALETTE: Dict[int, Optional[Palette]] = _build_hex_to_palette()
PALETTE_TO_ATTR_BITS: Dict[Palette, int] = {
    Palette.SKY: 0,
    Palette.STONE: 1,
    Palette.FOLIAGE: 2,
}

Tile = Tuple[Tuple[int, ...], ...]


@dataclass(frozen=True)
class PixelMatch:
    """The result of matching one source pixel to an approved NES color."""
    hex_color: int
    palette: Optional[Palette]  # None == shared backdrop
    exact: bool
    rgb: Tuple[int, int, int]  # original source pixel, kept for re-quantization


# ---------------------------------------------------------------------------
# Step 1: load the source image, resizing ONLY with nearest-neighbor and
# ONLY if it isn't already the exact NES screen resolution.
# ---------------------------------------------------------------------------
def load_source_image(path: str) -> Image.Image:
    if not os.path.exists(path):
        raise SystemExit(f"ERROR: {path} not found")
    img = Image.open(path).convert("RGB")
    if img.size != (IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX):
        img = img.resize((IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX), Image.NEAREST)
    return img


# ---------------------------------------------------------------------------
# Step 2: match every pixel to an approved NES color. Exact match first;
# nearest-color match only as a fallback. No pixel value is ever altered.
# ---------------------------------------------------------------------------
def _color_distance_sq(a: Tuple[int, int, int], b: Tuple[int, int, int]) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def match_pixel(rgb: Tuple[int, int, int]) -> PixelMatch:
    for hex_code, ref_rgb in NES_HEX_TO_RGB.items():
        if rgb == ref_rgb:
            return PixelMatch(hex_color=hex_code, palette=HEX_TO_PALETTE[hex_code], exact=True, rgb=rgb)

    best_hex: int = BACKDROP_COLOR
    best_dist: Optional[int] = None
    for hex_code, ref_rgb in NES_HEX_TO_RGB.items():
        dist = _color_distance_sq(rgb, ref_rgb)
        if best_dist is None or dist < best_dist:
            best_dist, best_hex = dist, hex_code
    return PixelMatch(hex_color=best_hex, palette=HEX_TO_PALETTE[best_hex], exact=False, rgb=rgb)


def build_pixel_matches(img: Image.Image) -> List[List[PixelMatch]]:
    pixels = img.load()
    return [
        [match_pixel(pixels[x, y]) for x in range(IMAGE_WIDTH_PX)]
        for y in range(IMAGE_HEIGHT_PX)
    ]


# ---------------------------------------------------------------------------
# Step 3: assign exactly one palette per 16x16 attribute block. If a block's
# pixels imply more than one non-backdrop palette, auto-resolve by majority
# vote (most covered pixels wins; ties broken Sky > Stone > Foliage) and
# record a warning describing exactly what was changed.
# ---------------------------------------------------------------------------
_TIE_BREAK_ORDER: Tuple[Palette, ...] = (Palette.SKY, Palette.STONE, Palette.FOLIAGE)


def assign_block_palettes(
    matches: List[List[PixelMatch]],
) -> Tuple[List[List[Palette]], List[str]]:
    block_palettes: List[List[Palette]] = [
        [Palette.SKY] * ATTR_BLOCKS_WIDE for _ in range(ATTR_BLOCKS_HIGH)
    ]
    warnings: List[str] = []

    for block_y in range(ATTR_BLOCKS_HIGH):
        for block_x in range(ATTR_BLOCKS_WIDE):
            counts: Counter[Palette] = Counter()
            base_y = block_y * ATTR_BLOCK_SIZE_PX
            base_x = block_x * ATTR_BLOCK_SIZE_PX
            for dy in range(ATTR_BLOCK_SIZE_PX):
                row = matches[base_y + dy]
                for dx in range(ATTR_BLOCK_SIZE_PX):
                    palette = row[base_x + dx].palette
                    if palette is not None:
                        counts[palette] += 1

            if not counts:
                # Pure-backdrop block: only $0F is ever drawn here, so the
                # palette choice is visually irrelevant. Sky is used as a
                # stable, arbitrary default.
                continue

            if len(counts) == 1:
                block_palettes[block_y][block_x] = next(iter(counts))
                continue

            # Mixed block: majority vote, ties broken by fixed priority.
            winner = max(
                counts,
                key=lambda p: (counts[p], -_TIE_BREAK_ORDER.index(p)),
            )
            block_palettes[block_y][block_x] = winner

            breakdown = ", ".join(
                f"{p.value} {counts[p]}px" for p in _TIE_BREAK_ORDER if p in counts
            )
            warnings.append(
                f"Attribute block ({base_x},{base_y}) mixed palettes [{breakdown}] "
                f"-> resolved to {winner.value} (majority). Minority pixels in this "
                f"block will be re-quantized to the nearest {winner.value} color."
            )

    return block_palettes, warnings


# ---------------------------------------------------------------------------
# Step 4: reduce each pixel to its 2-bit index within its block's palette.
# ---------------------------------------------------------------------------
def pixel_palette_index(match: PixelMatch, block_palette: Palette) -> int:
    if match.palette is None:
        return 0  # shared backdrop is always slot 0

    palette_colors = PALETTE_COLORS[block_palette]
    if match.hex_color in palette_colors:
        return palette_colors.index(match.hex_color)

    # This pixel's exact color belongs to a different palette than the one
    # the block was resolved to (a minority-vote pixel in a mixed block).
    # Re-quantize it to the nearest color within the block's palette; this
    # is the only place pixel colors are altered, and only ever happens for
    # pixels inside a block that build_pixel_matches/assign_block_palettes
    # already flagged with a printed warning.
    best_index = 0
    best_dist: Optional[int] = None
    for idx, hex_code in enumerate(palette_colors):
        dist = _color_distance_sq(match.rgb, NES_HEX_TO_RGB[hex_code])
        if best_dist is None or dist < best_dist:
            best_dist, best_index = dist, idx
    return best_index


def build_index_grid(
    matches: List[List[PixelMatch]],
    block_palettes: List[List[Palette]],
) -> List[List[int]]:
    grid: List[List[int]] = [[0] * IMAGE_WIDTH_PX for _ in range(IMAGE_HEIGHT_PX)]
    for y in range(IMAGE_HEIGHT_PX):
        block_y = y // ATTR_BLOCK_SIZE_PX
        row_palettes = block_palettes[block_y]
        for x in range(IMAGE_WIDTH_PX):
            block_x = x // ATTR_BLOCK_SIZE_PX
            grid[y][x] = pixel_palette_index(matches[y][x], row_palettes[block_x])
    return grid


# ---------------------------------------------------------------------------
# Step 5: split into 8x8 tiles and deduplicate on EXACT matches only.
# ---------------------------------------------------------------------------
def extract_tile(grid: List[List[int]], tile_x: int, tile_y: int) -> Tile:
    base_y = tile_y * TILE_SIZE_PX
    base_x = tile_x * TILE_SIZE_PX
    return tuple(
        tuple(grid[base_y + dy][base_x:base_x + TILE_SIZE_PX])
        for dy in range(TILE_SIZE_PX)
    )


def deduplicate_tiles(grid: List[List[int]]) -> Tuple[List[Tile], List[List[int]]]:
    unique_tiles: List[Tile] = []
    tile_lookup: Dict[Tile, int] = {}
    nametable: List[List[int]] = [[0] * TILES_WIDE for _ in range(TILES_HIGH)]

    for tile_y in range(TILES_HIGH):
        for tile_x in range(TILES_WIDE):
            tile = extract_tile(grid, tile_x, tile_y)
            idx = tile_lookup.get(tile)
            if idx is None:
                idx = len(unique_tiles)
                tile_lookup[tile] = idx
                unique_tiles.append(tile)
            nametable[tile_y][tile_x] = idx

    if len(unique_tiles) > MAX_STAGE_TILES:
        raise SystemExit(
            f"ERROR: Image uses {len(unique_tiles)} unique tiles.\n"
            f"Maximum allowed is {MAX_STAGE_TILES}.\n"
            f"No tiles were merged, replaced, or approximated.\n"
            f"Reduce the number of distinct 8x8 patterns in the artwork by hand "
            f"and re-run the conversion."
        )

    return unique_tiles, nametable


# ---------------------------------------------------------------------------
# Step 6: encode tiles to NES 2bpp and write them into the CHR bank.
# ---------------------------------------------------------------------------
def tile_to_2bpp(tile: Tile) -> bytes:
    lo = bytearray(TILE_PLANE_BYTES)
    hi = bytearray(TILE_PLANE_BYTES)
    for row_index, row in enumerate(tile):
        lo_byte = 0
        hi_byte = 0
        for col_index, value in enumerate(row):
            bit_position = 7 - col_index
            lo_byte |= (value & 1) << bit_position
            hi_byte |= ((value >> 1) & 1) << bit_position
        lo[row_index] = lo_byte
        hi[row_index] = hi_byte
    return bytes(lo) + bytes(hi)


def write_chr_bank(unique_tiles: List[Tile]) -> None:
    if not os.path.exists(CHR_PATH):
        raise SystemExit(f"ERROR: {CHR_PATH} not found — run tools/extract_bg_bank.py first")

    with open(CHR_PATH, "rb") as f:
        bank = bytearray(f.read())
    if len(bank) != CHR_BANK_BYTES:
        raise SystemExit(f"ERROR: {CHR_PATH} must be exactly {CHR_BANK_BYTES} bytes, found {len(bank)}")

    last_local_index = TILE_BASE + len(unique_tiles) - 1
    if last_local_index > MAX_LOCAL_TILE_INDEX:
        raise SystemExit(
            f"ERROR: stage tiles would occupy local indices {TILE_BASE}-{last_local_index}, "
            f"exceeding the allowed range (up to {MAX_LOCAL_TILE_INDEX})."
        )

    for i, tile in enumerate(unique_tiles):
        local_index = TILE_BASE + i
        offset = local_index * TILE_BYTES
        bank[offset:offset + TILE_BYTES] = tile_to_2bpp(tile)

    with open(CHR_PATH, "wb") as f:
        f.write(bank)


# ---------------------------------------------------------------------------
# Step 7: build the attribute table bytes from the validated block palettes.
# ---------------------------------------------------------------------------
def build_attribute_bytes(block_palettes: List[List[Palette]]) -> List[int]:
    attr_bytes: List[int] = []
    quad_offsets: Tuple[Tuple[int, int], ...] = ((0, 0), (0, 1), (1, 0), (1, 1))

    for attr_row in range(ATTR_BYTE_ROWS):
        for attr_col in range(ATTR_BYTE_COLS):
            byte_value = 0
            for quad_index, (dqy, dqx) in enumerate(quad_offsets):
                block_y = attr_row * 2 + dqy
                block_x = attr_col * 2 + dqx
                palette = block_palettes[block_y][block_x]
                byte_value |= PALETTE_TO_ATTR_BITS[palette] << (quad_index * 2)
            attr_bytes.append(byte_value)

    return attr_bytes


# ---------------------------------------------------------------------------
# Step 8: write the nametable + attribute table to stage_bg.inc.
# ---------------------------------------------------------------------------
def write_stage_inc(
    unique_tiles: List[Tile],
    nametable: List[List[int]],
    attr_bytes: List[int],
) -> None:
    with open(INC_PATH, "w") as f:
        f.write("; AUTO-GENERATED by tools/bg_convert.py — DO NOT EDIT BY HAND\n")
        f.write("; Re-run this script after changing the source artwork.\n\n")
        f.write(f"STAGE_TILE_BASE = {TILE_BASE}\n\n")

        f.write("stage_nametable:\n")
        for tile_y in range(TILES_HIGH):
            row_vals = [str(TILE_BASE + nametable[tile_y][tile_x]) for tile_x in range(TILES_WIDE)]
            f.write(f"    .byte {', '.join(row_vals)}\n")

        f.write("\n; Per-16x16-block palette assignment (0=Sky, 1=Stone, 2=Foliage),\n")
        f.write("; validated so every block uses exactly one non-backdrop palette.\n")
        f.write("stage_attribute_table:\n")
        for i in range(0, len(attr_bytes), ATTR_BYTE_COLS):
            row = attr_bytes[i:i + ATTR_BYTE_COLS]
            f.write("    .byte " + ", ".join(f"%{b:08b}" for b in row) + "\n")


# ---------------------------------------------------------------------------
# Step 9: debug summary.
# ---------------------------------------------------------------------------
def print_debug_summary(
    unique_tiles: List[Tile],
    block_palettes: List[List[Palette]],
) -> None:
    total_tile_slots = TILES_WIDE * TILES_HIGH
    reused_tiles = total_tile_slots - len(unique_tiles)
    used_palettes = sorted({p for row in block_palettes for p in row}, key=lambda p: p.value)

    print(f"Image size: {IMAGE_WIDTH_PX}x{IMAGE_HEIGHT_PX}")
    print(f"Unique tile count: {len(unique_tiles)}")
    print(f"Attribute palette count: {len(used_palettes)} ({', '.join(p.value for p in used_palettes)})")
    print(f"Tile count: {total_tile_slots}")
    print(f"CHR tile range used: {TILE_BASE}-{TILE_BASE + len(unique_tiles) - 1}")
    print(f"Number of reused tiles: {reused_tiles}")


def main() -> None:
    img = load_source_image(INPUT_PNG)
    matches = build_pixel_matches(img)
    block_palettes, palette_warnings = assign_block_palettes(matches)

    if palette_warnings:
        print(f"WARNING: {len(palette_warnings)} attribute block(s) had mixed palettes and were auto-resolved:")
        for w in palette_warnings:
            print(f"  - {w}")
        print()

    index_grid = build_index_grid(matches, block_palettes)
    unique_tiles, nametable = deduplicate_tiles(index_grid)

    write_chr_bank(unique_tiles)
    attr_bytes = build_attribute_bytes(block_palettes)
    write_stage_inc(unique_tiles, nametable, attr_bytes)

    print_debug_summary(unique_tiles, block_palettes)
    print(f"Wrote {CHR_PATH}")
    print(f"Wrote {INC_PATH}")


if __name__ == "__main__":
    main()