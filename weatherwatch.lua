require('luau')
require('strings')
require('pack')
res = require('resources')
bit = require('bit')
config = require('config')
api = require('api')
files = require('files')
file = T{}

-- https://github.com/cocosolos/WeatherWatch
_addon.name = 'WeatherWatch'
_addon.version = '0.0.2'
_addon.author = 'Coco Solos'
_addon.commands = {'weatherwatch', 'ww'}

-- Config
defaults = { }
defaults.send = true
defaults.quiet = false
defaults.exclude_zones = S{}
defaults.include_zones = S{}
settings = config.load(defaults)
config.save(settings)

-- State
current_zone = 0
zone_info = {}
weather_info = {}

-- Definitions
VANA_EPOCH = 1009810800
VANA_MINUTE = 2.4 -- seconds
VANA_HOUR = 60 * VANA_MINUTE
VANA_DAY = 24 * VANA_HOUR
VANA_WEEK = 8 * VANA_DAY
VANA_MONTH = 30 * VANA_DAY
VANA_YEAR = 12 * VANA_MONTH
WEATHER_CYCLE_LENGTH = 6 * VANA_YEAR + math.pi / 10

inverted_weathers = {}
for k, v in pairs(res.weather) do
    inverted_weathers[string.lower(v.en):gsub("%s", "")] = k
end

inverted_elements = {}
for k, v in pairs(res.elements) do
    inverted_elements[string.lower(v.en):gsub("%s", "")] = k
end

function setup_zone(zone)
    current_zone = zone
    file.packet_table = files.new('data/'.. windower.ffxi.get_player().name ..'/'.. res.zones[zone].en ..'.lua', true)
end

function log_weather(weather_info)
    local log_string = string.format(
        "    [%d] = {['weather_start']=%d, ['weather']=%d, ['weather_offset']=%d, ['previous_weather_start']=%d, ['previous_weather']=%d, ['previous_weather_offset']=%d, ['raw_packet']=\"%s\"},\n",
        weather_info.timestamp,
        weather_info.weather_start,
        weather_info.weather,
        weather_info.weather_offset,
        weather_info.previous_weather_start or -1,
        weather_info.previous_weather or -1,
        weather_info.previous_weather_offset or -1,
        weather_info.raw_packet
    )
    file.packet_table:append(log_string)
    if settings.send then
        api.submit(weather_info)
    end
end

function print_status(with_gaps)
    if not settings.quiet then
        if weather_info.weather and weather_info.weather_start and weather_info.timestamp then
            local weather_start = math.floor(VANA_EPOCH + math.floor((weather_info.timestamp - VANA_EPOCH) / WEATHER_CYCLE_LENGTH) * WEATHER_CYCLE_LENGTH + weather_info.weather_start * VANA_MINUTE)
            log(res.weather[weather_info.weather].en.." started on "..os.date('%c', weather_start))
            if with_gaps and settings.send then
                api.get_gap(weather_info.zone)
            end
        else
            log("Unknown weather status. Try zoning or relogging.")
        end
    end
end

function check_incoming_chunk(id, data, modified, injected, blocked)
    if (id == 0x00A) then
        weather_info = {}
        weather_info.timestamp = data:unpack('I', 0x38 + 1)
        weather_info.zone = data:unpack('H', 0x30 + 1)
        weather_info.weather = data:unpack('H', 0x68 + 1)
        weather_info.previous_weather = data:unpack('H', 0x6A + 1)
        weather_info.weather_start = data:unpack('I', 0x6C + 1)
        weather_info.previous_weather_start = data:unpack('I', 0x70 + 1)
        weather_info.weather_offset = data:unpack('H', 0x74 + 1)
        weather_info.previous_weather_offset = data:unpack('H', 0x76 + 1)
        weather_info.raw_packet = data:hex()

        if not bad_data(weather_info) then
            if zone_info[weather_info.zone] ~= weather_info.weather_start then
                zone_info[weather_info.zone] = weather_info.weather_start
                coroutine.schedule(function()
                    log_weather(weather_info)
                end, 3)
            end
            coroutine.schedule(function()
                print_status(true)
            end, 4)
        end
    elseif (id == 0x057 and current_zone ~= 0) then
        weather_info = weather_info or {}
        weather_info.timestamp = os.time()
        weather_info.zone = current_zone
        weather_info.previous_weather = weather_info.weather
        weather_info.previous_weather_start = weather_info.weather_start
        weather_info.previous_weather_offset = weather_info.weather_offset
        weather_info.weather_start = data:unpack('I', 0x04 + 1)
        weather_info.weather = data:unpack('H', 0x08 + 1)
        weather_info.weather_offset = data:unpack('H', 0x0A + 1)
        weather_info.raw_packet = data:hex()

        if not bad_data(weather_info) then
            zone_info[weather_info.zone] = weather_info.weather_start
            coroutine.schedule(function()
                log_weather(weather_info)
                print_status(false)
            end, 3)
        end
    end
end

function bad_data(weather)
    local unload = false
    local server_id = windower.ffxi.get_info().server
    if type(res.servers[server_id]) ~= 'table' or not res.servers[server_id].name then
        log('Private servers are not supported.')
        unload = true
    end
    if weather then
        if 
            weather.weather and weather.weather >= #res.weather or
            weather.previous_weather and weather.previous_weather >= #res.weather
        then
            log('Invalid data detected.')
            unload = true
        end
    end
    if unload then
        windower.send_command('lua unload weatherwatch')
    end
    return unload
end

windower.register_event('login',function ()
    if windower.ffxi.get_info().logged_in and not bad_data() then
        setup_zone(windower.ffxi.get_info().zone)
        log('Thank you for using WeatherWatch!')
    end
end)

windower.register_event('load',function ()
    if windower.ffxi.get_info().logged_in and not bad_data() then
        setup_zone(windower.ffxi.get_info().zone)
        log('Thank you for using WeatherWatch!')
        log('Consider zoning or relogging to capture the current weather.')
    end
end)

windower.register_event('zone change', function(new, old)
    setup_zone(new)
end)

windower.register_event('incoming chunk', check_incoming_chunk)


windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    local args = L{...}
    if command == 'status' then
        print_status(true)
    elseif command == 'find' then
        local search_string = ""
        local message = "Searching for "
        for _, arg in ipairs(args) do
            message = message .. arg .. " "
            search_string = search_string .. string.lower(arg)
        end

        if inverted_elements[search_string] then
            log(message .. "element weather...")
            for k, v in ipairs(res.weather) do
                if v.element == inverted_elements[search_string] then
                    api.find_weather(v.id)
                end
            end
        elseif inverted_weathers[search_string] then
            message = message:sub(1, -2) .. "...\n"
            log(message)
            api.find_weather(inverted_weathers[search_string])
        else
            message = "Please enter a valid weather or element: "
            for _, v in ipairs(res.weather) do
                message = message .. v.en .. ", "
            end
            for i = 0, 15 do
                if res.elements[i] then
                    message = message .. res.elements[i].en .. ", "
                end
            end
            log(message:sub(1, -3))
        end
    elseif command == 'quiet' then
        settings.quiet = not settings.quiet
        if settings.quiet then
            log("Chat log announcements disabled.")
        else
            log("Chat log announcements enabled.")
        end
        config.save(settings)
    elseif command == 'send' then
        settings.send = not settings.send
        if settings.send then
            log("Sending weather data enabled. Thank you for contributing!")
        else
            log("Disabled sending weather data.")
        end
        config.save(settings)
    elseif command == 'gaps' then
        api.get_global_gaps(args[1])
    elseif command == 'help' then
        log("status - Prints the current zone weather information.")
        log("find <weather|element> - Searches for the specified weather.")
        log("quiet - Toggles messages on zone/weather change.")
        log("send - Toggles sending weather information to the WW server.")
        log("gaps <limit?>- Requests the next 10 or <limit> global gaps in coverage from the WW server.")
    end
end)
