#!/usr/bin/env python3
"""
THE LAST KUMITE — Stage background PRE-PROCESSOR (prep_nes_bg.py).

This is deliberately NOT bg_convert.py. bg_convert.py's contract is to be a
validator/encoder that never alters pixels except as a last-resort, printed,
per-pixel remap inside an already-mixed block. This script's job is the
opposite: it IS an image processor, meant to run once, by hand, on art that
came out of an AI image tool (or any non-indexed source) and turn it into
something that will pass bg_convert.py cleanly — ideally with ZERO warnings.

What it does, in order:
  1. Resizes to 256x224 with nearest-neighbor ONLY if not already that size.
  2. Snaps every pixel to the nearest of the 10 canonical NES colors used by
     the Sky / Stone / Foliage palettes. This removes anti-aliasing, gradient
     shading, and off-palette noise that a generative model introduces.
  3. Resolves every 16x16 attribute block to a single palette by majority
     vote (identical rule to bg_convert.py: most-covered non-backdrop
     palette wins, ties broken Sky > Stone > Foliage), then re-quantizes any
     pixel in that block whose nearest color belongs to a different palette
     to the nearest color WITHIN the block's resolved palette.
  4. Reports the resulting unique 8x8 tile count against the MAX_STAGE_TILES
     budget, and prints every block that needed majority-vote resolution so
     you know exactly which regions were touched and why.

It writes:
  - <input>_nes_ready.png  — the corrected, NES-legal image
  - <input>_diff.png       — the corrected image with every changed pixel
                              highlighted in magenta, so you can see exactly
                              what this script altered before it goes near
                              the real encoder.

This script does NOT merge or reduce tile count — if the reported unique
tile count is still over budget after this runs, that's a genuine "too much
distinct detail" problem that has to be solved by redrawing/simplifying the
art (more repetition, less unique texture), not by further automated
processing. Merging visually-different tiles to hit a budget is exactly the
kind of silent approximation this whole pipeline is designed to avoid.

Usage: python3 prep_nes_bg.py <input.png>
"""
from __future__ import annotations

import os
import sys
from collections import Counter
from typing import Dict, List, Optional, Tuple

from PIL import Image

IMAGE_WIDTH_PX = 256
IMAGE_HEIGHT_PX = 224
TILE_SIZE_PX = 8
ATTR_BLOCK_SIZE_PX = 16
ATTR_BLOCKS_WIDE = IMAGE_WIDTH_PX // ATTR_BLOCK_SIZE_PX   # 16
ATTR_BLOCKS_HIGH = IMAGE_HEIGHT_PX // ATTR_BLOCK_SIZE_PX  # 14
MAX_STAGE_TILES = 96
BACKDROP_HEX = 0x0F

PALETTE_COLORS: Dict[str, Tuple[int, int, int, int]] = {
    "Sky": (0x0F, 0x21, 0x31, 0x20),
    "Stone": (0x0F, 0x0C, 0x1C, 0x2C),
    "Foliage": (0x0F, 0x0A, 0x1A, 0x2A),
}
NES_HEX_TO_RGB: Dict[int, Tuple[int, int, int]] = {
    0x0F: (0, 0, 0),
    0x21: (76, 154, 236), 0x31: (168, 204, 236), 0x20: (236, 238, 236),
    0x0C: (0, 50, 60), 0x1C: (0, 102, 120), 0x2C: (56, 180, 204),
    0x0A: (0, 64, 0), 0x1A: (8, 124, 0), 0x2A: (76, 208, 32),
}
HEX_TO_PALETTE: Dict[int, Optional[str]] = {BACKDROP_HEX: None}
for _pname, _hexes in PALETTE_COLORS.items():
    for _h in _hexes:
        if _h != BACKDROP_HEX:
            HEX_TO_PALETTE[_h] = _pname

TIE_BREAK_ORDER = ("Sky", "Stone", "Foliage")
DIFF_HIGHLIGHT = (255, 0, 220)  # loud magenta, won't be confused with real art


def _dist_sq(a: Tuple[int, int, int], b: Tuple[int, int, int]) -> int:
    return (a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2


def nearest_hex(rgb: Tuple[int, int, int]) -> int:
    best_hex, best_dist = BACKDROP_HEX, None
    for hex_code, ref_rgb in NES_HEX_TO_RGB.items():
        d = _dist_sq(rgb, ref_rgb)
        if best_dist is None or d < best_dist:
            best_dist, best_hex = d, hex_code
    return best_hex


def load_source(path: str) -> Image.Image:
    img = Image.open(path).convert("RGB")
    if img.size != (IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX):
        print(f"Resizing {img.size} -> {(IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX)} (nearest-neighbor)")
        img = img.resize((IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX), Image.NEAREST)
    return img


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 prep_nes_bg.py <input.png>")

    in_path = sys.argv[1]
    img = load_source(in_path)
    src_px = img.load()

    # Step 1: snap every pixel to its nearest of the 10 canonical colors.
    snapped_hex: List[List[int]] = [[0]*IMAGE_WIDTH_PX for _ in range(IMAGE_HEIGHT_PX)]
    for y in range(IMAGE_HEIGHT_PX):
        for x in range(IMAGE_WIDTH_PX):
            snapped_hex[y][x] = nearest_hex(src_px[x, y])

    # Step 2: resolve each 16x16 block to one palette by majority vote.
    block_palette: List[List[str]] = [["Sky"]*ATTR_BLOCKS_WIDE for _ in range(ATTR_BLOCKS_HIGH)]
    warnings: List[str] = []
    for by in range(ATTR_BLOCKS_HIGH):
        for bx in range(ATTR_BLOCKS_WIDE):
            counts: Counter = Counter()
            base_y, base_x = by*ATTR_BLOCK_SIZE_PX, bx*ATTR_BLOCK_SIZE_PX
            for dy in range(ATTR_BLOCK_SIZE_PX):
                for dx in range(ATTR_BLOCK_SIZE_PX):
                    h = snapped_hex[base_y+dy][base_x+dx]
                    p = HEX_TO_PALETTE[h]
                    if p is not None:
                        counts[p] += 1
            if not counts:
                continue
            if len(counts) == 1:
                block_palette[by][bx] = next(iter(counts))
                continue
            winner = max(counts, key=lambda p: (counts[p], -TIE_BREAK_ORDER.index(p)))
            block_palette[by][bx] = winner
            breakdown = ", ".join(f"{p} {counts[p]}px" for p in TIE_BREAK_ORDER if p in counts)
            warnings.append(f"Block ({base_x},{base_y}) mixed [{breakdown}] -> {winner}")

    # Step 3: re-quantize any pixel whose color doesn't belong to its
    # block's resolved palette, using nearest-color WITHIN that palette.
    final_hex: List[List[int]] = [row[:] for row in snapped_hex]
    remapped_pixels = 0
    for y in range(IMAGE_HEIGHT_PX):
        by = y // ATTR_BLOCK_SIZE_PX
        for x in range(IMAGE_WIDTH_PX):
            bx = x // ATTR_BLOCK_SIZE_PX
            h = snapped_hex[y][x]
            if h == BACKDROP_HEX:
                continue
            palette = block_palette[by][bx]
            allowed = PALETTE_COLORS[palette]
            if h in allowed:
                continue
            # nearest color within the resolved palette, using ORIGINAL rgb
            orig_rgb = src_px[x, y]
            best_h, best_d = BACKDROP_HEX, None
            for cand in allowed:
                d = _dist_sq(orig_rgb, NES_HEX_TO_RGB[cand])
                if best_d is None or d < best_d:
                    best_d, best_h = d, cand
            final_hex[y][x] = best_h
            remapped_pixels += 1

    # Build output images.
    out_img = Image.new("RGB", (IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX))
    out_px = out_img.load()
    diff_img = Image.new("RGB", (IMAGE_WIDTH_PX, IMAGE_HEIGHT_PX))
    diff_px = diff_img.load()
    changed_from_original = 0
    for y in range(IMAGE_HEIGHT_PX):
        for x in range(IMAGE_WIDTH_PX):
            rgb = NES_HEX_TO_RGB[final_hex[y][x]]
            out_px[x, y] = rgb
            if rgb != src_px[x, y]:
                changed_from_original += 1
                diff_px[x, y] = DIFF_HIGHLIGHT
            else:
                diff_px[x, y] = rgb

    # Tile count report (same rule as bg_convert.py: exact 8x8 index match).
    tiles = set()
    for ty in range(IMAGE_HEIGHT_PX // TILE_SIZE_PX):
        for tx in range(IMAGE_WIDTH_PX // TILE_SIZE_PX):
            tile = tuple(
                tuple(final_hex[ty*TILE_SIZE_PX+dy][tx*TILE_SIZE_PX:tx*TILE_SIZE_PX+TILE_SIZE_PX])
                for dy in range(TILE_SIZE_PX)
            )
            tiles.add(tile)

    base, ext = os.path.splitext(in_path)
    ready_path = f"{base}_nes_ready.png"
    diff_path = f"{base}_diff.png"
    out_img.save(ready_path)
    diff_img.save(diff_path)

    total_px = IMAGE_WIDTH_PX * IMAGE_HEIGHT_PX
    print(f"Pixels changed from source: {changed_from_original}/{total_px} "
          f"({100*changed_from_original/total_px:.1f}%)")
    print(f"Blocks requiring majority-vote resolution: {len(warnings)}/{ATTR_BLOCKS_WIDE*ATTR_BLOCKS_HIGH}")
    for w in warnings:
        print(f"  - {w}")
    print()
    print(f"Unique 8x8 tiles: {len(tiles)} (budget: {MAX_STAGE_TILES})")
    if len(tiles) > MAX_STAGE_TILES:
        print(f"STILL OVER BUDGET by {len(tiles) - MAX_STAGE_TILES} tiles.")
        print("This means the art still has more distinct 8x8 detail than the hardware")
        print("allows — color-snapping alone can't fix that. The repeating elements")
        print("(brick courses, crenellations, leaf clusters) need to be redrawn so their")
        print("8x8 blocks are pixel-identical to each other, not just similar.")
    else:
        print("Within budget.")
    print()
    print(f"Wrote {ready_path}")
    print(f"Wrote {diff_path}  (magenta = every pixel this script changed)")


if __name__ == "__main__":
    main()
