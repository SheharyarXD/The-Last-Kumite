; THE LAST KUMITE — Zero Page Variable Definitions
; $0000-$00FF — Most frequently accessed variables
; ============================================================================

; =============================================================================
; FRAME / NMI VARIABLES ($0000-$000F)
; =============================================================================
nmiflag             = $0000     ; Set to 1 each NMI, game loop waits
framecounter        = $0001     ; Increments every frame (60Hz)
framecounter_hi     = $0002     ; Upper byte for longer timing
scroll_x            = $0003     ; BG scroll X
scroll_y            = $0004     ; BG scroll Y
ppu_ctrl_cache      = $0005     ; Cached PPUCTRL
ppu_mask_cache      = $0006     ; Cached PPUMASK
gamestate           = $0007     ; Current game state ID
next_gamestate      = $0008     ; Pending state transition
state_timer         = $0009     ; State-local timer
state_initialized   = $000A     ; 1 = current state was set up
pause_flag          = $000B     ; 1 = paused

; Temporary scratch variables (used everywhere)
temp1               = $000C
temp2               = $000D
temp3               = $000E
temp4               = $000F

; =============================================================================
; INPUT SYSTEM ($0010-$001F)
; =============================================================================
pad1_prev           = $0010     ; Previous frame button state
pad1_new            = $0011     ; Newly pressed this frame
pad1_held           = $0012     ; Currently held (working copy)
pad2_prev           = $0013     ; Controller 2 (unused but read)
pad2_new            = $0014
pad2_held           = $0027     ; Currently held (working copy, ctrl 2)
combo_buffer_idx    = $0015     ; Combo input buffer index (0-7)
combo_timer         = $0016     ; Frames remaining in combo window
special_cooldown    = $0017     ; Frames until special reusable

; Input buffer: stores 8 entries of (buttons, directions)
input_buffer_btns   = $0018     ; 4 bytes (circular buffer)
input_buffer_dirs   = $001C     ; 4 bytes (circular buffer)
block_timer         = $001F     ; Block recovery

; =============================================================================
; RENDERING / PPU ($0020-$002F)
; =============================================================================
oam_index           = $0020     ; Next free OAM slot
nametable           = $0021     ; Current nametable (0 or 1)
render_flag         = $0022     ; 1 = rendering enabled this frame
bg_update_ptr       = $0023     ; BG update data pointer (16-bit)
bg_update_count     = $0024     ; BG update ENTRIES pending this frame (3 bytes/entry)
bg_update_byte_idx  = $0028     ; Next free BYTE offset into bg_update_buf (producer-side)
temp_quad_left_top  = $0029     ; DrawMetasprite scratch: resolved tile index, top-left cell
temp_quad_right_top = $002A     ; DrawMetasprite scratch: resolved tile index, top-right cell
temp_quad_left_bot  = $002B     ; DrawMetasprite scratch: resolved tile index, bottom-left cell
temp_quad_right_bot = $002C     ; DrawMetasprite scratch: resolved tile index, bottom-right cell
bg_update_ptr_hi    = $0025
vs_scroll_pos       = $0026     ; VS screen scroll

; =============================================================================
; GLOBAL GAME ($0030-$003F)
; =============================================================================
match_timer_sec     = $0030     ; Match countdown (seconds)
match_timer_sub     = $0031     ; Sub-frame counter
screen_shake_x      = $0032     ; Screen shake X offset
screen_shake_y      = $0033     ; Screen shake Y offset
shake_timer         = $0034     ; Screen shake duration
vs_screen_timer     = $0035     ; VS intro display timer
death_type          = $0036     ; Random death type (0-3)
next_death_type     = $0037     ; Counter for pseudo-random death
fade_level          = $0038     ; 0-5 brightness level
text_scroll_y       = $0039     ; For intro text scrolling

; =============================================================================
; PLAYER STATE — Michael Rivers ($0040-$005F)
; =============================================================================
plr_x               = $0040
plr_y               = $0041
plr_state           = $0042
plr_frame           = $0043
plr_frametimer      = $0044
plr_dir             = $0045     ; 0=right, 1=left
plr_hp              = $0046
plr_hp_disp         = $0047
plr_vel_x           = $0048
plr_vel_y           = $0049
plr_grounded        = $004A
plr_block           = $004B
plr_hitstun         = $004C
plr_atk_active      = $004D
plr_atk_type        = $004E
plr_atk_timer       = $004F
plr_atk_hit         = $0050
plr_stunned         = $0051
plr_stun_timer      = $0052
plr_cooldown        = $0053
plr_subx            = $0054     ; Subpixel X
plr_suby            = $0055     ; Subpixel Y
plr_anim_base       = $0056     ; Base tile for current anim
plr_pal             = $0057     ; Palette offset

; =============================================================================
; ENEMY STATE — Lightning ($0060-$007F)
; =============================================================================
en_x                = $0060
en_y                = $0061
en_state            = $0062
en_frame            = $0063
en_frametimer       = $0064
en_dir              = $0065     ; 0=right (faces player), 1=left
en_hp               = $0066
en_hp_disp          = $0067
en_vel_x            = $0068
en_vel_y            = $0069
en_grounded         = $006A
en_block            = $006B
en_hitstun          = $006C
en_atk_active       = $006D
en_atk_type         = $006E
en_atk_timer        = $006F
en_atk_hit          = $0070
en_stunned          = $0071
en_stun_timer       = $0072
en_cooldown         = $0073
en_ai_state         = $0074
en_ai_timer         = $0075
en_aggro            = $0076
en_dash_timer       = $0077
en_react_timer      = $0078
en_subx             = $0079
en_suby             = $007A
en_anim_base        = $007B
en_pal              = $007C

; =============================================================================
; COMBAT SYSTEM ($0080-$009F)
; =============================================================================
plr_hitbox_x1       = $0080
plr_hitbox_x2       = $0081
plr_hitbox_y1       = $0082
plr_hitbox_y2       = $0083
en_hitbox_x1        = $0084
en_hitbox_x2        = $0085
en_hitbox_y1        = $0086
en_hitbox_y2        = $0087
plr_body_x1         = $0088
plr_body_x2         = $0089
plr_body_y1         = $008A
plr_body_y2         = $008B
en_body_x1          = $008C
en_body_x2          = $008D
en_body_y1          = $008E
en_body_y2          = $008F
combo_count         = $0090
combo_display_t     = $0091
knockback_val       = $0092
hit_freeze          = $0093
hit_flash_timer     = $0094
special_effect_t    = $0095
plr_dmg_accum       = $0096     ; Damage for current hit
stun_combo_active   = $0097     ; 1 = enemy stunned by special

; =============================================================================
; TEXT / STORY RENDERING ($00A0-$00AF)
; =============================================================================
text_ptr_lo         = $00A0
text_ptr_hi         = $00A1
text_x_pos          = $00A2
text_y_pos          = $00A3
text_delay          = $00A4
text_timer          = $00A5
text_state          = $00A6     ; 0=off, 1=typing, 2=done, 3=wait_advance
text_page           = $00A7
text_total_pages    = $00A8
text_box_active     = $00A9

; =============================================================================
; SOUND ENGINE ($00B0-$00BF)
; =============================================================================
sfx_timer           = $00B0
sfx_channel         = $00B1
sfx_priority        = $00B2
music_timer         = $00B3
music_note_idx      = $00B4
sfx_queue_type      = $00B5
sfx_queue_timer     = $00B6

; =============================================================================
; WORK / SCRATCH ($00C0-$00CF)
; =============================================================================
work_ptr_lo         = $00C0
work_ptr_hi         = $00C1
work_count          = $00C2
work_val            = $00C3
rand_seed           = $00C4     ; Pseudo-random seed
menu_cursor         = $00C5     ; Post-game menu selection (0=CONTINUE, 1=START)

; =============================================================================
; OAM BUFFER ($0200-$02FF)
; =============================================================================
; 64 sprites × 4 bytes = 256 bytes
; Layout per sprite: Y, Tile, Attributes, X
OAM_BUF_Y           = $0200
OAM_BUF_TILE        = $0201
OAM_BUF_ATTR        = $0202
OAM_BUF_X           = $0203

; =============================================================================
; BG UPDATE BUFFER ($0300-$031F)
; =============================================================================
; Stores (addr_hi, addr_lo, tile) triplets for PPU updates
bg_update_buf       = $0300
MAX_BG_UPDATES      = 32        ; 32 entries x 3 bytes = 96 bytes ($0300-$035F)
                                 ; Worst case/frame: timer(2)+plr_bar(10)+en_bar(10)+combo(5)=27
