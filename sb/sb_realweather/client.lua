local weatherInfo = { temp = 0, desc = "Loading...", gta = "CLEAR", unit = "C" }
local manualWeather = nil
local transitionTime = Config.TransitionTime

RegisterNetEvent('rw:updateWeatherInfo')
AddEventHandler('rw:updateWeatherInfo', function(data)
    weatherInfo = data
end)

RegisterNetEvent('rw:setWeather')
AddEventHandler('rw:setWeather', function(weatherType)
    if not manualWeather then
        SetWeatherTypeOvertimePersist(weatherType, transitionTime)
    end
end)

RegisterNetEvent('rw:enableManualWeather')
AddEventHandler('rw:enableManualWeather', function(weatherType)
    manualWeather = weatherType
    SetWeatherTypeOvertimePersist(weatherType, transitionTime)
end)

RegisterNetEvent('rw:disableManualWeather')
AddEventHandler('rw:disableManualWeather', function()
    manualWeather = nil
end)