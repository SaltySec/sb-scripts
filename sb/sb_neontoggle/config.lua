Config = Config or {}


-- Toggle debug logging for sb_neontoggle
Config.Debug = false

-- Default keybind to toggle ALL installed sides
Config.DefaultKey = 'U'

-- If true and QBCore is running, use QBCore.Functions.Notify; otherwise chat message
Config.UseQBCoreNotifyIfPresent = true

-- Optional: enable an admin command to set/clear installs by plate
Config.EnableAdminCommands = true         -- /neon_set and /neon_clear
Config.AdminAce = 'command.neonadmin'     -- give_ace group.admin command.neonadmin allow
