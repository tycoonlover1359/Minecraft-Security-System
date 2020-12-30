os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local id = settings["id"]
local outputSide = settings["outputSide"]

local modem = peripheral.find("modem")
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local serverPublicKey = ""

modem.open(channel)

local function handshake()
    local success = false
    repeat
        print("Initiating Handshake with MCSS Server")
        local payload = {}
        payload.action = "handshake"
        payload.public_key = publicKey
        payload.id = id
        modem.transmit(channel, channel, payload)
        local timer = os.startTimer(5)
        local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw()
        if event == "modem_message" then
            success = true
            os.cancelTimer(timer)
            print("Handshake with MCSS Server Successful")
            serverPublicKey = message
        elseif event == "timer" then
            os.cancelTimer(timer)
            print("Handshake with MCSS Server Timed Out")
        end
        os.cancelTimer(timer)
        sleep(1)
    until success
end

local function checkServerPublicKey()
    repeat
        if type(serverPublicKey) ~= "table" then
            print("Invalid Server Public Key")
            print("Rehandshaking with Server")
            serverPublicKey = ""
        end
    until type(serverPublicKey) == "table"
end

handshake()

print("Server Public Key: " .. json.encode(serverPublicKey))

while true do
    checkServerPublicKey()
    local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
    checkServerPublicKey()
    if event == "modem_message" then
        print("Message Received from MCSS Server: " .. json.encode(message))
        if message == "rhs" then
            handshake()
        else
            local toVerify = message.payload .. message.timestamp
            if ecc.verify(serverPublicKey, toVerify, message.payload_signature) then
                print("MCSS Server Message Verified: " .. json.encode(message))
                print(message.payload)
                print(os.epoch("utc") - message.timestamp)
                if os.epoch("utc") - message.timestamp < 15000 then
                    local payload = json.decode(message.payload)
                    if payload.recepient_id == id or payload.recepient_id == "all" then
                        if payload.action == "shutdown" then
                            print("MCSS Client Shutdown Command Received")
                            print("Closing Modem Connection")
                            modem.closeAll()
                            print("Shutting Down...")
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
            else
                print("MCSS Server Message Invalid: Invalid Signature")
            end
        end
    end
end