-- sb_realtime/client.lua

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

-- Ease function
local function easeInOutQuad(t)
    if t < 0.5 then return 2 * t * t else return -1 + (4 - 2 * t) * t end
end

-- Debug print
local function DebugPrint(msg)
    if Config.Debug then print("^3[RealtimeDebug]^7 " .. msg) end
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
    local fadeStart, fadeEnd = Config.FadeInPercent, Config.FadeOutPercent
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
                DoScreenFadeOut(Config.FadeLength)
                didFadeOut = true
            end

            if not didFadeIn and rawProgress >= fadeEnd then
                DoScreenFadeIn(Config.FadeLength)
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

-- /time check
RegisterCommand("time", function()
    local hour, minute = GetClockHours(), GetClockMinutes()
    local realtimeStatus = GlobalState.realtimeEnabled and "On" or "Off"
    TriggerEvent("chat:addMessage", {
        args = { "[Time]", ("Current Time: %02d %02d | Realtime: %s"):format(hour, minute, realtimeStatus) }
    })
end, false)

-- Realtime toggle handler
RegisterNetEvent("realtimeclock:setRealtime", function(enable, hour, minute)
    if enable then
        -- entering realtime
        manualBase = { h = nil, m = nil, s = nil, t0 = nil } -- clear manual state
        needsFirstManualHardCommit = true -- next time we go to manual, do one hard commit

        if not realtimeMode then
            SmoothSetTime(hour, minute, Config.TransitionLength)
            Wait(Config.DelayUntilMessage)
            NotifyRandom()
        else
            -- already realtime: hard once to align, loop will soft-step
            ApplyClockHard(hour, minute, 0)
            return
        end

        realtimeMode = true
        baseRealTimeMs, baseGameHour, baseGameMinute = GetGameTimer(), hour, minute

        SetTimeout(Config.TransitionLength * 1000, function()
            if realtimeMode then
                if realtimeThread then TerminateThread(realtimeThread); realtimeThread = nil end
                realtimeThread = CreateThread(function()
                    while realtimeMode do
                        local elapsedMs = GetGameTimer() - baseRealTimeMs
                        local elapsedMinutes = elapsedMs / 60000.0
                        local totalMinutes = baseGameHour * 60 + baseGameMinute + elapsedMinutes
                        local h = math.floor((totalMinutes / 60) % 24)
                        local m = math.floor(totalMinutes % 60)
                        local s = math.floor((elapsedMinutes % 1) * 60)
                        -- SOFT only to avoid shudder
                        ApplyClockSoft(h, m, s)
                        Wait(Config.RealtimeLoopDelay)
                    end
                end)
            end
        end)
    else
        -- leaving realtime -> ensure next manual tick hard-commits once
        realtimeMode = false
        if realtimeThread then TerminateThread(realtimeThread); realtimeThread = nil end
        needsFirstManualHardCommit = true
        -- manual loop will take over once we receive forceTime ticks
    end
end)

-- Manual mode server tick: set base epoch; do a ONE-TIME HARD commit on first tick
RegisterNetEvent("realtimeclock:forceTime", function(hour, minute, second, msPerMin)
    if realtimeMode then return end

    -- Take authoritative rate if provided
    if msPerMin and msPerMin > 0 then
        manualMsPerGameMinute = msPerMin
    end

    manualBase.h, manualBase.m, manualBase.s = hour, minute, (second or 0)
    manualBase.t0 = GetGameTimer()

    if needsFirstManualHardCommit then
        ApplyClockHard(hour, minute, manualBase.s)
        needsFirstManualHardCommit = false
    else
        -- already aligned once; keep it smooth
        ApplyClockSoft(hour, minute, manualBase.s)
    end
end)

-- Manual time set handler (admin /settime issued)
RegisterNetEvent("realtimeclock:updateTime", function(hour, minute)
    realtimeMode = false
    if realtimeThread then TerminateThread(realtimeThread); realtimeThread = nil end
    -- Smooth to target, hard-commit at end
    SmoothSetTime(hour, minute, Config.TransitionLength)
    Wait(Config.DelayUntilMessage)
    NotifyRandom()
    -- Ensure after the admin set, we don't accidentally skip a hard commit if server stays in manual
    needsFirstManualHardCommit = false
end)

-- Timelapse handler (SOFT during the motion; HARD once at the end)
RegisterNetEvent("realtimeclock:startTimelapse", function(hours, minutes, duration)
    NotifyRandom()
    local totalMinutes = (hours * 60) + (minutes or 0)
    local startH, startM = GetClockHours(), GetClockMinutes()
    local startTotal = startH * 60 + startM
    local steps = math.max(1, math.floor((duration * 1000) / Config.TimelapseStepMS))
    local step = totalMinutes / steps

    CreateThread(function()
        local current = startTotal
        for i = 1, steps do
            current = (current + step) % (24 * 60)
            local h = math.floor(current / 60)
            local m = math.floor(current % 60)
            ApplyClockSoft(h, m, 0)
            Wait(Config.TimelapseStepMS)
        end
        local endH = math.floor(current / 60)
        local endM = math.floor(current % 60)
        ApplyClockHard(endH, endM, 0)
    end)
end)

-- Chat suggestions
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

-- Manual mode interpolation loop (keeps sun smooth between server ticks)
CreateThread(function()
    manualLoopStarted = true
    -- On resource start / first join, ensure we will do a hard commit
    needsFirstManualHardCommit = true

    while true do
        Wait(250)
        if not realtimeMode and manualBase.t0 then
            local elapsedMs = GetGameTimer() - manualBase.t0
            local addMinutes = elapsedMs / manualMsPerGameMinute -- authoritative rate
            local baseTotal = manualBase.h * 60 + manualBase.m + (manualBase.s or 0) / 60
            local cur = (baseTotal + addMinutes) % (24 * 60)
            local h = math.floor(cur / 60)
            local m = math.floor(cur % 60)
            local s = math.floor(((cur - math.floor(cur)) * 60))
            -- SOFT apply only (no world reset)
            ApplyClockSoft(h, m, s)
        end
    end
end)
