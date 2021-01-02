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
    file.write(json.encode(file))
    file.close()
    os.reboot() 
end