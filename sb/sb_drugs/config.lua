Config = {}

-- Core/UI
Config.UseQBCoreNotify = true

-- === OSP Ambulance integration ===
-- If true: pill use will write to the player's state bag -> BodyDamage.Pain = 0
Config.UseOSPAmbulance = true
Config.OSP = {
    bodyDamageKey = 'BodyDamage',
    painField = 'Pain',
    replicate = true
}

-- Visual effects
Config.HighScreenEffect = 'DrugsMichaelAliensFight'
Config.HighEffectSeconds = 900
Config.HighMovementClipset = 'move_m@drunk@slightlydrunk' -- set to false to disable

-- Overdose behavior
Config.OverdoseDrainSeconds = 300 -- 5 minutes

-- Healing & thresholds per item
Config.Drugs = {
    perc30 = { label = '30mg Percocet', healPercent = 0.30, highThreshold = 2, overdoseThreshold = 3, windowSeconds = 900 },
    perc10 = { label = '10mg Percocet', healPercent = 0.15, highThreshold = 3, overdoseThreshold = 5, windowSeconds = 900 },
    perc5  = { label = '5mg Percocet',  healPercent = 0.12, highThreshold = 4, overdoseThreshold = 6, windowSeconds = 900 },
    vic10  = { label = '10mg Vicodin',  healPercent = 0.15, highThreshold = 3, overdoseThreshold = 5, windowSeconds = 900 },
    vic5   = { label = '5mg Vicodin',   healPercent = 0.12, highThreshold = 4, overdoseThreshold = 6, windowSeconds = 900 },
}

-- Items
Config.NarcanItem = 'narcan'
Config.NarcanLabel = 'Narcan'

-- Animations
Config.PillAnim = { dict = 'mp_player_inteat@burger', anim = 'mp_player_int_eat_burger', durationMs = 2500 }
Config.NarcanAdminAnim = { dict = 'anim@heists@narcotics@funding@gang_idle', anim = 'gang_chatting_idle01', durationMs = 3500 }

-- Targeting (ox_target) for administering Narcan to another player
Config.UseOXTarget = true
Config.TargetDistance = 2.0
Config.TargetNarcan = { label = 'Administer Narcan', icon = 'fa-solid fa-syringe' }
