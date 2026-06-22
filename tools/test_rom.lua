-- THE LAST KUMITE — Automated headless test script for FCEUX (v2)
-- Logs to file directly; does not attempt to exit the process (caller kills it).

local logfile = io.open("/tmp/newtest/test_log.txt", "w")

local frame = 0
local last_gamestate = -1

local function logmsg(msg)
    local line = string.format("[F%05d] %s", frame, msg)
    logfile:write(line .. "\n")
    logfile:flush()
end

local function snap(name)
    gui.savescreenshotas("/tmp/newtest/shot_" .. name .. ".png")
    logmsg("Screenshot saved: " .. name)
end

local ADDR_GAMESTATE = 0x0007
local ADDR_PLR_HP    = 0x0046
local ADDR_EN_HP     = 0x0066
local ADDR_MATCH_SEC = 0x0030
local ADDR_PLR_STATE = 0x0042
local ADDR_EN_AI      = 0x0074

local STATE_NAMES = {
    [0] = "TITLE", [1] = "INTRO", [2] = "VS",
    [3] = "FIGHT", [4] = "WIN", [5] = "LOSE", [6] = "GAMEOVER"
}

logmsg("Test script loaded successfully")

local plry_write_count = 0
memory.register(0x0041, function()
    plry_write_count = plry_write_count + 1
    if plry_write_count <= 15 then
        local grounded = memory.readbyte(0x004A)
        local vely = memory.readbyte(0x0049)
        logmsg(string.format("WRITE to plr_y (write #%d) new_value=%d frame=%d grounded=%d vely=%d", plry_write_count, memory.readbyte(0x0041), frame, grounded, vely))
    end
end)

local last_framecounter = -1

emu.registerafter(function()
    frame = frame + 1
    local gs = memory.readbyte(ADDR_GAMESTATE)

    if frame <= 10 then
        local si = memory.readbyte(0x000A)
        local nametable_sel = memory.readbyte(0x0021)
        local fc = memory.readbyte(0x0001)
        logmsg(string.format("EARLY frame=%d gamestate=%d state_init=%d nametable=%d framecounter=%d", frame, gs, si, nametable_sel, fc))
    end
    if frame == 50 or frame == 100 or frame == 200 then
        local fc = memory.readbyte(0x0001)
        logmsg(string.format("CHECK frame=%d framecounter=%d", frame, fc))
    end

    if gs ~= last_gamestate then
        local name = STATE_NAMES[gs] or ("UNKNOWN(" .. gs .. ")")
        logmsg("STATE CHANGE -> " .. name .. " (raw=" .. gs .. ")")
        last_gamestate = gs
        snap(string.format("%02d_%s", frame, name))
    end

    if frame == 30 or frame == 31 then
        joypad.set(1, {start = true})
    end

    if frame >= 90 and frame < 600 and (frame % 20 == 0 or frame % 20 == 1) then
        joypad.set(1, {start = true})
    end

    if gs == 3 then
        local t = frame % 90
        if t < 20 then
            joypad.set(1, {left = true})
        elseif t < 35 then
            joypad.set(1, {right = true})
        elseif t < 55 then
            joypad.set(1, {B = true})
        elseif t < 60 then
            joypad.set(1, {A = true})
        end
    end

    if frame % 300 == 0 then
        local plr_hp = memory.readbyte(ADDR_PLR_HP)
        local en_hp = memory.readbyte(ADDR_EN_HP)
        local sec = memory.readbyte(ADDR_MATCH_SEC)
        local plr_state = memory.readbyte(ADDR_PLR_STATE)
        local en_ai = memory.readbyte(ADDR_EN_AI)
        local ppumask_cache = memory.readbyte(0x0006)
        local ppuctrl_cache = memory.readbyte(0x0005)
        local state_init = memory.readbyte(0x000A)
        local fade_level = memory.readbyte(0x0038)
        local oam_idx = memory.readbyte(0x0020)
        local plr_x = memory.readbyte(0x0040)
        local plr_y = memory.readbyte(0x0041)
        -- OAM sprite 0 (should be first sprite drawn this frame)
        local s0y = memory.readbyte(0x0200)
        local s0t = memory.readbyte(0x0201)
        local s0a = memory.readbyte(0x0202)
        local s0x = memory.readbyte(0x0203)
        logmsg(string.format("STATUS gamestate=%d plr_hp=%d en_hp=%d match_sec=%d ppuctrl=%02X oam_idx=%d plr_x=%d plr_y=%d state=%d | OAM0: y=%d t=%02X a=%02X x=%d",
            gs, plr_hp, en_hp, sec, ppuctrl_cache, oam_idx, plr_x, plr_y, plr_state, s0y, s0t, s0a, s0x))
        snap(string.format("periodic_%05d", frame))
    end
end)
