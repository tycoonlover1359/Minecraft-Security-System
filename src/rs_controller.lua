os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local id = settings["id"]
local outputSide = settings["side"]

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
        if message == "rehandshake" then
            handshake()
        else
            local toVerify = message.payload .. message.timestamp
            if ecc.verify(serverPublicKey, toVerify, message.payload_signature) then
                print("message verified: " .. json.encode(message))
                print(message.payload)
                print(os.epoch("utc") - message.timestamp)
                if os.epoch("utc") - message.timestamp < 15000 then
                    local payload = json.decode(message.payload)
                    if payload.recepient_id == id or payload.recepient_id == "all" then
                        if payload.action == "shutdown" then
                            sleep(3)
                            os.shutdown()
                        elseif payload.action == "redstoneUpdate" then
                            if payload.redstoneStatus == "true" or payload.redstoneStatus == true then
                                redstone.setOutput(outputSide, true)
                            elseif payload.redstoneStatus == "false" or payload.redstoneStatus == false then
                                redstone.setOutput(outputSide, false)
                            end
                        elseif payload.action == "tempOpen" then
                            redstone.setOutput(outputSide, false)
                            sleep(payload.openTime)
                            redstone.setOutput(outputSide, true)
                        end
                    end
                else
                    print("Timestamp check failed")
                end
            end
        end
    end
end