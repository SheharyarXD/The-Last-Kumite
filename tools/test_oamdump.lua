local logfile = io.open("/tmp/oamdump/test_log.txt", "w")
local frame = 0
local last_gamestate = -1
local gameover_frame = nil

local function logmsg(msg)
    logfile:write(msg .. "\n")
    logfile:flush()
end

emu.registerafter(function()
    frame = frame + 1
    local gs = memory.readbyte(0x0007)
    if gs ~= last_gamestate then
        last_gamestate = gs
        if gs == 6 then gameover_frame = frame end
    end

    if frame == 30 or frame == 31 then joypad.set(1, {start = true}) end
    if frame >= 90 and frame < 400 and (frame % 15 == 0 or frame % 15 == 1) then
        joypad.set(1, {start = true})
    end
    if gs == 3 then
        local plr_x = memory.readbyte(0x0040)
        local en_x = memory.readbyte(0x0060)
        local dist = math.abs(plr_x - en_x)
        if dist > 15 then
            if plr_x < en_x then joypad.set(1, {right = true})
            else joypad.set(1, {left = true}) end
        end
    end

    if gameover_frame and frame == gameover_frame + 30 then
        logmsg(string.format("=== OAM dump at frame %d (gameover+30) ===", frame))
        for i = 0, 48 do
            local base = 0x0200 + i*4
            local y = memory.readbyte(base)
            local t = memory.readbyte(base+1)
            local a = memory.readbyte(base+2)
            local x = memory.readbyte(base+3)
            logmsg(string.format("sprite %2d: Y=%3d TILE=%3d ATTR=%02X X=%3d", i, y, t, a, x))
        end
        logmsg("oam_index = " .. memory.readbyte(0x0020))
    end
end)
