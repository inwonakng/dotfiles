-- One click-through outline for the native focused window; no border daemon.
-- Webex shows its multitasking mini window when it considers the meeting
-- window covered. A window-sized overlay counts as covering, and so do strips
-- that overlap the window's entire outer edge. Draw four edge strips inset from
-- the frame so neither the interior nor the outermost edge is overlapped.
require("hs.canvas")
require("hs.window")
require("hs.window.filter")
require("hs.uielement.watcher")
require("hs.timer")
require("hs.eventtap")
local Border = {}
Border.__index = Border
local width, radius = 2, 12 -- Points; radius is an approximation of native macOS corners.
local inset = 1 -- Points left uncovered at the window edge (see header).

local sides = { "top", "bottom", "left", "right" }

local function newStrip()
    local canvas = assert(hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 }))
    -- One level below floating: above normal app windows (including windows
    -- Rift floats), but below floating panels such as Webex's mini window.
    -- Sharing their level would put the outline on top whenever it moves.
    canvas:level(hs.canvas.windowLevels.floating - 1):behaviorAsLabels({ "canJoinAllSpaces", "transient", "ignoresCycle" })
    canvas:clickActivating(false):canvasMouseEvents(false, false, false, false)
    return canvas
end

function Border.new()
    local strips = {}
    for _, side in ipairs(sides) do strips[side] = newStrip() end
    return setmetatable({ strips = strips }, Border)
end

function Border:hide()
    for _, canvas in pairs(self.strips) do canvas:hide() end
end

function Border:clear()
    if self.watcher then self.watcher:stop(); self.watcher = nil end
    self.windowId = nil
    self:hide()
end

function Border:scheduleRefresh()
    if self.pending then return end
    -- Let AX focus/visibility notifications finish before reading native focus.
    self.pending = hs.timer.doAfter(0, function()
        self.pending = nil
        self:refresh()
    end)
end

function Border:refresh()
    if self.dragging then
        if hs.eventtap.checkMouseButtons().left then return end
        self.dragging = nil
    end
    local window = hs.window.focusedWindow()
    -- Native focus is authoritative. window.filter's cached Space membership
    -- can reject the focused window when Rift moves windows between workspaces.
    if not window or not window:isStandard() or not window:isVisible() or window:isFullScreen() then
        self:clear()
        return
    end
    local native, id = window:frame(), window:id()
    local frame = {
        x = native.x + inset, y = native.y + inset,
        w = native.w - inset * 2, h = native.h - inset * 2,
    }
    if not id or frame.w <= width * 2 or frame.h <= width * 2 then
        self:clear()
        return
    end
    if self.windowId ~= id then
        self:clear()
        self.windowId = id
        local events = hs.uielement.watcher
        self.watcher = assert(window:newWatcher(function(_, event)
            if event == events.elementDestroyed then self:clear() end
            if (event == events.windowMoved or event == events.windowResized)
                and hs.eventtap.checkMouseButtons().left then
                -- A separate canvas cannot track a native drag smoothly.
                self.dragging = true
                self:hide()
                return
            end
            self:scheduleRefresh()
        end))
        -- Observe geometry directly; window.filter coalesces it for 0.5 s.
        self.watcher:start({ events.windowMoved, events.windowResized, events.elementDestroyed })
    end
    -- Top and bottom strips are tall enough to contain the rounded corners;
    -- side strips cover only the straight edges between them.
    local corner = math.min(radius, math.floor(frame.h / 2))
    local rects = {
        top = { x = frame.x, y = frame.y, w = frame.w, h = corner },
        bottom = { x = frame.x, y = frame.y + frame.h - corner, w = frame.w, h = corner },
        left = { x = frame.x, y = frame.y + corner, w = width, h = frame.h - corner * 2 },
        right = { x = frame.x + frame.w - width, y = frame.y + corner, w = width, h = frame.h - corner * 2 },
    }
    for side, rect in pairs(rects) do
        local canvas = self.strips[side]
        if rect.w <= 0 or rect.h <= 0 then
            canvas:hide()
        else
            canvas:frame(rect)
            -- Each strip draws the full outline in inset-frame coordinates
            -- and clips to its own bounds, so the strips join seamlessly.
            canvas:replaceElements({
                type = "rectangle", action = "stroke", strokeWidth = width,
                strokeColor = { red = 139 / 255, green = 213 / 255, blue = 176 / 255, alpha = 1 },
                -- Draw entirely inside the window frame, including at screen edges.
                frame = {
                    x = frame.x - rect.x + width / 2, y = frame.y - rect.y + width / 2,
                    w = frame.w - width, h = frame.h - width,
                },
                roundedRectRadii = { xRadius = radius - width / 2, yRadius = radius - width / 2 },
                trackMouseDown = false, trackMouseUp = false,
                trackMouseEnterExit = false, trackMouseMove = false,
            })
            canvas:show()
        end
    end
end

function Border:start()
    if self.filter then return end
    self.mouseUp = hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp }, function()
        if self.dragging then
            self.dragging = nil
            self:scheduleRefresh()
        end
        return false -- Observe release without consuming it.
    end):start()
    local events = hs.window.filter
    self.filter = events.new(true)
    self.filter:subscribe({
        events.windowFocused, events.windowUnfocused,
        events.windowOnScreen, events.windowNotOnScreen,
        events.windowFullscreened, events.windowUnfullscreened,
        events.windowNotVisible, events.windowDestroyed,
    }, function(window, _, event)
        if window:id() == self.windowId and (event == events.windowUnfocused
            or event == events.windowNotOnScreen or event == events.windowNotVisible
            or event == events.windowDestroyed) then self:clear() end
        self:scheduleRefresh()
    end)
    self:refresh()
end

function Border:delete()
    if self.mouseUp then self.mouseUp:stop(); self.mouseUp = nil end
    if self.filter then self.filter:delete(); self.filter = nil end
    if self.pending then self.pending:stop(); self.pending = nil end
    self:clear()
    for _, canvas in pairs(self.strips) do canvas:delete() end
end

function Border:status()
    return { window = self.windowId }
end

return Border
