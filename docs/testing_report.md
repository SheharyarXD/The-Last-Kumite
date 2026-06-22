# THE LAST KUMITE — Testing Report

## Methodology

This project was verified using a real toolchain end-to-end, not by reading
code and assuming correctness:

1. **`ca65`/`ld65` (cc65 2.19)** installed and used for every build — no
   custom or partial assemblers.
2. **py65** (Python 6502 emulator) used to step through RESET instruction-
   by-instruction and confirm control flow before involving a full emulator.
3. **FCEUX**, run headless under **Xvfb**, driven by a **Lua test script**
   that:
   - presses Start to advance Title → Intro → VS → Fight,
   - feeds scripted movement/attack/block/special inputs during Fight,
   - reads CPU/zero-page memory every frame to log game state
     (`gamestate`, HP, position, animation state, timers, PPU register
     caches),
   - sets write-watchpoints (`memory.register`) on specific zero-page
     addresses to catch exactly which instruction corrupts a value, and
   - takes PNG screenshots at every state transition and periodically
     during long states.

This combination — static assembly, cycle-level simulation, and live
emulator memory/video inspection — is what surfaced bugs that were
invisible from reading the source alone (most of the critical ones below).

## Emulators tested

| Emulator | Result |
|---|---|
| FCEUX 2.6.x (headless, Lua-scripted) | **Pass.** Full game flow verified: Title → Intro → VS → Fight → Win and Title → Intro → VS → Fight → Lose → Game Over, both confirmed via screenshot and memory dump. |
| Mesen | Not available in this sandboxed environment (no package available offline). The ROM uses only standard NROM-256 (mapper 0) hardware features — no mapper, MMC, or NES 2.0 extensions — so there is no known reason it would behave differently in Mesen, but this was not directly confirmed. |

## Controls tested

All confirmed via scripted FCEUX input during the Fight state:

| Input | Confirmed behavior |
|---|---|
| D-Pad Left/Right | Player X position updates, screen-edge clamping works |
| D-Pad Down | Crouch state entered, hurtbox shrinks |
| D-Pad Up | Jump state entered, gravity/landing returns to idle |
| A (Punch) | Damage applied to enemy on hit, 5 HP per the GDD |
| B (Kick) | Damage applied to enemy on hit, 10 HP per the GDD |
| Down + B + A | Special move triggers (`PLR_SPECIAL` state observed), cooldown enforced |
| Start (Title) | Advances to Intro |
| Start (Intro) | Advances story text pages |
| Start (Game Over) | Returns to Title |

Block was exercised indirectly (enemy attacks while player holds back) and
reduces damage taken; an explicit isolated block-only test was not run.

## Fight flow tested

Two full matches were played out by the scripted test to completion:

- **Loss path:** player took continuous damage down to 0 HP → `LOSE` state
  (frozen KO pose, ~2 seconds) → `GAMEOVER` state showing "GAME OVER",
  "RON HALL GIVES THUMBS DOWN", a randomized death-flavor line, and "PRESS
  START TO CONTINUE", all rendered correctly.
- **Win path:** player reduced Lightning's HP to 0 → `WIN` state showing
  "LIGHTNING DEFEATED" / "ENTRY GRANTED", rendered correctly.
- Match timer counts down from 60 in real time and is read correctly by the
  HUD every frame.
- HUD (names, health bars, timer) updates correctly as HP changes.

Timeout/draw resolution (timer reaching 0 mid-match) was verified by code
inspection of `CheckMatchEnd` in `combat.asm` but not forced to occur in the
scripted run.

## Known limitations

- **Sound is structurally verified, not audibly verified.** Every gameplay
  event correctly calls its `PlaySFXxxx` routine, which queues an SFX ID
  that `StartSFX`/`UpdateSound` consumes via a jump table into APU register
  writes (corrected `$4000`-range aliasing — see bug list). The automated
  test environment runs FCEUX with `--sound 0`. Audible confirmation on
  real hardware or a sound-enabled emulator session is recommended before
  final sign-off.
- **Sprite art is single-tile, not the originally-documented 2×2
  metasprite.** The CHR data provided in `chr/tiles.chr` contains standalone
  8×8 character poses (idle/walk/punch/kick/crouch/hit/KO frames for both a
  red and a gray fighter), not four-tile-per-pose metasprites. The rendering
  code was adjusted to match the real art (see bug list) rather than the
  art being regenerated, per the instruction to avoid replacing assets with
  placeholders where avoidable. Sprites are correspondingly small (8×8)
  rather than 16×16.
- **VS-screen character portraits are solid colored blocks**, not detailed
  art, matching what was already in the original source
  (`vs_screen.asm` describes this as a placeholder in its own comments).
  This was left as-is since building new portrait art was out of scope for
  a bug-fix/completion pass.
- **The two special-move trigger paths** (see README) are both correct but
  redundant.
- **AI** is the simple approach/attack/retreat/aggro-under-30% behavior
  specified for this one-level demo; it is not balanced for competitive
  play and the scripted test's pacing (player wins or loses depending on
  the exact scripted input pattern used) should not be read as a balance
  claim either way.

## Bugs found and fixed

Organized by how they were found, since several were only reachable through
actual execution rather than reading the source.

### Build system (would not assemble or link at all)

1. **Makefile**: the ROM-header recipe embedded a multi-line Python literal
   directly in a `make` recipe with no line continuations, which GNU Make
   cannot parse (`missing separator`). Replaced with a standalone
   `make_rom.py`.
2. **No shared-header includes anywhere.** Every `.asm` file used constants
   from `constants.asm`, zero-page addresses from `zeropage.asm`, and
   macros from `macros.asm` with zero `.include`/`.import` directives.
   Since each file is assembled as an independent ca65 module, none of
   those symbols — and *none* of the macros, which cannot cross module
   boundaries at all — were actually visible anywhere outside the three
   files that defined them. Fixed by adding `.include` headers to all 18
   dependent files and building with `ca65 -U`.
3. **Duplicate exported symbols**: `RenderTitle`, `RenderIntro`, `RenderVS`,
   `RenderGameOver` were each defined twice (a no-op stub in
   `state_machine.asm` and the real implementation in `title.asm` /
   `intro.asm` / `vs_screen.asm` / `gameover.asm`), which is a guaranteed
   link error. Removed the stub copies.
4. **ca65 macro parameter collision**: `PPU_SETSCROLL` used `x`/`y` as
   macro parameter names, which ca65 reserves as register names.
5. **`RANDOM_A` macro reused `@name:` local labels**, which are scoped to
   the *enclosing* label, not per macro-invocation — calling the macro
   twice in the same function collided. Switched to anonymous (`:`) labels.
6. **Several branch-out-of-range errors** (`beq`/`bne`/`bcc` targets more
   than 127 bytes away) in `sound.asm`, `player.asm`, `enemy.asm`,
   `combat.asm`, and `input.asm`, from long `cmp`/`branch` dispatch chains
   or forward branches over large code blocks. Fixed via jump tables
   (`sound.asm` SFX dispatch, `player.asm`/`enemy.asm` hitbox builders) or
   `bxx`+`jmp` trampolines (`combat.asm`, `input.asm`).
7. **`SFX_*` and `EN_STATE_*` constants** were defined in `sound.asm` and
   `enemy.asm` respectively but referenced from other files; moved to the
   shared `constants.asm`.
8. **Negative constant in an 8-bit immediate**: `lda #JUMP_VELOCITY` (-4)
   needs the `<` low-byte operator to assemble as a valid signed byte.
9. **`cmp #(64 * 4)`** (=256) doesn't fit an 8-bit immediate; corrected the
   OAM-capacity check's arithmetic.
10. **An undefined label** (`@apply_knockback`, referenced but never
    defined) silently passed assembly as an implicit import under `-U` and
    only failed at the branch-range check — the actual intended target was
    `@update_physics`.
11. **Linker config** (`last_kumite.cfg`): a `FEATURES`/`CONDES` block
    missing required `segment` attributes, a `SYMBOLS` block using invalid
    `NAME = value;` syntax instead of `NAME: type=weak, value=value;`
    (and duplicating constants already defined in `constants.asm`), and a
    PRG1 memory region six bytes too small (`$3FF4` instead of `$3FFA`),
    which silently produced a 32,762-byte PRG instead of the required
    32,768 — all removed or corrected.
12. **`fight_state.asm` was missing from the Makefile's source list**
    entirely.
13. **Missing zero-page allocation**: `pad2_held` was referenced in
    `input.asm` but never given an address in `zeropage.asm`.

### Runtime bugs (assembled and linked, but did not run correctly)

14. **Critical NMI deadlock**: `RESET` called `WAIT_NMI` (spin until the
    NMI handler sets a flag) *before* enabling NMI generation in
    `PPU_CTRL`. The CPU spun forever waiting for an interrupt that could
    never fire. Found via FCEUX's lag-frame counter (100% lag frames) and
    confirmed with a cycle-accurate py65 simulation. Fixed by enabling NMI
    before waiting for it.
15. **`InitTitle` never ran on the first frame**: `RESET` pre-set
    `state_initialized = 1`, so the main loop's "does this state need
    initializing" check was already satisfied before `InitTitle` had ever
    executed, skipping all of the title screen's text drawing permanently.
16. **`ClearNametable` filled the screen with garbage tiles** at four
    separate call sites (`InitIntro`, `InitVS`, `InitWin`,
    `InitGameOver`): each called it without reloading the accumulator
    first, so it ran with whatever value happened to be left over (e.g.
    `TEXT_SPEED`, `death_type`) instead of the intended blank tile `0`.
17. **PPU writes happened while rendering was active**: none of
    `InitIntro`/`InitVS`/`InitWin`/`InitGameOver` turned rendering off
    before doing direct `PPU_DATA` nametable writes, which is unreliable on
    real PPU hardware outside vblank. Added `RENDER_OFF`/`RENDER_ON`
    around each, matching the pattern already used correctly in
    `fight_state.asm`.
18. **`text_state` was set to `4` instead of `1`** in `InitIntro` (`lda #4`
    was reused for two consecutive `sta` targets that needed different
    values), which doesn't match any case in `HandleIntro`'s dispatch —
    the intro froze permanently with no text ever appearing.
19. **The background-update buffer's length bookkeeping was internally
    inconsistent.** Several producers (`DrawTextBuffered`, `TypeNextChar`,
    `DrawPlayerBar`, `DrawEnemyBar`, `DrawTimer`) tracked a *byte* offset in
    the same counter that the consumer (`ProcessBGUpdates`) decremented
    once per 3-byte *entry* — and two producers additionally wrote one PPU
    address followed by several raw tile bytes, a format the consumer
    can't parse at all (it expects a full address+tile triple per entry).
    Net effect: HUD and typed text rendered as corrupted or missing tiles.
    Fixed by introducing a separate `bg_update_byte_idx` for the producer-
    side write offset, keeping `bg_update_count` strictly as an entry
    count, and rewriting the two incompatible producers to emit one
    self-contained entry per tile. Also found and removed a third,
    entirely unused, independently-broken implementation
    (`UpdateHealthBar` in `ppu.asm`) with the same format bug.
20. **`InitFight` reset `next_gamestate` to 0** (`STATE_TITLE`) as part of
    its "reset state" block, which immediately queued a transition back to
    the title screen for the very next frame after entering the fight.
21. **Sprites read from the wrong CHR pattern table.** `PPUCTRL_SPR_PT`
    (the bit selecting `$1000` vs `$0000` for sprite tiles) was never
    actually set despite a comment claiming otherwise, and the player/enemy
    sprite-map tables referenced tile indices that — given the *actual*
    layout of `chr/tiles.chr` — pointed at the alphabet/UI tile region, not
    the fighter art (which lives in the `$1000` half of CHR). Fixed by
    setting `PPUCTRL_SPR_PT` and remapping both sprite tables to the
    correct local tile indices for the real character art, and rewrote
    `DrawMetasprite` to draw the single 8×8 tile the art actually provides
    instead of an incompatible 2×2 four-tile layout.
22. **Landing-physics bug corrupted the player's Y position.** In
    `ApplyPlayerPhysics`, the branch that checks "was the player jumping
    when they landed" fell through to a shared label (`@y_store`) whose
    job elsewhere in the function is "store the accumulator into `plr_y`"
    — but at that point the accumulator held `plr_state`, not a Y
    coordinate. Any landing while not in the jump state overwrote `plr_y`
    with the numeric value of the player's current state (e.g. `0` for
    idle), teleporting the sprite to the top of the screen. Found via an
    FCEUX write-watchpoint on `plr_y` showing the exact moment and value
    of corruption. Gave the "not jumping" path its own label.
23. **`CheckSpecialMove` (input.asm)** could trigger the special move
    without setting `special_cooldown`, unlike the equivalent path in
    `special.asm`/`fight_state.asm`. Added the missing cooldown write.

## What was intentionally left alone

Per the brief's priority order (gameplay → controls → assets → stability →
polish), the following known-rough edges were not changed because they do
not block a working, playable demo:

- The dead/no-op `ShowCursor`/`HideCursor` stub functions in
  `state_machine.asm`.
- The redundant special-move trigger path (both are correct; consolidating
  them is a refactor, not a fix).
- VS-screen portraits being solid color blocks rather than character art.
- `chr/tiles.chr`'s sparkle/title-flash tile (`$F2`) being a solid block
  rather than a star shape — cosmetic, not functional.

## Session 2: real asset pipeline, sprite/background rework

A follow-up pass replaced the single-8x8-tile sprite workaround from
session 1 with a proper, scriptable asset pipeline (`tools/`) producing
real 16x16 (2x2 metasprite) character art for both fighters and a
converted version of the client's castle-ruins background for the fight
stage, in place of the flat color-band placeholder. See
`docs/asset_pipeline.md` for how the pipeline works.

### New bugs found and fixed during this pass

24. **`DrawMetasprite` needed to go back to drawing a 2x2 quad** (it had
    been simplified to a single 8x8 tile in session 1 to match the *then*-
    available art, which really was single-tile). The 2x2 rewrite adds
    correct flip-aware quadrant ordering: a horizontally-flipped sprite
    must swap which tile renders on the left vs. right half, not just set
    the hardware mirror bit on each tile in place — doing only the latter
    would mirror each half's pixels but leave the halves themselves on the
    wrong side.
25. **New branch-out-of-range error** introduced by the longer
    `DrawMetasprite` body (the OAM-capacity check's `bcs @ms_done` could no
    longer reach its target). Fixed with a `bcc`-and-fall-through
    restructure.
26. **CHR tile-range collision** introduced while wiring up the new
    sprite pipeline: hit/stun effect tiles were initially placed at a
    fixed local range (128-147) that now overlapped Lightning's animation
    frames (which land at 68-135 given Michael occupies 0-67). Fixed by
    computing the effect-tile base dynamically (first free slot after both
    fighters' frames) and having `ppu.asm` reference that computed base via
    a generated constant (`EFFECT_TILE_BASE`) instead of a hardcoded value.
27. **Two decorative tiles went blank**: the title-screen sparkle flash
    and the VS-screen portrait placeholder blocks are referenced by literal
    tile number in `title.asm`/`vs_screen.asm` and were not part of the new
    sprite pipeline's output, so they silently zeroed out. Fixed by
    explicitly carrying those two specific tiles forward from the prior
    CHR data in `tools/chr_convert.py`.
28. **Lightning rendered in Michael's color.** `RenderEnemy` built its OAM
    attribute byte starting from `0` and never set the sprite-palette-select
    bits, so Lightning used sprite palette 0 (Michael's red) instead of
    palette 1. Fixed by initializing the attribute byte to select palette 1.
29. **Lightning's defined palette was the wrong hue.** The "Lightning
    (blue)" sprite palette in `init.asm` was actually set to NES palette
    indices `$14/$24/$34` (magenta/pink on real hardware), not blue.
    Corrected to `$02/$12/$22` (the actual blue column).
30. **Background palette mislabeled.** The fight stage's converted
    background was initially drawn against BG2 ("Building/wall" in
    `init.asm`'s own comment), which is actually dark red/orange on real
    NES hardware, not brown/stone-colored as the label implied — this
    produced a recognizable but unintentionally red-tinted castle scene.
    Switched to BG1 ("Ground earth tones"), which is genuinely olive/brown,
    for the intended stone-ruins look.
31. **16-bit loop counter needed for the stage nametable stream.** The
    background nametable is 896 bytes (32x28), which an 8-bit `X` register
    can't count past directly; the initial draft of `LoadFightStage`
    miscounted as a result. Rewrote to use a proper 16-bit byte counter
    (`temp1`:`temp2`) compared against `<896`/`>896`.

### Re-verification

The full FCEUX scripted play-through (Title -> Intro -> VS -> Fight ->
Win, and separately -> Lose -> Game Over) was re-run after this pass and
both paths complete correctly, with screenshots confirming: both fighters
visible as distinctly-colored 16x16 sprites, the castle background
rendering recognizably (towers, clouds, tree line) in the intended brown/
olive palette, HUD/health bars/timer all updating correctly throughout,
and no crashes or hangs across a 3600-frame (60-second) run.
