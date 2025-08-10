local QBCore = exports['qb-core']:GetCoreObject()
Config = Config or {}

RegisterServerEvent("teleportcircle:attemptTeleport")
AddEventHandler("teleportcircle:attemptTeleport", function(index)
    local src = source
    local teleport = Config.Teleports and Config.Teleports[index]
    if not teleport then
        print("[TeleportCircle] Invalid teleport index or config not found!")
        return
    end

    local players = QBCore.Functions.GetPlayers()
    local fromPos = GetEntityCoords(GetPlayerPed(src))
    local toPos = teleport.outPos
    local radius = teleport.radius

    for _, pid in pairs(players) do
        local ped = GetPlayerPed(pid)
        local coords = GetEntityCoords(ped)

        if #(coords - fromPos) <= radius then
            TriggerClientEvent("teleportcircle:receiveTeleportTarget", pid, toPos)
        end
    end
end)
