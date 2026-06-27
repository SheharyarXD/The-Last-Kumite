mkdir build

ca65 -U -g -t nes --debug-info -I src -o build\init.o src\init.asm
ca65 -U -g -t nes --debug-info -I src -o build\ppu.o src\ppu.asm
ca65 -U -g -t nes --debug-info -I src -o build\input.o src\input.asm
ca65 -U -g -t nes --debug-info -I src -o build\sound.o src\sound.asm
ca65 -U -g -t nes --debug-info -I src -o build\state_machine.o src\state_machine.asm
ca65 -U -g -t nes --debug-info -I src -o build\title.o src\title.asm
ca65 -U -g -t nes --debug-info -I src -o build\intro.o src\intro.asm
ca65 -U -g -t nes --debug-info -I src -o build\vs_screen.o src\vs_screen.asm
ca65 -U -g -t nes --debug-info -I src -o build\player.o src\player.asm
ca65 -U -g -t nes --debug-info -I src -o build\enemy.o src\enemy.asm
ca65 -U -g -t nes --debug-info -I src -o build\combat.o src\combat.asm
ca65 -U -g -t nes --debug-info -I src -o build\special.o src\special.asm
ca65 -U -g -t nes --debug-info -I src -o build\hud.o src\hud.asm
ca65 -U -g -t nes --debug-info -I src -o build\gameover.o src\gameover.asm
ca65 -U -g -t nes --debug-info -I src -o build\fight_state.o src\fight_state.asm
ca65 -U -g -t nes --debug-info -I src -o build\main.o src\main.asm
ca65 -U -g -t nes --debug-info -I src -o build\vectors.o src\vectors.asm

ld65 -C linker\nrom256.cfg --dbgfile build\TheLastKumite.dbg -o build\TheLastKumite_raw.bin build\init.o build\ppu.o build\input.o build\sound.o build\state_machine.o build\title.o build\intro.o build\vs_screen.o build\player.o build\enemy.o build\combat.o build\special.o build\hud.o build\gameover.o build\fight_state.o build\main.o build\vectors.o

python build_rom.py build\TheLastKumite_raw.bin chr\tiles.chr build\TheLastKumite.nes