-- Global variables for weather information and control
local weatherInfo = { temp = 0, desc = "Loading...", gta = "CLEAR", unit = "C" }
local manualWeather = nil -- Stores the weather type if manual override is active
local transitionTime = Config.TransitionTime -- Time in milliseconds for weather transitions (from config.lua)
-- The 'currentActiveWeather' variable is kept for logging purposes.
local currentActiveWeather = nil -- Tracks the weather type currently active in the game

-- Helper function to send logs to the server terminal
local function logToServer(logType, weatherType, transitionTimeUsed, isManual, previousWeather)
    TriggerServerEvent('rw:clientLog', logType, weatherType, transitionTimeUsed, isManual, previousWeather)
end

-- Event handler for updating real weather information (temperature, description)
-- This data is received from the server and used for display purposes if needed.
RegisterNetEvent('rw:updateWeatherInfo')
AddEventHandler('rw:updateWeatherInfo', function(data)
    weatherInfo = data
end)

-- Event handler for setting the weather type from the server or commands
RegisterNetEvent('rw:setWeather')
AddEventHandler('rw:setWeather', function(weatherType)
    -- Only proceed if manual weather is not active, allowing real weather to apply
    if not manualWeather then
        local prevWeather = currentActiveWeather -- Store previous weather for logging
        -- Always apply the full transition time, regardless of whether the weather type is new or same.
        SetWeatherTypeOvertimePersist(weatherType, transitionTime)
        currentActiveWeather = weatherType -- Update current active weather

        -- Log that a weather update (and thus a transition) was applied
        if prevWeather ~= weatherType then
            logToServer('change', weatherType, transitionTime, false, prevWeather) -- Automatic weather change
        else
            logToServer('refresh', weatherType, transitionTime, false, prevWeather) -- Automatic weather refresh (same type)
        end
    end
end)

-- Event handler for enabling manual weather override
-- When manual weather is enabled, real-world weather updates are paused.
RegisterNetEvent('rw:enableManualWeather')
AddEventHandler('rw:enableManualWeather', function(weatherType)
    manualWeather = weatherType -- Set the manual weather type
    local prevWeather = currentActiveWeather -- Store previous weather for logging

    -- Always apply the full transition time for manual weather, regardless of type.
    SetWeatherTypeOvertimePersist(weatherType, transitionTime)
    currentActiveWeather = weatherType -- Update current active weather

    -- Log that a manual weather update (and thus a transition) was applied
    if prevWeather ~= weatherType then
        logToServer('change', weatherType, transitionTime, true, prevWeather) -- Manual weather change
    else
        logToServer('refresh', weatherType, transitionTime, true, prevWeather) -- Manual weather refresh (same type)
    end
end)

-- Event handler for disabling manual weather override
-- This will allow the real-world weather sync to resume.
RegisterNetEvent('rw:disableManualWeather')
AddEventHandler('rw:disableManualWeather', function()
    manualWeather = nil -- Clear the manual weather override
    logToServer('manual_disabled') -- Send this log to the server terminal
    -- When manual weather is disabled, the next real weather update (from server-side loop)
    -- will automatically apply the current real weather, ensuring a transition.
end)

-- Optional: Initial weather setup on resource start for the client
-- This ensures that when a player joins, the weather is immediately set
-- to the server's current weather. The server's initial fetchWeather()
-- will trigger the 'rw:setWeather' event after a short delay.
-- Citizen.CreateThread(function()
--     -- You might want to request initial weather from the server here
--     -- or rely on the server's periodic updates to synchronize.
-- end)
