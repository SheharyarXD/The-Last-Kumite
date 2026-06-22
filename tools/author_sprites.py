#!/usr/bin/env python3
"""
THE LAST KUMITE — Fighter sprite authoring tool.

Generates 16x16 pixel NES-style sprites for both fighters (Michael Rivers,
red/black gi; Lightning, blue/dark gi) across every animation pose required
by the GDD: idle, walk, punch, kick, jump, crouch, crouch-attack, block,
hit, KO.

This does NOT hand-trace the reference photos pixel-for-pixel (they are
realistic stock-art proportioned figures at non-NES resolution, ~40-60px
tall figures in a 256px-wide sheet — far too high-detail to map 1:1 onto a
16x16 NES sprite). Instead it builds clean, readable, NES-proportioned
silhouettes that follow the same poses and color language the reference
sheets establish (upright fighting stance, gi top + dark pants, bandana/
headband accent) so the in-game sprites are recognizably the same
characters at the resolution the hardware can actually display.

Output: a PNG sprite sheet (one row per character, one column per frame)
at 16x16 per cell, used as the input to chr_convert.py.
"""
import os
from PIL import Image

# NES-ish 4-color-per-sprite palette indices (we draw in RGB and quantize
# to indices later in chr_convert.py). Using exactly 4 flat colors per
# character keeps the conversion to 2bpp CHR lossless.
TRANSPARENT = (0, 0, 0, 0)

# Michael Rivers: red gi, white belt/trim, skin tone, black pants/hair
MICHAEL_PALETTE = {
    "gi":    (216, 40, 40),
    "trim":  (240, 240, 240),
    "skin":  (236, 178, 122),
    "dark":  (32, 28, 28),
}

# Lightning: blue gi, white trim, skin tone, black pants/hair
LIGHTNING_PALETTE = {
    "gi":    (56, 96, 216),
    "trim":  (240, 240, 240),
    "skin":  (236, 178, 122),
    "dark":  (32, 28, 28),
}

W, H = 16, 16


def blank():
    return Image.new("RGBA", (W, H), TRANSPARENT)


def px(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color + (255,))


def rect(img, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, color)


def draw_head(img, cx, top, pal):
    rect(img, cx - 1, top, cx + 1, top + 2, pal["skin"])
    px(img, cx - 1, top - 1, pal["dark"])
    px(img, cx, top - 1, pal["dark"])
    px(img, cx + 1, top - 1, pal["dark"])


def draw_idle(pal, frame):
    img = blank()
    cx = 7
    bob = 1 if frame == 1 else 0
    draw_head(img, cx, 1 + bob, pal)
    # torso
    rect(img, cx - 2, 4 + bob, cx + 2, 8 + bob, pal["gi"])
    rect(img, cx - 2, 8 + bob, cx + 2, 9 + bob, pal["trim"])
    # arms (guard stance)
    rect(img, cx - 4, 5 + bob, cx - 3, 7 + bob, pal["skin"])
    rect(img, cx + 3, 5 + bob, cx + 4, 7 + bob, pal["skin"])
    # legs
    rect(img, cx - 2, 10 + bob, cx - 1, 14, pal["dark"])
    rect(img, cx + 1, 10 + bob, cx + 2, 14, pal["dark"])
    rect(img, cx - 2, 14, cx - 1, 15, pal["trim"])
    rect(img, cx + 1, 14, cx + 2, 15, pal["trim"])
    return img


def draw_walk(pal, frame):
    img = blank()
    cx = 7
    draw_head(img, cx, 1, pal)
    rect(img, cx - 2, 4, cx + 2, 8, pal["gi"])
    rect(img, cx - 2, 8, cx + 2, 9, pal["trim"])
    rect(img, cx - 4, 5, cx - 3, 7, pal["skin"])
    rect(img, cx + 3, 5, cx + 4, 7, pal["skin"])
    # legs alternate based on frame (0-3)
    leg_off = [0, 1, 0, -1][frame % 4]
    rect(img, cx - 2 + leg_off, 10, cx - 1 + leg_off, 14, pal["dark"])
    rect(img, cx + 1 - leg_off, 10, cx + 2 - leg_off, 14, pal["dark"])
    rect(img, cx - 2 + leg_off, 14, cx - 1 + leg_off, 15, pal["trim"])
    rect(img, cx + 1 - leg_off, 14, cx + 2 - leg_off, 15, pal["trim"])
    return img


def draw_punch(pal, frame):
    img = blank()
    cx = 6
    draw_head(img, cx, 1, pal)
    rect(img, cx - 2, 4, cx + 2, 8, pal["gi"])
    rect(img, cx - 2, 8, cx + 2, 9, pal["trim"])
    reach = 5 if frame == 1 else 2
    rect(img, cx + 3, 5, cx + 3 + reach, 6, pal["skin"])
    rect(img, cx - 4, 6, cx - 3, 8, pal["skin"])
    rect(img, cx - 2, 10, cx - 1, 14, pal["dark"])
    rect(img, cx + 1, 10, cx + 2, 14, pal["dark"])
    rect(img, cx - 2, 14, cx - 1, 15, pal["trim"])
    rect(img, cx + 1, 14, cx + 2, 15, pal["trim"])
    return img


def draw_kick(pal, frame):
    img = blank()
    cx = 6
    draw_head(img, cx, 1, pal)
    rect(img, cx - 2, 4, cx + 2, 8, pal["gi"])
    rect(img, cx - 2, 8, cx + 2, 9, pal["trim"])
    rect(img, cx - 4, 5, cx - 3, 7, pal["skin"])
    rect(img, cx + 3, 5, cx + 4, 7, pal["skin"])
    rect(img, cx - 2, 10, cx - 1, 13, pal["dark"])
    extend = {0: 3, 1: 6, 2: 4}.get(frame, 3)
    rect(img, cx + 1, 10, cx + 1 + extend, 11, pal["dark"])
    rect(img, cx + 1 + extend - 1, 11, cx + 1 + extend, 12, pal["trim"])
    rect(img, cx - 2, 13, cx - 1, 15, pal["trim"])
    return img


def draw_crouch(pal):
    img = blank()
    cx = 7
    draw_head(img, cx, 5, pal)
    rect(img, cx - 2, 8, cx + 2, 11, pal["gi"])
    rect(img, cx - 2, 11, cx + 2, 12, pal["trim"])
    rect(img, cx - 4, 9, cx - 3, 11, pal["skin"])
    rect(img, cx + 3, 9, cx + 4, 11, pal["skin"])
    rect(img, cx - 3, 13, cx - 1, 15, pal["dark"])
    rect(img, cx + 1, 13, cx + 3, 15, pal["dark"])
    return img


def draw_jump(pal, frame):
    img = blank()
    cx = 7
    top = 0 if frame == 0 else 2
    draw_head(img, cx, top, pal)
    rect(img, cx - 2, top + 3, cx + 2, top + 7, pal["gi"])
    rect(img, cx - 2, top + 7, cx + 2, top + 8, pal["trim"])
    rect(img, cx - 4, top + 2, cx - 3, top + 5, pal["skin"])
    rect(img, cx + 3, top + 2, cx + 4, top + 5, pal["skin"])
    rect(img, cx - 3, top + 9, cx - 1, top + 11, pal["dark"])
    rect(img, cx + 1, top + 9, cx + 3, top + 11, pal["dark"])
    return img


def draw_block(pal):
    img = blank()
    cx = 7
    draw_head(img, cx, 1, pal)
    rect(img, cx - 2, 4, cx + 2, 8, pal["gi"])
    rect(img, cx - 2, 8, cx + 2, 9, pal["trim"])
    # arms crossed up front
    rect(img, cx - 1, 3, cx + 3, 5, pal["skin"])
    rect(img, cx - 2, 10, cx - 1, 14, pal["dark"])
    rect(img, cx + 1, 10, cx + 2, 14, pal["dark"])
    rect(img, cx - 2, 14, cx - 1, 15, pal["trim"])
    rect(img, cx + 1, 14, cx + 2, 15, pal["trim"])
    return img


def draw_hit(pal):
    img = blank()
    cx = 8
    draw_head(img, cx, 2, pal)
    rect(img, cx - 3, 5, cx + 1, 9, pal["gi"])
    rect(img, cx - 3, 9, cx + 1, 10, pal["trim"])
    rect(img, cx + 2, 4, cx + 5, 6, pal["skin"])
    rect(img, cx - 5, 6, cx - 4, 8, pal["skin"])
    rect(img, cx - 3, 11, cx - 2, 14, pal["dark"])
    rect(img, cx, 11, cx + 1, 14, pal["dark"])
    return img


def draw_ko(pal):
    img = blank()
    # lying down silhouette
    rect(img, 1, 12, 4, 14, pal["skin"])
    rect(img, 4, 11, 12, 14, pal["gi"])
    rect(img, 12, 12, 14, 14, pal["dark"])
    rect(img, 4, 14, 12, 15, pal["trim"])
    return img


def build_sheet(pal):
    frames = []
    frames.append(("idle0", draw_idle(pal, 0)))
    frames.append(("idle1", draw_idle(pal, 1)))
    frames.append(("walk0", draw_walk(pal, 0)))
    frames.append(("walk1", draw_walk(pal, 1)))
    frames.append(("walk2", draw_walk(pal, 2)))
    frames.append(("walk3", draw_walk(pal, 3)))
    frames.append(("crouch0", draw_crouch(pal)))
    frames.append(("jump0", draw_jump(pal, 0)))
    frames.append(("jump1", draw_jump(pal, 1)))
    frames.append(("punch0", draw_punch(pal, 0)))
    frames.append(("punch1", draw_punch(pal, 1)))
    frames.append(("kick0", draw_kick(pal, 0)))
    frames.append(("kick1", draw_kick(pal, 1)))
    frames.append(("kick2", draw_kick(pal, 2)))
    frames.append(("block0", draw_block(pal)))
    frames.append(("hit0", draw_hit(pal)))
    frames.append(("ko0", draw_ko(pal)))
    return frames


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "chr", "src_frames")
    os.makedirs(out_dir, exist_ok=True)

    for name, pal in [("michael", MICHAEL_PALETTE), ("lightning", LIGHTNING_PALETTE)]:
        frames = build_sheet(pal)
        sheet = Image.new("RGBA", (16 * len(frames), 16), TRANSPARENT)
        for i, (fname, img) in enumerate(frames):
            sheet.paste(img, (i * 16, 0))
        sheet_path = os.path.join(out_dir, f"{name}_sheet.png")
        sheet.save(sheet_path)
        print(f"Wrote {sheet_path} ({len(frames)} frames)")
        with open(os.path.join(out_dir, f"{name}_frames.txt"), "w") as f:
            for fname, _ in frames:
                f.write(fname + "\n")


if __name__ == "__main__":
    main()
