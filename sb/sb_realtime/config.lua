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

-- ==== Debug ====
Config.Debug = false
