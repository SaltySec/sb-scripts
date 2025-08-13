local QBCore = exports['qb-core']:GetCoreObject()

local function registerDrugItem(itemName)
    QBCore.Functions.CreateUseableItem(itemName, function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if Player.Functions.RemoveItem(itemName, 1) then
            TriggerClientEvent('sb_drugs:usePill', source, itemName)
        end
    end)
end
for itemName in pairs(Config.Drugs) do registerDrugItem(itemName) end

QBCore.Functions.CreateUseableItem(Config.NarcanItem, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if Player.Functions.RemoveItem(Config.NarcanItem, 1) then
        TriggerClientEvent('sb_drugs:useNarcan', source)
    end
end)

RegisterNetEvent('sb_drugs:tryAdministerNarcan', function(targetId)
    local src = source
    if not targetId or src == targetId then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.Functions.GetItemByName(Config.NarcanItem) then
            if Player.Functions.RemoveItem(Config.NarcanItem, 1) then
                TriggerClientEvent('sb_drugs:useNarcan', src)
                TriggerClientEvent('sb_drugs:playAdminAnim', src)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, ('You do not have %s.'):format(Config.NarcanLabel), 'error', 4500)
        end
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Player or not Target then return end

    local item = Player.Functions.GetItemByName(Config.NarcanItem)
    if not item or (item.amount or 0) < 1 then
        TriggerClientEvent('QBCore:Notify', src, ('You do not have %s.'):format(Config.NarcanLabel), 'error', 4500)
        return
    end

    if Player.Functions.RemoveItem(Config.NarcanItem, 1) then
        TriggerClientEvent('sb_drugs:playAdminAnim', src)
        TriggerClientEvent('sb_drugs:useNarcan', Target.PlayerData.source)
        TriggerClientEvent('QBCore:Notify', src, ('You administered %s.'):format(Config.NarcanLabel), 'success', 3500)
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('%s was administered to you.'):format(Config.NarcanLabel), 'primary', 3500)
    end
end)

lib.callback.register('sb_drugs:isOverdosing', function(source)
    return GlobalState['sb_drugs_od_' .. tostring(source)] == true
end)
RegisterNetEvent('sb_drugs:setODState', function(isOD)
    local src = source
    GlobalState['sb_drugs_od_' .. tostring(src)] = isOD and true or false
end)
