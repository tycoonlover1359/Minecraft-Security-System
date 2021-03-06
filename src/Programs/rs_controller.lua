os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local id = settings["id"]
local outputSide = settings["outputSide"]

local modem = peripheral.find("modem")
local secretKey, publicKey = ecc.keypair(ecc.random.random())

local oldStatus = true
local lockdownStatus = false
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
            if type(message) == "table" then
                if message.id ~= nil and message.id == "server" then
                    success = true
                    os.cancelTimer(timer)
                    print("Handshake with MCSS Server successful")
                    serverPublicKey = message.public_key
                else
                    print("Handshake with MCSS Server Failed")
                end
            else
                print("Handshake with MCSS Server Failed")
            end
        elseif event == "timer" then
            os.cancelTimer(timer)
            print("Handshake with MCSS Server Timed Out")
        end
        os.cancelTimer(timer)
        sleep(1 + math.random() * 3)
    until success
end

local function checkServerPublicKey()
    repeat
        if type(serverPublicKey) ~= "table" then
            print("Invalid Server Public Key")
            print("Rehandshaking with Server")
            serverPublicKey = ""
            handshake()
        end
    until type(serverPublicKey) == "table"
end

handshake()

while true do
    checkServerPublicKey()
    local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
    checkServerPublicKey()
    if event == "modem_message" then
        print("Message Received from MCSS Server: " .. json.encode(message))
        if message == "rhs" then
            handshake()
        else
            if message.payload then
                local toVerify = message.payload .. message.timestamp
                if ecc.verify(serverPublicKey, toVerify, message.payload_signature) then
                    print("MCSS Server Message Verified: " .. json.encode(message))
                    print(message.payload)
                    print(os.epoch("utc") - message.timestamp)
                    if os.epoch("utc") - message.timestamp < 15000 then
                        local payload = json.decode(message.payload)
                        print("Target: " .. payload.target)
                        if payload.target == id or payload.target == "all" then
                            print("Action: " .. payload.action)
                            if payload.action == "shutdown" then
                                if not lockdownStatus then
                                    print("MCSS Client Shutdown Command Received")
                                    print("Closing Modem Connection")
                                    modem.closeAll()
                                    print("Shutting Down...")
                                    os.shutdown()
                                end
                            elseif payload.action == "reboot" then
                                if not lockdownStatus then
                                    print("MCSS Client Reboot Command Received")
                                    print("Closing Modem Connection")
                                    modem.closeAll()
                                    print("Rebooting...")
                                    os.reboot()
                                end
                            elseif payload.action == "redstoneUpdate" then
                                if not lockdownStatus then
                                    if payload.redstoneStatus == "true" or payload.redstoneStatus == true then
                                        redstone.setOutput(outputSide, true)
                                    elseif payload.redstoneStatus == "false" or payload.redstoneStatus == false then
                                        redstone.setOutput(outputSide, false)
                                    end
                                end
                            elseif payload.action == "toggleStatus" then
                                if not lockdownStatus then
                                    redstone.setOutput(outputSide, not redstone.getOutput(outputSide))
                                end
                            elseif payload.action == "tempOpen" then
                                if not lockdownStatus then
                                    redstone.setOutput(outputSide, false)
                                    sleep(payload.open_time)
                                    redstone.setOutput(outputSide, true)
                                end
                            elseif payload.action == "startLockdown" then
                                print("Lockdown Command Received: Starting")
                                lockdownStatus = true
                                oldStatus = redstone.getOutput(outputSide)
                                redstone.setOutput(outputSide, true)
                            elseif payload.action == "endLockdown" then
                                print("Lockdown Command Received: Ending")
                                lockdownStatus = false
                                redstone.setOutput(outputSide, oldStatus)
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
end