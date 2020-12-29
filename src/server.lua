os.loadAPI("json")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]

local websocket = http.websocket(websocket_url)

local function refreshWebsocket()
    if websocket.isOpen() then websocket.close() end
    websocket = http.websocket(websocket_url)
end

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
            modem.transmit(channel, channel, contents)
        end
    end
end