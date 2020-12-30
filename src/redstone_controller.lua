os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local id = settings["id"]

local modem = peripheral.find("modem")
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local serverPublicKey = ""

modem.open(channel)

function handshake()
    print("initiating handshake with server")
    local payload = {}
    payload.action = "handshake"
    modem.transmit(channel, channel, payload)
    local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
    if event == "modem_message" then
        serverPublicKey = message
    end
end

repeat
    handshake()
    sleep(1)
until serverPublicKey ~= ""

print(serverPublicKey)

while true do
    local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
    if event == "modem_message" then
        print("message received")
        if ecc.verify(serverPublicKey, message.payload, message.payload_signature) then
            print("message verified")
            print(message.payload)
            local payload = json.decode(message.payload)
            if payload.recepient_id == id or payload.recepient_id == "all" then
                if payload.action == "shutdown" then
                    sleep(3)
                    os.shutdown()
                elseif payload.action == "redstoneUpdate" then
                    if payload.redstoneStatus == "true" or payload.redstoneStatus == true then
                        redstone.setOutput(payload.side, true)
                    elseif payload.redstoneStatus == "false" or payload.redstoneStatus == false then
                        redstone.setOutput(payload.side, false)
                    end
                end
            end
        end
    end
end