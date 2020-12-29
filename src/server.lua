os.loadAPI("json")

local settings = json.decodeFromFile("settings.json")
local websocket = http.websocket(settings[websocket_url])

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
    end
end

local function websocketHandler()
    while true do
        local event, url, contents, binary = os.pullEvent({"websocket_message", "websocket_closed"})
        if event == "websocket_closed" then

        elseif event == "websocket_message" then
            print(contents)
        end
    end
end