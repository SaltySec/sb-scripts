-- Global variables for weather information and control
local weatherInfo = { temp = 0, desc = "Loading...", gta = "CLEAR", unit = "C" }
local manualWeather = nil -- Stores the weather type if manual override is active
local transitionTime = Config.TransitionTime -- Time in milliseconds for weather transitions (from config.lua)
local currentActiveWeather = nil -- Tracks the weather type currently active in the game

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
        -- Check if the requested weatherType is different from the currently active one
        -- This is crucial for smooth transitions. If we constantly try to set the same
        -- weather, it can interrupt or reset the native's transition logic.
        if currentActiveWeather ~= weatherType then
            -- Set the weather type with a smooth transition over the defined time
            SetWeatherTypeOvertimePersist(weatherType, transitionTime)
            -- Update the locally tracked active weather
            currentActiveWeather = weatherType
            print(('[RealWeather-Client] Changing weather to: %s with transition over %s ms'):format(weatherType, transitionTime))
        else
            -- Log if the weather type is already active, indicating no change is needed
            print(('[RealWeather-Client] Weather is already %s, no transition needed.'):format(weatherType))
        end
    end
end)

-- Event handler for enabling manual weather override
-- When manual weather is enabled, real-world weather updates are paused.
RegisterNetEvent('rw:enableManualWeather')
AddEventHandler('rw:enableManualWeather', function(weatherType)
    -- Set the manual weather type
    manualWeather = weatherType
    -- Apply the manual weather type with a transition, but only if it's different
    -- from the current active weather to ensure smooth transitions and prevent snapping.
    if currentActiveWeather ~= weatherType then
        SetWeatherTypeOvertimePersist(weatherType, transitionTime)
        currentActiveWeather = weatherType
        print(('[RealWeather-Client] Manual weather enabled: %s with transition over %s ms'):format(weatherType, transitionTime))
    else
        -- Log if the manual weather type is already active, indicating no change is needed
        print(('[RealWeather-Client] Manual weather is already %s, no transition needed.'):format(weatherType))
    end
end)

-- Event handler for disabling manual weather override
-- This will allow the real-world weather sync to resume.
RegisterNetEvent('rw:disableManualWeather')
AddEventHandler('rw:disableManualWeather', function()
    manualWeather = nil -- Clear the manual weather override
    print('[RealWeather-Client] Manual weather disabled. Real weather sync will resume.')
    -- When manual weather is disabled, the next real weather update (from server-side loop)
    -- will automatically apply the current real weather, which will then trigger a transition
    -- if it's different from the last manually set weather.
end)

-- Optional: Initial weather setup on resource start for the client
-- This ensures that when a player joins, the weather is immediately set
-- to the server's current weather. The server's initial fetchWeather()
-- will trigger the 'rw:setWeather' event after a short delay.
-- Citizen.CreateThread(function()
--     -- You might want to request initial weather from the server here
--     -- or rely on the server's periodic updates to synchronize.
-- end)