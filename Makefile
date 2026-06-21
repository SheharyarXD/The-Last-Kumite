# THE LAST KUMITE — NES Demo Makefile
# Toolchain: ca65 + ld65 (cc65 suite)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ROM_NAME    := last_kumite
SRC_DIR     := src
CHR_DIR     := chr
BUILD_DIR   := build
EMU         := mesen  # Change to fceux or your preferred emulator

# Source files (order matters for segments)
ASM_SOURCES := \
	$(SRC_DIR)/constants.asm \
	$(SRC_DIR)/zeropage.asm \
	$(SRC_DIR)/macros.asm \
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
	$(SRC_DIR)/main.asm \
	$(SRC_DIR)/chr_data.asm \
	$(SRC_DIR)/vectors.asm

OBJECTS     := $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(ASM_SOURCES))
CHR_DATA    := $(CHR_DIR)/tiles.chr

# ---------------------------------------------------------------------------
# ca65 / ld65 settings
# ---------------------------------------------------------------------------
CA65        := ca65
LD65        := ld65
CA65_FLAGS  := -g -t nes --debug-info
LD65_FLAGS  := -C $(ROM_NAME).cfg --dbgfile $(BUILD_DIR)/$(ROM_NAME).dbg

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
.PHONY: all clean run dirs

all: dirs $(BUILD_DIR)/$(ROM_NAME).nes

dirs:
	@mkdir -p $(BUILD_DIR)

# Link step: produce raw binary, then prepend iNES header
$(BUILD_DIR)/$(ROM_NAME).nes: $(OBJECTS) $(CHR_DATA) $(ROM_NAME).cfg
	@echo "[LD] Linking ROM..."
	$(LD65) $(LD65_FLAGS) -o $(BUILD_DIR)/$(ROM_NAME)_raw.bin $(OBJECTS)
	@echo "[HEADER] Adding iNES header..."
	@python3 -c "
import sys
# iNES header: 16 bytes
header = bytearray(16)
header[0:4] = b'NES\\x1a'           # Signature
header[4]   = 2                        # PRG-ROM: 2 × 16KB = 32KB
header[5]   = 1                        # CHR-ROM: 1 × 8KB = 8KB
header[6]   = 0x00                     # Flags 6: mapper 0, vertical mirroring
header[7]   = 0x00                     # Flags 7: mapper 0, NES 2.0 off
header[8]   = 0x00                     # PRG-RAM size
header[9]   = 0x00                     # TV system (NTSC)
header[10:16] = b'\\x00\\x00\\x00\\x00\\x00\\x00'  # Padding
with open('$(BUILD_DIR)/$(ROM_NAME).nes', 'wb') as out:
    out.write(header)
    with open('$(BUILD_DIR)/$(ROM_NAME)_raw.bin', 'rb') as f:
        out.write(f.read())
    with open('$(CHR_DATA)', 'rb') as f:
        out.write(f.read())
print(f'ROM size: {16 + 32768 + 8192} bytes')
print('Build complete: $(BUILD_DIR)/$(ROM_NAME).nes')
"

# Assembly step: compile each .asm to .o
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@echo "[AS] $<"
	$(CA65) $(CA65_FLAGS) -o $@ $<

# CHR data generation (placeholder - generates test pattern if no tiles.chr)
$(CHR_DATA):
	@echo "[CHR] Generating placeholder CHR data..."
	@mkdir -p $(CHR_DIR)
	@python3 -c "
import sys
data = bytearray(8192)
# Generate test pattern tiles
for i in range(256):
    offset = i * 16
    for j in range(8):
        data[offset + j] = ((i + j) * 17) & 0xFF
        data[offset + j + 8] = 0x00
with open('$(CHR_DATA)', 'wb') as f:
    f.write(data)
print('Placeholder CHR data generated (8192 bytes)')
"

run: all
	@echo "[RUN] Launching emulator..."
	$(EMU) $(BUILD_DIR)/$(ROM_NAME).nes

clean:
	@echo "[CLEAN] Removing build artifacts..."
	rm -rf $(BUILD_DIR)

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.asm $(SRC_DIR)/constants.asm $(SRC_DIR)/zeropage.asm
$(BUILD_DIR)/init.o: $(SRC_DIR)/init.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/ppu.o: $(SRC_DIR)/ppu.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/input.o: $(SRC_DIR)/input.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/state_machine.o: $(SRC_DIR)/state_machine.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/combat.o: $(SRC_DIR)/combat.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/player.o: $(SRC_DIR)/player.asm $(SRC_DIR)/constants.asm
$(BUILD_DIR)/enemy.o: $(SRC_DIR)/enemy.asm $(SRC_DIR)/constants.asm
