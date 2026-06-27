# THE LAST KUMITE — NES Demo Makefile
# Toolchain: ca65 + ld65 (cc65 suite). Install with: apt-get install cc65
#
# NOTE: constants.asm, zeropage.asm, and macros.asm are NOT assembled as
# standalone object files. They contain only shared constant/macro
# definitions and are pulled in via `.include` directives at the top of
# every other source file. The auto-generated src/sprite_tiles_*.inc files
# are included the same way (see tools/chr_convert.py).

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ROM_NAME    := TheLastKumite
SRC_DIR     := src
CHR_DIR     := chr
BUILD_DIR   := build
LINKER_DIR  := linker
TOOLS_DIR   := tools
EMU         := fceux

ASM_SOURCES := \
	$(SRC_DIR)/init.asm \
	$(SRC_DIR)/ppu.asm \
	$(SRC_DIR)/input.asm \
	$(SRC_DIR)/sound.asm \
	$(SRC_DIR)/state_machine.asm \
	$(SRC_DIR)/title.asm \
	$(SRC_DIR)/intro.asm \
	$(SRC_DIR)/vs_screen.asm \
	$(SRC_DIR)/player.asm \
	$(SRC_DIR)/enemy.asm \
	$(SRC_DIR)/combat.asm \
	$(SRC_DIR)/special.asm \
	$(SRC_DIR)/hud.asm \
	$(SRC_DIR)/gameover.asm \
	$(SRC_DIR)/fight_state.asm \
	$(SRC_DIR)/main.asm \
	$(SRC_DIR)/vectors.asm

OBJECTS     := $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(ASM_SOURCES))
CHR_DATA    := $(CHR_DIR)/tiles.chr
LINKER_CFG  := $(LINKER_DIR)/nrom256.cfg

CA65        := ca65
LD65        := ld65
CA65_FLAGS  := -U -g -t nes --debug-info -I $(SRC_DIR)
LD65_FLAGS  := -C $(LINKER_CFG) --dbgfile $(BUILD_DIR)/$(ROM_NAME).dbg

.PHONY: all clean run dirs chr bg assets

all: dirs $(BUILD_DIR)/$(ROM_NAME).nes

dirs:
	@mkdir -p $(BUILD_DIR) 2>/dev/null || true

# Rebuild CHR data + generated sprite-map .inc files from the authored art.
chr:
	@echo "[ASSETS] Authoring sprite frames..."
	python $(TOOLS_DIR)/author_sprites.py
	@echo "[ASSETS] Converting to CHR + generating sprite maps..."
	python $(TOOLS_DIR)/chr_convert.py

# Rebuild the fight-stage background from assets/32732.png.
bg:
	@echo "[ASSETS] Converting stage background..."
	python $(TOOLS_DIR)/bg_convert.py
	@echo "[ASSETS] Re-merging CHR (background half changed)..."
	python $(TOOLS_DIR)/chr_convert.py

assets: chr bg

$(BUILD_DIR)/$(ROM_NAME).nes: $(OBJECTS) $(CHR_DATA) $(LINKER_CFG) build_rom.py
	@echo "[LD] Linking ROM..."
	$(LD65) $(LD65_FLAGS) -o $(BUILD_DIR)/$(ROM_NAME)_raw.bin $(OBJECTS)
	@echo "[HEADER] Building final .nes (iNES header + PRG + CHR)..."
	python build_rom.py $(BUILD_DIR)/$(ROM_NAME)_raw.bin $(CHR_DATA) $(BUILD_DIR)/$(ROM_NAME).nes

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(BUILD_DIR) 2>/dev/null || true
	@echo "[AS] $<"
	$(CA65) $(CA65_FLAGS) -o $@ $<

$(CHR_DATA):
	@echo "ERROR: $(CHR_DATA) not found. Run 'make chr' to build it from" >&2
	@echo "       chr/src_frames/ + chr/tiles_bg.chr first." >&2
	@exit 1

run: all
	@echo "[RUN] Launching emulator ($(EMU))..."
	$(EMU) $(BUILD_DIR)/$(ROM_NAME).nes

clean:
	@echo "[CLEAN] Removing build artifacts..."
	@rm -rf $(BUILD_DIR) 2>/dev/null || true

SHARED_HEADERS := \
	$(SRC_DIR)/constants.asm \
	$(SRC_DIR)/zeropage.asm \
	$(SRC_DIR)/macros.asm \
	$(SRC_DIR)/sprite_tiles_const.inc \
	$(SRC_DIR)/sprite_tiles_player.inc \
	$(SRC_DIR)/sprite_tiles_enemy.inc \
	$(SRC_DIR)/stage_bg.inc
$(OBJECTS): $(SHARED_HEADERS)