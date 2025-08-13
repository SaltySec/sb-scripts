local QBCore = exports['qb-core']:GetCoreObject()
local apiKey = Config.ApiKey
local isRealWeatherEnabled = Config.RealWeather
local useFahrenheit = Config.UseFahrenheit

-- Valid weather types
local validWeathers = {
    clear = "Clear sky, sunny weather.",
    extrasunny = "Very clear and bright sunny weather.",
    clouds = "Partly cloudy skies.",
    overcast = "Cloudy and gray sky.",
    rain = "Rainy weather with wet roads.",
    clearing = "Rain clearing up, clouds breaking.",
    thunder = "Thunderstorms with heavy rain.",
    smog = "Low visibility due to smog.",
    foggy = "Fog reducing visibility.",
    snowlight = "Light snow falling.",
    snow = "Moderate snow weather.",
    blizzard = "Heavy snowstorm with blizzard conditions.",
    xmas = "Festive snow-covered ground.",
    snow_halloween = "Halloween with snow.",
    rain_halloween = "Halloween with rain.",
    halloween = "Spooky weather for Halloween.",
    neutral = "Neutral clear sky."
}


local isInRestartOverride = false

local function getMinutesUntilNextRestart()
    local now = os.date("*t")
    local currentMinutes = now.hour * 60 + now.min
    local minDiff = nil

    for _, restart in ipairs(Config.RestartTimesLocal) do
        local restartMinutes = restart.hour * 60 + restart.minute
        local diff = restartMinutes - currentMinutes
        if diff < 0 then diff = diff + 1440 end  -- handle wrap around to next day
        if not minDiff or diff < minDiff then
            minDiff = diff
        end
    end

    return minDiff
end

local function checkRestartOverride()
    local minutes = getMinutesUntilNextRestart()

    if minutes <= 20 then
        isInRestartOverride = true

        if minutes <= 5 then
            print("[RealWeather] Server restart in <= 5 minutes. Applying thunder")
            TriggerClientEvent('rw:setWeather', -1, 'thunder')
        elseif minutes <= 10 then
            print("[RealWeather] Server restart in <= 10 minutes. Applying rain")
            TriggerClientEvent('rw:setWeather', -1, 'rain')
        elseif minutes <= 15 then
            print("[RealWeather] Server restart in <= 15 minutes. Applying overcast")
            TriggerClientEvent('rw:setWeather', -1, 'overcast')
        elseif minutes <= 20 then
            print("[RealWeather] Server restart in <= 20 minutes. Applying clouds")
            TriggerClientEvent('rw:setWeather', -1, 'clouds')
        end
    else
        isInRestartOverride = false
    end
end

-- Notify helper
local function notifyPlayer(src, message, type, length)
    TriggerClientEvent('QBCore:Notify', src, message, type or 'primary', length or 10000)
end

-- /realweather command
RegisterCommand('realweather', function(source, args)
    local src, sub = source, args[1]
    if not sub then
        notifyPlayer(src, '/realweather [on/off]', 'primary')
        return
    end

    if sub == 'on' then
        isRealWeatherEnabled = true
        TriggerClientEvent('rw:disableManualWeather', -1)
        notifyPlayer(src, 'Real-world weather enabled.', 'success')
        fetchWeather()
    elseif sub == 'off' then
        isRealWeatherEnabled = false
        notifyPlayer(src, 'Real-world weather disabled. Use /weather to set manually.', 'success')
    else
        notifyPlayer(src, '/realweather [on/off]', 'primary')
    end
end, true)

-- /weather command
RegisterCommand("weather", function(source, args)
    local src = source
    local sub = args[1] and args[1]:lower()

    if isInRestartOverride then
    print("[RealWeather] Override active — skipping real weather update.")
    return
end

    if not sub then
        notifyPlayer(src, "Usage: /weather [type] or /weather help", "error")
        return
    end

    if sub == "help" then
        local helpMessage = "Valid weather types:\n"
        for k, desc in pairs(validWeathers) do
            helpMessage = helpMessage .. string.upper(k) .. " - " .. desc .. "\n"
        end
        TriggerClientEvent("chat:addMessage", src, {
            color = {255, 255, 0},
            multiline = true,
            args = {"Weather Help", helpMessage}
        })
        return
    end

    if validWeathers[sub] then
        isRealWeatherEnabled = false
        -- For /weather command, we now call enableManualWeather directly on the client.
        -- This ensures the manual override state is set before the weather change.
        TriggerClientEvent("rw:enableManualWeather", -1, sub)
        notifyPlayer(src, "Weather changed to: " .. string.upper(sub), "success")
    else
        notifyPlayer(src, "Invalid weather type. Use /weather help to list options.", "error")
    end
end, true)

-- Convert OpenWeather to GTA
local function mapOpenWeatherToFiveM(weatherMain, weatherDesc)
    weatherMain = weatherMain:lower()
    weatherDesc = weatherDesc:lower()

    if weatherMain:find("clear") then
        return "extrasunny"
    elseif weatherMain:find("cloud") then
        if weatherDesc:find("few") or weatherDesc:find("scattered") then
            return "clouds"
        else
            return "overcast"
        end
    elseif weatherMain:find("rain") then
        if weatherDesc:find("thunder") then
            return "thunder"
        elseif weatherDesc:find("light") or weatherDesc:find("drizzle") then
            return "clearing"
        else
            return "rain"
        end
    elseif weatherMain:find("thunder") then
        return "thunder"
    elseif weatherMain:find("fog") or weatherMain:find("mist") or weatherMain:find("haze") then
        return "foggy"
    elseif weatherMain:find("smoke") or weatherMain:find("smog") then
        return "smog"
    elseif weatherMain:find("snow") or weatherMain:find("sleet") then
        if weatherDesc:find("light") then
            return "snowlight"
        elseif weatherDesc:find("blizzard") then
            return "blizzard"
        else
            return "snow"
        end
    else
        return "clear"
    end
end

-- Fetch weather from OpenWeather API
function fetchWeather()
    if isInRestartOverride then
    print("[RealWeather] Override active — skipping real weather update.")
    return
end

    if not isRealWeatherEnabled then return end

    local minsLeft = getMinutesUntilNextRestart()
    if minsLeft <= Config.DisableWeatherBeforeStormMinutes then
        return
    end

    local units = useFahrenheit and 'imperial' or 'metric'
    local url = string.format(
        'http://api.openweathermap.org/data/2.5/weather?q=%s,%s&appid=%s&units=%s',
        Config.City:gsub(' ', '%%20'),
        Config.CountryCode,
        apiKey,
        units
    )

    PerformHttpRequest(url, function(status, response)
        if status == 200 and response then
            local data = json.decode(response)
            if data and data.weather and data.main then
                local weatherDesc = data.weather[1].description
                local temperature = data.main.temp
                local gtaWeather = mapOpenWeatherToFiveM(data.weather[1].main, weatherDesc)

                -- Instead of directly setting weather here, we now trigger the client's rw:setWeather
                -- which will handle the transition logic (always smooth in the new client).
                TriggerClientEvent('rw:setWeather', -1, gtaWeather)
                TriggerClientEvent('rw:updateWeatherInfo', -1, {
                    temp = temperature,
                    desc = weatherDesc,
                    gta = gtaWeather,
                    unit = useFahrenheit and "F" or "C"
                })

                print(('[RealWeather] Updated: %s°%s | %s | GTA: %s'):format(
                    tostring(temperature), useFahrenheit and "F" or "C", weatherDesc, gtaWeather))
                print("[RealWeather] Current local time: " .. os.date("%Y-%m-%d %H:%M:%S"))
            else
                print("[RealWeather] Failed to parse API data.")
            end
        else
            print("[RealWeather] API request failed. Status: " .. tostring(status))
        end
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end

-- Poll loop
Citizen.CreateThread(function()
    while true do
        checkRestartOverride()
        fetchWeather()
        Citizen.Wait(Config.UpdateInterval * 1000)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerClientEvent('chat:addSuggestion', -1, '/realweather', 'Toggle real-weather syncing.', {
            { name = "on/off", help = "Enable or disable real-weather" }
        })

        TriggerClientEvent('chat:addSuggestion', -1, '/weather', 'Manually set the in-game weather.', {
            { name = "Weather Type", help = "do help here to see valid weather types" },
        })
    end
end)

-- Server-side event to receive client logs and print them to the server terminal
-- This event is triggered from the client using TriggerServerEvent('rw:clientLog', ...)
RegisterNetEvent('rw:clientLog')
AddEventHandler('rw:clientLog', function(logType, weatherType, transitionTimeUsed, isManual, previousWeather)
    local src = source -- Get the source player ID. 0 means it's coming from the server itself.
    local prefix = "[RealWeather-Client Log]"
    if src ~= 0 then -- If the source is a player, include their ID in the log.
        prefix = prefix .. " [Player " .. src .. "]"
    end

    -- Process different types of log messages received from the client
    if logType == 'change' then
        -- Log a message when the weather type is genuinely changing
        local typeIndicator = isManual and "Manual" or "Automatic"
        print(('%s %s Changing weather from %s to %s with transition over %s ms'):format(prefix, typeIndicator, previousWeather or 'N/A', weatherType, transitionTimeUsed))
    -- elseif logType == 'refresh' then
        -- Log a message when the same weather type is being re-applied (refreshed)
        -- local typeIndicator = isManual and "Manual" or "Automatic"
        -- print(('%s %s Refreshing weather %s with transition over %s ms'):format(prefix, typeIndicator, weatherType, transitionTimeUsed))
    elseif logType == 'manual_disabled' then
        -- Log a message when manual weather override is disabled
        print(('%s Manual weather disabled. Real weather sync will resume.'):format(prefix))
    end
end)
