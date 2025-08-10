local QBCore = exports['qb-core']:GetCoreObject()
local basketModel = `rescue_basket`

local attachedBasket = nil
local attachedHeli = nil

local ropeData = {
    rope = nil,
    heli = nil,
    basket = nil,
    length = 0.55,
    minLength = 0.55,
    maxLength = 250.0,
    speedPerSecond = 2.2 -- How fast rope changes per second
}

-- UI Drawing
CreateThread(function()
    while true do
        Wait(0)
        if ropeData.rope and ropeData.heli and ropeData.basket then
            DrawRect(0.91, 0.93, 0.13, 0.10, 50, 50, 50, 180)
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 215)
            SetTextEntry("STRING")

            local readyToStow = ropeData.length <= ropeData.minLength + 0.05
            local stowText = readyToStow and "~g~Yes" or "~r~No"

            AddTextComponentString(string.format("Rope Length: %.1f\nShorten Winch:      ↑\nLengthen Winch:    ↓\nReady to Stow: %s", ropeData.length, stowText))
            DrawText(0.855, 0.880)
        else
            Wait(500)
        end
    end
end)

function SpawnBasketAndRope()
    local ped = PlayerPedId()
    local heli = GetVehiclePedIsIn(ped, false)
    if heli == 0 or not IsPedInAnyHeli(ped) then
        QBCore.Functions.Notify("You must be in a helicopter.", "error")
        return
    end
    if DoesEntityExist(attachedBasket) then
        QBCore.Functions.Notify("Basket is already deployed.", "error")
        return
    end

    RequestModel(basketModel)
    while not HasModelLoaded(basketModel) do Wait(0) end
    local pos = GetOffsetFromEntityInWorldCoords(heli, 3.5, 2.5, -0.5)
    local basket = CreateObject(basketModel, pos.x, pos.y, pos.z, true, true, false)
    SetEntityAsMissionEntity(basket, true, true)
    ActivatePhysics(basket)

    attachedBasket = basket
    attachedHeli = heli
    SetVehicleExtra(heli, 12, true)

    local heliNetId = NetworkGetNetworkIdFromEntity(heli)
    local basketNetId = NetworkGetNetworkIdFromEntity(basket)
    QBCore.Functions.Notify("🚁 Basket deployed.", "success")
    TriggerEvent("rescue:attachBasketRope", heliNetId, basketNetId)
end

function RemoveBasketAndRope()
    if ropeData.length > ropeData.minLength + 0.05 then
        QBCore.Functions.Notify("Winch must be fully retracted to stow basket.", "error")
        return
    end

    -- Remove rope first
    if ropeData.rope then
        DeleteRope(ropeData.rope)
        ropeData.rope = nil
    end

    -- If we have a basket entity, check for any occupant
    if DoesEntityExist(attachedBasket) then
        local occupantServerId = Entity(attachedBasket).state.basketOccupant
        if occupantServerId then
            -- Tell the server to make that player warp into this heli
            TriggerServerEvent("rescue:server:warpFromBasket", occupantServerId, VehToNet(attachedHeli))
        end

        -- Clear statebag for basket
        Entity(attachedBasket).state:set('basketOccupant', nil, true)

        -- Delete basket object
        DeleteEntity(attachedBasket)
        attachedBasket = nil
    end

    -- Reset heli extras and clear stored references
    if DoesEntityExist(attachedHeli) then
        SetVehicleExtra(attachedHeli, 12, false)
        attachedHeli = nil
    end

    ropeData.heli = nil
    ropeData.basket = nil
    QBCore.Functions.Notify("🚑 Basket removed.", "primary")
end


RegisterCommand("togglebasket", function()
    if DoesEntityExist(attachedBasket) then
        RemoveBasketAndRope()
    else
        SpawnBasketAndRope()
    end
end)

RegisterKeyMapping('togglebasket', 'Toggle Rescue Basket', 'keyboard', 'J')

RegisterCommand("enterbasket", function()
    local ped = PlayerPedId()
    if DoesEntityExist(attachedBasket) and DoesEntityExist(attachedHeli) then
        local heli = attachedHeli
        if heli ~= 0 and not IsPedInVehicle(ped, attachedBasket) and not IsPedInAnyVehicle(ped, false) then
            TaskWarpPedIntoVehicle(ped, attachedBasket, -1)
        end
    end
end, false)

RegisterKeyMapping("enterbasket", "Enter Rescue Basket", "keyboard", "K")

RegisterNetEvent("rescue:attachBasketRope", function(heliNetId, basketNetId)
    local heli = NetworkGetEntityFromNetworkId(heliNetId)
    local basket = NetworkGetEntityFromNetworkId(basketNetId)

    if not (DoesEntityExist(heli) and DoesEntityExist(basket)) then
        print("[Winch] One of the entities does not exist.")
        return
    end

    ropeData.heli = heli
    ropeData.basket = basket

    local pos = GetEntityCoords(heli)
    RopeLoadTextures()
    local rope = AddRope(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, ropeData.maxLength, 4, ropeData.maxLength, 0.25, 0.0, false, true, false, 5.0, false, 0)
    ropeData.rope = rope

    local heliBone = GetEntityBoneIndexByName(heli, "extra_5")
    local basketBone = GetEntityBoneIndexByName(basket, "hook_attach")

    local pos1 = GetWorldPositionOfEntityBone(heli, heliBone)
    local pos2 = GetWorldPositionOfEntityBone(basket, basketBone)

    AttachEntitiesToRope(rope, heli, basket, pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, ropeData.length, false, false, nil, nil)
    ActivatePhysics(basket)
    StartRopeWinding(rope)
    RopeForceLength(rope, ropeData.length)

    print("[Winch] Rope attached between heli and basket.")
end)

-- Smooth Rope Length Controls with delta time
CreateThread(function()
    local prevTime = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local delta = (now - prevTime) / 1000.0
        prevTime = now

        if ropeData.rope and ropeData.heli and ropeData.basket then
            local isUp = IsControlPressed(0, 172)
            local isDown = IsControlPressed(0, 173)

            if isDown and ropeData.length < ropeData.maxLength then
                ropeData.length = math.min(ropeData.length + (ropeData.speedPerSecond * delta), ropeData.maxLength)
                StopRopeWinding(ropeData.rope)
                StartRopeUnwindingFront(ropeData.rope)
                RopeForceLength(ropeData.rope, ropeData.length)
            elseif isUp and ropeData.length > ropeData.minLength then
                ropeData.length = math.max(ropeData.length - (ropeData.speedPerSecond * delta), ropeData.minLength)
                StopRopeUnwindingFront(ropeData.rope)
                StartRopeWinding(ropeData.rope)
                RopeForceLength(ropeData.rope, ropeData.length)
            end
        else
            Wait(1000)
        end
        Wait(0)
    end
end)

RegisterNetEvent("rescue:client:warpFromBasket", function(heliNetId)
    local heli = NetworkGetEntityFromNetworkId(heliNetId)
    if not DoesEntityExist(heli) then return end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    DetachEntity(ped, true, true)
    ClearPedTasksImmediately(ped)

    -- Try seat 8 first
    if IsVehicleSeatFree(heli, 8) then
        TaskWarpPedIntoVehicle(ped, heli, 8)
    else
        local placed = false
        local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(heli))
        for seat = 0, maxSeats - 1 do
            if IsVehicleSeatFree(heli, seat) then
                TaskWarpPedIntoVehicle(ped, heli, seat)
                placed = true
                break
            end
        end
        if not placed then
            print("⚠️ No free seats in heli")
        end
    end
end)