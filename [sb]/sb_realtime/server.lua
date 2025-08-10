local realtimeEnabled = Config.DefaultRealtime
local QBCore = exports['qb-core']:GetCoreObject()

-- Debug print
local function DebugPrint(msg)
    if Config.Debug then print("^3[RealtimeDebug]^7 " .. msg) end
end

-- Sync server time to player on join
AddEventHandler('playerJoining', function(playerId)
    if realtimeEnabled then
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", playerId, true, t.hour, t.min)
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

    local arg = args[1]
    if not arg then return end

    if arg == "on" then
        GlobalState.realtimeEnabled, realtimeEnabled = true, true
        local t = os.date("*t")
        TriggerClientEvent("realtimeclock:setRealtime", -1, true, t.hour, t.min)
    elseif arg == "off" then
        GlobalState.realtimeEnabled, realtimeEnabled = false, false
        TriggerClientEvent("realtimeclock:setRealtime", -1, false)
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

    SetTimeout(200, function()
        TriggerClientEvent("realtimeclock:updateTime", -1, h, m)
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
