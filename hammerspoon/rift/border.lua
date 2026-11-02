-- One click-through outline for the native focused window; no border daemon.
require("hs.canvas")
require("hs.window")
require("hs.window.filter")
require("hs.uielement.watcher")
require("hs.timer")
require("hs.eventtap")
local Border = {}
Border.__index = Border
local width, radius = 2, 12 -- Points; radius is an approximation of native macOS corners.

function Border.new()
    local canvas = assert(hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 }))
    canvas:level("floating"):behaviorAsLabels({ "canJoinAllSpaces", "transient", "ignoresCycle" })
    canvas:clickActivating(false):canvasMouseEvents(false, false, false, false)
    return setmetatable({ canvas = canvas }, Border)
end

function Border:clear()
    if self.watcher then self.watcher:stop(); self.watcher = nil end
    self.windowId = nil
    self.canvas:hide()
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
    local frame, id = window:frame(), window:id()
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
                self.canvas:hide()
                return
            end
            self:scheduleRefresh()
        end))
        -- Observe geometry directly; window.filter coalesces it for 0.5 s.
        self.watcher:start({ events.windowMoved, events.windowResized, events.elementDestroyed })
    end
    self.canvas:frame(frame)
    self.canvas:replaceElements({
        type = "rectangle", action = "stroke", strokeWidth = width,
        strokeColor = { red = 139 / 255, green = 213 / 255, blue = 176 / 255, alpha = 1 },
        -- Draw entirely inside the window frame, including at screen edges.
        frame = { x = width / 2, y = width / 2, w = frame.w - width, h = frame.h - width },
        roundedRectRadii = { xRadius = radius - width / 2, yRadius = radius - width / 2 },
        trackMouseDown = false, trackMouseUp = false,
        trackMouseEnterExit = false, trackMouseMove = false,
    })
    self.canvas:show()
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
    self.canvas:delete()
end

function Border:status()
    return { window = self.windowId }
end

return Border
