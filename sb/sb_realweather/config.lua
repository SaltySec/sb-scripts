Config = {}

Config.ApiKey = 'be3d2d3be9a472d3d91fb16a0f39f4cf'
Config.City = 'Los Angeles'
Config.CountryCode = 'US'
Config.UpdateInterval = 60    -- 1 minute
Config.RealWeather = true      -- start enabled
Config.UseFahrenheit = true   -- default unit
Config.RestartTimesLocal = {
    { hour = 4, minute = 30},
    { hour = 11, minute = 0},
    { hour = 15, minute = 30},
}
Config.DisableWeatherBeforeStormMinutes = 10
Config.TransitionTime = 45.0 -- Seconds it takes the weather types to transition