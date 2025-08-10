local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("rescuebasket:putInBasket", function(basketNetId)
    local src = source
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not basket then return end

    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)

    -- Find nearest player within range
    local players = QBCore.Functions.GetPlayers()
    local nearest = nil
    local minDist = 3.0

    for _, id in pairs(players) do
        if id ~= src then
            local ped = GetPlayerPed(id)
            local dist = #(GetEntityCoords(ped) - coords)
            if dist < minDist then
                nearest = id
                minDist = dist
            end
        end
    end

    if nearest then
        -- 🔹 Set statebag to nearest player's server ID
        Entity(basket).state:set('basketOccupant', nearest, true)

        TriggerClientEvent("rescuebasket:client:attachToBasket", nearest, basketNetId)
    else
        TriggerClientEvent('QBCore:Notify', src, "No one nearby to place in basket", "error")
    end
end)

RegisterNetEvent("rescuebasket:getInBasket", function(basketNetId)
    local src = source
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not basket then return end

    -- 🔹 Set statebag to this player's server ID
    Entity(basket).state:set('basketOccupant', src, true)

    TriggerClientEvent("rescuebasket:client:attachToBasket", src, basketNetId)
end)

RegisterNetEvent("rescuebasket:removeFromBasket", function(basketNetId)
    local src = source
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not basket then return end

    -- 🔹 Clear statebag when removing
    Entity(basket).state:set('basketOccupant', nil, true)

    local players = QBCore.Functions.GetPlayers()
    for _, id in pairs(players) do
        TriggerClientEvent("rescuebasket:client:detachFromBasket", id, basketNetId)
    end
end)

RegisterNetEvent("rescuebasket:getOutOfBasket", function(basketNetId)
    local src = source
    local basket = NetworkGetEntityFromNetworkId(basketNetId)
    if not basket then return end

    -- 🔹 Clear statebag when they get out
    Entity(basket).state:set('basketOccupant', nil, true)

    TriggerClientEvent("rescuebasket:client:detachFromBasket", src, basketNetId)
end)
