os.loadAPI("json")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]

local websocket = http.websocket(websocket_url)
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local function refreshWebsocket()
    if websocket.isOpen() then websocket.close() end
    websocket = http.websocket(websocket_url)
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
        if not websocket.isOpen() then
            refreshWebsocket()
        end
        if ecc.verify(message.public_key, message.payload, message.payload_signature) then
            websocket.send(message.payload)
        else
            modem.transmit(channel, channel, "Invalid Signature")
        end
    end
end

local function websocketHandler()
    while true do
        local event, url, contents, binary = os.pullEvent({"websocket_message", "websocket_closed"})
        if event == "websocket_closed" then
            refreshWebsocket()
        elseif event == "websocket_message" then
            local messageToTransmit = {
                ["payload"] = contents,
                ["payload_signature"] = ecc.sign(secretKey, payload),
                ["public_key"] = publicKey
            }
            modem.transmit(channel, channel, messageToTransmit)
        end
    end
end