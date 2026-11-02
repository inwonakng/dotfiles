-- Conservative external editing: only AX text inputs with a readable value and
-- restorable selection qualify. Never fall back to copying/pasting an unknown UI.
require("hs.axuielement")
require("hs.eventtap")
require("hs.task")
require("hs.timer")
require("hs.window")
require("hs.pasteboard")
local M = {}
local log = hs.logger.new("edit-popup", "info")
local titlePrefix = "Hammerspoon Edit Popup "
local moduleDirectory = assert(debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$"))
local active, tap
local fail, restoreClipboard
local tasks, timers = {}, {}

local function later(delay, fn)
    local timer
    timer = hs.timer.doAfter(delay, function()
        timers[timer] = nil
        local ok, err = pcall(fn)
        if not ok then
            if active then fail(active, tostring(err)) else log.e(tostring(err)) end
        end
    end)
    timers[timer] = true
    return timer
end

local function run(path, args, callback)
    local task
    task = hs.task.new(path, function(code, stdout, stderr)
        tasks[task] = nil
        callback(code, stdout, stderr)
    end, args)
    if not task then callback(-1, "", "Cannot create task: " .. path); return end
    tasks[task] = true
    if not task:start() then
        tasks[task] = nil
        callback(-1, "", "Cannot start task: " .. path)
    end
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local value = file:read("*a")
    file:close()
    return value
end

local function removeFiles(session)
    for _, name in ipairs({ "buffer.txt", "ready", "apply", "result", "result.tmp" }) do
        os.remove(session.directory .. "/" .. name)
    end
    hs.fs.rmdir(session.directory)
end

local function notify(message)
    log.w(message)
    hs.notify.new({ title = "Neovim edit popup", informativeText = message }):send()
end

fail = function(session, message)
    if active ~= session then return end
    if session.guard then session.guard:stop() end
    restoreClipboard(session)
    active = nil
    notify(message .. (session.directory and ("\nText retained at " .. session.directory .. "/buffer.txt") or ""))
end

-- Accessibility ranges count UTF-16 code units, not Lua bytes or codepoints.
local function textRange(value, range)
    local units, first, last = 0, nil, nil
    for byte, code in utf8.codes(value) do
        if units == range.location then first = byte end
        if units == range.location + range.length then last = byte end
        units = units + (code > 0xffff and 2 or 1)
    end
    if units == range.location then first = #value + 1 end
    if units == range.location + range.length then last = #value + 1 end
    if not first or not last then return nil end
    return value:sub(first, last - 1), value:sub(1, first - 1), value:sub(last), units
end

local function focusedElement()
    return hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
end

local function editableInput(element)
    local role = element:attributeValue("AXRole")
    return (role == "AXTextField" or role == "AXTextArea" or role == "AXComboBox")
        and element:attributeValue("AXSubrole") ~= "AXSecureTextField"
        and element:attributeValue("AXProtectedContent") ~= true
        and element:attributeValue("AXEnabled") ~= false
        and element:attributeValue("AXEditable") ~= false
        and element:isAttributeSettable("AXSelectedTextRange")
        and (element:isAttributeSettable("AXValue")
            or element:isAttributeSettable("AXSelectedText")
            or element:attributeValue("AXEditable") == true)
end

local function capture()
    if hs.eventtap.isSecureInputEnabled() then return nil end
    local window, element = hs.window.focusedWindow(), focusedElement()
    if not window or not element or not editableInput(element) then return nil end
    local value = element:attributeValue("AXValue")
    local range = element:attributeValue("AXSelectedTextRange")
    if type(value) ~= "string" or type(range) ~= "table"
        or type(range.location) ~= "number" or type(range.length) ~= "number"
        or range.location < 0 or range.length < 0 then return nil end
    local selected, before, after, length = textRange(value, range)
    if not selected then return nil end
    if range.length == 0 then
        selected, before, after = value, "", ""
        range = { location = 0, length = length }
    end
    return { element = element, window = window, app = window:application(),
        original = value, range = range, initial = selected, before = before, after = after }
end

local function validTarget(session)
    return not hs.eventtap.isSecureInputEnabled()
        and session.element:isValid() and session.window:id() ~= nil
        and session.element:pid() == session.app:pid()
        and editableInput(session.element)
        and session.element:attributeValue("AXValue") == session.original
end

local function targetFocused(session)
    local window = hs.window.focusedWindow()
    return window and window:id() == session.window:id()
        and hs.application.frontmostApplication() == session.app
        and focusedElement() == session.element
end

restoreClipboard = function(session)
    if session.clipboardCount and hs.pasteboard.changeCount() == session.clipboardCount then
        hs.pasteboard.writeAllData(session.clipboard)
    end
    session.clipboardCount = nil
end

local function paste(session, edited)
    if not validTarget(session) or not targetFocused(session) then
        fail(session, "The original input changed or could not be focused. Nothing pasted."); return
    end
    session.element:setAttributeValue("AXSelectedTextRange", session.range)
    local range = session.element:attributeValue("AXSelectedTextRange")
    if not range or range.location ~= session.range.location or range.length ~= session.range.length
        or not targetFocused(session) or not validTarget(session) then
        fail(session, "Could not restore the original selection. Nothing pasted."); return
    end
    local expected = session.before .. edited .. session.after
    if expected == session.original then
        active = nil
        removeFiles(session)
        return -- A no-op edit must not race clipboard restoration with a paste.
    end
    if edited == "" then
        if session.range.length > 0 then hs.eventtap.keyStroke({}, "delete", 0, session.app) end
    else
        -- Preserve the clipboard as it is NOW, not as it was when editing began.
        session.clipboard = hs.pasteboard.readAllData()
        if not hs.pasteboard.setContents(edited) then
            fail(session, "Could not set the clipboard. Nothing pasted."); return
        end
        session.clipboardCount = hs.pasteboard.changeCount()
        hs.eventtap.keyStroke({ "cmd" }, "v", 0, session.app)
    end
    local deadline = hs.timer.secondsSinceEpoch() + 1
    local function confirm()
        if active ~= session then return end
        if session.element:isValid() and session.element:attributeValue("AXValue") == expected then
            restoreClipboard(session)
            active = nil
            removeFiles(session)
        elseif hs.timer.secondsSinceEpoch() >= deadline then
            restoreClipboard(session)
            fail(session, "Paste could not be confirmed; it will not be retried.")
        else
            later(0.05, confirm)
        end
    end
    later(0.05, confirm)
end

local function returnToInput(session, edited)
    if not validTarget(session) then
        fail(session, "The original input changed or disappeared. Nothing pasted."); return
    end
    session.window:focus()
    session.element:setAttributeValue("AXFocused", true)
    local deadline = hs.timer.secondsSinceEpoch() + 1
    local interrupted = false
    local types = hs.eventtap.event.types
    session.guard = hs.eventtap.new({ types.keyDown, types.leftMouseDown, types.rightMouseDown,
        types.otherMouseDown }, function() interrupted = true; return false end):start()
    local function check()
        if active ~= session then session.guard:stop(); return end
        if interrupted or not session.guard:isEnabled() then
            session.guard:stop()
            fail(session, "Focus restoration was interrupted. Nothing pasted.")
        elseif targetFocused(session) then
            session.guard:stop()
            paste(session, edited)
        elseif hs.timer.secondsSinceEpoch() >= deadline then
            session.guard:stop()
            fail(session, "Could not focus the original input. Nothing pasted.")
        else
            later(0.05, check)
        end
    end
    later(0.05, check)
end

local function cancel(session)
    active = nil
    removeFiles(session)
    -- Return after cancelling in the popup, but do not steal focus if the user
    -- already moved elsewhere while the editor was closing.
    local focused = hs.window.focusedWindow()
    if session.popup and (not focused or focused:id() == session.popup:id())
        and session.element:isValid() then
        session.window:focus()
        session.element:setAttributeValue("AXFocused", true)
    end
end

local function findPopup(session)
    for _, window in ipairs(hs.window.allWindows()) do
        local app = window:application()
        if app and app:bundleID() == "com.mitchellh.ghostty" and window:title() == session.title then
            return window
        end
    end
end

local function watch(session)
    if active ~= session then return end
    local ok, err = pcall(function()
        local result = readFile(session.directory .. "/result")
        if result then
            if result == "apply\n" then
                local edited = readFile(session.directory .. "/buffer.txt")
                if not edited then fail(session, "Cannot read the edited text."); return end
                returnToInput(session, edited)
            elseif result == "cancel\n" then
                cancel(session) -- Never writes to the source or clipboard.
            else
                fail(session, "Neovim did not exit successfully. Nothing pasted.")
            end
            return
        end
        local popup = not session.popup and findPopup(session) or nil
        if popup then
            session.popup = popup
            session.popupElement = hs.axuielement.windowElement(popup)
            local frame = session.window:screen():frame()
            local w, h = math.min(900, frame.w * 0.8), math.min(550, frame.h * 0.75)
            popup:setFrame({ x = frame.x + (frame.w - w) / 2, y = frame.y + (frame.h - h) / 2, w = w, h = h })
        elseif session.popupElement and not session.popupElement:isValid() then
            -- Closing the window sends SIGHUP; it never authorizes applying.
            cancel(session)
            return
        elseif not session.popup and hs.timer.secondsSinceEpoch() > session.launchDeadline then
            fail(session, "Ghostty did not open the editor window.")
            return
        end
        later(0.15, function() watch(session) end)
    end)
    if not ok then fail(session, tostring(err)) end
end

local function executable(name)
    for _, directory in ipairs({ os.getenv("HOME") .. "/.local/bin/", "/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/" }) do
        local path = directory .. name
        if hs.fs.attributes(path, "mode") == "file" then return path end
    end
end

local function launch(session)
    local nvim = executable("nvim")
    local ghostty = hs.application.pathForBundleID("com.mitchellh.ghostty")
    if not nvim or not ghostty then fail(session, "Neovim or Ghostty was not found."); return end
    local temporary = (os.getenv("TMPDIR") or "/tmp/"):gsub("/+$", "")
    run("/usr/bin/mktemp", { "-d", temporary .. "/hs-edit-popup.XXXXXX" }, function(code, stdout, stderr)
        if active ~= session then return end
        if code ~= 0 then fail(session, "Cannot create a private temporary directory: " .. stderr); return end
        session.directory = stdout:gsub("\n$", "")
        local ok, err = pcall(function()
            if not validTarget(session) or not targetFocused(session) then
                active = nil; removeFiles(session); return
            end
            local file = assert(io.open(session.directory .. "/buffer.txt", "wb"))
            assert(file:write(session.initial))
            assert(file:close())
            session.title = titlePrefix .. session.directory:match("[^/]+$")
            local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
            local command = table.concat({ "/bin/bash", quote(moduleDirectory .. "/edit-popup.sh"),
                quote(nvim), quote(moduleDirectory .. "/edit-popup-nvim.lua"), quote(session.directory) }, " ")
            session.launchDeadline = hs.timer.secondsSinceEpoch() + 15
            run("/usr/bin/open", { "-na", ghostty, "--args", "--title=" .. session.title,
                "--window-save-state=never", "--quit-after-last-window-closed=true", "--initial-window=true",
                "--wait-after-command=false", "--confirm-close-surface=false", "--working-directory=" .. session.directory,
                "-e", "/bin/bash", "-c", command }, function(exit, _, errors)
                if exit ~= 0 then fail(session, "Cannot launch Ghostty: " .. errors) end
            end)
            watch(session)
        end)
        if not ok then fail(session, tostring(err)) end
    end)
end

function M.start()
    if tap then return end
    local types = hs.eventtap.event.types
    local swallowed = false
    tap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
        if event:getKeyCode() ~= hs.keycodes.map.o then return false end
        if event:getType() == types.keyUp then
            local consume = swallowed; swallowed = false; return consume
        end
        if swallowed then return true end
        local flags = event:getFlags()
        if active or not flags.ctrl or flags.cmd or flags.alt or flags.shift or flags.fn then return false end
        local ok, session = pcall(capture)
        if not ok then log.w(tostring(session)); return false end
        if not session then return false end
        active, swallowed = session, true
        -- Do not launch processes or move focus inside the event-tap callback.
        later(0, function() if active == session then launch(session) end end)
        return true
    end):start()
    if not tap:isEnabled() then notify("Cannot watch Ctrl+o. Check Hammerspoon Accessibility/Input Monitoring permissions.") end
end

function M.stop()
    if tap then tap:stop(); tap = nil end
    if active then
        if active.guard then active.guard:stop() end
        restoreClipboard(active)
        fail(active, "Hammerspoon reloaded; automatic paste-back was cancelled.")
    end
    for timer in pairs(timers) do timer:stop() end
    for task in pairs(tasks) do task:terminate() end
    timers, tasks = {}, {}
end

return M
