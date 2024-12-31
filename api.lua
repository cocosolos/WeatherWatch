local https = require("ssl.https")
local json = require("parse")

local api_endpoint = "https://weather.solos.dev"
local debug = false

local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local M = {}

function M.get_gap(zone_id)
    local message = ""
    local resp = {}
    local endpoint = api_endpoint .. "/zone/" .. zone_id
    local body, code, headers, status = https.request(endpoint)

    if code == 200 then
        local zone_name = res.zones[zone_id].en
        local result = json.parse(body)
        result = result[1]["gaps"]
        if next(result) ~= nil then
            message = message .. "Next gap in coverage for " .. zone_name .. ":\n"
            local gap_start = os.date("%c", result[1][1])
            local gap_end = os.date("%c", result[1][2])

            message = message .. gap_start .. " - " .. gap_end
        end
    else
        message = "Unable to contact weather server."
    end

    return message
end

function M.get_global_gaps(limit)
    local message = ""
    local resp = {}
    local endpoint = api_endpoint .. "/gaps"
    if limit then
        endpoint = endpoint .. "?limit=" .. limit
    end
    local body, code, headers, status = https.request(endpoint)

    if code == 200 then
        local result = json.parse(body)
        if next(result) ~= nil then
            message = message .. "Next ending global gaps in coverage:"
            for _, gap in ipairs(result) do
                if next(gap) ~= nil then
                    local gap_start = os.date("%c", gap[2][1])
                    local gap_end = os.date("%c", gap[2][2])
        
                    message = message .. "\n" .. gap_start .. " - " .. gap_end .. " in " .. res.zones[gap[1]].en
                end
            end
        end
    else
        message = "Unable to contact weather server."
    end

    return message
end

function M.find_weather(weather)
    local message = ""
    local resp = {}
    local endpoint = api_endpoint .. "/weather/" .. weather
    local query = {}
    for v, _ in pairs(settings.include_zones) do
        if v ~= "" then
            table.insert(query, "include="..v)
        end
    end
    for v, _ in pairs(settings.exclude_zones) do
        if v ~= "" then
            table.insert(query, "exclude="..v)
        end
    end
    if #query > 0 then
        endpoint = endpoint .. "?"
        for _, v in pairs(query) do
            endpoint = endpoint .. v .. "&"
        end
    end

    local body, code, headers, status = https.request(endpoint)

    if code == 200 then
        local weather_name = res.weather[tonumber(weather)].en
        local result = json.parse(body)

        if next(result) ~= nil then
            if not result.previous.timestamp or not result.upcoming.timestamp then
                return "Not enough data."
            end
            message = message ..
                "Last known " .. weather_name .. " weather: " .. os.date("%c", result.previous.timestamp) .. " in " ..
                res.zones[result.previous.zone].en ..
                "\nNext known " .. weather_name .. " weather: " .. os.date("%c", result.upcoming.timestamp) .. " in " ..
                res.zones[result.upcoming.zone].en
        end
    else
        message = "Unable to contact weather server."
    end

    return message
end

function M.post(weather_info)
    local cycle =  math.floor((weather_info.timestamp - VANA_EPOCH) / WEATHER_CYCLE_LENGTH)

    local packet1 =
        '{"zoneId": ' .. weather_info.zone ..
        ', "cycle": ' .. cycle ..
        ', "weatherId": ' .. weather_info.weather ..
        ', "tick": ' .. weather_info.weather_start ..
        ', "offset": ' .. weather_info.weather_offset

    if weather_info.previous_weather_start then
        packet1 = packet1 .. ', "prev": ' .. weather_info.previous_weather_start
    end

    packet1 = packet1 .. '}'

    local response_body = {}

    if debug then log("Packet 1: " .. packet1) end

    local res, code, response_headers = https.request {
        url = api_endpoint .. "/submit",
        method = "POST",
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(packet1:len())
        },
        source = ltn12.source.string(packet1),
        sink = ltn12.sink.table(response_body)
    }

    if debug then
        log("Code: " .. code)
        log("Response: " .. dump(response_body))
    end

    if weather_info.previous_weather_start then
        if weather_info.previous_weather_start > weather_info.weather_start then
            cycle = cycle - 1
        end

        local packet2 =
            '{"zoneId": ' .. weather_info.zone ..
            ', "cycle": ' .. cycle ..
            ', "weatherId": ' .. weather_info.previous_weather ..
            ', "tick": ' .. weather_info.previous_weather_start ..
            ', "offset": ' .. weather_info.previous_weather_offset .. '}'

        if debug then log("Packet 2: " .. packet2) end

        res, code, response_headers = https.request {
            url = api_endpoint .. "/submit",
            method = "POST",
            headers = {
                ["content-type"] = "application/json",
                ["content-length"] = tostring(packet2:len())
            },
            source = ltn12.source.string(packet2),
            sink = ltn12.sink.table(response_body)
        }

        if debug then
            log("Code: " .. code)
            log("Response: " .. dump(response_body))
        end
    end
end

return M
