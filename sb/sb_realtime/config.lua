Config = {}

-- ==== Transition / Fade settings ====
Config.TransitionLength = 10        -- seconds for smooth time transition (manual/realtime)
Config.FadeLength = 2000            -- fade in/out length in ms (screen fade)
Config.FadeInPercent = 0.10         -- % of transition to start fading out
Config.FadeOutPercent = 0.75        -- % of transition to start fading in

-- ==== Messaging settings ====
Config.UseQBCoreNotify = true       -- true = use QBCore notify, false = chat:addMessage
Config.MessageTime = 7000           -- ms to show notification
Config.DelayUntilMessage = 2000     -- delay (ms) before showing message after fade starts

-- ==== Realtime sync ====
Config.DefaultRealtime = false      -- true = realtime enabled on resource start
Config.RebroadcastInterval = 5000   -- ms between server → client time rebroadcasts
Config.RealtimeLoopDelay = 0        -- ms delay between realtime loop ticks on client (0 = every frame)

-- ==== Timelapse settings ====
Config.TimelapseStepMS = 5         -- ms between timelapse clock updates
Config.TimelapseVisible = true      -- true = no fade for timelapse (cinematic visible effect)

-- ==== Permissions ====
Config.RequireAceForCommands = true -- true = require ACE permissions for all commands

-- ==== Immersive / Confusing Messages ====
Config.RandomMessages = {
    "You start to feel a little dizzy...",
    "The world around you seems to shift slightly...",
    "Time feels... strange...",
    "You blink, and things don't look quite the same...",
    "A wave of vertigo washes over you...",
    "Reality bends for just a moment...",
    "You swear the sun just moved...",
    "Something in the air feels... different..."
}

-- ==== Time Sync with RealWeather Off Settings ====
-- Default GTA is ~1 game minute per 2 real seconds (2000 ms).
Config.ManualMsPerGameMinute = 2000
-- How often the server tells all clients “the current manual time”.
Config.ManualBroadcastInterval = 2000  -- ms (2s is plenty to keep clients in lockstep)

-- ==== Debug ====
Config.Debug = true
