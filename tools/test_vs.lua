-- THE LAST KUMITE — VS screen settled-frame capture
local logfile = io.open("/tmp/vstest/test_log.txt", "w")
local frame = 0
local last_gamestate = -1
local vs_frame = nil

local function logmsg(msg)
    logfile:write(string.format("[F%05d] %s", frame, msg) .. "\n")
    logfile:flush()
end

local function snap(name)
    gui.savescreenshotas("/tmp/vstest/shot_" .. name .. ".png")
end

local STATE_NAMES = {
    [0]="TITLE",[1]="INTRO",[2]="VS",[3]="FIGHT",[4]="WIN",[5]="LOSE",[6]="GAMEOVER",[7]="MENU"
}

emu.registerafter(function()
    frame = frame + 1
    local gs = memory.readbyte(0x0007)

    if gs ~= last_gamestate then
        logmsg("STATE CHANGE -> " .. (STATE_NAMES[gs] or ("UNKNOWN("..gs..")")))
        last_gamestate = gs
        if gs == 2 then vs_frame = frame end
    end

    if frame == 30 or frame == 31 then joypad.set(1, {start = true}) end
    if frame >= 90 and frame < 400 and (frame % 15 == 0 or frame % 15 == 1) then
        joypad.set(1, {start = true})
    end

    if vs_frame then
        local since = frame - vs_frame
        if since == 0 or since == 5 or since == 20 or since == 60 or since == 120 then
            logmsg(string.format("VS+%d", since))
            snap(string.format("vs_plus_%03d", since))
        end
        if since > 150 then
            vs_frame = -999999
        end
    end
end)
