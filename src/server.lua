os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]

local modem = peripheral.find("modem")
local websocket = http.websocket(websocket_url)
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local function refreshWebsocket()
    websocket.close()
    websocket = http.websocket(websocket_url)
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
        if message.action == "handshake" then
            modem.transmit(1, 1, publicKey)
        else
            if ecc.verify(message.public_key, message.payload, message.payload_signature) then
                websocket.send(message.payload)
            else
                modem.transmit(channel, channel, "Invalid Signature")
            end
        end
    end
end

local function websocketHandler()
    while true do
        local message, isBinary = websocket.receive()
        if not isBinary then
            if message then
                print("Message received from websocket: " .. message)
                local message messageToTransmit = {
                    ["payload"] = message,
                    ["payload_signature"] = ecc.sign(secretKey, message)
                }
                print("Broadcasting message")
                modem.transmit(channel, channel, messageToTransmit)
            else
                print("Empty message received from websocket.")
            end
        end
    end
end

parallel.waitForAny(modemHandler, websocketHandler)