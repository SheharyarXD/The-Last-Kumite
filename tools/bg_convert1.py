#!/usr/bin/env python3
"""
THE LAST KUMITE — Fight stage background conversion (v2).

Converts assets/32732.png (256x224, exact NES screen resolution) into a
deduplicated NES background tileset plus a nametable + attribute table,
written to src/stage_bg.inc and streamed into the PPU by LoadFightStage.

--- Why v1 produced a wall of noise instead of a castle -----------------
The previous version quantized every pixel into 4 GLOBAL brightness
buckets and painted the whole lower 3/4 of the screen with a single
"earth tone" palette. Two compounding problems:

1. A single 3-color (+backdrop) palette cannot represent an image that
   actually contains FOUR distinct hue families: blue sky, teal-grey
   castle stone, green foliage, and the tan/brown ground band. Forcing
   all of that into one earth-tone palette meant the converter had no
   genuinely distinct *colors* left to draw the shapes with, only
   distinct *brightness levels* -- so once tile-budget snapping kicked
   in, the castle silhouette dissolved into a repeating noisy pattern.
2. Bucketing by brightness PERCENTILE (equal population per bucket)
   guarantees a fixed fraction of pixels always lands in index 0, which
   is hard-wired on real NES hardware to a single shared backdrop color
   -- regardless of whether those pixels actually belonged together.

--- The fix --------------------------------------------------------------
This version assigns one of THREE region palettes per 16x16-pixel
attribute quadrant (the same granularity the NES attribute table
actually supports) based on that quadrant's dominant hue, then quantizes
each pixel to the NEAREST color within its quadrant's assigned palette
(real RGB distance, not a forced equal-population bucket):

  BG0 "sky"     -- blue/white, used for quadrants that are mostly sky
  BG1 "stone"   -- teal-grey ramp, used for castle/ground/pillars
  BG2 "foliage" -- green ramp, used for tree/bush quadrants

The top two attribute rows are always forced to "sky" (matches the
reference art's clean horizon line). Below that, each quadrant is
classified by comparing its average green-channel dominance against
red/blue to tell foliage apart from stone. Because matching is nearest-
*color* rather than population-equalized brightness, the shared backdrop
slot only gets used by pixels that are actually close to black (mortar
lines, window shadows) instead of a fixed guaranteed quarter of the
image -- so structure stops disappearing.

--- v2 still rendered the castle as a black silhouette -------------------
Nearest-color matching alone wasn't enough: the source art's castle
stone is genuinely dark (avg RGB ~10,40,50), which is legitimately
closest to PAL_STONE's dark slot $0C. But $0C is one of the NES's
darkest, most desaturated colors -- on real hardware/most emulator
palettes it reads as almost indistinguishable from black ($0F). Since
~70% of the castle body's pixels are that dark, nearly the whole
structure collapsed into the same near-black tone as the mortar-line/
shadow pixels that are *supposed* to use $0F, producing a flat
silhouette instead of a shaded castle.
SOURCE_BRIGHTNESS pre-boosts the image before quantizing (not just
remapping the palette) so the castle's actual midtones land on the
ramp's visibly-distinct mid/light slots ($1C/$2C) instead of piling
into the near-black slot. This is a brightness lift, not a contrast
stretch, specifically because a contrast stretch would also blow out
the sky/cloud quadrants that were already well-exposed.

Usage: python3 tools/bg_convert.py
Reads:  assets/32732.png
        chr/tiles_bg.chr
Writes: chr/tiles_bg.chr (updated)
        src/stage_bg.inc
"""
import os
from PIL import Image, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(__file__), "..")
BG_IMAGE = os.path.join(ROOT, "assets", "32732.png")
BG_CHR = os.path.join(ROOT, "chr", "tiles_bg.chr")
OUT_INC = os.path.join(ROOT, "src", "stage_bg.inc")

TILE_BYTES = 16
BANK_BYTES = 4096
TILES_W, TILES_H = 32, 28
TILE_BASE = 32
MAX_STAGE_TILES = 96
PRE_BLUR_RADIUS = 1.0
# Pre-quantization brightness lift (see "v2 still rendered the castle as
# a black silhouette" above). 1.6 was picked empirically: low enough that
# the already-bright sky/cloud quadrants don't clip to flat white, high
# enough that the castle stone's dark midtones cross from PAL_STONE's
# near-black slot ($0C) into its clearly-visible mid slot ($1C).
SOURCE_BRIGHTNESS = 1.6

NES_RGB = {
    0x0F: (0, 0, 0),
    0x21: (76, 154, 236), 0x31: (168, 204, 236), 0x20: (236, 238, 236),
    0x0C: (0, 50, 60),    0x1C: (0, 102, 120),    0x2C: (56, 180, 204),
    0x0A: (0, 64, 0),     0x1A: (8, 124, 0),       0x2A: (76, 208, 32),
}

BACKDROP = 0x0F
PAL_SKY = [BACKDROP, 0x21, 0x31, 0x20]
PAL_STONE = [BACKDROP, 0x0C, 0x1C, 0x2C]
PAL_FOLIAGE = [BACKDROP, 0x0A, 0x1A, 0x2A]
REGION_SKY, REGION_STONE, REGION_FOLIAGE = 0, 1, 2
PALETTES = {REGION_SKY: PAL_SKY, REGION_STONE: PAL_STONE, REGION_FOLIAGE: PAL_FOLIAGE}
SKY_ATTR_ROWS = 2


def color_dist(c1, c2):
    return (c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2


def classify_region(avg_rgb):
    r, g, b = avg_rgb
    if g - max(r, b) > 12:
        return REGION_FOLIAGE
    return REGION_STONE


def quantize_quadrant(img, qx, qy):
    pixels = [img.getpixel((qx * 16 + x, qy * 16 + y))[:3]
              for y in range(16) for x in range(16)]

    attr_row = (qy * 16) // 32
    if attr_row < SKY_ATTR_ROWS:
        region = REGION_SKY
    else:
        avg = tuple(sum(c[i] for c in pixels) / len(pixels) for i in range(3))
        region = classify_region(avg)

    pal = PALETTES[region]
    pal_rgb = [NES_RGB[c] for c in pal]

    out = [[0] * 16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            px = img.getpixel((qx * 16 + x, qy * 16 + y))[:3]
            best_i, best_d = 0, None
            for i, prgb in enumerate(pal_rgb):
                d = color_dist(px, prgb)
                if best_d is None or d < best_d:
                    best_d, best_i = d, i
            out[y][x] = best_i
    return region, out


def tile_to_2bpp(pixel_idx_8x8):
    lo = bytearray(8)
    hi = bytearray(8)
    for y in range(8):
        lo_byte = 0
        hi_byte = 0
        for x in range(8):
            v = pixel_idx_8x8[y][x] & 3
            lo_byte |= (v & 1) << (7 - x)
            hi_byte |= ((v >> 1) & 1) << (7 - x)
        lo[y] = lo_byte
        hi[y] = hi_byte
    return bytes(lo) + bytes(hi)


def pattern_diff(a, b):
    d = 0
    for ra, rb in zip(a, b):
        for va, vb in zip(ra, rb):
            d += abs(va - vb)
    return d


def main():
    if not os.path.exists(BG_IMAGE):
        raise SystemExit(f"ERROR: {BG_IMAGE} not found")
    if not os.path.exists(BG_CHR):
        raise SystemExit(f"ERROR: {BG_CHR} not found — run tools/extract_bg_bank.py first")

    img = Image.open(BG_IMAGE).convert("RGB")
    if img.size != (256, 224):
        img = img.resize((256, 224))
    img = ImageEnhance.Brightness(img).enhance(SOURCE_BRIGHTNESS)
    img = img.filter(ImageFilter.GaussianBlur(radius=PRE_BLUR_RADIUS))

    QW, QH = TILES_W // 2, TILES_H // 2
    quad_region = [[0] * QW for _ in range(QH)]
    pix_idx = [[0] * (TILES_W * 8) for _ in range(TILES_H * 8)]

    for qy in range(QH):
        for qx in range(QW):
            region, block = quantize_quadrant(img, qx, qy)
            quad_region[qy][qx] = region
            for y in range(16):
                for x in range(16):
                    pix_idx[qy * 16 + y][qx * 16 + x] = block[y][x]

    unique_tiles = {}
    tile_order = []
    nametable = [[0] * TILES_W for _ in range(TILES_H)]

    for ty in range(TILES_H):
        for tx in range(TILES_W):
            block = tuple(tuple(pix_idx[ty * 8 + y][tx * 8:tx * 8 + 8]) for y in range(8))
            if block in unique_tiles:
                idx = unique_tiles[block]
            elif len(tile_order) < MAX_STAGE_TILES:
                idx = len(tile_order)
                unique_tiles[block] = idx
                tile_order.append(block)
            else:
                idx = min(range(len(tile_order)), key=lambda i: pattern_diff(tile_order[i], block))
            nametable[ty][tx] = idx

    print(f"Unique background tiles used: {len(tile_order)} / budget {MAX_STAGE_TILES}")

    with open(BG_CHR, "rb") as f:
        bg_bank = bytearray(f.read())
    if len(bg_bank) != BANK_BYTES:
        raise SystemExit(f"ERROR: {BG_CHR} must be exactly {BANK_BYTES} bytes")

    for i, block in enumerate(tile_order):
        tile_bytes = tile_to_2bpp(block)
        local_idx = TILE_BASE + i
        if local_idx > 127:
            raise SystemExit("ERROR: background tiles overflow into the alphabet range (local 128+)")
        offset = local_idx * TILE_BYTES
        bg_bank[offset:offset + TILE_BYTES] = tile_bytes

    with open(BG_CHR, "wb") as f:
        f.write(bg_bank)
    print(f"Updated {BG_CHR} with {len(tile_order)} stage tiles starting at local {TILE_BASE}")

    attr_bytes = []
    for arow in range(8):
        for acol in range(8):
            byte = 0
            for qi, (dqy, dqx) in enumerate([(0, 0), (0, 1), (1, 0), (1, 1)]):
                qy = arow * 2 + dqy
                qx = acol * 2 + dqx
                region = quad_region[qy][qx] if qy < QH and qx < QW else REGION_STONE
                byte |= (region & 3) << (qi * 2)
            attr_bytes.append(byte)

    with open(OUT_INC, "w") as f:
        f.write("; AUTO-GENERATED by tools/bg_convert.py — DO NOT EDIT BY HAND\n")
        f.write("; Re-run `make bg` after changing assets/32732.png.\n\n")
        f.write(f"STAGE_TILE_BASE = {TILE_BASE}\n\n")
        f.write("stage_nametable:\n")
        for ty in range(TILES_H):
            row_vals = [str(TILE_BASE + nametable[ty][tx]) for tx in range(TILES_W)]
            f.write(f"    .byte {', '.join(row_vals)}\n")
        f.write("\n; Per-quadrant region palette assignment (0=sky BG0, 1=stone BG1,\n")
        f.write("; 2=foliage BG2), computed per 16x16px block from the source art.\n")
        f.write("stage_attribute_table:\n")
        for i in range(0, 64, 8):
            f.write("    .byte " + ", ".join(f"%{b:08b}" for b in attr_bytes[i:i + 8]) + "\n")

    print(f"Wrote {OUT_INC}")


if __name__ == "__main__":
    main()
