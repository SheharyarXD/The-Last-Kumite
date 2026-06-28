#!/usr/bin/env python3
"""
THE LAST KUMITE — CHR build pipeline.

Converts authored PNG sprite sheets (see author_sprites.py) into NES 2bpp
CHR tile data, merges them with the existing background/UI/font tile bank,
and writes the final chr/tiles.chr (8KB, 512 tiles) used by the ROM.

It also emits src/sprite_tiles.inc: ca65 .byte tables giving the LOCAL
(pattern-table-1) tile index for the top-left tile of every authored frame,
for both fighters. player.asm / enemy.asm include this file directly, so
the CHR data and the sprite-map tables that reference it are generated
from the same source of truth and cannot silently drift apart.

Usage: python3 tools/chr_convert.py
Reads:  chr/src_frames/{michael,lightning}_sheet.png (+ *_frames.txt)
        chr/tiles_bg.chr  (existing background/UI/font tile bank, pattern
                           table 0)
Writes: chr/tiles.chr (final 8KB CHR-ROM)
        src/sprite_tiles.inc
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC_FRAMES = os.path.join(ROOT, "chr", "src_frames")
BG_CHR = os.path.join(ROOT, "chr", "tiles_bg.chr")
OUT_CHR = os.path.join(ROOT, "chr", "tiles.chr")
OUT_INC_CONSTANTS = os.path.join(ROOT, "src", "sprite_tiles_const.inc")
OUT_INC_PLAYER = os.path.join(ROOT, "src", "sprite_tiles_player.inc")
OUT_INC_ENEMY = os.path.join(ROOT, "src", "sprite_tiles_enemy.inc")

TILE_BYTES = 16
TILES_PER_BANK = 256
BANK_BYTES = TILE_BYTES * TILES_PER_BANK  # 4096

MICHAEL_GI = (216, 64, 24)
LIGHTNING_GI = (40, 88, 216)


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


def sprite16_to_tiles(pixel_idx_16x16):
    quads = []
    for qy in (0, 8):
        for qx in (0, 8):
            block = [[pixel_idx_16x16[qy + y][qx + x] for x in range(8)] for y in range(8)]
            quads.append(tile_to_2bpp(block))
    return [quads[0], quads[1], quads[2], quads[3]]


def quantize_5_to_4(img, gi_rgb):
    """Map authored RGBA pixels onto a 4-entry NES sprite palette:
      0 = transparent (no sprite pixel drawn)
      1 = gi color (red-orange for Michael, blue for Lightning)
      2 = warm gold/orange accent (headband, sash, hands, feet/boots --
          the reference art uses the same warm accent tone for all of
          these on both fighters)
      3 = dark (hair, pants) -- maps to black ($0F) in the in-game sprite
          palette (init.asm), not a skin tone; there is no separate skin
          color in this 3-color budget, so hands/feet are folded into the
          index-2 accent bucket instead (see author_sprites.py) since the
          reference sheets render them in a matching warm tone anyway.
    """
    w, h = img.size
    out = [[0] * w for _ in range(h)]
    table = {1: gi_rgb, 2: (232, 156, 40), 3: (20, 18, 18)}
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                out[y][x] = 0
                continue
            best, best_d = 1, None
            for i in (1, 2, 3):
                pr, pg, pb = table[i]
                d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
                if best_d is None or d < best_d:
                    best_d, best = d, i
            out[y][x] = best
    return out


def quantize_generic_3color(img, color1, color2, color3):
    """Like quantize_5_to_4, but for one-off static images (VS portraits,
    the Game Over thumbs-down art) authored with their own named palette
    rather than the fighter gi/accent/dark convention. Same 0=transparent,
    nearest-of-3 mapping otherwise."""
    w, h = img.size
    out = [[0] * w for _ in range(h)]
    table = {1: color1, 2: color2, 3: color3}
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                out[y][x] = 0
                continue
            best, best_d = 1, None
            for i in (1, 2, 3):
                pr, pg, pb = table[i]
                d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
                if best_d is None or d < best_d:
                    best_d, best = d, i
            out[y][x] = best
    return out


def load_static_image(filename):
    path = os.path.join(SRC_FRAMES, filename)
    return Image.open(path).convert("RGBA")


def build_static_tile_block(img, color1, color2, color3):
    """Convert an arbitrary-sized (multiple-of-8 in both dimensions) RGBA
    image into a flat list of 2bpp tile bytes, reading left-to-right,
    top-to-bottom in 8x8 cells -- i.e. NOT the 2x2-quad metasprite order
    sprite16_to_tiles uses for animation frames, since these are static
    images drawn once by a dedicated render routine that walks tiles in
    simple raster order."""
    w, h = img.size
    assert w % 8 == 0 and h % 8 == 0, f"image size {img.size} must be a multiple of 8x8"
    pix = quantize_generic_3color(img, color1, color2, color3)
    tiles = []
    for ty in range(h // 8):
        for tx in range(w // 8):
            block = [[pix[ty * 8 + y][tx * 8 + x] for x in range(8)] for y in range(8)]
            tiles.append(tile_to_2bpp(block))
    return tiles, (w // 8, h // 8)


def load_frames(name):
    sheet_path = os.path.join(SRC_FRAMES, f"{name}_sheet.png")
    names_path = os.path.join(SRC_FRAMES, f"{name}_frames.txt")
    sheet = Image.open(sheet_path).convert("RGBA")
    with open(names_path) as f:
        names = [l.strip() for l in f if l.strip()]
    n = len(names)
    frame_w = sheet.width // n
    frames = []
    for i, fname in enumerate(names):
        frame = sheet.crop((i * frame_w, 0, (i + 1) * frame_w, sheet.height))
        frames.append((fname, frame))
    return frames


def build_sprite_bank(name, gi_rgb):
    frames = load_frames(name)
    tiles = []
    index_map = {}
    for fname, img in frames:
        pix = quantize_5_to_4(img, gi_rgb)
        quad_tiles = sprite16_to_tiles(pix)
        index_map[fname] = len(tiles)
        tiles.extend(quad_tiles)
    return tiles, index_map


def main():
    if not os.path.exists(BG_CHR):
        raise SystemExit(
            f"ERROR: {BG_CHR} not found. Run tools/extract_bg_bank.py once "
            f"to extract the background/UI/font tile bank from the "
            f"previously-working chr/tiles.chr before running this script."
        )

    with open(BG_CHR, "rb") as f:
        bg_bank = f.read()
    if len(bg_bank) != BANK_BYTES:
        raise SystemExit(f"ERROR: {BG_CHR} must be exactly {BANK_BYTES} bytes, got {len(bg_bank)}")

    michael_tiles, michael_map = build_sprite_bank("michael", MICHAEL_GI)
    lightning_tiles, lightning_map = build_sprite_bank("lightning", LIGHTNING_GI)

    sprite_bank = bytearray(BANK_BYTES)
    offset = 0
    for t in michael_tiles:
        sprite_bank[offset:offset + TILE_BYTES] = t
        offset += TILE_BYTES
    michael_base = 0

    lightning_base = offset // TILE_BYTES
    for t in lightning_tiles:
        sprite_bank[offset:offset + TILE_BYTES] = t
        offset += TILE_BYTES

    print(f"Michael: {len(michael_tiles)//4} frames, {len(michael_tiles)} tiles, base local index {michael_base}")
    print(f"Lightning: {len(lightning_tiles)//4} frames, {len(lightning_tiles)} tiles, base local index {lightning_base}")
    next_free = offset // TILE_BYTES
    print(f"Next free local tile index: {next_free}")

    effect_base = next_free
    # --- Static one-off images: VS portraits + Game Over thumbs-down art.
    # Placed right after the effect tiles, in the space freed up by the
    # fighter sprite rework (see asset_pipeline.md tile budget notes).
    # Tile 242 is skipped (title.asm hardcodes $F2 for its sparkle sprite);
    # everything else in 156-255 is free, including the old 252 "solid
    # block" placeholder tile since vs_screen.asm no longer uses it.
    RESERVED_TILES = {242}
    static_base = effect_base + 20  # 20 effect tiles
    static_layout = {}
    static_cursor = static_base

    def next_free_tile():
        nonlocal static_cursor
        while static_cursor in RESERVED_TILES:
            static_cursor += 1
        t = static_cursor
        static_cursor += 1
        return t

    for out_name, filename, colors in [
        ("gameover_thumbs", "gameover_thumbs.png", ((230, 110, 48), (224, 168, 24), (16, 38, 52))),
        ("vs_michael", "vs_michael.png", ((216, 64, 24), (232, 156, 40), (20, 18, 18))),
        ("vs_lightning", "vs_lightning.png", ((40, 88, 216), (232, 156, 40), (20, 18, 18))),
    ]:
        path = os.path.join(SRC_FRAMES, filename)
        if not os.path.exists(path):
            print(f"WARNING: {path} not found, skipping {out_name} (run the matching author_*.py tool)")
            continue
        img = load_static_image(filename)
        tiles, (tiles_w, tiles_h) = build_static_tile_block(img, *colors)
        placed_indices = []
        for t in tiles:
            idx = next_free_tile()
            if idx > 255:
                raise SystemExit(
                    f"ERROR: static image '{out_name}' overflows the sprite pattern table "
                    f"(ran out of local tile indices at 255)"
                )
            sprite_bank[idx * TILE_BYTES:idx * TILE_BYTES + TILE_BYTES] = t
            placed_indices.append(idx)
        # These images are always placed in one contiguous run in practice
        # (the only reserved tile, 242, falls after all three at current
        # sizes); assert that here so a future size change that would
        # actually fragment the block fails loudly instead of silently
        # emitting a wrong base index.
        if placed_indices != list(range(placed_indices[0], placed_indices[0] + len(placed_indices))):
            raise SystemExit(
                f"ERROR: static image '{out_name}' was fragmented by a reserved tile -- "
                f"raster order assumes a contiguous block. Adjust RESERVED_TILES handling "
                f"or shrink/reorder the static images so this one doesn't straddle tile 242."
            )
        base = placed_indices[0]
        static_layout[out_name] = (base, tiles_w, tiles_h)
        print(f"{out_name}: {tiles_w}x{tiles_h} tiles, base local index {base}")

    if os.path.exists(OUT_CHR):
        with open(OUT_CHR, "rb") as f:
            old = f.read()
        if len(old) == BANK_BYTES * 2:
            old_sprite_bank = old[BANK_BYTES:]
            # Effect tiles previously lived at local 128-147 (20 tiles) in
            # the old layout. Copy them to the first free slot after both
            # fighters' frames instead of their old fixed location, since
            # that range now legitimately belongs to character animation
            # frames.
            num_effect_tiles = 20
            src_start = 128 * TILE_BYTES
            src_end = src_start + num_effect_tiles * TILE_BYTES
            dst_start = effect_base * TILE_BYTES
            dst_end = dst_start + num_effect_tiles * TILE_BYTES
            if dst_end > BANK_BYTES:
                raise SystemExit(
                    f"ERROR: not enough room in the sprite pattern table for "
                    f"effect tiles (need tiles {effect_base}-{effect_base+num_effect_tiles-1}, "
                    f"bank only holds 256 tiles)."
                )
            sprite_bank[dst_start:dst_end] = old_sprite_bank[src_start:src_end]
            print(f"Relocated effect tiles to local {effect_base}-{effect_base+num_effect_tiles-1} "
                  f"(was 128-147 in the old layout)")

            # Carry forward the one decorative tile still referenced
            # directly by a hardcoded tile index: title.asm's sparkle
            # sprite at local 242. (The old vs_screen.asm solid-block
            # placeholder at local 252 is intentionally NOT carried
            # forward any more -- vs_screen.asm now draws real portrait
            # art instead, and 252 is legitimately reused by the static
            # image packer above.)
            for decorative_tile in (242,):
                start = decorative_tile * TILE_BYTES
                end = start + TILE_BYTES
                sprite_bank[start:end] = old_sprite_bank[start:end]

    final_chr = bg_bank + bytes(sprite_bank)
    assert len(final_chr) == BANK_BYTES * 2

    with open(OUT_CHR, "wb") as f:
        f.write(final_chr)
    print(f"Wrote {OUT_CHR} ({len(final_chr)} bytes)")

    def emit_table(label, index_map, base, frame_order):
        lines = [f"{label}:"]
        for state_name, frame_names in frame_order:
            vals = [str(base + index_map[fn]) for fn in frame_names]
            while len(vals) < 4:
                vals.append(vals[0] if vals else "0")
            lines.append(f"    .byte {', '.join(vals)}  ; {state_name}")
        return "\n".join(lines)

    player_frame_order = [
        ("PLR_IDLE", ["idle0", "idle1"]),
        ("PLR_WALK", ["walk0", "walk1", "walk2", "walk3"]),
        ("PLR_CROUCH", ["crouch0"]),
        ("PLR_JUMP", ["jump0", "jump1"]),
        ("PLR_PUNCH", ["punch0", "punch1"]),
        ("PLR_KICK", ["kick0", "kick1", "kick2"]),
        ("PLR_BLOCK", ["block0"]),
        ("PLR_HIT", ["hit0"]),
        ("PLR_KO", ["ko0"]),
        ("PLR_SPECIAL", ["punch1", "punch0", "punch1", "punch0"]),
        ("PLR_JUMPKICK", ["kick1"]),
        ("PLR_CROUCH_PUNCH", ["crouch0"]),
        ("PLR_CROUCH_KICK", ["crouch0"]),
    ]
    enemy_frame_order = [
        ("EN_STATE_IDLE", ["idle0", "idle1"]),
        ("EN_STATE_WALK", ["walk0", "walk1", "walk2", "walk3"]),
        ("EN_STATE_PUNCH", ["punch0", "punch1"]),
        ("EN_STATE_KICK", ["kick0", "kick1", "kick2"]),
        ("EN_STATE_BLOCK", ["block0"]),
        ("EN_STATE_HIT", ["hit0"]),
        ("EN_STATE_KO", ["ko0"]),
        ("EN_STATE_DASH", ["walk1", "walk3"]),
        ("EN_STATE_JUMP", ["jump0", "jump1"]),
    ]

    with open(OUT_INC_CONSTANTS, "w") as f:
        f.write("; AUTO-GENERATED by tools/chr_convert.py — DO NOT EDIT BY HAND\n")
        f.write("; Re-run `make chr` after changing chr/src_frames/*.png.\n\n")
        f.write(f"EFFECT_TILE_BASE = {effect_base}  ; local tile index, hit/stun fx (20 tiles)\n\n")
        for out_name in ("gameover_thumbs", "vs_michael", "vs_lightning"):
            if out_name not in static_layout:
                continue
            base, tw, th = static_layout[out_name]
            const_name = out_name.upper()
            f.write(f"{const_name}_BASE = {base}\n")
            f.write(f"{const_name}_TILES_W = {tw}\n")
            f.write(f"{const_name}_TILES_H = {th}\n")
    print(f"Wrote {OUT_INC_CONSTANTS}")

    with open(OUT_INC_PLAYER, "w") as f:
        f.write("; AUTO-GENERATED by tools/chr_convert.py — DO NOT EDIT BY HAND\n")
        f.write("; Re-run `make chr` after changing chr/src_frames/michael_sheet.png.\n\n")
        f.write(emit_table("player_spritemap", michael_map, michael_base, player_frame_order))
        f.write("\n")
    print(f"Wrote {OUT_INC_PLAYER}")

    with open(OUT_INC_ENEMY, "w") as f:
        f.write("; AUTO-GENERATED by tools/chr_convert.py — DO NOT EDIT BY HAND\n")
        f.write("; Re-run `make chr` after changing chr/src_frames/lightning_sheet.png.\n\n")
        f.write(emit_table("enemy_spritemap", lightning_map, lightning_base, enemy_frame_order))
        f.write("\n")
    print(f"Wrote {OUT_INC_ENEMY}")


if __name__ == "__main__":
    main()
