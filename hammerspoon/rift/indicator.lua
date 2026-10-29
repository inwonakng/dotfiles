-- Fixed layout symbols, independent of the workspace's moving window geometry.
require("hs.canvas")
require("hs.menubar")
require("hs.json")
local Indicator = {}
Indicator.__index = Indicator

local function layoutIcon(mode)
    local canvas = assert(hs.canvas.new({ x = 0, y = 0, w = 22, h = 16 }))
    local function rectangle(x, y, w, h)
        canvas:appendElements({
            type = "rectangle", action = "stroke", strokeColor = { white = 1 },
            strokeWidth = 1, roundedRectRadii = { xRadius = 0.8, yRadius = 0.8 },
            frame = { x = x, y = y, w = w, h = h },
        })
    end
    if mode == "traditional" then
        for _, y in ipairs({ 1.5, 8.5 }) do
            for _, x in ipairs({ 1.5, 12.5 }) do rectangle(x, y, 8, 5) end
        end
    else
        rectangle(0.5, 1.5, 15, 13)
        -- The next column continues beyond the right edge of the icon.
        rectangle(18.5, 1.5, 15, 13)
    end
    local image = assert(canvas:imageFromCanvas())
    canvas:delete()
    return image
end

function Indicator.new()
    return setmetatable({
        menu = assert(hs.menubar.new(false, "rift-workspace-layout")),
        icons = { traditional = layoutIcon("traditional"), scrolling = layoutIcon("scrolling") },
        displays = {},
    }, Indicator)
end

function Indicator:clear()
    self.menu:removeFromMenuBar()
    self.signature, self.displays, self.width = nil, {}, nil
end

-- Displays arrive in physical left-to-right, then top-to-bottom order.
function Indicator:update(displays)
    if #displays == 0 then self:clear(); return end
    local signature = hs.json.encode(displays)
    if signature == self.signature then return end
    local canvas = assert(hs.canvas.new({ x = 0, y = 0, w = 1, h = 18 }))
    local x, tooltip = 0, {}
    local function text(value, size, width)
        canvas:appendElements({
            type = "text", text = value, textFont = ".AppleSystemUIFont", textSize = size,
            textColor = { white = 1 }, frame = { x = x, y = 0, w = 1, h = 18 },
        })
        local index = #canvas
        local measured = canvas:minimumTextSize(index, value)
        width = width or math.ceil(measured.w)
        canvas[index].frame = { x = x, y = (18 - measured.h) / 2, w = width, h = measured.h }
        x = x + width
    end
    for index, display in ipairs(displays) do
        if index > 1 then
            x = x + 7
            text("|", 13)
            x = x + 7
        end
        local icon = self.icons[display.mode]
        if icon then
            canvas:appendElements({
                type = "image", image = icon, frame = { x = x, y = 1, w = 22, h = 16 },
            })
            x = x + 22
        else
            -- Do not mislabel an unconfigured layout engine as tiled/scrolling.
            text("?", 13, 22)
        end
        x = x + 4
        text(display.workspace, 10)
        table.insert(tooltip, display.name .. ": " .. display.mode .. " · " .. display.workspace)
    end
    canvas:size({ w = x, h = 18 })
    local image = assert(canvas:imageFromCanvas())
    canvas:delete()
    assert(self.menu:setIcon(image, true)) -- Template image follows the menu bar's light/dark appearance.
    self.menu:setTooltip(table.concat(tooltip, "\n"))
    self.menu:returnToMenuBar()
    self.signature, self.displays, self.width = signature, displays, x
end

function Indicator:status()
    return { visible = self.menu:isInMenuBar(), displays = self.displays, width = self.width }
end

function Indicator:delete()
    self.menu:delete()
end

return Indicator
