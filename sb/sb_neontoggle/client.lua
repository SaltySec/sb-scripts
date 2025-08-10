-- client.lua
local QBCore = nil
if Config.UseQBCoreNotifyIfPresent then
    pcall(function()
        QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
    end)
end

-- Cache for installed neon sides per-vehicle
-- Using weak keys so cache doesn’t grow forever if entities despawn
local neonCache = setmetatable({}, { __mode = 'k' })

-- ===== Utilities =====
local function notify(msg, typ)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, typ or 'primary', 3500)
    else
        TriggerEvent('chat:addMessage', { args = { '^3Neon', msg } })
    end
end

local function getPlayerVehicleIfDriver()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return nil, 'You must be in the driver seat.'
    end
    return veh
end

-- indices: 0=Left, 1=Right, 2=Front, 3=Back
local function isNeonOn(vehicle, index)
    return IsVehicleNeonLightEnabled(vehicle, index)
end

local function setNeon(vehicle, index, toggle)
    SetVehicleNeonLightEnabled(vehicle, index, toggle)
end

local function refreshInstalledNeons()
    local veh, err = getPlayerVehicleIfDriver()
    if not veh then return end

    local installed = { [0]=false, [1]=false, [2]=false, [3]=false }

    if QBCore and QBCore.Functions and QBCore.Functions.GetVehicleProperties then
        local ok, props = pcall(QBCore.Functions.GetVehicleProperties, veh)
        if ok and props then
            local ne = props.neonEnabled
            if type(ne) == 'table' then
                installed[0] = not not ne[1]   -- Left
                installed[1] = not not ne[2]   -- Right
                installed[2] = not not ne[3]   -- Front
                installed[3] = not not ne[4]   -- Back
            end
        end
    end

    -- Save in cache & statebag
    neonCache[veh] = installed
    local state = Entity(veh).state
    if state then state:set('sb_neon_installed', installed, true) end
end

-- Updated getInstalledNeonSides to use our cache first
local function getInstalledNeonSides(vehicle)
    if neonCache[vehicle] then
        return neonCache[vehicle]
    end
    refreshInstalledNeons()
    return neonCache[vehicle] or { [0]=false, [1]=false, [2]=false, [3]=false }
end

-- Auto-refresh every 30 seconds for the player's vehicle
CreateThread(function()
    while true do
        Wait(30000) -- 30 seconds
        refreshInstalledNeons()
    end
end)

-- Manual event trigger if you ever want to force-refresh from other scripts
RegisterNetEvent('sb_neontoggle:refresh', function()
    refreshInstalledNeons()
end)

local function anyInstalled(installed)
    for i=0,3 do if installed[i] then return true end end
    return false
end

local function anyInstalledNeonCurrentlyOn(vehicle, installed)
    for i=0,3 do
        if installed[i] and isNeonOn(vehicle, i) then
            return true
        end
    end
    return false
end

-- ===== Toggling logic (installed-only) =====
local function toggleNeonAllInstalled()
    local veh, err = getPlayerVehicleIfDriver()
    if not veh then return notify(err or 'You must be in a vehicle.') end

    local installed = getInstalledNeonSides(veh)
    if not anyInstalled(installed) then
        return notify('This vehicle has no underglow installed.', 'error')
    end

    local anyOn = anyInstalledNeonCurrentlyOn(veh, installed)
    if anyOn then
        -- Turn OFF any installed sides that are currently on
        local turned = 0
        for i=0,3 do
            if installed[i] and isNeonOn(veh, i) then
                setNeon(veh, i, false)
                turned = turned + 1
            end
        end
        notify(('Underglow OFF (%d sides).'):format(turned))
    else
        -- Turn ON all installed sides
        local turned = 0
        for i=0,3 do
            if installed[i] then
                setNeon(veh, i, true)
                turnedOn = true
                turned = turned + 1
            end
        end
        notify(('Underglow ON (%d sides).'):format(turned))
    end
end

local function toggleNeonSideInstalled(sideIndex, label)
    local veh, err = getPlayerVehicleIfDriver()
    if not veh then return notify(err or 'You must be in a vehicle.') end

    local installed = getInstalledNeonSides(veh)
    if not installed[sideIndex] then
        return notify(('This vehicle does not have %s underglow installed.'):format(label), 'error')
    end

    local currentlyOn = isNeonOn(veh, sideIndex)
    setNeon(veh, sideIndex, not currentlyOn)
    notify(('Underglow %s: %s'):format(label, (not currentlyOn) and 'ON' or 'OFF'))
end

-- ===== Commands & Keybinds =====
RegisterCommand('+neonToggleAll', function() toggleNeonAllInstalled() end, false)
RegisterCommand('-neonToggleAll', function() end, false) -- keyup noop

-- Use configured default key if present, else fallback to 'U'
local defaultKey = (Config and Config.DefaultKey) or 'U'
RegisterKeyMapping('+neonToggleAll', 'Toggle vehicle underglow (installed sides only)', 'keyboard', defaultKey)

-- Per-side commands, installed-aware
RegisterCommand('neon_front', function() toggleNeonSideInstalled(2, 'Front') end, false)
RegisterCommand('neon_back',  function() toggleNeonSideInstalled(3, 'Back')  end, false)
RegisterCommand('neon_left',  function() toggleNeonSideInstalled(0, 'Left')  end, false)
RegisterCommand('neon_right', function() toggleNeonSideInstalled(1, 'Right') end, false)

-- Optional chat aliases
RegisterCommand('neon', toggleNeonAllInstalled, false)
RegisterCommand('neon_all', toggleNeonAllInstalled, false)
