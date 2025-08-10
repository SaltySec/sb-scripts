RegisterNetEvent("rescue:server:warpFromBasket", function(targetServerId, heliNetId)
    TriggerClientEvent("rescue:client:warpFromBasket", targetServerId, heliNetId)
end)
