# WeatherWatch

**THIS ADDON IS NOT INTENDED FOR USE ON PRIVATE SERVERS.**

Track weather changes, search for upcoming weather.

WeatherWatch prints to the chat log the current weather and when it started upon entering a new zone and whenever the weather changes. This information is also logged to a file in the data directory and sent to the WeatherWatch server.

![status](https://github.com/user-attachments/assets/5c46a7b6-e718-4c45-89c9-d315cdd79f1a)

Upcoming weather can be searched for by weather or element using `//ww find <weather|element>`. Zones can be included or exluded from results in the settings as a comma separated list of zone IDs (example: Reisenjima Sanctorium weather changes very frequently so you can add `<exclude_zones>,293</exclude_zones>` to settings.xml to filter that zone. At least 1 comma is required for these settings to be correctly parsed.) This feature depends on user submissions and should improve over time.

![find](https://github.com/user-attachments/assets/feefecf6-2d6e-4298-828f-a171e935f634)

Weather information is sent to the WeatherWatch server so that weather timelines can be built for each zone. All data submitted is completely anonymous and is used only to fill in missing weather information. The weather in FFXI repeats every 6 Vana'diel years (about 86-87 IRL days). The goal is to map the weather timelines for every zone, at which point this addon can be updated to remove the API calls and instead use a local database distributed with the addon.

## Thanks

[WhereIsDI](https://github.com/aphung/whereisdi) whose network code was used as a starting point for this addon.

parse.lua - https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
