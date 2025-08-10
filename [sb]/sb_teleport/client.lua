local QBCore = exports['qb-core']:GetCoreObject()
Config = Config or {}
local pendingTeleport = false

-- Register custom keybind in FiveM keybindings
RegisterKeyMapping('teleportcircle_use', 'Teleport Circle: Use', 'keyboard', 'E')

-- === Helper: Draw floating 3D text ===
local function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- === Helper: Draw markers at all teleport in-points ===
local function DrawAllTeleportMarkers()
    for _, loc in pairs(Config.Teleports) do
        DrawMarker(1, loc.inPos.x, loc.inPos.y, loc.inPos.z - 1.0,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            loc.radius * 2, loc.radius * 2, 1.0,
            255, 255, 255, 120, false, true, 2, nil, nil, false)
    end
end

-- === Event: perform teleport with fade and offset ===
RegisterNetEvent("teleportcircle:receiveTeleportTarget", function(toPos)
    local fadeTime = Config.FadeTime or 1500

    DoScreenFadeOut(fadeTime)
    while not IsScreenFadedOut() do Wait(100) end

    local ped = PlayerPedId()

    -- Small random offset
    local offset = vector3(
        math.random(-50, 50) / 100.0,
        math.random(-50, 50) / 100.0,
        0.0
    )

    local finalX = toPos.x + offset.x
    local finalY = toPos.y + offset.y
    local finalZ = toPos.z
    local heading = toPos.w or 0.0

    -- Move attached entity if present
    local attachedEntity = GetEntityAttachedTo(ped)
    if attachedEntity and attachedEntity ~= 0 then
        SetEntityCoords(attachedEntity, finalX, finalY, finalZ, false, false, false, false)
        SetEntityHeading(attachedEntity, heading)

        FreezeEntityPosition(attachedEntity, true)
        Wait(100)
        FreezeEntityPosition(attachedEntity, false)

        PlaceObjectOnGroundProperly(attachedEntity)
    end

    -- Teleport player
    SetEntityCoords(ped, finalX, finalY, finalZ, false, false, false, false)
    SetEntityHeading(ped, heading)

    Wait(250)
    DoScreenFadeIn(fadeTime)

    TriggerEvent("teleportcircle:notify", "You've been teleported!", "success")
    Wait(3000)
    pendingTeleport = false
end)

-- === Optional notify event ===
RegisterNetEvent("teleportcircle:notify", function(msg, type)
    QBCore.Functions.Notify(msg, type or "primary", 3000)
end)

-- === Main loop: draw marker & floating text ===
CreateThread(function()
    while true do
        Wait(0)

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        DrawAllTeleportMarkers()

        for _, loc in pairs(Config.Teleports) do
            if #(playerCoords - loc.inPos) < loc.radius then
                Draw3DText(loc.inPos.x, loc.inPos.y, loc.inPos.z + 1.0, "Teleport nearby players")
            end
        end
    end
end)

-- === Command triggered by the keybinding ===
RegisterCommand('teleportcircle_use', function()
    if pendingTeleport then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for index, loc in pairs(Config.Teleports) do
        if #(coords - loc.inPos) < loc.radius then
            pendingTeleport = true
            TriggerServerEvent("teleportcircle:attemptTeleport", index)
            break
        end
    end
end, false)
