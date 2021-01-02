local baseUrl = "https://gitlab.com/tycoonlover1359/Minecraft-Security-System/-/raw/main/src/"

local function download(urlPath, filePath)
    local request = http.get(baseUrl .. urlPath)
    local file = fs.open(filePath, "w")
    file.write(request.readAll())
    file.close()
    request.close()
end

print("Updating startup script")
download("startup.lua", "startup.lua")

print("Updating the main program")
os.loadAPI("json.lua")
local settings = json.decodeFromFile("settings.json")
local type = settings["type"]

if type == "mcss_server" then
    print("Downloading MCSS Server")
    download("Programs/server.lua", "main.lua")
elseif type == "mcss_pocket_admin" then
    print("Downloading MCSS Administrator Panel")
        download("Programs/pocket_controller.lua", "main.lua")
elseif type == "mcss_redstone_controller" then
    print("Downloading MCSS Redstone Controller Client")
    download("Programs/rs_controller.lua", "main.lua")
end

shell.run("main.lua")