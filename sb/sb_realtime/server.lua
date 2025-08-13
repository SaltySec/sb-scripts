-- sb_realtime/server.lua

-- ==== Safe defaults (won't overwrite an existing config.lua) ====
Config = Config or {}
if Config.DefaultRealtime == nil then Config.DefaultRealtime = false end
if Config.RebroadcastInterval == nil then Config.RebroadcastInterval = 2000 end
if Config.ManualMsPerGameMinute == nil then Config.ManualMsPerGameMinute = 2000 end -- ~1 game minute / 2s
if Config.ManualBroadcastInterval == nil then Config.ManualBroadcastInterval = 2000 end
if Config.RequireAceForCommands == nil then Config.RequireAceForCommands = true end
if Config.Debug == nil then Config.Debug = false end
-- ===============================================================

local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil

-- Global realtime flag
local realtimeEnabled = Config.DefaultRealtime
GlobalState.realtimeEnabled = realtimeEnabled

-- Manual clock state (for realtime=OFF)
local manualClockThread = nil
local manualBaseMinutes = 12 * 60 -- default noon
local accumulatedMs = 0

-- Debug print
local function DebugPrint(msg)
    if Config.Debug then print("^3[RealtimeDebug]^7 " .. msg) end
end

-- Forward declarations
local startManualClockLoop
local setManualTime

-- Define helpers
setManualTime = function(h, m)
    manualBaseMinutes = ((h or 0) * 60 + (m or 0)) % (24 * 60)
    accumulatedMs = 0
    local s = 0
    TriggerClientEvent("realtimeclock:forceTime", -1, h or 0, m or 0, s)
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

-- Sync time to player on join
AddEventHandler('playerJoining', function(_oldId)
    local playerId = source
    if realtimeEnabled then
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", playerId, true, t.hour, t.min)
    else
        local h = math.floor(manualBaseMinutes / 60)
        local m = manualBaseMinutes % 60
        TriggerClientEvent("realtimeclock:forceTime", playerId, h, m, 0)
    end
end)

-- Realtime rebroadcast while realtime is ON
CreateThread(function()
    while true do
        if realtimeEnabled then
            local t = os.date("*t")
            TriggerClientEvent("realtimeclock:setRealtime", -1, true, t.hour, t.min)
        end
        Wait(Config.RebroadcastInterval)
    end
end)

-- Permission helper
local function hasPermOrConsole(src)
    if not Config.RequireAceForCommands then return true end
    if src == 0 then return true end -- console
    return IsPlayerAceAllowed(src, "command")
end

-- /realtime on|off
RegisterCommand("realtime", function(source, args)
    if not hasPermOrConsole(source) then return end
    local arg = args[1]; if not arg then return end

    if arg == "on" then
        realtimeEnabled = true
        GlobalState.realtimeEnabled = true
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", -1, true, t.hour, t.min)
        DebugPrint("Realtime enabled.")
    elseif arg == "off" then
        realtimeEnabled = false
        GlobalState.realtimeEnabled = false
        TriggerClientEvent("realtimeclock:setRealtime", -1, false)
        startManualClockLoop()
        DebugPrint("Realtime disabled; manual loop started.")
    end
end, true)

-- /settime H M
RegisterCommand("settime", function(source, args)
    if not hasPermOrConsole(source) then return end

    local h, m = tonumber(args[1]), tonumber(args[2])
    if not h or not m or h < 0 or h > 23 or m < 0 or m > 59 then return end

    realtimeEnabled = false
    GlobalState.realtimeEnabled = false
    TriggerClientEvent("realtimeclock:setRealtime", -1, false)

    SetTimeout(200, function()
        TriggerClientEvent("realtimeclock:updateTime", -1, h, m)
        setManualTime(h, m)
        startManualClockLoop()
        DebugPrint(("Manual time set to %02d:%02d; loop running."):format(h, m))
    end)
end, true)

-- /timelapse hours [minutes] duration_sec
RegisterCommand("timelapse", function(source, args)
    if not hasPermOrConsole(source) then return end

    local hours = tonumber(args[1])
    local minutes = tonumber(args[2]) or 0
    local duration = tonumber(args[3])
    if not hours or not duration then return end

    TriggerClientEvent("realtimeclock:startTimelapse", -1, hours, minutes, duration)
    DebugPrint(("Timelapse: +%dh %dm over %ds"):format(hours, minutes, duration))
end, true)
