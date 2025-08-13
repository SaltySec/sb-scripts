local QBCore = exports['qb-core']:GetCoreObject()
local basketModel = `rescue_basket`
local animThread = nil

local function isBasketOccupied(entity)
    local players = GetActivePlayers()
    for _, ply in ipairs(players) do
        local ped = GetPlayerPed(ply)
        if IsEntityAttachedToEntity(ped, entity) then
            return true
        end
    end
    return false
end

RegisterCommand("baskettestanim", function()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    Wait(100)

    local dict = "veh@low@front_ps@base"
    local clip = "lean_forward_idle"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end

    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 1, 0, false, false, false)
end)

RegisterCommand("spawnbasket", function()
    RequestModel(basketModel)
    while not HasModelLoaded(basketModel) do Wait(10) end

    local coords = GetEntityCoords(PlayerPedId())
    local basket = CreateObject(basketModel, coords.x + 1.0, coords.y, coords.z, true, true, true)
    PlaceObjectOnGroundProperly(basket)
    SetEntityAsMissionEntity(basket, true, true)

    print("✅ Basket spawned.")
end, false)

RegisterCommand("deletebaskets", function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == basketModel then
            local dist = #(GetEntityCoords(obj) - playerCoords)
            if dist < 50.0 then
                DeleteEntity(obj)
            end
        end
    end
    print("🗑️ Deleted nearby baskets.")
end, false)

CreateThread(function()
    exports.ox_target:addGlobalObject({
        {
            name = 'putInBasket',
            icon = 'fas fa-user-plus',
            label = 'Put Nearest Person In Basket',
            groups = { 'fire', 'police' },
            canInteract = function(entity)
                return DoesEntityExist(entity)
                    and pcall(GetEntityModel, entity)
                    and GetEntityModel(entity) == basketModel
                    and not isBasketOccupied(entity)
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                TriggerServerEvent('rescuebasket:putInBasket', netId)
            end
        },
        {
            name = 'getInBasket',
            icon = 'fas fa-sign-in-alt',
            label = 'Get Into Basket',
            groups = { 'fire', 'police' },
            canInteract = function(entity)
                return DoesEntityExist(entity)
                    and pcall(GetEntityModel, entity)
                    and GetEntityModel(entity) == basketModel
                    and not isBasketOccupied(entity)
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                TriggerServerEvent('rescuebasket:getInBasket', netId)
            end
        },
        {
            name = 'removeFromBasket',
            icon = 'fas fa-user-minus',
            label = 'Remove Person From Basket',
            groups = { 'fire', 'police' },
            canInteract = function(entity)
                return DoesEntityExist(entity)
                    and pcall(GetEntityModel, entity)
                    and GetEntityModel(entity) == basketModel
                    and isBasketOccupied(entity)
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                TriggerServerEvent('rescuebasket:removeFromBasket', netId)
            end
        },
        {
            name = 'getOutBasket',
            icon = 'fas fa-sign-out-alt',
            label = 'Get Out of Basket',
            groups = { 'fire', 'police' },
            canInteract = function(entity)
                return DoesEntityExist(entity)
                    and pcall(GetEntityModel, entity)
                    and GetEntityModel(entity) == basketModel
                    and IsEntityAttachedToEntity(PlayerPedId(), entity)
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                TriggerServerEvent('rescuebasket:getOutOfBasket', netId)
            end
        }
    })
    print("✅ ox_target: global basket interactions with safe model checks loaded.")
end)

RegisterNetEvent("rescuebasket:client:attachToBasket", function(basketNetId)
    local ped = PlayerPedId()
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not DoesEntityExist(basket) then return end

    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, GetEntityCoords(basket))
    Wait(100)

    AttachEntityToEntity(ped, basket, 0, 0.0, 0.14, -0.3, 0.0, 0.0, 180.0, false, false, true, false, 2, true)

    local dict = "veh@low@front_ps@base"
    local clip = "lean_forward_idle"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end

    animThread = CreateThread(function()
        while IsEntityAttachedToEntity(ped, basket) do
            if not IsEntityPlayingAnim(ped, dict, clip, 3) then
                TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            Wait(1000)
        end
    end)

    FreezeEntityPosition(ped, true)

    local playerServerId = GetPlayerServerId(PlayerId())
    Entity(basket).state:set('basketOccupant', playerServerId, true)

end)

RegisterNetEvent("rescuebasket:client:detachFromBasket", function(basketNetId)
    local ped = PlayerPedId()
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not DoesEntityExist(basket) then return end

    FreezeEntityPosition(ped, false)
    DetachEntity(ped, true, true)
    ClearPedTasksImmediately(ped)

    animThread = nil  -- just clear the reference

    local offset = GetOffsetFromEntityInWorldCoords(basket, 0.0, 2.0, 0.0)
    SetEntityCoords(ped, offset.x, offset.y, offset.z + 0.05, false, false, false, true)

    Entity(basket).state:set('basketOccupant', nil, true)

end)