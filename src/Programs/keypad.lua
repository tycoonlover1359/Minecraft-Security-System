os.loadAPI("touchpoint.lua")
os.loadAPI("json.lua")

local settings = json.decodeFromFile("settings.json")
local monitorSide = settings["keypad_monitor_side"]
local exitButtonSide = settings["exit_button_side"]
local reboot = false

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
        local event = { keypad:handleEvents(os.pullEventRaw()) }
        if event[1] == "button_click" then
            local label = event[2]
            keypad:flash(label)
        end
    end
end

exitButton:add("Exit", exit, 1, 1, exitButtonSize.X, exitButtonSize.Y, colors.red, colors.green)

keypad:add("1", nil, 1, 1, 1, 1, colors.red, colors.lime)
keypad:add("2", nil, 4, 1, 4, 1, colors.red, colors.lime)
keypad:add("3", nil, 7, 1, 7, 1, colors.red, colors.lime)
keypad:add("4", nil, 1, 2, 1, 2, colors.red, colors.lime)
keypad:add("5", nil, 4, 2, 4, 2, colors.red, colors.lime)
keypad:add("6", nil, 7, 2, 7, 2, colors.red, colors.lime)
keypad:add("7", nil, 1, 3, 1, 3, colors.red, colors.lime)
keypad:add("8", nil, 4, 3, 4, 3, colors.red, colors.lime)
keypad:add("9", nil, 7, 3, 7, 3, colors.red, colors.lime)

parallel.waitForAny(function() exitButton:run() end, keypadHandler)