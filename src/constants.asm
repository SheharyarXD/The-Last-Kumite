; THE LAST KUMITE — Game Constants
; 6502 Assembly for NES
; ============================================================================

; =============================================================================
; HARDWARE REGISTERS
; =============================================================================
PPU_CTRL    = $2000
PPU_MASK    = $2001
PPU_STATUS  = $2002
OAM_ADDR    = $2003
OAM_DATA    = $2004
PPU_SCROLL  = $2005
PPU_ADDR    = $2006
PPU_DATA    = $2007
OAM_DMA     = $4014

APU_SQ1_VOL  = $4000
APU_SQ1_SWEEP= $4001
APU_SQ1_LO   = $4002
APU_SQ1_HI   = $4003
APU_SQ1_TIMER= $4002    ; alias: timer low byte (same reg as APU_SQ1_LO)
APU_SQ1_LEN  = $4003    ; alias: length counter + timer high (same reg as APU_SQ1_HI)
APU_SQ2_VOL  = $4004
APU_SQ2_SWEEP= $4005
APU_SQ2_LO   = $4006
APU_SQ2_HI   = $4007
APU_SQ2_TIMER= $4006    ; alias: timer low byte (same reg as APU_SQ2_LO)
APU_SQ2_LEN  = $4007    ; alias: length counter + timer high (same reg as APU_SQ2_HI)
APU_TRI_LINEAR= $4008
APU_TRI_LO   = $400A
APU_TRI_HI   = $400B
APU_NOISE_VOL= $400C
APU_NOISE_LO  = $400E
APU_NOISE_HI  = $400F
APU_NOISE_PERIOD = $400E ; alias: noise period/mode (same reg as APU_NOISE_LO)
APU_NOISE_LEN    = $400F ; alias: length counter load (same reg as APU_NOISE_HI)
APU_DMC_FREQ  = $4010
APU_CTRL      = $4015
APU_FRAME_COUNTER = $4017

JOYPAD1     = $4016
JOYPAD2     = $4017

; =============================================================================
; PPU CONTROL FLAGS
; =============================================================================
PPUCTRL_NMI         = %10000000
PPUCTRL_MASTER_SLAVE= %01000000
PPUCTRL_SPR16       = %00100000
PPUCTRL_BG_PT       = %00010000
PPUCTRL_SPR_PT      = %00001000
PPUCTRL_INC         = %00000100
PPUCTRL_NAMETABLE   = %00000011

PPUSPRITE_LEFT8     = %00000100
PPUBG_LEFT8         = %00000010
PPUSPRITE_ON        = %00010000
PPUBG_ON            = %00001000

; =============================================================================
; GAME STATES
; =============================================================================
STATE_TITLE         = 0
STATE_INTRO         = 1
STATE_VS            = 2
STATE_FIGHT         = 3
STATE_WIN           = 4
STATE_LOSE          = 5
STATE_GAMEOVER      = 6
STATE_MENU          = 7     ; Post-game menu: Continue / Start New Game

; =============================================================================
; PLAYER STATES (Michael Rivers)
; =============================================================================
PLR_IDLE            = 0
PLR_WALK            = 1
PLR_CROUCH          = 2
PLR_JUMP            = 3
PLR_PUNCH           = 4
PLR_KICK            = 5
PLR_BLOCK           = 6
PLR_HIT             = 7
PLR_KO              = 8
PLR_SPECIAL         = 9
PLR_JUMPKICK        = 10
PLR_CROUCH_PUNCH    = 11
PLR_CROUCH_KICK     = 12

; =============================================================================
; ENEMY AI STATES (Lightning)
; =============================================================================
AI_IDLE             = 0
AI_APPROACH         = 1
AI_ATTACK           = 2
AI_RETREAT          = 3
AI_ANTIAIR          = 4
AI_BLOCK            = 5
AI_STUNNED          = 6
AI_DASH             = 7
AI_KO               = 8

; =============================================================================
; DIRECTIONS
; =============================================================================
DIR_RIGHT           = 0
DIR_LEFT            = 1

; =============================================================================
; ATTACK TYPES
; =============================================================================
ATK_NONE            = 0
ATK_PUNCH           = 1
ATK_KICK            = 2
ATK_JUMP            = 3
ATK_SPECIAL         = 4
ATK_DASH            = 5

; =============================================================================
; DAMAGE VALUES
; =============================================================================
DMG_PUNCH           = 5
DMG_KICK            = 10
DMG_JUMP            = 12
DMG_DASH            = 8
DMG_SPECIAL         = 0   ; Special stun does 0 direct damage

; =============================================================================
; TIMING CONSTANTS (frames at 60fps)
; =============================================================================
HITSTOP_PUNCH       = 6
HITSTOP_KICK        = 8
HITSTOP_JUMP        = 10
HITSTOP_BLOCKED     = 4
HITSTOP_SPECIAL     = 12

HITSTUN_PUNCH       = 15
HITSTUN_KICK        = 20
HITSTUN_JUMP        = 25
HITSTUN_BLOCKED     = 8

STUN_DURATION       = 90  ; 1.5 seconds
SPECIAL_COOLDOWN    = 180 ; 3 seconds

KNOCKBACK_PUNCH     = 2
KNOCKBACK_KICK      = 4
KNOCKBACK_JUMP      = 6
KNOCKBACK_BLOCKED   = 1

; =============================================================================
; MOVEMENT CONSTANTS
; =============================================================================
WALK_SPEED          = 1
DASH_SPEED          = 3
JUMP_VELOCITY       = -4
GRAVITY             = 1
GROUND_Y            = 160

; =============================================================================
; AI TIMING
; =============================================================================
AI_DECISION_MIN     = 8
AI_DECISION_MAX     = 15
AI_APPROACH_DIST    = 80
AI_ATTACK_DIST      = 40
AI_AGGRO_HP         = 24  ; 30% of 80 HP
AI_DASH_SPEED       = 4

; =============================================================================
; SCREEN POSITIONS
; =============================================================================
SCREEN_LEFT         = 16
SCREEN_RIGHT        = 230
PLAYER_START_X      = 60
ENEMY_START_X       = 196

; =============================================================================
; OAM / SPRITE
; =============================================================================
OAM_BUF             = $0200
SPRITE_SIZE         = 4       ; bytes per sprite (Y, tile, attr, X)
MAX_SPRITES         = 64
METASPRITE_W        = 2       ; tiles wide
METASPRITE_H        = 2       ; tiles tall
SPRITES_PER_CHAR    = 4       ; 2x2 metasprite

; =============================================================================
; INPUT BUTTON BITS
; =============================================================================
BTN_A               = %10000000
BTN_B               = %01000000
BTN_SELECT          = %00100000
BTN_START           = %00010000
BTN_UP              = %00001000
BTN_DOWN            = %00000100
BTN_LEFT            = %00000010
BTN_RIGHT           = %00000001

; =============================================================================
; TEXT RENDERING
; =============================================================================
TEXT_SPEED          = 4       ; frames between characters
TITLE_X             = 8       ; tile X for title text
TITLE_Y             = 8       ; tile Y for title
STORY_X             = 4
STORY_Y             = 6

; =============================================================================
; PALETTE INDICES
; =============================================================================
PAL_BG              = 0
PAL_PLR             = 1
PAL_ENEMY           = 2
PAL_EFFECT          = 3

; =============================================================================
; MATCH TIMER
; =============================================================================
MATCH_TIME_DEFAULT  = 60  ; 60 seconds

; =============================================================================
; ENEMY ANIMATION/RENDER STATES (Lightning) — distinct from AI_* behavior states
; =============================================================================
EN_STATE_IDLE   = 0
EN_STATE_WALK   = 1
EN_STATE_PUNCH  = 2
EN_STATE_KICK   = 3
EN_STATE_BLOCK  = 4
EN_STATE_HIT    = 5
EN_STATE_KO     = 6
EN_STATE_DASH   = 7
EN_STATE_JUMP   = 8

; =============================================================================
; SFX ID CONSTANTS
; =============================================================================
SFX_PUNCH       = 1
SFX_KICK        = 2
SFX_HIT         = 3
SFX_BLOCK       = 4
SFX_SPECIAL     = 5
SFX_SPECIAL_HIT = 6
SFX_JUMP        = 7
SFX_LAND        = 8
SFX_KO_DOWN     = 9
SFX_START       = 10
