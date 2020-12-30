local baseUrl = "https://gitlab.com/tycoonlover1359/Minecraft-Security-System/-/raw/main/src/"

local function download(urlPath, filePath)
    local request = http.get(baseUrl .. urlPath)
    local file = fs.open(filePath, "w")
    file.write(request.readAll())
    file.close()
    request.close()
end

print("Updating the auto updater")
download("autoupdater.lua", "autoupdater.lua")

print("Updating the main program")
os.loadAPI("json.lua")
local settings = json.decodeFromFile("settings.json")
local type = settings["type"]

if type == "server" then
    download("server.lua", "main.lua")
end

shell.run("main.lua")