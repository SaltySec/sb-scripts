-- sb_realtime/client.lua
-- Smooth realtime + manual clock with correct hour/minute carry and hard-push support.
-- Keeps existing command names and event names used by your server script.

-- ==== Safe defaults (won't overwrite an existing config.lua) ====
Config = Config or {}
if Config.Debug == nil then Config.Debug = false end
if Config.UseQBCoreNotify == nil then Config.UseQBCoreNotify = false end
if Config.MessageTime == nil then Config.MessageTime = 5000 end
if Config.RandomMessages == nil then Config.RandomMessages = {} end
if Config.TransitionLength == nil then Config.TransitionLength = 10 end
if Config.FadeLength == nil then Config.FadeLength = 2000 end
if Config.FadeInPercent == nil then Config.FadeInPercent = 0.25 end
if Config.FadeOutPercent == nil then Config.FadeOutPercent = 0.75 end
if Config.DelayUntilMessage == nil then Config.DelayUntilMessage = 1500 end
if Config.RealtimeLoopDelay == nil then Config.RealtimeLoopDelay = 500 end
if Config.TimelapseStepMS == nil then Config.TimelapseStepMS = 100 end
-- Mirror server so client can interpolate manual mode smoothly (may be overridden by server packet)
if Config.ManualMsPerGameMinute == nil then Config.ManualMsPerGameMinute = 2000 end
-- ===============================================================

local realtimeMode = false
local baseRealTimeMs, baseGameHour, baseGameMinute
local realtimeThread
local isTransitioning = false

-- Manual mode interpolation state
local manualBase = { h = nil, m = nil, s = nil, t0 = nil } -- base game time + client ms epoch
local manualLoopStarted = false

-- One-time hard commit flag for manual mode
local needsFirstManualHardCommit = true
local manualMsPerGameMinute = Config.ManualMsPerGameMinute -- authoritative rate may come from server

-- Debug print
local function DebugPrint(msg)
    if Config.Debug then print("^3[RealtimeDebug]^7 " .. msg) end
end

-- Notify wrapper (picks random immersive/confusing message)
local function NotifyRandom()
    if not Config.RandomMessages or #Config.RandomMessages == 0 then return end
    local msg = Config.RandomMessages[math.random(1, #Config.RandomMessages)]
    if Config.UseQBCoreNotify then
        TriggerEvent('QBCore:Notify', msg, 'primary', Config.MessageTime)
    else
        TriggerEvent("chat:addMessage", { args = { "[Time]", msg } })
    end
end

-- Easing
local function easeInOutQuad(t)
    if t < 0.5 then return 2 * t * t else return -1 + (4 - 2 * t) * t end
end

-- SOFT apply = visuals only (no lighting jerk)
local function ApplyClockSoft(h, m, s)
    s = s or 0
    NetworkOverrideClockTime(h, m, s)
end

-- HARD apply = set world + visuals (use sparingly)
local function ApplyClockHard(h, m, s)
    s = s or 0
    SetClockTime(h, m, s)   -- lighting / sun position
    PauseClock(false)       -- ensure not paused by other scripts
    NetworkOverrideClockTime(h, m, s)
end

-- Smooth time transition with fade (SOFT during tween, HARD once at end)
local function SmoothSetTime(targetHour, targetMinute, duration)
    if isTransitioning then return end
    isTransitioning = true

    local currentHour, currentMinute = GetClockHours(), GetClockMinutes()
    local startTime = currentHour * 60 + currentMinute
    local endTime = targetHour * 60 + targetMinute
    local diff = (endTime - startTime) % 1440
    if diff > 720 then diff = diff - 1440 end

    local startTimeMs = GetGameTimer()
    local durationMs = math.max(1, duration * 1000)
    local fadeStart, fadeEnd = Config.FadeInPercent or 0.25, Config.FadeOutPercent or 0.75
    local didFadeOut, didFadeIn = false, false

    CreateThread(function()
        while true do
            local elapsed = GetGameTimer() - startTimeMs
            local rawProgress = math.min(elapsed / durationMs, 1.0)
            local easedProgress = easeInOutQuad(rawProgress)

            local newMinutes = (startTime + diff * easedProgress) % 1440
            local hour = math.floor(newMinutes / 60)
            local minute = math.floor(newMinutes % 60)
            ApplyClockSoft(hour, minute, 0)

            if not didFadeOut and rawProgress >= fadeStart then
                DoScreenFadeOut(Config.FadeLength or 2000)
                didFadeOut = true
            end

            if not didFadeIn and rawProgress >= fadeEnd then
                DoScreenFadeIn(Config.FadeLength or 2000)
                didFadeIn = true
            end

            if rawProgress >= 1.0 then break end
            Wait(0)
        end
        -- Commit final moment to world clock once
        ApplyClockHard(targetHour, targetMinute, 0)
        isTransitioning = false
    end)
end

-- ===== Commands (client helper only; real commands live on server) =====
-- /time check
RegisterCommand("time", function()
    local hour, minute = GetClockHours(), GetClockMinutes()
    local realtimeStatus = GlobalState.realtimeEnabled and "On" or "Off"
    TriggerEvent("chat:addMessage", {
        args = { "[Time]", ("Current Time: %02d %02d | Realtime: %s"):format(hour, minute, realtimeStatus) }
    })
end, false)

-- ===== Realtime handling =====
local function ensureRealtimeThread()
    if realtimeThread then return end
    realtimeThread = CreateThread(function()
        DebugPrint(("Realtime loop started at base %02d:%02d"):format(baseGameHour or -1, baseGameMinute or -1))
        while realtimeMode do
            local now = GetGameTimer()
            local elapsed = now - (baseRealTimeMs or now)
            if elapsed < 0 then elapsed = 0 end
            local elapsedMin = math.floor(elapsed / 60000)          -- integer minutes elapsed
            local total = (baseGameHour * 60 + baseGameMinute + elapsedMin)
            local h = (total // 60) % 24                             -- integer carry to hours
            local m = total % 60
            local s = math.floor((elapsed % 60000) / 1000)          -- cosmetic seconds 0..59
            ApplyClockSoft(h, m, s)
            Wait((Config.RealtimeLoopDelay ~= nil) and Config.RealtimeLoopDelay or 500)
        end
        DebugPrint("Realtime loop exited")
        realtimeThread = nil
    end)
end

-- Server tells us whether realtime is on, and what H/M to use
RegisterNetEvent("realtimeclock:setRealtime", function(enable, hour, minute)
    if enable then
        -- entering or staying in realtime: update base every packet and keep a smooth local tick
        realtimeMode = true
        baseGameHour = hour % 24
        baseGameMinute = minute % 60
        baseRealTimeMs = GetGameTimer()
        -- First entry: smooth to target + fun msg
        if not realtimeThread then
            SmoothSetTime(baseGameHour, baseGameMinute, Config.TransitionLength or 10)
            Wait(Config.DelayUntilMessage or 1500)
            NotifyRandom()
        end
        ensureRealtimeThread()
    else
        -- leaving realtime -> stop local tick; next manual tick will hard-commit once
        realtimeMode = false
        if realtimeThread then TerminateThread(realtimeThread); realtimeThread = nil end
        needsFirstManualHardCommit = true
    end
end)

-- ===== Manual mode =====
-- Server pushes H/M/S (+ authoritative ms/min). We hard-commit once, then interpolate smoothly.
RegisterNetEvent("realtimeclock:forceTime", function(hour, minute, second, msPerMin)
    if realtimeMode then return end
    if msPerMin and msPerMin > 0 then
        manualMsPerGameMinute = msPerMin
    end
    manualBase.h, manualBase.m, manualBase.s = hour % 24, minute % 60, (second or 0) % 60
    manualBase.t0 = GetGameTimer()

    if needsFirstManualHardCommit then
        ApplyClockHard(manualBase.h, manualBase.m, manualBase.s)
        needsFirstManualHardCommit = false
    else
        ApplyClockSoft(manualBase.h, manualBase.m, manualBase.s)
    end
end)

-- Admin set time while in manual: smooth to that value
RegisterNetEvent("realtimeclock:updateTime", function(hour, minute)
    realtimeMode = false
    if realtimeThread then TerminateThread(realtimeThread); realtimeThread = nil end
    SmoothSetTime(hour % 24, minute % 60, Config.TransitionLength or 10)
    Wait(Config.DelayUntilMessage or 1500)
    NotifyRandom()
    needsFirstManualHardCommit = false -- already committed by SmoothSetTime
end)

-- Timelapse (cinematic)
RegisterNetEvent("realtimeclock:startTimelapse", function(hours, minutes, duration)
    NotifyRandom()
    local totalMinutes = (hours * 60) + (minutes or 0)
    local startH, startM = GetClockHours(), GetClockMinutes()
    local startTotal = startH * 60 + startM
    local steps = math.max(1, math.floor((duration * 1000) / (Config.TimelapseStepMS or 100)))
    local step = totalMinutes / steps

    CreateThread(function()
        local current = startTotal
        for i = 1, steps do
            current = (current + step) % (24 * 60)
            local h = math.floor(current / 60)
            local m = math.floor(current % 60)
            ApplyClockSoft(h, m, 0)
            Wait(Config.TimelapseStepMS or 100)
        end
        local endH = math.floor(current / 60)
        local endM = math.floor(current % 60)
        ApplyClockHard(endH, endM, 0)
    end)
end)

-- Chat suggestions (optional)
TriggerEvent('chat:addSuggestion', '/realtime', 'Enable or disable real-time mode', {
    { name = "on|off", help = "Turn real-time mode on or off" }
})
TriggerEvent('chat:addSuggestion', '/settime', 'Set the in-game time', {
    { name = "hour", help = "Hour (0-23)" },
    { name = "minute", help = "Minute (0-59)" }
})
TriggerEvent('chat:addSuggestion', '/timelapse', 'Run a cinematic time-lapse', {
    { name = "hours", help = "Hours to pass" },
    { name = "minutes", help = "Minutes to pass" },
    { name = "duration", help = "Seconds for the entire time-lapse" }
})

-- Manual interpolation loop (keeps sun smooth between server manual ticks)
CreateThread(function()
    manualLoopStarted = true
    needsFirstManualHardCommit = true
    while true do
        Wait(250)
        if not realtimeMode and manualBase.t0 then
            local elapsedMs = GetGameTimer() - manualBase.t0
            if elapsedMs < 0 then elapsedMs = 0 end
            local addMinutes = elapsedMs / (manualMsPerGameMinute > 0 and manualMsPerGameMinute or 2000)
            local baseTotal = manualBase.h * 60 + manualBase.m + (manualBase.s or 0) / 60
            local cur = (baseTotal + addMinutes) % (24 * 60)
            local h = math.floor(cur / 60)
            local m = math.floor(cur % 60)
            local s = math.floor(((cur - math.floor(cur)) * 60))
            ApplyClockSoft(h, m, s)
        end
    end
end)

-- Ask server for a hard-push on resource start (covers late-start clients)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('realtimeclock:requestHardPush')
end)
