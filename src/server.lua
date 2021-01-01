os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]
local apiKey = settings["api_key"]

local modem = peripheral.find("modem")
local websocket = http.websocket(websocket_url .. "&authorization=" .. apiKey)
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local clientPublicKeys = {}

local function refreshWebsocket()
    websocket.close()
    websocket = http.websocket(websocket_url .. "&authorization=" .. apiKey)
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
        if message.action == "handshake" then
            print("Receiving Handshake from MCSS Client")
            local payload = {
                ["public_key"] = publicKey,
                ["id"] = "server"
            }
            modem.transmit(1, 1, payload)
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
                local m = json.decode(message)
                if m.recepient_id == "server" then
                    if m.action == "shutdown" then
                        print("MCSS Server Shutdown Command Received")
                        print("Closing Modem Connection")
                        modem.closeAll()
                        print("Closing Websocket Conection")
                        websocket.close()
                        print("Shutting down...")
                        sleep(2.5)
                        os.shutdown()
                    end
                elseif m.recepient_id == "all" then
                    if m.action == "shutdown" then
                        print("MCSS Network Shutdown Command Received")
                        print("Broadcasting Shutdown Command")
                        local epoch = os.epoch("utc")
                        local messageToTransmit = {
                            ["payload"] = message,
                            ["payload_signature"] = ecc.sign(secretKey, message .. epoch),
                            ["timestamp"] = epoch
                        }
                        modem.transmit(channel, channel, messageToTransmit)
                        print("Closing Modem Connection")
                        modem.closeAll()
                        print("Closing Websocket Conection")
                        websocket.close()
                        print("Shutting down...")
                        sleep(2.5)
                        os.shutdown()
                    elseif m.action == "reboot" then
                        print("MCSS Network Reboot Command Received")
                        print("Broadcasting Reboot Command")
                        local epoch = os.epoch("utc")
                        local messageToTransmit = {
                            ["payload"] = message,
                            ["payload_signature"] = ecc.sign(secretKey, message .. epoch),
                            ["timestamp"] = epoch
                        }
                        modem.transmit(channel, channel, messageToTransmit)
                        print("Closing Modem Connection")
                        modem.closeAll()
                        print("Closing Websocket Conection")
                        websocket.close()
                        print("Rebooting...")
                        sleep(2.5)
                        os.reboot()
                    else
                        local epoch = os.epoch("utc")
                        local messageToTransmit = {
                            ["payload"] = message,
                            ["payload_signature"] = ecc.sign(secretKey, message .. epoch),
                            ["timestamp"] = epoch
                        }
                        print("Broadcasting Websocket Message: " .. json.encode(messageToTransmit))
                        modem.transmit(channel, channel, messageToTransmit)
                    end
                else
                    local epoch = os.epoch("utc")
                    local messageToTransmit = {
                        ["payload"] = message,
                        ["payload_signature"] = ecc.sign(secretKey, message .. epoch),
                        ["timestamp"] = epoch
                    }
                    print("Broadcasting Websocket Message: " .. json.encode(messageToTransmit))
                    modem.transmit(channel, channel, messageToTransmit)
                end
            else
                print("Empty Websocket Message Received")
            end
        else
            refreshWebsocket()
        end
    end
end

term.clear()
term.setCursorPos(1,1)
print("MCSS Server Running")
modem.open(channel)
modem.transmit(1, 1, "rhs")

parallel.waitForAny(modemHandler, websocketHandler)