-- THE LAST KUMITE — Deterministic LOSE/GAMEOVER path test
-- Player stands still and blocks nothing, enemy AI naturally attacks and
-- wins. Captures screenshots through LOSE -> GAMEOVER, settled frames only.

local logfile = io.open("/tmp/losetest/test_log.txt", "w")
local frame = 0
local last_gamestate = -1

local function logmsg(msg)
    logfile:write(string.format("[F%05d] %s", frame, msg) .. "\n")
    logfile:flush()
end

local function snap(name)
    gui.savescreenshotas("/tmp/losetest/shot_" .. name .. ".png")
end

local ADDR_GAMESTATE = 0x0007
local ADDR_PLR_HP    = 0x0046
local ADDR_EN_HP     = 0x0066
local STATE_NAMES = {
    [0]="TITLE",[1]="INTRO",[2]="VS",[3]="FIGHT",[4]="WIN",[5]="LOSE",[6]="GAMEOVER",[7]="MENU"
}

local lose_frame = nil
local gameover_frame = nil

emu.registerafter(function()
    frame = frame + 1
    local gs = memory.readbyte(ADDR_GAMESTATE)

    if gs ~= last_gamestate then
        local name = STATE_NAMES[gs] or ("UNKNOWN(" .. gs .. ")")
        logmsg("STATE CHANGE -> " .. name)
        last_gamestate = gs
        if gs == 5 then lose_frame = frame end
        if gs == 6 then gameover_frame = frame end
    end

    if frame == 30 or frame == 31 then joypad.set(1, {start = true}) end
    if frame >= 90 and frame < 400 and (frame % 15 == 0 or frame % 15 == 1) then
        joypad.set(1, {start = true})
    end

    -- During fight: walk into close range and stay there (no block, no
    -- attack) so the AI's own attack pattern naturally wins.
    if gs == 3 then
        local plr_x = memory.readbyte(0x0040)
        local en_x = memory.readbyte(0x0060)
        local dist = math.abs(plr_x - en_x)
        if dist > 15 then
            if plr_x < en_x then joypad.set(1, {right = true})
            else joypad.set(1, {left = true}) end
        end
        -- otherwise: do nothing, just stand and take it
    end

    if lose_frame then
        local since = frame - lose_frame
        if since == 0 or since == 5 or since == 30 or since == 60 or since == 119 then
            logmsg(string.format("LOSE+%d", since))
            snap(string.format("lose_plus_%03d", since))
        end
    end
    if gameover_frame then
        local since = frame - gameover_frame
        if since == 0 or since == 5 or since == 30 or since == 60 or since == 90 then
            logmsg(string.format("GAMEOVER+%d", since))
            snap(string.format("gameover_plus_%03d", since))
        end
        if since > 120 then
            gameover_frame = -999999
        end
    end

    if frame > 0 and frame % 200 == 0 then
        logmsg(string.format("heartbeat frame=%d gs=%d plr_hp=%d en_hp=%d",
            frame, gs, memory.readbyte(ADDR_PLR_HP), memory.readbyte(ADDR_EN_HP)))
    end
end)
