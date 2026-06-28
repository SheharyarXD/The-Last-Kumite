#!/usr/bin/env python3
"""
THE LAST KUMITE — Ron Hall "thumbs down" Game Over portrait.

Hand-authors a 56x72 pixel illustration of Ron Hall giving the double
thumbs-down, guided by assets/thumbs.png (the client's reference art).
This is drawn rather than auto-downscaled/quantized: at this resolution
and a 3-color-per-sprite NES budget, naive downscale+quantize of the
photographic-shaded reference loses the face/hair structure and produces
speckled noise (see docs/asset_pipeline.md for the same issue and fix on
the fight-stage background). A deliberate flat-color illustration that
follows the reference's silhouette, pose, and palette (dark teal/navy
robe, gold trim, orange/tan skin, blonde-rendered-as-gold hair) reads far
more clearly at NES sprite resolution.

Output: chr/src_frames/gameover_thumbs.png, a 56x72 RGBA sheet (7x9 tiles)
consumed by tools/chr_convert.py and placed in pattern table 1 (the sprite
bank) alongside the fighter frames, since pattern table 0 (background/UI)
has no free tile budget left (see asset_pipeline.md tile budget notes).
"""
import os
from PIL import Image

TRANSPARENT = (0, 0, 0, 0)
ROBE = (16, 38, 52)      # dark teal/navy robe
TRIM = (224, 168, 24)    # gold trim / hair
SKIN = (230, 110, 48)    # orange/tan skin

W, H = 56, 56


def blank():
    return Image.new("RGBA", (W, H), TRANSPARENT)


def px(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color + (255,))


def rect(img, x0, y0, x1, y1, color):
    if x1 < x0 or y1 < y0:
        return
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, color)


def diag_fill(img, x0, y0, x1, y1, color, taper):
    """Vertical strip whose width tapers linearly between two x-ranges,
    used for the flared robe sleeves and skirt."""
    h = y1 - y0
    for i, y in enumerate(range(y0, y1 + 1)):
        t = i / max(h, 1)
        lx = x0 - int(taper * t)
        rx = x1 + int(taper * t)
        rect(img, lx, y, rx, y, color)


def draw():
    img = blank()
    cx = 28

    # --- Hair mass behind/around the head, flowing past the shoulders ---
    rect(img, cx - 9, 2, cx + 9, 9, TRIM)
    rect(img, cx - 11, 6, cx - 9, 22, TRIM)
    rect(img, cx + 9, 6, cx + 11, 22, TRIM)
    rect(img, cx - 12, 14, cx - 10, 26, TRIM)
    rect(img, cx + 10, 14, cx + 12, 26, TRIM)

    # --- Face (skin) inset within the hair frame ---
    rect(img, cx - 6, 5, cx + 6, 15, SKIN)
    # Simple smiling features in a dark tone (eyebrows + grin), enough to
    # read as a face at a glance without a 4th color
    rect(img, cx - 4, 9, cx - 2, 9, ROBE)
    rect(img, cx + 2, 9, cx + 4, 9, ROBE)
    rect(img, cx - 3, 13, cx + 3, 13, ROBE)

    # --- Neck / chest V opening (skin) leading down into the robe ---
    rect(img, cx - 3, 16, cx + 3, 22, SKIN)
    # Medallion at the base of the V
    rect(img, cx - 1, 20, cx + 1, 22, TRIM)

    # --- Robe body (torso), flaring out toward the waist ---
    diag_fill(img, cx - 9, 16, cx + 9, 44, ROBE, taper=10)
    # Gold trim lining the V-neck opening
    rect(img, cx - 4, 16, cx - 3, 23, TRIM)
    rect(img, cx + 3, 16, cx + 4, 23, TRIM)
    # Belt
    rect(img, cx - 11, 42, cx + 11, 45, ROBE)
    rect(img, cx - 3, 43, cx + 3, 44, TRIM)

    # --- Robe skirt below the belt (shortened to fit the 56x56 canvas --
    #     the face, arms, and fists matter far more for recognizability
    #     than how far the hem extends) ---
    diag_fill(img, cx - 11, 46, cx + 11, 55, ROBE, taper=2)

    # --- Raised sleeves/arms angling up and outward to the thumbs-down
    #     fists, with a gold cuff stripe near each wrist ---
    for i in range(0, 16):
        y = 17 + i
        x0 = cx - 9 - i
        x1 = cx - 9 - i + 6
        rect(img, x0, y, x1, y, ROBE)
    rect(img, cx - 9 - 17, 28, cx - 9 - 11, 32, TRIM)   # left cuff
    rect(img, cx - 9 - 19, 16, cx - 9 - 12, 28, ROBE)   # forearm to fist

    for i in range(0, 16):
        y = 17 + i
        x0 = cx + 9 + i - 6
        x1 = cx + 9 + i
        rect(img, x0, y, x1, y, ROBE)
    rect(img, cx + 9 + 11, 28, cx + 9 + 17, 32, TRIM)   # right cuff
    rect(img, cx + 9 + 12, 16, cx + 9 + 19, 28, ROBE)   # forearm to fist

    # --- Fists (skin), narrower than the cuff, with a small thumb tab
    #     projecting straight down -- the unmistakable "thumbs down" tell ---
    rect(img, cx - 9 - 17, 9, cx - 9 - 10, 19, SKIN)
    rect(img, cx - 9 - 15, 20, cx - 9 - 12, 25, SKIN)   # thumb tab, pointing down
    rect(img, cx + 9 + 10, 9, cx + 9 + 17, 19, SKIN)
    rect(img, cx + 9 + 12, 20, cx + 9 + 15, 25, SKIN)   # thumb tab, pointing down

    return img


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "chr", "src_frames")
    os.makedirs(out_dir, exist_ok=True)
    img = draw()
    out_path = os.path.join(out_dir, "gameover_thumbs.png")
    img.save(out_path)
    print(f"Wrote {out_path} ({img.size[0]}x{img.size[1]} = "
          f"{img.size[0] // 8}x{img.size[1] // 8} tiles)")


if __name__ == "__main__":
    main()
