local baseUrl = "https://gitlab.com/tycoonlover1359/Minecraft-Security-System/-/raw/main/src/"

print("Updating the auto updater")
local response = http.get(baseUrl .. "autoupdater.lua")
local file = fs.open("autoupdater.lua", "w")
file.write(response.readAll())
file.close()

shell.run("autoupdater.lua")