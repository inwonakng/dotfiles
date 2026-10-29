-- Rift supplies membership and commits focus; this overlay never activates an app
-- while cycling. Snapshots stay in memory only for the duration of one invocation.
require("hs.canvas")
require("hs.eventtap")
require("hs.keycodes")
require("hs.image")
require("hs.screen")
require("hs.timer")
require("hs.window")
require("hs.logger")
local Picker = {}
Picker.__index = Picker
local log = hs.logger.new("rift-picker", "info")

function Picker.new(request, select)
    return setmetatable({ request = request, select = select }, Picker)
end

function Picker:cancel()
    self.session = nil
    if self.keys then self.keys:stop(); self.keys = nil end
    if self.release then self.release:stop(); self.release = nil end
    if self.capture then self.capture:stop(); self.capture = nil end
    if self.canvas then self.canvas:delete(); self.canvas = nil end
end

function Picker:finish()
    local session = self.session
    if not session then return end
    -- A quick Cmd-Tab can finish before the asynchronous Rift query returns.
    -- Retain the cycle count, but never flash the overlay after Command is up.
    if not session.snapshot then session.released = true; return end
    local entry = session.snapshot.entries[session.selected]
    self:cancel()
    if entry then self.select(entry.window, session.snapshot) end
end

local function text(value, x, y, w, h, size, color, alignment)
    return {
        type = "text", text = value, textFont = ".AppleSystemUIFont", textSize = size,
        textColor = color or { white = 0.95 }, textAlignment = alignment or "left",
        textLineBreak = "truncateTail", frame = { x = x, y = y, w = w, h = h },
    }
end

function Picker:draw()
    local session = self.session
    if not session or not session.snapshot or session.released then return end
    local entries = session.snapshot.entries
    local screen = hs.screen.mainScreen():frame()
    local columns = math.max(1, math.min(4, #entries, math.floor((screen.w - 48) / 252)))
    local rows = math.max(1, math.min(2, math.ceil(#entries / columns),
        math.floor((screen.h - 132) / 194)))
    local capacity = columns * rows
    local first = math.floor((session.selected - 1) / capacity) * capacity + 1
    local last = math.min(#entries, first + capacity - 1)
    local cardW = math.min(240, screen.w - 64)
    local cardH, gap, padding = 182, 12, 20
    local width = columns * (cardW + gap) - gap + padding * 2
    local height = rows * (cardH + gap) - gap + 100
    local frame = { x = screen.x + (screen.w - width) / 2,
        y = screen.y + (screen.h - height) / 2, w = width, h = height }
    if not self.canvas then
        self.canvas = assert(hs.canvas.new(frame))
        self.canvas:level("overlay"):behaviorAsLabels({ "canJoinAllSpaces", "stationary" })
    else
        self.canvas:frame(frame)
    end
    local elements = {
        { type = "rectangle", action = "fill", fillColor = { white = 0.08, alpha = 0.97 },
            roundedRectRadii = { xRadius = 18, yRadius = 18 },
            frame = { x = 0, y = 0, w = width, h = height } },
        text("Workspace " .. session.snapshot.name, padding, 14, width - 130, 22, 14),
        text(session.selected .. " / " .. #entries, width - 100, 14, 80, 22, 13,
            { white = 0.65 }, "right"),
        text("Release ⌘ to switch    ·    ⇧Tab to go back    ·    Esc to cancel",
            padding, height - 32, width - padding * 2, 20, 11, { white = 0.65 }, "center"),
    }
    for index = first, last do
        local entry = entries[index]
        local cell = index - first
        local x = padding + (cell % columns) * (cardW + gap)
        local y = 48 + math.floor(cell / columns) * (cardH + gap)
        local selected = index == session.selected
        table.insert(elements, {
            type = "rectangle", action = "strokeAndFill",
            fillColor = { white = selected and 0.23 or 0.13 },
            strokeColor = selected and { hex = "#8ab4f8" } or { white = 0.22 },
            strokeWidth = selected and 3 or 1,
            roundedRectRadii = { xRadius = 10, yRadius = 10 },
            frame = { x = x, y = y, w = cardW, h = cardH },
        })
        if entry.preview then
            table.insert(elements, { type = "image", image = entry.preview, imageScaling = "scaleProportionally",
                frame = { x = x + 8, y = y + 8, w = cardW - 16, h = 122 } })
        elseif entry.icon then
            table.insert(elements, { type = "image", image = entry.icon,
                frame = { x = x + (cardW - 64) / 2, y = y + 36, w = 64, h = 64 } })
        else
            table.insert(elements, text("Preview unavailable", x + 8, y + 57, cardW - 16, 24,
                12, { white = 0.5 }, "center"))
        end
        if entry.icon then
            table.insert(elements, { type = "image", image = entry.icon,
                frame = { x = x + 10, y = y + 139, w = 28, h = 28 } })
        end
        table.insert(elements, text(entry.window.app_name or "Window", x + 44, y + 134, cardW - 54, 19, 12))
        local title = entry.window.title
        table.insert(elements, text(title and title ~= "" and title or "Untitled", x + 44, y + 153,
            cardW - 54, 19, 11, { white = 0.65 }))
    end
    self.canvas:replaceElements(table.unpack(elements)):show()
    session.first, session.last = first, last
end

function Picker:captureNext()
    if self.capture then self.capture:stop(); self.capture = nil end
    local session = self.session
    if not session or not session.snapshot or session.released then return end
    for index = session.first, session.last do
        local entry = session.snapshot.entries[index]
        if not entry.captured then
            -- Yield between windows: key release and cancellation must not wait
            -- behind a whole workspace of potentially expensive image captures.
            self.capture = hs.timer.doAfter(0.01, function()
                self.capture = nil
                if self.session ~= session then return end
                entry.captured = true
                local ok, preview = pcall(hs.window.snapshotForID, entry.window.window_server_id)
                if ok then entry.preview = preview end -- Protected/uncapturable windows keep their icon.
                self:draw()
                self:captureNext()
            end)
            return
        end
    end
end

function Picker:step(direction)
    local session = self.session
    if session and session.released then self:cancel(); session = nil end
    if session then
        if session.snapshot then
            session.selected = (session.selected - 1 + direction) % #session.snapshot.entries + 1
            self:draw()
            self:captureNext()
        else
            session.delta = session.delta + direction
        end
        return
    end
    session = { delta = direction, direction = direction }
    self.session = session
    local types = hs.eventtap.event.types
    self.keys = hs.eventtap.new({ types.keyDown, types.flagsChanged,
        types.leftMouseDown, types.rightMouseDown, types.otherMouseDown }, function(event)
        if event:getType() == types.flagsChanged then
            if not event:getFlags().cmd then self:finish() end
        elseif event:getType() == types.keyDown then
            local code = event:getKeyCode()
            if code == hs.keycodes.map.escape then self:cancel(); return true end
            if code ~= hs.keycodes.map.tab then self:cancel() end
        else
            self:cancel()
        end
        return false
    end):start()
    if not self.keys:isEnabled() then
        self:cancel()
        log.e("Cannot monitor picker input; check Hammerspoon Accessibility permission")
        return
    end
    -- Also detect Command release if macOS drops a flagsChanged event. Stop
    -- instead of stealing focus if the input tap itself becomes unavailable.
    self.release = hs.timer.doEvery(0.02, function()
        if not self.keys:isEnabled() then self:cancel(); return end
        if not hs.eventtap.checkKeyboardModifiers().cmd then self:finish() end
    end)
    self.request(function(snapshot)
        if self.session ~= session then return end
        if not snapshot or #snapshot.entries == 0 then self:cancel(); return end
        session.snapshot = snapshot
        local origin = (snapshot.focused or session.direction < 0) and 0 or -1
        session.selected = (origin + session.delta) % #snapshot.entries + 1
        if session.released or not hs.eventtap.checkKeyboardModifiers().cmd then
            self:finish()
        else
            self:draw()
            self:captureNext()
        end
    end)
end

function Picker:start()
    if self.shortcut then return end
    -- macOS reserves Cmd-Tab, so Carbon hotkey registration fails. Consume the
    -- actual Tab events before Dock sees them instead of using hs.hotkey.
    local types = hs.eventtap.event.types
    self.shortcut = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
        if event:getKeyCode() ~= hs.keycodes.map.tab then return false end
        if event:getType() == types.keyUp then
            if self.tabDown then self.tabDown = nil; return true end
            return false
        end
        local flags = event:getFlags()
        if flags.cmd and not flags.alt and not flags.ctrl then
            self.tabDown = true
            self:step(flags.shift and -1 or 1)
            return true
        end
        return false
    end):start()
    if not self.shortcut:isEnabled() then
        self.shortcut:stop()
        self.shortcut = nil
        error("Cannot intercept Cmd-Tab; check Hammerspoon Accessibility permission")
    end
end

function Picker:stop()
    self:cancel()
    if self.shortcut then self.shortcut:stop(); self.shortcut = nil end
    self.tabDown = nil
end

function Picker:status()
    local session = self.session
    local snapshot = session and session.snapshot
    local ids, previews = {}, 0
    for _, entry in ipairs(snapshot and snapshot.entries or {}) do
        table.insert(ids, entry.window.window_server_id)
        if entry.preview then previews = previews + 1 end
    end
    return { active = session ~= nil, visible = self.canvas ~= nil,
        enabled = self.shortcut ~= nil and self.shortcut:isEnabled(),
        workspace = snapshot and snapshot.workspace, windows = ids, previews = previews,
        selected = session and session.selected }
end

return Picker
