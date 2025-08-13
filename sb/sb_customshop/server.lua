local shopType = 'hooddoc_shop'

-- Wait for ox_inventory to be ready before registering the shop
CreateThread(function()
    -- Defensive wait to ensure exports are available on restart
    while not exports.ox_inventory do Wait(100) end

    local items = {}

    -- Normalize items for ox_inventory (copying what the shops module expects)
    for i, slot in ipairs(Config.Items) do
        items[i] = {
            name = slot.name,
            price = slot.price or 0,
            count = slot.count,           -- nil => infinite
            metadata = slot.metadata,     -- optional
            currency = slot.currency or Config.DefaultCurrency,
            grade = slot.grade,           -- optional (number or {numbers})
        }
    end

    -- Build locations/targets table for ox_inventory’s shops module
    local locationsOrTargets
    if Config.RegisterAsLocation then
        -- As a simple location (distance check only; we also supply coords for server-side validation)
        locationsOrTargets = {
            vec3(Config.ShopLocation.x, Config.ShopLocation.y, Config.ShopLocation.z)
        }
    else
        -- As a target “box” (the shops module reads this shape if shared.target=true)
        local minZ = Config.ShopLocation.z - (Config.ZoneSize.z / 2)
        local maxZ = Config.ShopLocation.z + (Config.ZoneSize.z / 2)
        locationsOrTargets = {
            [1] = {
                loc = vec3(Config.ShopLocation.x, Config.ShopLocation.y, Config.ShopLocation.z),
                length = Config.ZoneSize.x,
                width  = Config.ZoneSize.y,
                heading = Config.ZoneHeading,
                minZ = minZ,
                maxZ = maxZ,
                distance = Config.InteractDistance,
            }
        }
    end

    -- Register the shop with ox_inventory
    -- groups = { [job] = minGrade } → any grade >= minGrade is allowed
    exports.ox_inventory:RegisterShop(shopType, {
        name = Config.ShopLabel,
        groups = { [Config.Job] = 0 },
        inventory = items,
        -- The shops module auto-picks 'targets' vs 'locations' using its shared.target flag.
        -- We can safely provide both keys; it’ll read the one it wants.
        targets = locationsOrTargets,
        locations = locationsOrTargets,
    })

    print(('[sb_hooddocshop] Registered shop "%s" for job "%s" with %d items.')
        :format(Config.ShopLabel, Config.Job, #items))
end)
