os.loadAPI("touchpoint.lua")
os.loadAPI("json.lua")

local lockdownStatus = false

local sizeX, sizeY = term.getSize()
local maxX = sizeX
local maxY = sizeY - 1

local mainMenu = touchpoint.new()

local settings = json.decodeFromFile("settings.json")
local websocket_url = settings["websocket_url"]
local apiKey = settings["api_key"]

local websocket = http.websocket(websocket_url .. "&authorization=" .. apiKey)

local function refreshWebsocket()
    websocket.close()
    websocket = http.websocket(websocket_url .. "&authorization=" .. apiKey)
end

local function websocketRequest(data, tries)
    if not tries then tries = 1 end
    local requestData = json.encode(data)
    local success, response, isBinary = pcall(function() 
        websocket.send(requestData)
        return websocket.receive(5)
    end)
    if success then 
        return json.decode(response)
    elseif tries < 3 then
        refreshWebsocket()
        sleep(math.random() * 3)
        websocketRequest(data)
    else
        return nil
    end
end

local function paginate(items)
    local count = 1
    local pages = {}
    local page = touchpoint.new()
    local currentX, currentY = 2, 2
    repeat
        if #items == 0 or items == {} then 
            table.insert(pages, page)
            break 
        end
        page:add(items[count], nil, currentX, currentY, currentX + 22, currentY, colors.blue, colors.lime)
        currentY = currentY + 2
        if count % 9 == 0 or count == #items then
            table.insert(pages, page)
            page = touchpoint.new()
            currentY = 2
        end
        count = count + 1
    until count == #items + 1
    for _, page in pairs(pages) do
        page:add("Back", nil, 11, sizeY, 16, sizeY, colors.blue, colors.lime)
        page:add("<-", nil, 1, sizeY, 4, sizeY, colors.blue, colors.lime)
        page:add("->", nil, sizeX - 3, sizeY, sizeX, sizeY, colors.blue, colors.lime)
    end
    pages[1]:remove("<-")
    pages[#pages]:remove("->")
    return pages
end

local function handlePaginator(itemList)
    local menus = paginate(itemList)
    local activeMenuNumber = 1
    local run = true
    while run do
        local activeMenu = menus[activeMenuNumber]
        activeMenu:draw()
        local event = { activeMenu:handleEvents(os.pullEvent()) }
        if event[1] == "button_click" then
            local label = event[2]
            activeMenu:flash(label)
            if label == "Back" then 
                run = false
            elseif label == "->" then
                activeMenuNumber = activeMenuNumber + 1
            elseif label == "<-" then
                activeMenuNumber = activeMenuNumber - 1
            end
        end
    end
end

local function redstoneControllers()
    if not lockdownStatus then
        mainMenu:flash("Redstone")
        local requestData = {
            ["action"] = "listPeripherals",
            ["filter"] = "RSCTRL",
            ["expression_attribute_names"] = {
                ["#n"] = "Name"
            },
            ["projection_expression"] = "#n, SK"
        }
        local controllers = websocketRequest(requestData)
        local controllerList = {}
        for _, controller in pairs(controllers) do
            table.insert(controllerList, controller["Name"])
        end
        handlePaginator(controllerList)
    end
end

local function drones()
    if not lockdownStatus then
        mainMenu:flash("Drones")
    end
end

local function shutdown()
    if not lockdownStatus then
        mainMenu:flash("Shutdown")
    end
end

local function lockdown()
    lockdownStatus = not lockdownStatus
    mainMenu:toggleButton("Lockdown")
end

local function exit()
    mainMenu:flash("Exit")
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    websocket.close()
    os.queueEvent("terminate")
    os.pullEvent("terminate")
end

mainMenu:add("Redstone", redstoneControllers, 2, 2, 25, 2, colors.blue, colors.lime)
mainMenu:add("Drones", drones, 2, 4, 25, 4, colors.blue, colors.lime)
mainMenu:add("Shutdown", shutdown, 2, 14, 25, 14, colors.blue, colors.lime)
mainMenu:add("Lockdown", lockdown, 2, 16, 25, 18, colors.blue, colors.lime)
mainMenu:add("Exit", exit, 11, sizeY, 16, sizeY, colors.blue, colors.lime)

mainMenu:run()