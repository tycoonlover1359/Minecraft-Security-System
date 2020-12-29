os.loadAPI("json.lua")
local ecc = require("ecdsa")

local settings = json.decodeFromFile("settings.json")
local channel = settings["channel"]
local id = settings["id"]

local modem = peripheral.find("modem")
local secretKey, publicKey = ecc.keypair(ecc.random.random())

while true do
    modem.open(channel)
    local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
    if event == "modem_message" then
        if ecc.verify(message.public_key, message.payload, message.payload_signature) then
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