local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("scba:syncToggle", function()
    local src = source
    TriggerClientEvent("scba:playToggle", src)
end)
