script_name('FCNotifier')
script_author('Brad (Discord: _shehab)') -- Report any bugs or suggestions on discord: _shehab

local http = require("socket.http")
local ltn12 = require("ltn12")

-- Configuration
local config = {
    forum_username = "",       -- Your forum username
    forum_password = "",        -- Your forum password
    check_interval = 600,          -- Time in seconds (600 = 10 minutes)
    login_url = "https://forums.hzgaming.net/login.php?do=login",
    complaints_url = "https://forums.hzgaming.net/forumdisplay.php/26-Player-Complaints",
    player_name = "" -- Your in-game name
}

local cookies = "" -- To store session cookies

-- Unified logging function
function logMessage(message)
    print("[FCNotifier] " .. message) -- Print to console
    sampAddChatMessage("[FCNotifier] " .. message, -1) -- Print to SA-MP chat
end

-- Save HTTP response for debugging
function saveDebugResponse(filename, content)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
        logMessage("Response saved to " .. filename)
    else
        logMessage("Failed to save response to " .. filename)
    end
end

-- Login to the forum
function loginToForum()
    local response_body = {}

    -- Step 1: Fetch the redirected forum page
    local forumPage, forumCode, forumHeaders = http.request {
        url = "https://forums.hzgaming.net/forum.php",
        method = "GET",
        redirect = true,
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        },
        sink = ltn12.sink.table(response_body)
    }

    if forumCode ~= 200 then
        logMessage("Failed to load forum page. HTTP Code: " .. tostring(forumCode))
        return false
    end

    -- Save response for debugging
    saveDebugResponse("forum_page.html", table.concat(response_body))

    local pageContent = table.concat(response_body)
    local securityToken = pageContent:match('name="securitytoken" value="(.-)"') or "guest"
    cookies = forumHeaders["set-cookie"] or ""

    -- Step 2: Prepare the login request
    local request_body = string.format(
        "vb_login_username=%s&vb_login_password=%s&securitytoken=%s&do=login&cookieuser=1",
        config.forum_username,
        config.forum_password,
        securityToken
    )

    response_body = {} -- Reset response table

    -- Step 3: Perform the login POST request
    local res, code, headers = http.request {
        url = config.login_url,
        method = "POST",
        redirect = true,
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = tostring(#request_body),
            ["Cookie"] = cookies
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    }

    -- Save login response for debugging
    saveDebugResponse("login_response.html", table.concat(response_body))

    if code == 200 and headers["set-cookie"] then
        cookies = headers["set-cookie"]
        logMessage("Login successful! Cookies received.")
        return true
    else
        logMessage("Login failed! HTTP Code: " .. tostring(code))
        return false
    end
end

-- Check for player complaints
function checkPlayerComplaints()
    local response_body = {}

    -- Ensure user is logged in
    if cookies == "" then
        logMessage("Not logged in! Attempting to login...")
        if not loginToForum() then
            logMessage("Login attempt failed. Cannot check complaints.")
            return
        end
    end

    -- Fetch complaints page
    local res, code, headers = http.request {
        url = config.complaints_url,
        method = "GET",
        redirect = true,
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            ["Cookie"] = cookies -- Send cookies for authentication
        },
        sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
        logMessage("Failed to fetch complaints page. HTTP Code: " .. tostring(code))
        return
    end

    -- Save response for debugging
    saveDebugResponse("complaints_page.html", table.concat(response_body))

    -- Check for player complaints
    local pageContent = table.concat(response_body)
    local complaintPattern = "Player Complaint against " .. config.player_name:gsub(" ", "%%s+")

    if pageContent:match(complaintPattern) then
        logMessage("⚠️ Complaint found against " .. config.player_name .. "!")
        sampAddChatMessage("⚠️ A player complaint has been filed against you! Check the forums.", -1)
    else
        logMessage("No complaints found.")
    end
end

-- Main loop
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then
        logMessage("SA-MP or SampFuncs not loaded. Exiting.")
        return
    end

    -- Start checking complaints
    while true do
        checkPlayerComplaints()
        wait(config.check_interval * 1000) -- Wait for the configured interval
    end
end
