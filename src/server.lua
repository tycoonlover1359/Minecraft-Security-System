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
            print("Receiving handshake from client")
            modem.transmit(1, 1, publicKey)
        else
            if ecc.verify(message.public_key, message.payload, message.payload_signature) then
                local maxTries = 3
                local tries = 0
                repeat
                    tries = tries + 1
                    success, err = pcall(function() websocket.send(message.payload) end)
                until success or tries == maxTries
                if not success then
                    print("Error occurred: " + err)
                end
            else
                modem.transmit(channel, channel, "Invalid Signature")
            end
        end
    end
end

local function websocketHandler()
    while true do
        -- if success is false, then message is the error/traceback
        local success, message, isBinary = pcall(function() return websocket.receive() end)
        if success and not isBinary then
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
        else
            refreshWebsocket()
        end
    end
end

print(publicKey)
modem.open(channel)
parallel.waitForAny(modemHandler, websocketHandler)