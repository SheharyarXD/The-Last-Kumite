-- THE LAST KUMITE — Deterministic WIN-path test
-- Spams kick toward the enemy to force a fast, repeatable win, then keeps
-- capturing screenshots for many frames after the WIN transition so we can
-- see settled (not mid-transition) frames.

local logfile = io.open("/tmp/wintest/test_log.txt", "w")
local frame = 0
local last_gamestate = -1

local function logmsg(msg)
    logfile:write(string.format("[F%05d] %s", frame, msg) .. "\n")
    logfile:flush()
end

local function snap(name)
    gui.savescreenshotas("/tmp/wintest/shot_" .. name .. ".png")
end

local ADDR_GAMESTATE = 0x0007
local ADDR_PLR_HP    = 0x0046
local ADDR_EN_HP     = 0x0066
local STATE_NAMES = {
    [0]="TITLE",[1]="INTRO",[2]="VS",[3]="FIGHT",[4]="WIN",[5]="LOSE",[6]="GAMEOVER",[7]="MENU"
}

local win_frame = nil

emu.registerafter(function()
    frame = frame + 1
    local gs = memory.readbyte(ADDR_GAMESTATE)

    if gs ~= last_gamestate then
        local name = STATE_NAMES[gs] or ("UNKNOWN(" .. gs .. ")")
        logmsg("STATE CHANGE -> " .. name)
        last_gamestate = gs
        if gs == 4 then win_frame = frame end
    end

    -- Advance Title -> Intro -> VS with Start presses
    if frame == 30 or frame == 31 then joypad.set(1, {start = true}) end
    if frame >= 90 and frame < 400 and (frame % 15 == 0 or frame % 15 == 1) then
        joypad.set(1, {start = true})
    end

    if gs == 3 then
        -- Walk right toward enemy, then tap kick once per ~30-frame window
        -- (kick lasts up to 18 frames; 30-frame spacing guarantees release+
        -- re-press edge-detection and lets the active-hitbox window occur)
        local plr_x = memory.readbyte(0x0040)
        local en_x = memory.readbyte(0x0060)
        local dist = math.abs(plr_x - en_x)
        if dist > 35 then
            if plr_x < en_x then
                joypad.set(1, {right = true})
            else
                joypad.set(1, {left = true})
            end
        else
            local t = frame % 30
            if t == 0 then
                joypad.set(1, {B = true})
            end
        end
    end

    if win_frame then
        local since = frame - win_frame
        if since == 0 or since == 1 or since == 2 or since == 5 or since == 10 or since == 30 or since == 60 then
            local plr_hp = memory.readbyte(ADDR_PLR_HP)
            local en_hp = memory.readbyte(ADDR_EN_HP)
            logmsg(string.format("WIN+%d plr_hp=%d en_hp=%d", since, plr_hp, en_hp))
            snap(string.format("win_plus_%03d", since))
        end
        if since > 90 then
            logmsg("Done, stopping captures")
            win_frame = -999999  -- stop re-triggering
        end
    end

    if frame > 0 and frame % 200 == 0 then
        logmsg(string.format("heartbeat frame=%d gs=%d plr_hp=%d en_hp=%d plr_x=%d en_x=%d plr_state=%d",
            frame, gs, memory.readbyte(ADDR_PLR_HP), memory.readbyte(ADDR_EN_HP),
            memory.readbyte(0x0040), memory.readbyte(0x0060), memory.readbyte(0x0042)))
    end
end)
