local monitor = peripheral.find("monitor")
local relay = peripheral.find("redstone_relay") or nil

local Button = {}
Button.instances = {}
function Button:new(x, y, xTOff, yTOff, width, height, text)
    if text ~= nil then
        assert(#text + xTOff <= width, "text is wider than the button, consider using acronyms (ex: DOR for door), or decreasing offset if present")
    end
    local obj = { x = x, y = y, xTOff=xTOff, yTOff=yTOff, width = width, height = height, active = false, text = text or nil}
    setmetatable(obj, self)
    self.__index = self
    table.insert(self.instances, obj)
    return obj
end

function Button:draw()
    local bgcolor
    if self.active then
        bgcolor = "d"
    else
        bgcolor = "e"
    end
    for i = 0, self.height - 1 do
        monitor.setCursorPos(self.x, self.y + i)
        monitor.blit(string.rep(" ", self.width), string.rep("0", self.width), string.rep(bgcolor, self.width))
    end
    if self.text ~= nil then
        monitor.setCursorPos(self.x + self.xTOff, self.y + self.yTOff)
        monitor.blit(self.text, string.rep("0", #self.text), string.rep(bgcolor, #self.text))
    end
end

function Button:onClick()
    local eventData = {os.pullEvent()}
    local event = eventData[1]
    if event == "monitor_touch" then
        local x = eventData[3]
        local y = eventData[4]
        for _, button in ipairs(Button.instances) do
            if x >= button.x and x <= button.x + button.width - 1 and y >= button.y and y <= button.y + button.height - 1 then
                button.active = not button.active
            end
        end
    end
end

function Button:drawButtons()
    for _, button in ipairs(Button.instances) do
        button:draw()
    end
end

local function handleInput()
    while true do
        Button:onClick()
    end
end

local Output = {}
Output.instances = {}
function Output:new(side, powerconsumption, initialActivity, linkedButton)
    local obj = {side = side, powerconsumption = powerconsumption, initialActivity = initialActivity, active = initialActivity, linkedButton = linkedButton or nil}
    setmetatable(obj, self)
    self.__index = self
    table.insert(self.instances, obj)
    return obj
end

local power = 9999
local function handlePower()
    for _, output in ipairs(Output.instances) do
        if output.linkedButton ~= nil then
            if output.linkedButton.active then
                power = power - output.powerconsumption
                output.active = not output.initialActivity
            else
                output.active = output.initialActivity
            end
        else
            power = power - output.powerconsumption
        end
    end

    if power <= 0 then
        power = 0
        for _, button in ipairs(Button.instances) do
            button.active = false
        end
        for _, output in ipairs(Output.instances) do
            if output.linkedButton ~= nil then
                output.active = false
            else
                output.active = not output.initialActivity
            end
        end
    end

    for _, output in ipairs(Output.instances) do
        if relay ~= nil then
            relay.setOutput(output.side, output.active)
        else
            rs.setOutput(output.side, output.active)
        end
    end

    if os.time() >= 6 then
        power = 9999
        for _, output in ipairs(Output.instances) do
            if output.linkedButton == nil then
                output.active = output.initialActivity
            end
        end
    end
end

local function celebrate6AM()
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(3, 1)
    monitor.write("5AM")
    sleep(2)
    monitor.clear()
    monitor.setCursorPos(3, 1)
    monitor.setBackgroundColor(colors.blue)
    monitor.clear()
    monitor.write("6AM")
    sleep(2)
    monitor.setCursorPos(1, 2)
    monitor.write("Your")
    sleep(0.8)
    monitor.setCursorPos(1, 3)
    monitor.write("shift")
    sleep(0.8)
    monitor.setCursorPos(1, 4)
    monitor.write("is")
    sleep(0.8)
    monitor.setCursorPos(1,5)
    monitor.write("over!")
    sleep(6)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local powerconsumelevel = 0
local powerlvlcolors = { "d", "d4", "d44", "d44e", "d44ee", "d44eee", "d44eeee" }
local function drawScreen()
    monitor.setCursorPos(1, 1)
    monitor.write("PWR")
    monitor.setCursorPos(5, 1)
    monitor.write(tostring(math.floor(power / 100)).. "%")
    monitor.setCursorPos(1, 2)
    for _, output in ipairs(Output.instances) do
        if output.active then
            powerconsumelevel = powerconsumelevel + 1
        end
    end
    if powerconsumelevel > 0 then
        monitor.blit(string.rep("=", powerconsumelevel), powerlvlcolors[powerconsumelevel], string.rep("f", powerconsumelevel))
    end
    powerconsumelevel = 0
    Button:drawButtons()
    if power <= 0 then
        monitor.setTextColor(colors.red)
        powerconsumelevel=0
    else
        monitor.setTextColor(colors.white)
    end
end

local debounce = false
local function mainLoop()
    while true do
        handlePower()
        if os.time() == 6 and debounce == false then
            debounce = true
            celebrate6AM()
        end
        if os.time() == 0 and debounce == true then
            debounce = false
        end
        drawScreen()
        sleep(0.05)
        monitor.clear()
    end
end

--############################################ EDIT HERE ############################################

--BUTTON FORMAT:
-- local button = Button:new( button X coordinate, button Y coordinate, X coordinate text offset, Y coordinate text offset, width, height, text )
-- coordinates are from the top left of the monitor screen, where 1,1 is the very top left pixel, a 1x1 block monitor has a 7x7 pixel screen.
-- text offset offsets the button text from the top left of the button, 0 means no offset, you can use offset to put text in the
-- middle of a button in case you have a bigger button.
-- width and height are the width and height of the button.
-- text is the text that shows up on the button, leave empty for no text.

local doorButton = Button:new(1,3,0,0,3,1,"DOR")
local lightButton = Button:new(5,3,0,0,3,1,"LIT")
local ventButton = Button:new(1,4,0,0,3,1,"VNT")

--OUTPUT FORMAT: 
-- local output = Output:new( side, power consumption, initial activity state, linked button )
-- side is the side of the computer block or redstone relay which redstone signal will be outputted to, the computer screen is the front.
-- powerconsumption is how much power this output consumes, more means more power consumed, sides can be "front","back","right","left","top","bottom".
-- initial activity state is whether the output will be on or off initially, for example poweroutput is supposed to be
-- on for as long as there is power, so it should initially be true, I use poweroutput to keep the office lights on while power is working and turn off when
-- power goes out.
-- linked button is the button which controls the output, leave empty for no button.

local doorOutput = Output:new("front", 10, false, doorButton)
local lightOutput = Output:new("bottom", 10, false, lightButton)
local ventOutput = Output:new("right", 10, false, ventButton)
local powerOutput = Output:new("left", 1 , true)

--#################################################################################################
-- script by defaulito

parallel.waitForAny(mainLoop, handleInput)