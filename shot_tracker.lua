script_name("Accuracy Tracker")
script_author("SEDD (_shehab) & AKACROSS Libraries")

local imgui = require 'mimgui'
local encoding = require 'encoding'
local ffi = require 'ffi'
local sampev = require 'lib.samp.events'
local weapons = require 'game.weapons'

-- Encoding
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Variables
local totalShots = 0
local totalHits = 0
local hitPlayers = {}

local isWindowVisible = true
local lastAmmo = 0 -- For ammo-based shot detection

-- Main function
function main()
    repeat wait(0) until isSampAvailable()
    sampAddChatMessage("Shot Tracker script loaded. Use /shotstats to toggle the window.", 0xFFFFFF)
    
    -- Register chat command correctly
    local success, err = pcall(function()
        sampRegisterChatCommand("shotstats", toggleWindow)
    end)
    
    if success then
        sampAddChatMessage("Command '/shotstats' registered successfully.", 0x00FF00)
    else
        sampAddChatMessage("Failed to register command '/shotstats': " .. tostring(err), 0xFF0000)
    end

    -- Continuously check for shots (ammo-based approach)
    while true do
        wait(0)
        detectShots()
    end
end

-- Toggle window visibility
function toggleWindow(cmd)
    sampAddChatMessage("toggleWindow function called.", 0x00FF00) -- Debug message
    isWindowVisible = not isWindowVisible
    sampAddChatMessage(string.format("Shot stats window is now %s", isWindowVisible and "visible" or "hidden"), 0xFFFFFF)
end

-- Detect shots fired using ammo count
function detectShots()
    local currentAmmo = getCharAmmo(PLAYER_PED, getCurrentCharWeapon(PLAYER_PED))
    if currentAmmo < lastAmmo then
        totalShots = totalShots + 1
        sampAddChatMessage(string.format("Shot detected! Total Shots: %d", totalShots), 0x00FF00)
    end
    lastAmmo = currentAmmo
end

-- Detect hits using onPlayerWeaponShot event
function sampev.onPlayerWeaponShot(playerId, weaponId, hitType, hitId, x, y, z)
    -- Debug: Print shot details
    sampAddChatMessage(string.format(
        "Shot detected - PlayerID: %d, WeaponID: %d, HitType: %d, HitID: %d, Coordinates: (%f, %f, %f)",
        playerId, weaponId, hitType, hitId, x, y, z
    ), 0xFFFFFF)

    -- Get local player ID
    local localPlayerId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    if not localPlayerId then
        sampAddChatMessage("Failed to get local player ID!", 0xFF0000)
        return
    end

    -- Debug: Print local player ID
    sampAddChatMessage(string.format("Local Player ID: %d", localPlayerId), 0x00FF00)

    -- Check if the shot was fired by the local player
    if playerId == localPlayerId then
        -- Check if the shot hit a player
        if hitType == 1 then -- Player hit
            totalHits = totalHits + 1
            local playerName = sampGetPlayerNickname(hitId)
            if playerName then
                hitPlayers[playerName] = (hitPlayers[playerName] or 0) + 1
                sampAddChatMessage(string.format("Hit player: %s (Total hits: %d)", playerName, hitPlayers[playerName]), 0x00FF00)
            else
                sampAddChatMessage("Failed to get player nickname for ID: " .. tostring(hitId), 0xFF0000)
            end
        end
    end
end

-- ImGui initialization
imgui.OnInitialize(function()
    sampAddChatMessage("ImGui initialized successfully.", 0x00FF00) -- Debug message
    applyCustomStyle()
end)

-- Apply custom styles
function applyCustomStyle()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding = 5.0
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(5, 5)
    style.ItemSpacing = imgui.ImVec2(5, 5)
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.94)
    style.Colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
end

-- ImGui rendering
imgui.OnFrame(function() return isWindowVisible end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(200, 150), imgui.Cond.FirstUseEver)
    imgui.Begin("Shot Statistics", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    -- Calculate accuracy
    local accuracy = totalShots > 0 and (totalHits / totalShots) * 100 or 0
    imgui.Text(string.format("Total Shots: %d", totalShots))
    imgui.Text(string.format("Total Hits: %d", totalHits))
    imgui.Text(string.format("Accuracy: %.2f%%", accuracy))

    -- Display players hit
    imgui.Separator()
    imgui.Text("Players Hit:")
    for playerName, hits in pairs(hitPlayers) do
        imgui.Text(string.format("%s: %d hits", playerName, hits))
    end

    imgui.End()
end).HideCursor = true