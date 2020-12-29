os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local websocket_url = settings["websocket_url"]

local websocket = http.websocket(websocket_url)
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local function refreshWebsocket()
    print("Refreshing websocket")
    if websocket.isOpen() then websocket.close() end
    websocket = http.websocket(websocket_url)
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
        if not websocket.isOpen() then
            refreshWebsocket()
        end
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
        if not websocket.isOpen() then
            refreshWebsocket()
        end
        local message, isBinary = websocket.receive()
        if not isBinary then
            if message then
                print("Message received from websocket: " .. message)
            else
                print("Empty message received from websocket.")
            end
        end
        -- local event, url, contents, binary = os.pullEvent({"websocket_message", "websocket_closed"})
        -- if event == "websocket_closed" then
        --     refreshWebsocket()
        -- elseif event == "websocket_message" then
        --     print("Received message from websocket: \n" .. contents)
        --     local messageToTransmit = {
        --         ["payload"] = contents,
        --         ["payload_signature"] = ecc.sign(secretKey, payload),
        --         ["public_key"] = publicKey
        --     }
        --     modem.transmit(channel, channel, messageToTransmit)
        -- end
    end
end

parallel.waitForAny(modemHandler, websocketHandler)