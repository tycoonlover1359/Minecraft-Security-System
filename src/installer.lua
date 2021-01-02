local baseUrl = "https://gitlab.com/tycoonlover1359/Minecraft-Security-System/-/raw/main/src/"

local function download(urlPath, filePath)
    local request = http.get(baseUrl .. urlPath)
    local file = fs.open(filePath, "w")
    file.write(request.readAll())
    file.close()
    request.close()
end

local function getInput(prompt, replacement)
    term.write(prompt)
    return read(replacement)
end

term.clear()
term.setCursorPos(1,1)

print("Downloading Autoupdater")
download("autoupdater.lua", "autoupdater.lua")

print("Downloading JSON API")
download("APIs/json.lua", "json.lua")

print("Downloading Eliptic Curve Cryptography API")
download("APIs/ecc.lua", "ecc.lua")

print("API Downloads Complete")
sleep(1)

local settings = {}

repeat
    local success = false

    term.clear()
    term.setCursorPos(1,1)
    
    print("[1] MCSS Server")
    print("[2] MCSS Redstone Controller")
    print("[3] MCSS Pocket Admin Panel")
    print(" ")
    local input = getInput("Enter Type Number: ")

    if input == "1" then
        success = true
        settings["type"] = "mcss_server"
        print("Downloading MCSS Server")
        download("Programs/server.lua", "main.lua")
    elseif input == "2" then 
        success = true
        settings["type"] = "mcss_redstone_controller"
        print("Downloading MCSS Redstone Controller")
        download("Programs/rs_controller.lua", "main.lua")
    elseif input == "3" then
        success = true
        settings["type"] = "mcss_pocket_admin"
        print("Downloading MCSS Pocket Administrator Panel")
        download("Programs/pocket_controller.lua", "main.lua")
        print("Downloading Touchpoint API")
        download("APIs/touchpoint.lua", "touchpoint.lua")
    else
        print("Invalid Option")
    end
    sleep(1)
until success

term.clear()
term.setCursorPos(1,1)

if settings["type"] == "mcss_server" then
    settings["websocket_url"] = "wss://" .. getInput("API Gateway ID: ") .. ".execute-api.us-west-2.amazonaws.com/" .. getInput("API Gateway Stage: ") .."?networkid=" .. getInput("MCSS Network ID: ") .. "&type=server"
    settings["api_key"] = getInput("MCSS Server Key: ", "*")
    local channel = getInput("MCSS Channel (Nothing for Default): ")
    if channel == "" then channel = 1 end
    settings["channel"] = channel
elseif settings["type"] == "mcss_pocket_admin" then
    settings["websocket_url"] = "wss://" .. getInput("API Gateway ID: ") .. ".execute-api.us-west-2.amazonaws.com/" .. getInput("API Gateway Stage: ") .. "?networkid=" .. getInput("MCSS Network ID: ") .. "&type=admin"
    settings["api_key"] = getInput("MCSS Admin Key: ", "*")
elseif settings["type"] == "mcss_redstone_controller" then
    settings["id"] = getInput("MCSS Peripheral ID: ")
    settings["outputSide"] = getInput("MCSS Peripheral Output Side: ")

    local channel = getInput("MCSS Channel (Nothing for Default): ")
    if channel == "" then channel = 1 end
    settings["channel"] = channel
end

os.loadAPI("json.lua")

term.clear()
term.setCursorPos(1,1)

print("Saving Settings")
local file = fs.open("settings.json", "w")
file.write(json.encode(settings))
file.close()
sleep(1)

print("Saving Startup File")
local file = fs.open("startup.lua", "w")
file.write([[shell.run("autoupdater.lua")]])
file.close()

term.clear()
term.setCursorPos(1,1)

print("Restarting")
sleep(3)

os.reboot()