os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]

local modem = peripheral.find("modem")
local websocket = http.websocket(websocket_url)
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local clientPublicKeys = {}

local function refreshWebsocket()
    websocket.close()
    websocket = http.websocket(websocket_url)
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
        if message.action == "handshake" then
            print("Receiving Handshake from MCSS Client")
            modem.transmit(1, 1, publicKey)
            clientPublicKeys[message.id] = message.public_key
        else
            if ecc.verify(clientPublicKeys[message.id], message.payload, message.payload_signature) then
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
                modem.transmit(channel, channel, "MCSS Client Message Invalid: Invalid Signature")
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
                print("Websocket Message Received: \n" .. message)
                local epoch = os.epoch("utc")
                local messageToTransmit = {
                    ["payload"] = message,
                    ["payload_signature"] = ecc.sign(secretKey, message .. epoch),
                    ["timestamp"] = epoch
                }
                print("Broadcasting Websocket Message: " .. json.encode(messageToTransmit))
                modem.transmit(channel, channel, messageToTransmit)
            else
                print("Empty Websocket Message Received")
            end
        else
            refreshWebsocket()
        end
    end
end

print(publicKey)
modem.open(channel)
modem.transmit(1, 1, "rehandshake")

parallel.waitForAny(modemHandler, websocketHandler)