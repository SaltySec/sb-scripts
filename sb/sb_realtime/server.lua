local realtimeEnabled = Config.DefaultRealtime
local QBCore = exports['qb-core']:GetCoreObject()
local realtimeEnabled = Config.DefaultRealtime
local manualClockThread = nil
local manualBaseMinutes = 12 * 60   -- default noon fallback
local accumulatedMs = 0

-- Manual clock state (for realtime=OFF)
local manualClockThread = nil
local manualBaseMinutes = 12 * 60 -- default noon
local accumulatedMs = 0

-- Forward declarations (so they exist when called further down)
local startManualClockLoop
local setManualTime

-- Define helpers
setManualTime = function(h, m)
    manualBaseMinutes = ((h or 0) * 60 + (m or 0)) % (24 * 60)
    accumulatedMs = 0
    TriggerClientEvent("realtimeclock:forceTime", -1, h or 0, m or 0, 0)
end

startManualClockLoop = function()
    if manualClockThread then return end
    manualClockThread = true
    CreateThread(function()
        local last = GetGameTimer()
        local nextBroadcast = 0
        while not realtimeEnabled do
            Wait(0)
            local now = GetGameTimer()
            local dt = now - last
            last = now

            accumulatedMs = accumulatedMs + dt
            while accumulatedMs >= Config.ManualMsPerGameMinute do
                accumulatedMs = accumulatedMs - Config.ManualMsPerGameMinute
                manualBaseMinutes = (manualBaseMinutes + 1) % (24 * 60)
            end

            nextBroadcast = nextBroadcast + dt
            if nextBroadcast >= Config.ManualBroadcastInterval then
                nextBroadcast = 0
                local h = math.floor(manualBaseMinutes / 60)
                local m = manualBaseMinutes % 60
                local s = math.floor((accumulatedMs / Config.ManualMsPerGameMinute) * 60)
                TriggerClientEvent("realtimeclock:forceTime", -1, h, m, s)
            end

            if realtimeEnabled then break end
        end
        manualClockThread = nil
    end)
end

-- Debug print
local function DebugPrint(msg)
    if Config.Debug then print("^3[RealtimeDebug]^7 " .. msg) end
end

-- Sync server time to player on join
AddEventHandler('playerJoining', function(playerId)
    if realtimeEnabled then
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", playerId, true, t.hour, t.min)
    else
        local h = math.floor(manualBaseMinutes / 60)
        local m = manualBaseMinutes % 60
        TriggerClientEvent("realtimeclock:forceTime", playerId, h, m, 0)
    end
end)

-- Rebroadcast time periodically
CreateThread(function()
    while true do
        if realtimeEnabled then
            local t = os.date("*t")
            TriggerClientEvent("realtimeclock:setRealtime", -1, true, t.hour, t.min)
        end
        Wait(Config.RebroadcastInterval)
    end
end)

-- /realtime
RegisterCommand("realtime", function(source, args)
    if Config.RequireAceForCommands and source > 0 and not IsPlayerAceAllowed(source, "command") then
        return
    end
    local arg = args[1]; if not arg then return end

    if arg == "on" then
        GlobalState.realtimeEnabled, realtimeEnabled = true, true
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", -1, true, t.hour, t.min)
    elseif arg == "off" then
        GlobalState.realtimeEnabled, realtimeEnabled = false, false
        TriggerClientEvent("realtimeclock:setRealtime", -1, false)
        -- Kick manual loop if not running
        startManualClockLoop()
    end
end, true)

-- /settime
RegisterCommand("settime", function(source, args)
    if Config.RequireAceForCommands and source > 0 and not IsPlayerAceAllowed(source, "command") then
        return
    end
    local h, m = tonumber(args[1]), tonumber(args[2])
    if not h or not m or h < 0 or h > 23 or m < 0 or m > 59 then return end

    GlobalState.realtimeEnabled, realtimeEnabled = false, false
    TriggerClientEvent("realtimeclock:setRealtime", -1, false)

    -- Smooth jump to the requested time (your existing behavior)
    SetTimeout(200, function()
        TriggerClientEvent("realtimeclock:updateTime", -1, h, m)
        -- Also seed the server-owned manual clock and start advancing/broadcasting
        setManualTime(h, m)
        startManualClockLoop()
    end)
end, true)

-- /timelapse
RegisterCommand("timelapse", function(source, args)
    if Config.RequireAceForCommands and source > 0 and not IsPlayerAceAllowed(source, "command") then
        return
    end

    local hours = tonumber(args[1])
    local minutes = tonumber(args[2]) or 0
    local duration = tonumber(args[3])
    if not hours or not duration then return end

    TriggerClientEvent("realtimeclock:startTimelapse", -1, hours, minutes, duration)
end, true)

local function startManualClockLoop()
    if manualClockThread then return end
    manualClockThread = true
    CreateThread(function()
        local last = GetGameTimer()  -- server-side monotonic ms
        local nextBroadcast = 0
        while not realtimeEnabled do
            Wait(0)
            local now = GetGameTimer()
            local dt = now - last
            last = now

            accumulatedMs = accumulatedMs + dt
            -- Advance game minutes when enough real ms have passed
            while accumulatedMs >= Config.ManualMsPerGameMinute do
                accumulatedMs = accumulatedMs - Config.ManualMsPerGameMinute
                manualBaseMinutes = (manualBaseMinutes + 1) % (24 * 60)
            end

            nextBroadcast = nextBroadcast + dt
            if nextBroadcast >= Config.ManualBroadcastInterval then
                nextBroadcast = 0
                local h = math.floor(manualBaseMinutes / 60)
                local m = manualBaseMinutes % 60
                local s = math.floor((accumulatedMs / Config.ManualMsPerGameMinute) * 60)
                TriggerClientEvent("realtimeclock:forceTime", -1, h, m, s)
            end

            if realtimeEnabled then break end
        end
        manualClockThread = nil
    end)
end

local function setManualTime(h, m)
    manualBaseMinutes = (h * 60 + m) % (24 * 60)
    accumulatedMs = 0
    local s = 0
    -- Push an immediate authoritative tick so everyone snaps to the same moment
    TriggerClientEvent("realtimeclock:forceTime", -1, h, m, s)
end