#!/usr/bin/env python3
"""
THE LAST KUMITE — VS screen character portraits.

Hand-authors a 32x48 pixel portrait of each fighter for the VS screen,
guided by the same reference sheets used for the in-game fighter sprites
(assets/sprites char (1).png for Lightning's blue gi, assets/Design2-
juanjuanh-BC802-IMAGE1-1.png for Michael's orange/red gi) and using the
identical 3-color-per-sprite palette convention (gi color, gold accent,
dark hair/pants) established in tools/author_sprites.py, just at a larger,
single-pose scale appropriate for a face-off screen portrait rather than a
16x16 animation frame.

Output: chr/src_frames/vs_michael.png and chr/src_frames/vs_lightning.png,
each a 32x48 RGBA sheet (4x6 tiles) consumed by tools/chr_convert.py and
placed in the sprite pattern table bank alongside the fighter frames.
"""
import os
from PIL import Image

TRANSPARENT = (0, 0, 0, 0)

MICHAEL_PALETTE = {
    "gi":     (216, 64, 24),
    "accent": (232, 156, 40),
    "dark":   (20, 18, 18),
}
LIGHTNING_PALETTE = {
    "gi":     (40, 88, 216),
    "accent": (232, 156, 40),
    "dark":   (20, 18, 18),
}

W, H = 32, 32


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


def draw_portrait(pal, facing=1):
    """A tight bust-only portrait (head + shoulders) facing the opponent.
    facing: 1 = faces right (Michael, left side of VS screen),
            -1 = faces left (Lightning, right side of VS screen)."""
    img = blank()
    cx = 16

    # Hair: spiky mass with a forward-leaning spike toward facing dir
    rect(img, cx - 5, 0, cx + 5, 5, pal["dark"])
    px(img, cx - 6, 3, pal["dark"])
    px(img, cx + 6, 3, pal["dark"])
    rect(img, cx + 5 * facing, 0, cx + 7 * facing, 1, pal["dark"])

    # Headband stripe across the brow
    rect(img, cx - 5, 6, cx + 5, 7, pal["accent"])
    px(img, cx + 5 * facing, 6, pal["accent"])

    # Face sliver (kept dark like the 16x16 sprites -- no separate skin
    # tone in the 3-color budget; see author_sprites.py for the rationale)
    rect(img, cx - 4, 8, cx + 4, 10, pal["dark"])

    # Neck into the gi top
    rect(img, cx - 2, 11, cx + 2, 12, pal["gi"])

    # Shoulders/chest filling the rest of the portrait, wide and confident
    rect(img, cx - 14, 13, cx + 14, 14, pal["gi"])
    rect(img, cx - 15, 15, cx + 15, 27, pal["gi"])

    # Sash peeking at the bottom edge
    rect(img, cx - 15, 28, cx + 15, 31, pal["accent"])

    return img


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "chr", "src_frames")
    os.makedirs(out_dir, exist_ok=True)

    michael = draw_portrait(MICHAEL_PALETTE, facing=1)
    michael_path = os.path.join(out_dir, "vs_michael.png")
    michael.save(michael_path)
    print(f"Wrote {michael_path} ({W}x{H} = {W // 8}x{H // 8} tiles)")

    lightning = draw_portrait(LIGHTNING_PALETTE, facing=-1)
    lightning_path = os.path.join(out_dir, "vs_lightning.png")
    lightning.save(lightning_path)
    print(f"Wrote {lightning_path} ({W}x{H} = {W // 8}x{H // 8} tiles)")


if __name__ == "__main__":
    main()
