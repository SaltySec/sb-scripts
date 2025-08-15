-- server.lua
-- oxmysql-backed persistence for installed neon sides by plate

---------------------------------------------------------------------
-- Debug helper
---------------------------------------------------------------------
local function dbg(fmt, ...)
    if Config.Debug then
        print(('[sb_neon] ' .. fmt):format(...))
    end
end

---------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------
local function normPlate(plate)
    if not plate then return nil end
    plate = plate:gsub('^%s*(.-)%s*$', '%1')
    if plate == '' then return nil end
    return plate:upper()
end

local function toBool(v)
    return v == true or v == 1 or v == "1" or v == "true"
end

local function anyTrueSides(s)
    if type(s) ~= 'table' then return false end
    for i=0,3 do
        if toBool(s[i]) then return true end
    end
    return false
end

local function rowToSides(row)
    if not row then return nil end
    return {
        [0] = toBool(row.left_side),
        [1] = toBool(row.right_side),
        [2] = toBool(row.front_side),
        [3] = toBool(row.back_side),
    }
end

local function sidesToRow(s)
    return {
        left_side  = toBool(s[0]) and 1 or 0,
        right_side = toBool(s[1]) and 1 or 0,
        front_side = toBool(s[2]) and 1 or 0,
        back_side  = toBool(s[3]) and 1 or 0,
    }
end

---------------------------------------------------------------------
-- DB access (oxmysql)
---------------------------------------------------------------------
local function loadInstallDB(plate)
    local p = normPlate(plate); if not p then return nil end
    dbg('loadInstallDB: %s', p)
    local row = MySQL.single.await(
        'SELECT left_side, right_side, front_side, back_side FROM sb_neon_installs WHERE plate = ?',
        { p }
    )
    return rowToSides(row)
end

local function saveInstallDB(plate, sides)
    local p = normPlate(plate); if not p then return end
    if not anyTrueSides(sides) then
        dbg('saveInstallDB: %s -> no true sides, skipping persist', p)
        return
    end
    local row = sidesToRow(sides)
    dbg('saveInstallDB: %s -> L=%d R=%d F=%d B=%d', p, row.left_side, row.right_side, row.front_side, row.back_side)

    MySQL.query.await([[
        INSERT INTO sb_neon_installs (plate, left_side, right_side, front_side, back_side)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            left_side=VALUES(left_side),
            right_side=VALUES(right_side),
            front_side=VALUES(front_side),
            back_side=VALUES(back_side)
    ]], { p, row.left_side, row.right_side, row.front_side, row.back_side })
end

---------------------------------------------------------------------
-- Cache to avoid repeated SELECTs
---------------------------------------------------------------------
local cache = {}
local CACHE_TTL = 5

local function getCached(plate)
    local e = cache[plate]
    if e and (os.time() - e.t) <= CACHE_TTL then return e.sides end
    return nil
end

local function putCached(plate, sides)
    cache[plate] = { sides = sides, t = os.time() }
end

---------------------------------------------------------------------
-- Net events
---------------------------------------------------------------------
RegisterNetEvent('sb_neontoggle:requestInstall', function(plate, bootstrapSides)
    local src = source
    local p = normPlate(plate)

    if not p then
        TriggerClientEvent('sb_neontoggle:setInstall', src, plate, { [0]=false,[1]=false,[2]=false,[3]=false })
        return
    end

    local c = getCached(p)
    if c then
        TriggerClientEvent('sb_neontoggle:setInstall', src, p, c)
        return
    end

    local sides = loadInstallDB(p)

    if not sides and anyTrueSides(bootstrapSides) then
        sides = {
            [0] = toBool(bootstrapSides[0]),
            [1] = toBool(bootstrapSides[1]),
            [2] = toBool(bootstrapSides[2]),
            [3] = toBool(bootstrapSides[3]),
        }
        saveInstallDB(p, sides)
    end

    sides = sides or { [0]=false,[1]=false,[2]=false,[3]=false }
    putCached(p, sides)
    TriggerClientEvent('sb_neontoggle:setInstall', src, p, sides)
end)

RegisterNetEvent('sb_neontoggle:saveInstall', function(plate, sides)
    local p = normPlate(plate)
    if not p or type(sides) ~= 'table' then return end

    local norm = {
        [0] = toBool(sides[0]),
        [1] = toBool(sides[1]),
        [2] = toBool(sides[2]),
        [3] = toBool(sides[3]),
    }
    saveInstallDB(p, norm)
    putCached(p, norm)
end)
