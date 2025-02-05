script_name("pingdisplay")
script_author("SEDD (_shehab) & AKACROSS Libraries")

-- Load required libraries
local imgui = require 'mimgui'
local encoding = require 'encoding'
local sampev = require 'lib.samp.events'
local memory = require 'memory'

-- Encoding setup
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Variables
local aimedPlayerId = -1 -- ID of the player you're aiming at
local aimedPlayerPing = 0 -- Ping of the aimed player
local windowVisible = false -- Toggle display
local windowPos = imgui.ImVec2(50, 50) -- Initial window position

function main()
    -- Wait for SA-MP to be available
    while not isSampAvailable() do wait(100) end

    sampAddChatMessage("COMBAT PING DISPLAYER - Use /pingdisplay to toggle the window.", 0xFFFFFF)

    -- Register command
    sampRegisterChatCommand("pingdisplay", function()
        windowVisible = not windowVisible
        sampAddChatMessage("[PingDisplay] Window is now " .. (windowVisible and "VISIBLE" or "HIDDEN"), 0xFFFFFF)
    end)

    -- Debug message to confirm script loaded
    sampAddChatMessage("[PingDisplay] Script loaded. Use /pingdisplay to toggle.", 0x00FF00)

    -- Update aimed player in a loop
    while true do
        wait(0)
        updateAimedPlayer()
    end
end

function updateAimedPlayer()
    aimedPlayerId = -1 -- Reset player ID

    local camX, camY, camZ = getActiveCameraCoordinates()
    local camTargetX, camTargetY, camTargetZ = getActiveCameraPointAt()

    -- Ensure proper line-of-sight detection
    local result, hit, endX, endY, endZ, _, entity = processLineOfSight(
        camX, camY, camZ, camTargetX, camTargetY, camTargetZ, 
        true, false, false, true, false, false, false, false
    )

    if result and isCharPed(entity) then
        local playerId = sampGetPlayerIdByCharHandle(entity)
        if playerId and sampIsPlayerConnected(playerId) then
            aimedPlayerId = playerId
            aimedPlayerPing = sampGetPlayerPing(playerId)
        end
    end
end

imgui.OnFrame(function() return windowVisible end, function()
    imgui.SetNextWindowPos(windowPos, imgui.Cond.FirstUseEver)
    imgui.Begin("Ping Display", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    if aimedPlayerId ~= -1 then
        imgui.Text(string.format("Player: %s", sampGetPlayerNickname(aimedPlayerId)))
        imgui.Text(string.format("Ping: %d ms", aimedPlayerPing))
    else
        imgui.Text("No player in sight.")
    end

    imgui.End()
end).HideCursor = true
