Config = {}

Config.Teleports = {
    {
        inPos = vector3(339.9272, -584.4135, 74.1656),-- Teleports from Helipad Elevator to Lobby
        outPos = vector4(307.6295, -591.1017, 43.2919, 245.5580),
        radius = 2.0
    },
    {
        inPos = vector3(324.7001, -598.4960, 43.2918), -- Teleports from Lobby elevator to Helipad Elevator
        outPos = vector4(339.9272, -584.4135, 74.1656, 251.9156),
        radius = 1.25
    },
}
Config.FadeTime = 2500 -- milliseconds
Config.TeleportKey = 38-- Default: N