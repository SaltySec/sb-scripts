local QBCore = exports['qb-core']:GetCoreObject()

local savedHelmet = {
    prop = { drawable = nil, texture = nil }
}

-- === Utility ===
local function LoadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function PlayAnimAndWait(ped, anim, duration)
    LoadAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.name, 3.0, -1, duration, 0, 0, false, false, false)
    Wait(duration)
    StopAnimTask(ped, anim.dict, anim.name, 1.0)
end

-- === Helmet Handling ===
local function SaveCurrentHelmet()
    local ped = PlayerPedId()
    local drawable = GetPedPropIndex(ped, 0)
    local texture = GetPedPropTextureIndex(ped, 0)

    for _, id in ipairs(Config.AllowedHelmetProps) do
        if drawable == id then
            savedHelmet.prop.drawable = drawable
            savedHelmet.prop.texture = texture
            return
        end
    end

    savedHelmet.prop.drawable = -1 -- No valid helmet
end

local function RemoveHelmet()
    local ped = PlayerPedId()
    if savedHelmet.prop.drawable ~= -1 then
        ClearPedProp(ped, 0)
    end
end

local function RestoreHelmet()
    local ped = PlayerPedId()
    if savedHelmet.prop.drawable ~= -1 then
        SetPedPropIndex(ped, 0, savedHelmet.prop.drawable, savedHelmet.prop.texture, true)
    end
end

-- === Mask Handling ===
local function IsWearingSCBA()
    local ped = PlayerPedId()
    local comp = Config.MaskOn.component
    local drawable = GetPedDrawableVariation(ped, comp)
    local texture = GetPedTextureVariation(ped, comp)

    local isMaskOn  = (drawable == Config.MaskOn.drawable  and texture == Config.MaskOn.texture)
    local isMaskOff = (drawable == Config.MaskOff.drawable and texture == Config.MaskOff.texture)

    return (isMaskOn or isMaskOff)
end

local function ApplyMask(maskData)
    local ped = PlayerPedId()
    SetPedComponentVariation(ped, maskData.component, maskData.drawable, maskData.texture, 2)
end

-- === Main Toggle ===
local function ToggleSCBAWithHelmet()
    local ped = PlayerPedId()

    if not IsWearingSCBA() then
        QBCore.Functions.Notify(Config.Notify.NoSCBA, "error")
        return
    end

    local currentDrawable = GetPedDrawableVariation(ped, Config.MaskOn.component)
    local isMaskOn = (currentDrawable == Config.MaskOn.drawable)

    -- Save helmet before removal
    SaveCurrentHelmet()

    -- Remove helmet if wearing one
    if savedHelmet.prop.drawable ~= -1 then
        PlayAnimAndWait(ped, Config.Animations.removeHelmet, Config.Animations.removeHelmet.duration)
        RemoveHelmet()
    end

    -- Mask change
    if isMaskOn then
        PlayAnimAndWait(ped, Config.Animations.removeMask, Config.Animations.removeMask.duration)
        ApplyMask(Config.MaskOff)
        QBCore.Functions.Notify(Config.Notify.TakeOff, "success")
    else
        PlayAnimAndWait(ped, Config.Animations.putMask, Config.Animations.putMask.duration)
        ApplyMask(Config.MaskOn)
        QBCore.Functions.Notify(Config.Notify.PutOn, "success")
    end

    -- Restore helmet if we had one
    if savedHelmet.prop.drawable ~= -1 then
        PlayAnimAndWait(ped, Config.Animations.putHelmet, Config.Animations.putHelmet.duration)
        RestoreHelmet()
    end
end

-- === Command & Keybind ===
RegisterCommand("togglescba", function()
    TriggerServerEvent("scba:syncToggle")
end, false)

RegisterKeyMapping("togglescba", "Toggle SCBA Mask with Helmet", "keyboard", "J")

-- === Sync Events ===
RegisterNetEvent("scba:playToggle", function(serverId)
    if GetPlayerFromServerId(serverId) == PlayerId() then
        ToggleSCBAWithHelmet()
    else
        -- For now, we just trigger the same so others see animations too
        ToggleSCBAWithHelmet()
    end
end)
