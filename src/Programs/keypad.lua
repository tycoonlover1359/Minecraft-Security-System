os.loadAPI("touchpoint.lua")
os.loadAPI("json.lua")
local ecc = require("ecc")

local settings = json.decodeFromFile("settings.json")
local monitorSide = settings["keypad_monitor_side"]
local exitButtonSide = settings["exit_button_side"]
local channel = settings["channel"]
local id = settings["id"]

local secretKey, publicKey = ecc.keypair(ecc.random.random())
local serverPublicKey = ""

local reboot = false
local inputCode = ""
local modem = peripheral.find("modem", function(name, handle)
    if #handle.getNamesRemote() == 0 then
        return true
    else
        return false
    end
end)
local disk = peripheral.find("drive")

if not monitorSide then
    reboot = true
    term.write("Enter Keypad Side or ID: ")
    settings["keypad_monitor_side"] = read()
end

if not exitButtonSide then
    reboot = true
    term.write("Enter Exit Button Side or ID: ")
    settings["exit_button_side"] = read()
end

if reboot then 
    local file = fs.open("settings.json", "w")
    file.write(json.encode(settings))
    file.close()
    os.reboot() 
end

local keypad = touchpoint.new(monitorSide)
local keypadMonitor = peripheral.wrap(monitorSide)
local exitButton = touchpoint.new(exitButtonSide)
local exitButtonMonitor = peripheral.wrap(exitButtonSide)

keypadMonitor.setTextScale(1)
exitButtonMonitor.setTextScale(1)

local keypadMonitorSize = {}
keypadMonitorSize["X"], keypadMonitorSize["Y"] = keypadMonitor.getSize()

local exitButtonSize = {}
exitButtonSize["X"], exitButtonSize["Y"] = exitButtonMonitor.getSize()

local function signPayload(payload)
    if type(payload) ~= "string" then payload = json.encode(payload) end
    local timestamp = os.epoch("utc")
    local signedPayload = {
        ["payload"] = payload,
        ["payload_signature"] = ecc.sign(secretKey, payload .. timestamp),
        ["timestamp"] = timestamp,
        ["id"] = id
    }
    return signedPayload
end

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

local function exit()
    exitButton:flash("Exit")
    payload = {
        ["action"] = "exitButton",
        ["client_id"] = id
    }
    modem.transmit(channel, channel, signPayload(payload))
end

local function keypadHandler()
    while true do
        keypad:draw()
        local event = { keypad:handleEvents(os.pullEvent()) }
        if event[1] == "button_click" then
            local label = event[2]
            keypad:flash(label)
            if tonumber(label) then
                inputCode = inputCode .. label
            elseif label == "R" then
                inputCode = ""
            elseif label == ">" then
                local timestamp = os.epoch("utc")
                payload = {
                    ["action"] = "checkCode",
                    ["code"] = inputCode,
                    ["client_id"] = id
                }
                modem.transmit(channel, channel, signPayload(payload))
                inputCode = ""
            end
        end
    end
end

local function keycardHandler()
    while true do
        local event, side = os.pullEventRaw("disk")
        print("Disk event received; reading disk")
        local file = fs.open("disk/id.json", "r")
        if file then
            print("transmitting keycard id")
            local text = file.readAll()
            file.close()
            local data = json.decode(text)
            local keycardId = data["keycard_id"]
            local payload = {
                ["action"] = "checkKeycard",
                ["keycard_id"] = keycardId,
                ["client_id"] = id
            }
            modem.transmit(channel, channel, signPayload(payload))
        end
        print("Ejecting disk")
        disk.ejectDisk()
    end
end

local function modemHandler()
    while true do
        local event, side, frequency, replyFrequency, message, distance = os.pullEventRaw("modem_message")
        if message == "rhs" then
            handshake()
            checkServerPublicKey()
        else
            local toVerify = message.payload .. message.timestamp
            if ecc.verify(serverPublicKey, toVerify, message.payload_signature) then
                if os.epoch("utc") - message.timestamp < 15000 then
                    local payload = json.decode(message.payload)
                    if payload.target == id or payload.target == "all" then
                        if payload.action == "shutdown" then
                            exitButtonMonitor.setBackgroundColor(colors.black)
                            exitButtonMonitor.clear()
                            keypadMonitor.setBackgroundColor(colors.black)
                            keypadMonitor.clear()
                            disk.ejectDisk()
                            print("MCSS Client Shutdown Command Received")
                            print("Closing Modem Connection")
                            modem.closeAll()
                            print("Shutting Down...")
                            os.shutdown()
                            sleep(3)
                        elseif payload.action == "reboot" then
                            exitButtonMonitor.setBackgroundColor(colors.black)
                            exitButtonMonitor.clear()
                            keypadMonitor.setBackgroundColor(colors.black)
                            keypadMonitor.clear()
                            disk.ejectDisk()
                            print("MCSS Client Reboot Command Received")
                            print("Closing Modem Connection")
                            modem.closeAll()
                            print("Rebooting...")
                            os.reboot()
                            sleep(3)
                        end
                    end
                end
            end
        end
    end
end

exitButton:add("Exit", exit, 1, 1, exitButtonSize.X, exitButtonSize.Y, colors.red, colors.green)

keypad:add("1", nil, 1, 1, 1, 1, colors.black, colors.orange)
keypad:add("2", nil, 3, 1, 3, 1, colors.black, colors.orange)
keypad:add("3", nil, 5, 1, 5, 1, colors.black, colors.orange)
keypad:add("4", nil, 1, 3, 1, 3, colors.black, colors.orange)
keypad:add("5", nil, 3, 3, 3, 3, colors.black, colors.orange)
keypad:add("6", nil, 5, 3, 5, 3, colors.black, colors.orange)
keypad:add("7", nil, 1, 5, 1, 5, colors.black, colors.orange)
keypad:add("8", nil, 3, 5, 3, 5, colors.black, colors.orange)
keypad:add("9", nil, 5, 5, 5, 5, colors.black, colors.orange)
keypad:add("0", nil, 7, 3, 7, 3, colors.black, colors.orange)
keypad:add(">", nil, 7, 5, 7, 5, colors.red, colors.orange)
keypad:add("R", nil, 7, 1, 7, 1, colors.red, colors.orange)

modem.open(channel)
disk.ejectDisk()

handshake()
checkServerPublicKey()

parallel.waitForAny(
    function() 
        exitButton:run() 
    end, 
    keypadHandler, 
    modemHandler,
    keycardHandler
)