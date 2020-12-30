local baseUrl = "https://gitlab.com/tycoonlover1359/Minecraft-Security-System/-/raw/main/src/"

local function download(urlPath, filePath)
    local request = http.get(baseUrl .. urlPath)
    local file = fs.open(filePath)
    file.write(request.readAll())
    file.close()
    request.close()
end

term.clear()
term.setCursorPos(1,1)

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
    print(" ")
    term.write("Enter Type Number: ")
    local input = read()

    if input == "1" then
        success = true
        settings["type"] = "mcss_server"
        print("Downloading MCSS Server")
        download("server.lua", "main.lua")
    elseif input == "2"
        success = true
        settings["type"] = "mcss_redstone_controller"
        print("Downloading MCSS Redstone Controller")
        download("rs_controller.lua")
    else
        print("Invalid Option")
    end
    sleep(1)
until success

term.clear()
term.setCursorPos(1,1)

if settings["type"] == "mcss_server" then
    
end