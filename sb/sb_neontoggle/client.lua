-- client.lua (plate-keyed cache)
local QBCore = nil
if Config.UseQBCoreNotifyIfPresent then
    pcall(function()
        QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
    end)
end

-- Cache now keyed by PLATE string, not vehicle handle.
local neonCache = {}            -- [plate] = { [0]=L, [1]=R, [2]=F, [3]=B }
local lastDriverVeh, lastPlate = nil, nil

-- ===== Utilities =====
local function notify(msg, typ)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, typ or 'primary', 3000)
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

local function getPlate(veh)
    if veh == 0 then return nil end
    local plate = GetVehicleNumberPlateText(veh)
    if not plate or plate == '' then return nil end
    plate = plate:gsub('^%s*(.-)%s*$', '%1'):upper()
    return plate
end

-- indices: 0=Left, 1=Right, 2=Front, 3=Back
local function isNeonOn(vehicle, index)
    return IsVehicleNeonLightEnabled(vehicle, index)
end
local function setNeon(vehicle, index, toggle)
    SetVehicleNeonLightEnabled(vehicle, index, toggle)
end

-- Bootstrap sources
local function readInstalledFromProps(veh)
    local installed = { [0]=false, [1]=false, [2]=false, [3]=false }
    if QBCore and QBCore.Functions and QBCore.Functions.GetVehicleProperties then
        local ok, props = pcall(QBCore.Functions.GetVehicleProperties, veh)
        if ok and props then
            local ne = props.neonEnabled
            if type(ne) == 'table' then
                installed[0] = not not ne[1]
                installed[1] = not not ne[2]
                installed[2] = not not ne[3]
                installed[3] = not not ne[4]
            end
        end
    end
    return installed
end

local function readInstalledFromNatives(veh)
    return {
        [0] = IsVehicleNeonLightEnabled(veh, 0),
        [1] = IsVehicleNeonLightEnabled(veh, 1),
        [2] = IsVehicleNeonLightEnabled(veh, 2),
        [3] = IsVehicleNeonLightEnabled(veh, 3),
    }
end

local function orSides(a, b)
    local out = { [0]=false, [1]=false, [2]=false, [3]=false }
    if type(a) == 'table' then for i=0,3 do out[i] = out[i] or (a[i] == true) end end
    if type(b) == 'table' then for i=0,3 do out[i] = out[i] or (b[i] == true) end end
    return out
end

-- Plate-keyed cache helpers
local function setInstalled(plate, sides)
    if not plate then return end
    neonCache[plate] = sides
    -- also expose on the entity state for other scripts, if you want:
    local veh = lastDriverVeh
    if veh and getPlate(veh) == plate then
        local state = Entity(veh).state
        if state then state:set('sb_neon_installed', sides, true) end
    end
end

local function getInstalledNeonSides(plate)
    return (plate and neonCache[plate]) or { [0]=false, [1]=false, [2]=false, [3]=false }
end

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

-- ===== Seat entry: seed cache immediately, then ask server
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            if veh ~= lastDriverVeh then
                lastDriverVeh = veh
                local plate = getPlate(veh)
                lastPlate = plate
                if plate then
                    local bootstrap = orSides(readInstalledFromProps(veh), readInstalledFromNatives(veh))
                    setInstalled(plate, bootstrap)  -- works instantly
                    TriggerServerEvent('sb_neontoggle:requestInstall', plate, bootstrap) -- canonical
                end
            end
        else
            lastDriverVeh, lastPlate = nil, nil
        end
    end
end)

-- Server returns canonical record
RegisterNetEvent('sb_neontoggle:setInstall', function(plate, sides)
    if not plate or plate ~= (lastPlate or '') then return end
    setInstalled(plate, {
        [0] = not not sides[0],
        [1] = not not sides[1],
        [2] = not not sides[2],
        [3] = not not sides[3],
    })
end)

-- External hook to set installs (also persists via server)
RegisterNetEvent('sb_neontoggle:refreshInstall', function(payload)
    local veh = getPlayerVehicleIfDriver()
    if not veh or type(payload) ~= 'table' then return end
    local plate = getPlate(veh); if not plate then return end
    local installed = {
        [0] = not not payload.left,
        [1] = not not payload.right,
        [2] = not not payload.front,
        [3] = not not payload.back,
    }
    setInstalled(plate, installed)
    TriggerServerEvent('sb_neontoggle:saveInstall', plate, installed)
end)

-- ===== Toggle logic (installed-only)
local function toggleNeonAllInstalled()
    local veh, err = getPlayerVehicleIfDriver()
    if not veh then return notify(err or 'You must be in a vehicle.') end
    local plate = getPlate(veh); if not plate then return notify('Could not read plate.', 'error') end

    local installed = getInstalledNeonSides(plate)
    if not anyInstalled(installed) then
        -- tiny debug to help you verify state
        notify(('No underglow installed. (dbg L=%s R=%s F=%s B=%s)')
            :format(tostring(installed[0]), tostring(installed[1]), tostring(installed[2]), tostring(installed[3])), 'error')
        return
    end

    local anyOn = anyInstalledNeonCurrentlyOn(veh, installed)
    if anyOn then
        local turned = 0
        for i=0,3 do
            if installed[i] and isNeonOn(veh, i) then
                setNeon(veh, i, false); turned = turned + 1
            end
        end
        notify(('Underglow OFF (%d sides).'):format(turned))
    else
        local turned = 0
        for i=0,3 do
            if installed[i] then setNeon(veh, i, true); turned = turned + 1 end
        end
        notify(('Underglow ON (%d sides).'):format(turned))
    end
end

local function toggleNeonSideInstalled(sideIndex, label)
    local veh, err = getPlayerVehicleIfDriver()
    if not veh then return notify(err or 'You must be in a vehicle.') end
    local plate = getPlate(veh); if not plate then return notify('Could not read plate.', 'error') end

    local installed = getInstalledNeonSides(plate)
    if not installed[sideIndex] then
        return notify(('This vehicle does not have %s underglow installed.'):format(label), 'error')
    end

    local currentlyOn = isNeonOn(veh, sideIndex)
    setNeon(veh, sideIndex, not currentlyOn)
    notify(('Underglow %s: %s'):format(label, (not currentlyOn) and 'ON' or 'OFF'))
end

-- ===== Commands & Keybinds
RegisterCommand('+neonToggleAll', function() toggleNeonAllInstalled() end, false)
RegisterCommand('-neonToggleAll', function() end, false)

local defaultKey = (Config and Config.DefaultKey) or 'U'
RegisterKeyMapping('+neonToggleAll', 'Toggle vehicle underglow (installed sides only)', 'keyboard', defaultKey)

RegisterCommand('neon_front', function() toggleNeonSideInstalled(2, 'Front') end, false)
RegisterCommand('neon_back',  function() toggleNeonSideInstalled(3, 'Back')  end, false)
RegisterCommand('neon_left',  function() toggleNeonSideInstalled(0, 'Left')  end, false)
RegisterCommand('neon_right', function() toggleNeonSideInstalled(1, 'Right') end, false)

RegisterCommand('neon', toggleNeonAllInstalled, false)
RegisterCommand('neon_all', toggleNeonAllInstalled, false)

-- Manual seed (uses plate helper)
RegisterCommand('neon_seed', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false); if veh == 0 then return end
    local plate = getPlate(veh); if not plate then return end
    local bootstrap = readInstalledFromNatives(veh)
    setInstalled(plate, bootstrap) -- keep local in sync
    TriggerServerEvent('sb_neontoggle:saveInstall', plate, bootstrap)
    print('[sb_neon] neon_seed sent', plate, bootstrap[0], bootstrap[1], bootstrap[2], bootstrap[3])
end, false)
