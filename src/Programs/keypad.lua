os.loadAPI("touchpoint.lua")
os.loadAPI("json.lua")

local settings = json.decodeFromFile("settings.json")
local monitorSide = settings["keypad_monitor_side"]
local exitButtonSide = settings["exit_button_side"]

local reboot = false
local inputCode = ""


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

local function exit()
    exitButton:flash("Exit")
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

parallel.waitForAny(function() exitButton:run() end, keypadHandler)