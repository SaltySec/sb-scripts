Config = {}

-- Name shown at the top of the shop UI
Config.ShopLabel = 'HoodDoc Supplies'

-- Lock to this job (must match your framework job name)
Config.Job = 'hooddoc'

-- Shop position (your vec4)
Config.ShopLocation = vec4(956.6049, -1139.4927, 26.7588, 0)

-- ox_target zone size & interaction distance
Config.ZoneSize = vec3(1, 1, 1)   -- length, width, height
Config.ZoneHeading = 0.0
Config.InteractDistance = 2.0            -- how close the player must be to interact

-- Show the target option even for non-hooddoc players?
-- (Server still enforces access; this just hides the option for others.)
Config.HideForNonJob = true

-- If true, create an ox_target zone to open the shop (no blip, no marker).
-- If false, you can still open the shop via command /hooddocshop (for testing).
Config.UseOxTarget = true

-- Currency for all items unless overridden per item. 'money' or any ox_inventory item (e.g. 'black_money')
Config.DefaultCurrency = 'money'

-- INVENTORY: add your items here. Omit 'count' for unlimited stock.
-- price = per-unit cost. Optional: metadata, currency (override), grade requirement (see notes below).
-- Example entries are just placeholders — replace with your actual item names.
Config.Items = {
    { name = 'bandage',                        price = 15 },      -- unlimited
    { name = 'painkillers',                    price = 30 },     -- unlimited
    { name = 'quick_clot',                     price = 45 },
    { name = 'packing_bandage',                price = 30 },
    { name = 'sewing_kit',                     price = 50 },
    { name = 'legsplint',                     price = 100 },
    { name = 'armsplint',                     price = 100 },
    { name = 'perc30',                          price = 40 },
    { name = 'perc10',                         price = 10 },
    { name = 'perc5',                          price = 5 },
    { name = 'vic10',                          price = 15 },
    { name = 'vic5',                           price = 7 },
    { name = 'narcan',                           price = 7 },

}

-- If you prefer to let ox_inventory place its internal “location” (no target),
-- set this to true. (We still add our own target by default which is invisible.)
Config.RegisterAsLocation = false
