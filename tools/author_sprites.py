#!/usr/bin/env python3
"""
THE LAST KUMITE — Fighter sprite authoring tool.

Generates 16x16 pixel NES-style sprites for both fighters (Michael Rivers,
red-orange gi; Lightning, blue gi) across every animation pose required by
the GDD: idle, walk, punch, kick, jump, crouch, crouch-attack, block, hit,
KO.

This does NOT hand-trace the reference photos pixel-for-pixel (they are
illustrated figures at non-NES resolution, roughly 40-60px tall on a 256px
sheet -- too high-detail to map losslessly onto a 16x16 NES sprite, which
also only gets 3 real colors + transparent on real hardware). Instead it
builds clean, readable, NES-proportioned silhouettes that follow the same
poses and color language the reference sheets (assets/sprites char (1).png,
assets/Design2-juanjuanh-BC802-IMAGE1-1.png) establish: spiky hair with a
headband, a gi top in the fighter's color, a contrasting sash/belt, dark gi
pants, and gold/orange hands+feet -- the reference sheets use that same warm
accent tone for headband, sash, and hands/feet on both fighters, so it is
shared as a single accent color here (see the 3-color budget note in
tools/chr_convert.py's quantize_5_to_4).

Output: a PNG sprite sheet (one row per character, one column per frame)
at 16x16 per cell, used as the input to chr_convert.py.
"""
import os
from PIL import Image

TRANSPARENT = (0, 0, 0, 0)

# Michael Rivers: red-orange gi, gold accent (headband/sash/hands/feet),
# near-black hair/pants. Drawn in full RGB; chr_convert.py quantizes down
# to the in-game 3-color sprite palette (see init.asm SPR0).
MICHAEL_PALETTE = {
    "gi":     (216, 64, 24),
    "accent": (232, 156, 40),
    "dark":   (20, 18, 18),
}

# Lightning: blue gi, same gold accent, near-black hair/pants (see init.asm
# SPR1) -- matches the reference sheets, which use identical accent/dark
# tones for both fighters and only swap the gi color.
LIGHTNING_PALETTE = {
    "gi":     (40, 88, 216),
    "accent": (232, 156, 40),
    "dark":   (20, 18, 18),
}

W, H = 16, 16


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


def draw_head(img, cx, top, pal, facing=1, tilt=0):
    """Spiky hair block with a headband stripe across the forehead.
    facing: 1 = right, -1 = left (shifts the hair spike forward).
    tilt: extra rows the head is lowered (crouch/hit poses)."""
    top += tilt
    rect(img, cx - 1, top, cx + 1, top + 1, pal["dark"])
    px(img, cx - 2, top + 1, pal["dark"])
    px(img, cx + 2, top + 1, pal["dark"])
    px(img, cx + 2 * facing, top, pal["dark"])
    rect(img, cx - 1, top + 2, cx + 1, top + 2, pal["accent"])
    px(img, cx + facing, top + 2, pal["accent"])
    rect(img, cx - 1, top + 3, cx + 1, top + 3, pal["dark"])


def draw_torso(img, cx, top, pal, w=2):
    """Gi top + sash. w = half-width of the torso block."""
    rect(img, cx - w, top, cx + w, top + 3, pal["gi"])
    rect(img, cx - w, top + 4, cx + w, top + 4, pal["accent"])


def draw_legs(img, cx, top, pal, leg_off=0, h=5):
    """Standing/walking legs: dark gi pants, accent boots at the foot."""
    rect(img, cx - 2 + leg_off, top, cx - 1 + leg_off, top + h - 1, pal["dark"])
    rect(img, cx + 1 - leg_off, top, cx + 2 - leg_off, top + h - 1, pal["dark"])
    rect(img, cx - 2 + leg_off, top + h, cx - 1 + leg_off, top + h + 1, pal["accent"])
    rect(img, cx + 1 - leg_off, top + h, cx + 2 - leg_off, top + h + 1, pal["accent"])


def draw_idle(pal, frame):
    img = blank()
    cx = 7
    bob = 1 if frame == 1 else 0
    draw_head(img, cx, 1 + bob, pal)
    draw_torso(img, cx, 5 + bob, pal)
    rect(img, cx - 4, 6 + bob, cx - 3, 7 + bob, pal["accent"])
    rect(img, cx + 3, 6 + bob, cx + 4, 7 + bob, pal["accent"])
    draw_legs(img, cx, 10 + bob, pal, h=14 - (10 + bob))
    return img


def draw_walk(pal, frame):
    img = blank()
    cx = 7
    draw_head(img, cx, 1, pal)
    draw_torso(img, cx, 5, pal)
    rect(img, cx - 4, 6, cx - 3, 7, pal["accent"])
    rect(img, cx + 3, 6, cx + 4, 7, pal["accent"])
    leg_off = [0, 1, 0, -1][frame % 4]
    draw_legs(img, cx, 10, pal, leg_off=leg_off, h=4)
    return img


def draw_punch(pal, frame):
    img = blank()
    cx = 6
    draw_head(img, cx, 1, pal)
    draw_torso(img, cx, 5, pal)
    reach = 6 if frame == 1 else 3
    rect(img, cx + 3, 5, cx + 1 + reach, 6, pal["gi"])
    rect(img, cx + 2 + reach, 5, cx + 3 + reach, 6, pal["accent"])
    rect(img, cx - 4, 7, cx - 3, 8, pal["accent"])
    draw_legs(img, cx, 10, pal, h=4)
    return img


def draw_kick(pal, frame):
    img = blank()
    cx = 6
    draw_head(img, cx, 1, pal)
    draw_torso(img, cx, 5, pal)
    rect(img, cx - 4, 6, cx - 3, 7, pal["accent"])
    rect(img, cx + 3, 6, cx + 4, 7, pal["accent"])
    rect(img, cx - 2, 10, cx - 1, 13, pal["dark"])
    rect(img, cx - 2, 14, cx - 1, 15, pal["accent"])
    extend = {0: 3, 1: 7, 2: 5}.get(frame, 3)
    rise = {0: 0, 1: 2, 2: 1}.get(frame, 0)
    rect(img, cx + 1, 10 - rise, cx + 1 + extend, 11 - rise, pal["dark"])
    rect(img, cx + extend, 11 - rise, cx + 1 + extend, 12 - rise, pal["accent"])
    return img


def draw_crouch(pal):
    img = blank()
    cx = 7
    draw_head(img, cx, 5, pal)
    draw_torso(img, cx, 9, pal, w=2)
    rect(img, cx - 4, 10, cx - 3, 11, pal["accent"])
    rect(img, cx + 3, 10, cx + 4, 11, pal["accent"])
    rect(img, cx - 3, 13, cx - 1, 14, pal["dark"])
    rect(img, cx + 1, 13, cx + 3, 14, pal["dark"])
    rect(img, cx - 3, 15, cx - 1, 15, pal["accent"])
    rect(img, cx + 1, 15, cx + 3, 15, pal["accent"])
    return img


def draw_jump(pal, frame):
    img = blank()
    cx = 7
    top = 0 if frame == 0 else 2
    draw_head(img, cx, top, pal)
    draw_torso(img, cx, top + 4, pal)
    rect(img, cx - 4, top + 3, cx - 3, top + 4, pal["accent"])
    rect(img, cx + 3, top + 3, cx + 4, top + 4, pal["accent"])
    rect(img, cx - 3, top + 9, cx - 1, top + 10, pal["dark"])
    rect(img, cx + 1, top + 9, cx + 3, top + 10, pal["dark"])
    rect(img, cx - 3, top + 11, cx - 1, top + 11, pal["accent"])
    rect(img, cx + 1, top + 11, cx + 3, top + 11, pal["accent"])
    return img


def draw_block(pal):
    img = blank()
    cx = 7
    draw_head(img, cx, 1, pal)
    draw_torso(img, cx, 5, pal)
    rect(img, cx - 1, 2, cx + 2, 3, pal["accent"])
    rect(img, cx - 1, 4, cx + 2, 4, pal["gi"])
    draw_legs(img, cx, 10, pal, h=4)
    return img


def draw_hit(pal):
    img = blank()
    cx = 8
    draw_head(img, cx, 2, pal, facing=-1, tilt=1)
    draw_torso(img, cx - 1, 7, pal, w=2)
    rect(img, cx + 2, 5, cx + 4, 6, pal["accent"])
    rect(img, cx - 5, 7, cx - 4, 8, pal["accent"])
    rect(img, cx - 3, 12, cx - 2, 14, pal["dark"])
    rect(img, cx, 12, cx + 1, 14, pal["dark"])
    rect(img, cx - 3, 15, cx - 2, 15, pal["accent"])
    rect(img, cx, 15, cx + 1, 15, pal["accent"])
    return img


def draw_ko(pal):
    img = blank()
    rect(img, 0, 12, 2, 13, pal["dark"])
    rect(img, 1, 13, 3, 14, pal["accent"])
    rect(img, 3, 11, 11, 14, pal["gi"])
    rect(img, 3, 14, 11, 14, pal["accent"])
    rect(img, 11, 12, 14, 14, pal["dark"])
    rect(img, 13, 14, 15, 15, pal["accent"])
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
