os.loadAPI("json.lua")
os.loadAPI("touchpoint.lua")

local t = touchpoint.new()

t:add("button", nil, 2, 2, 5, 5, colors.red, colors.lime)

t:draw()

while true do
    local event, p1 = t:handleEvents(os.pullEvent())
    if event == "button_click" then
        t:flash(p1)
    end
end