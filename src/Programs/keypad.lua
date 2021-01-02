os.loadAPI("touchpoint.lua")
os.loadAPI("json.lua")

local settings = json.decodeFromFile("settings.json")
local monitorSide = settings["monitor_side"]

local keypadMonitor = touchpoint.new(peripheral.wrap("top"))