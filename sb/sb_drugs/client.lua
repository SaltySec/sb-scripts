local QBCore = exports['qb-core']:GetCoreObject()

-- runtime state
local takenCounts = {}
local isOverdosing = false
local odStartTime, odTick, highFxActiveUntil = 0, 0, 0

-- ===== Notify =====
local function Notify(msg, typ, ms)
    if Config.UseQBCoreNotify then
        TriggerEvent('QBCore:Notify', msg, typ or 'primary', ms or 5000)
    else
        print(('[sb_drugs] %s'):format(msg))
    end
end

-- ===== Animations =====
local function playPillAnim()
    local ped = PlayerPedId()
    RequestAnimDict(Config.PillAnim.dict)
    while not HasAnimDictLoaded(Config.PillAnim.dict) do Wait(0) end
    TaskPlayAnim(ped, Config.PillAnim.dict, Config.PillAnim.anim, 8.0, 8.0, Config.PillAnim.durationMs, 49, 0.0, false, false, false)
    Wait(Config.PillAnim.durationMs)
    ClearPedTasks(ped)
end

local function playAdminAnim()
    local ped = PlayerPedId()
    local a = Config.NarcanAdminAnim
    RequestAnimDict(a.dict)
    while not HasAnimDictLoaded(a.dict) do Wait(0) end
    TaskPlayAnim(ped, a.dict, a.anim, 8.0, 8.0, a.durationMs, 49, 0.0, false, false, false)
    Wait(a.durationMs)
    ClearPedTasks(ped)
end

-- ===== Healing =====
local function healPercent(percent)
    local ped = PlayerPedId()
    local maxHp = GetEntityMaxHealth(ped)
    local cur = GetEntityHealth(ped)
    local add = math.floor(maxHp * percent + 0.5)
    SetEntityHealth(ped, math.min(cur + add, maxHp))
end

-- ===== OSP Ambulance via state bag (optional) =====
local function applyPainRelief_OSP()
    if not Config.UseOSPAmbulance then return end
    local st = LocalPlayer and LocalPlayer.state
    if not st then return end

    local bodyKey   = (Config.OSP and Config.OSP.bodyDamageKey) or 'BodyDamage'
    local painKey   = (Config.OSP and Config.OSP.painField) or 'Pain'
    local replicate = (Config.OSP and Config.OSP.replicate) ~= false

    local bd = st[bodyKey]
    if type(bd) ~= 'table' then bd = {} end
    bd[painKey] = 0

    if st.set then
        st:set(bodyKey, bd, replicate)
    else
        st[bodyKey] = bd
    end
end

-- ===== FX =====
local function applyHighFX()
    if Config.HighScreenEffect and Config.HighScreenEffect ~= '' then
        StartScreenEffect(Config.HighScreenEffect, 0, true) -- loop; we stop via timer
    end
    if Config.HighMovementClipset and Config.HighMovementClipset ~= '' then
        RequestAnimSet(Config.HighMovementClipset)
        while not HasAnimSetLoaded(Config.HighMovementClipset) do Wait(0) end
        SetPedMotionBlur(PlayerPedId(), true)
        SetPedMovementClipset(PlayerPedId(), Config.HighMovementClipset, 1.0)
    end
    highFxActiveUntil = GetGameTimer() + (Config.HighEffectSeconds * 1000)
end

local function clearHighFX()
    StopAllScreenEffects()
    if Config.HighMovementClipset then
        ResetPedMovementClipset(PlayerPedId(), 0.0)
        SetPedMotionBlur(PlayerPedId(), false)
    end
end

-- ===== Overdose (no ragdoll/voice) =====
local function startOverdose(drugLabel)
    if isOverdosing then return end
    isOverdosing = true
    odStartTime, odTick = GetGameTimer(), GetGameTimer()
    TriggerServerEvent('sb_drugs:setODState', true)
    Notify(('You think you took too many %s... You feel unwell.'):format(drugLabel), 'error', 8000)

    CreateThread(function()
        while isOverdosing do
            local now = GetGameTimer()
            local elapsed = now - odStartTime
            local ped = PlayerPedId()

            -- Stop if dead/0 HP
            if IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then
                isOverdosing = false
                TriggerServerEvent('sb_drugs:setODState', false)
                clearHighFX()
                takenCounts = {}
                break
            end

            -- Drain towards 0 HP over remaining time
            if now - odTick >= 1000 then
                local hp = GetEntityHealth(ped)
                if hp > 0 then
                    local remain = math.max(0, (Config.OverdoseDrainSeconds * 1000 - elapsed) / 1000)
                    local perSec = math.max(1, math.floor(hp / math.max(1, remain)))
                    SetEntityHealth(ped, math.max(0, hp - perSec))
                end
                odTick = now
            end

            Wait(0)
        end
    end)
end

local function stopOverdose()
    if not isOverdosing then return end
    isOverdosing = false
    TriggerServerEvent('sb_drugs:setODState', false)
end

-- ===== Pill tracking =====
local function addPillUse(itemName)
    local nowMs = GetGameTimer()
    local cfg = Config.Drugs[itemName]
    local slot = takenCounts[itemName]
    if not slot or (nowMs - slot.startedMs) > (cfg.windowSeconds * 1000) then
        slot = { count = 0, startedMs = nowMs }
        takenCounts[itemName] = slot
    end
    slot.count = slot.count + 1
    return slot.count, cfg
end

-- ===== Use handlers =====
local function usePill(itemName)
    local cfg = Config.Drugs[itemName]
    if not cfg then return end

    playPillAnim()
    Notify(('You take %s.'):format(cfg.label), 'primary', 3500)

    -- Heal then OSP pain relief (statebag) if enabled
    healPercent(cfg.healPercent)
    applyPainRelief_OSP()

    local count = addPillUse(itemName)
    if count >= cfg.highThreshold and not isOverdosing then
        applyHighFX()
    end
    if count >= cfg.overdoseThreshold then
        startOverdose(cfg.label)
    end
end

local function useNarcan()
    stopOverdose()
    clearHighFX()
    Notify('Narcan administered. Your symptoms subside.', 'success', 5000)
end

-- ===== FX timer guard =====
CreateThread(function()
    while true do
        if highFxActiveUntil > 0 and GetGameTimer() > highFxActiveUntil then
            clearHighFX()
            highFxActiveUntil = 0
        end
        Wait(500)
    end
end)

-- ===== ox_target: Administer Narcan to another player =====
CreateThread(function()
    if not Config.UseOXTarget then return end
    local ok = pcall(function() return exports['ox_target'] ~= nil end)
    if not ok then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'sb_administer_narcan',
            icon  = (Config.TargetNarcan and Config.TargetNarcan.icon) or 'fa-solid fa-syringe',
            label = (Config.TargetNarcan and Config.TargetNarcan.label) or 'Administer Narcan',
            distance = Config.TargetDistance or 2.0,
            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then return end
                local ply = NetworkGetPlayerIndexFromPed(entity)
                if not ply then return end
                local targetId = GetPlayerServerId(ply)
                if not targetId then return end
                TriggerServerEvent('sb_drugs:tryAdministerNarcan', targetId)
            end
        }
    })
end)

-- ===== Net events =====
RegisterNetEvent('sb_drugs:usePill', function(itemName) usePill(itemName) end)
RegisterNetEvent('sb_drugs:useNarcan', function() useNarcan() end)
RegisterNetEvent('sb_drugs:playAdminAnim', function() playAdminAnim() end)

-- ===== Cleanup =====
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopOverdose()
    clearHighFX()
end)
