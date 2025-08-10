Config = {}

-- === SCBA Mask Variants ===
-- Make sure these match your actual EUP component / drawable / texture values.
Config.MaskOn  = { component = 8, drawable = 244, texture = 0 }  -- Example ON
Config.MaskOff = { component = 8, drawable = 243, texture = 0 }  -- Example OFF

-- === Helmet Props (only these will be removed/restored) ===
-- These are the prop IDs for firefighter helmets (prop slot 0)
Config.AllowedHelmetProps = { 272, 273 }

-- === Animations ===
Config.Animations = {
    removeHelmet = { dict = "missheist_agency2ahelmet", name = "take_off_helmet_stand", duration = 1500 }, --WORKING
    putHelmet    = { dict = "veh@common@fp_helmet@", name = "put_on_helmet", duration = 1500 },
    removeMask   = { dict = "missfbi4", name = "takeoff_mask", duration = 1500 },  --
    putMask      = { dict = "mp_masks@standard_car@rds@", name = "put_on_mask", duration = 1500 }
}

-- === Notifications ===
Config.Notify = {
    PutOn   = "SCBA mask put on.",
    TakeOff = "SCBA mask removed.",
    NoSCBA  = "You do not have an SCBA equipped!"
}
