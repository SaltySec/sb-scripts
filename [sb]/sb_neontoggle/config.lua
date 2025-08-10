Config = {}

-- Default keybind for toggling all equipped neon sides.
-- Players can change this in GTA V key bindings: Settings → Key Bindings → FiveM
Config.DefaultKey = 'U'   -- change if you want

-- If no neon is currently ON and you press the toggle, we need to know what to turn ON.
-- This is your fallback “equipped” profile. Set true/false per side.
-- Order: [0]=Left, [1]=Right, [2]=Front, [3]=Back
Config.DefaultSidesOn = {
    [0] = true,  -- Left
    [1] = true,  -- Right
    [2] = true,  -- Front
    [3] = true,  -- Back
}

-- Use QBCore notify when available, else fallback to chat message.
Config.UseQBCoreNotifyIfPresent = true
