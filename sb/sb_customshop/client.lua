local shopType = 'hooddoc_shop'

-- Helper: open the shop UI
local function OpenHoodDocShop()
    -- Pass the server-side shop type and id (we use ID=1 since we have one location)
    exports.ox_inventory:openInventory('shop', { type = shopType, id = 1 })
end

-- Optional: hide target for non-job users (server still blocks purchase)
local function PlayerIsHoodDoc()
    if not Config.HideForNonJob then return true end

    -- Try QBCore/QBox (safe-guarded)
    local ok, QBCore = pcall(function()
        return exports['qb-core'] and exports['qb-core']:GetCoreObject()
    end)
    if ok and QBCore and QBCore.Functions and QBCore.Functions.GetPlayerData then
        local data = QBCore.Functions.GetPlayerData()
        return data and data.job and data.job.name == Config.Job
    end

    -- Try ox_core (if you use it)
    if GetResourceState('ox_core') == 'started' then
        local playerData = LocalPlayer and LocalPlayer.state
        local job = playerData and playerData.job
        if type(job) == 'table' and job.name == Config.Job then return true end
        if type(job) == 'string' and job == Config.Job then return true end
    end

    -- If we can’t determine job on client, just show it (server enforces anyway)
    return true
end

-- Create ox_target zone (invisible) with an interaction to open the shop
CreateThread(function()
    if not Config.UseOxTarget or GetResourceState('ox_target') ~= 'started' then return end

    local loc = Config.ShopLocation
    local size = Config.ZoneSize
    local heading = Config.ZoneHeading
    local minZ = loc.z - (size.z / 2)
    local maxZ = loc.z + (size.z / 2)

    exports.ox_target:addBoxZone({
        coords = vec3(loc.x, loc.y, loc.z),
        size = vec3(size.x, size.y, size.z),
        rotation = heading,
        debug = false, -- set true to visualize while testing
        options = {
            {
                name = 'hooddoc_shop_open',
                icon = 'fa-solid fa-briefcase-medical',
                label = ('Open %s'):format(Config.ShopLabel),
                distance = Config.InteractDistance,
                canInteract = function(entity, distance, coords, name)
                    return PlayerIsHoodDoc()
                end,
                onSelect = function(data)
                    OpenHoodDocShop()
                end
            }
        }
    })
end)

-- Debug / fallback command (no blip/marker; useful if you disable ox_target)
RegisterCommand('hooddocshop', function()
    OpenHoodDocShop()
end, false)
