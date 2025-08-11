# Seans Real Weather ReadMe

Thank you for taking a look at my script! This is fairly straightforward and includes commands to overwrite the real weather implementaiton on the fly. This script utilizes the open weather maps API and does a call to check for weather updates every minute. 

## Commands:

``/realweather [on/off]`` turns realweather on or off in game, and on the fly. 

``/weather help`` - displays a list of all commands for weather.

``/weather [weather condition]`` - sets the weather to your desired condition. If real weather is on, it will turn it off. If you turn real weather on while using a /weather command, it will switch back to using IRL weather. 

## Possible weather options

``clear`` = "Clear sky, sunny weather.",

``extrasunny`` = "Very clear and bright sunny weather.",

``clouds`` = "Partly cloudy skies.",

``overcast`` = "Cloudy and gray sky.",

``rain`` = "Rainy weather with wet roads.",

``clearing`` = "Rain clearing up, clouds breaking.",

``thunder`` = "Thunderstorms with heavy rain.",

``smog`` = "Low visibility due to smog.",

``foggy`` = "Fog reducing visibility.",

``snowlight`` = "Light snow falling.",

``snow`` = "Moderate snow weather.",

``blizzard`` = "Heavy snowstorm with blizzard conditions."

## Configuring

To set the city and county, just adjust those lines in the config.lua. Line 4 is the City, and line 5 is the start. Currently set to "Los Angeles, US"

To adjust how frequently this updates, change Config.UpdateInterval = [Desired Value]. The value is in seconds. Please do **not** update more frequently than 60 seconds, otherwise the script will stop working at the end of every hour. 
