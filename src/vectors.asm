; THE LAST KUMITE — NES Vector Table
; Located at $FFFA-$FFFF in PRG-ROM
; ============================================================================

.include "constants.asm"
.include "zeropage.asm"
.include "macros.asm"

.segment "VECTORS"

; =============================================================================
; NES CPU VECTOR TABLE
; $FFFA = NMI vector (VBlank interrupt)
; $FFFC = RESET vector (Power-on / reset)
; $FFFE = IRQ/BRK vector (not used in this game)
; =============================================================================
    .word NMI               ; $FFFA: NMI handler (in ppu.asm)
    .word RESET             ; $FFFC: RESET handler (in init.asm)
    .word IRQ               ; $FFFE: IRQ handler (stub)

; =============================================================================
; IRQ HANDLER — Unused but required for vector table completeness
; =============================================================================
.segment "CODE"
IRQ:
    rti                     ; Return immediately (no IRQs expected)
