-- Rift owns workspace/window definitions; Hammerspoon owns the custom automation.
-- hs.task captures its loading Lua state for late stream callbacks. Load native
-- extensions on the main thread before any queued coroutine can first use them.
require("hs.task")
require("hs.timer")
require("hs.json")
require("hs.fs")
require("hs.logger")
require("hs.window")
require("hs.window.filter")
require("hs.eventtap")
require("hs.screen.watcher")
require("hs.spaces.watcher")
local History = require("rift.history")
local Indicator = require("rift.indicator")
local Picker = require("rift.picker")
local M = {}
local log = hs.logger.new("rift", "info")
local home = os.getenv("HOME")
local cacheFile = home .. "/.cache/rift-windows.json"
local cache = hs.fs.attributes(cacheFile) and hs.json.read(cacheFile)
if hs.fs.attributes(cacheFile) and type(cache) ~= "table" then
    error("Cannot read Rift window history: " .. cacheFile)
end
cache = cache or {}

local function executable(name)
    for _, directory in ipairs({ "/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/" }) do
        local path = directory .. name
        if hs.fs.attributes(path, "mode") == "file" then return path end
    end
    error("Executable not found: " .. name)
end

local riftCli = executable("rift-cli")
local bordersCli = executable("borders")
local running = false
local generation = 0
local jobs, tasks, timers = {}, {}, {}
local current, history, stream, servers
local closeWatcher, lastNativeFocus, closingNativeFocus
local nativeWindows, inputGuards = {}, {}
local focusIntent, closeRevision = 0, 0
local workspaceSnapshots = {}
local heartbeat, expiry, expiryQueued
local indicator, indicatorPending, screenWatcher, spaceWatcher, picker
local borderQueued, borderWindows = {}, {}
local lastError
local workspaceRevision = 0
local workspaceRevisions = {} -- History queries are independent across native Spaces.
local pump

local function now() return hs.timer.absoluteTime() / 1e9 end

local function persist()
    hs.fs.mkdir(home .. "/.cache")
    local temporary = cacheFile .. ".tmp"
    local file = assert(io.open(temporary, "w"))
    local ok, err = file:write(hs.json.encode(cache), "\n")
    local closed, closeError = file:close()
    assert(ok, err)
    assert(closed, closeError)
    assert(os.rename(temporary, cacheFile))
end

local function save(workspace, key, window)
    cache[workspace] = cache[workspace] or {}
    cache[workspace][key] = window and {
        id = window.id, window_server_id = window.window_server_id,
    } or nil
    persist()
end

local function resume(thread, ...)
    if not running or current ~= thread then return end
    local ok, err = coroutine.resume(thread, ...)
    if not ok then
        lastError = tostring(err)
        log.e(lastError)
    end
    if not ok or coroutine.status(thread) == "dead" then
        current = nil
        pump()
    end
end

pump = function()
    if not running or current or #jobs == 0 then return end
    current = coroutine.create(table.remove(jobs, 1))
    resume(current)
end

local function enqueue(fn)
    if not running then return end
    table.insert(jobs, fn)
    pump()
end

-- Await child processes without blocking Hammerspoon's UI/IPC thread. All actions
-- and stream events share this queue so focus history observes the original order.
local function run(path, args, allowFailure, timeout)
    local thread = coroutine.running()
    local task, watchdog
    local completed = false
    local output, errors = {}, {}
    local function finish(code, stdout, stderr)
        if completed then return end
        completed = true
        if watchdog then watchdog:stop(); timers[watchdog] = nil end
        if task then tasks[task] = nil end
        -- hs.task can deliver its last streaming chunk after termination. Defer
        -- resumption so that chunk precedes the unread tail from the exit callback.
        local settled
        settled = hs.timer.doAfter(0, function()
            timers[settled] = nil
            resume(thread, code, table.concat(output) .. (stdout or ""),
                table.concat(errors) .. (stderr or ""))
        end)
        timers[settled] = true
    end
    task = hs.task.new(path, finish, function(_, stdout, stderr)
        table.insert(output, stdout or "")
        table.insert(errors, stderr or "")
        return true
    end, args)
    assert(task, "Cannot create task: " .. path)
    tasks[task] = true
    if not task:start() then tasks[task] = nil; error("Cannot start task: " .. path) end
    task:closeInput()
    if timeout ~= false then
        watchdog = hs.timer.doAfter(timeout or 3, function()
            task:terminate()
            finish(-1, "", "Command timed out: " .. path)
        end)
        timers[watchdog] = true
    end
    local code, stdout, stderr = coroutine.yield()
    if code ~= 0 and not allowFailure then
        error(string.format("%s %s: %s (exit %s)", path, table.concat(args, " "), stderr, code))
    end
    return stdout, code
end

local function sleep(seconds)
    local thread = coroutine.running()
    local timer
    timer = hs.timer.doAfter(seconds, function()
        timers[timer] = nil
        resume(thread)
    end)
    timers[timer] = true
    coroutine.yield()
end

local function cli(args) return run(riftCli, args) end

local function query(kind, space)
    local revision = workspaceRevision
    local args = { "query", kind }
    if space then table.insert(args, "--space-id"); table.insert(args, tostring(space)) end
    local output = cli(args)
    local value = hs.json.decode(output)
    assert(value ~= nil or output:match("^%s*null%s*$"), "Invalid Rift JSON: " .. output)
    if kind == "workspaces" and revision == workspaceRevision then
        for _, workspace in ipairs(value) do
            workspaceSnapshots[workspace.id] = {
                windows = workspace.windows, active = workspace.is_active, revision = revision,
            }
            -- Blacklisted apps may receive native focus without a Rift focus
            -- event. Bind their native observations to confirmed membership too.
            for _, window in ipairs(workspace.windows) do
                local record = nativeWindows[window.window_server_id]
                if record and record.pid == window.id.pid then
                    record.window, record.workspace = window, workspace.id
                    record.last_tiled = (cache[workspace.id] or {}).last_tiled
                end
            end
        end
    end
    return value
end

function M.refreshIndicator()
    if not running or not stream then return end
    if indicatorPending then indicatorPending.dirty = true; return end
    local pending, token = {}, generation
    indicatorPending = pending
    enqueue(function()
        if token ~= generation then return end
        pending.dirty = false
        local ok, err = pcall(function()
            local displays = query("displays")
            table.sort(displays, function(a, b)
                local left, right = a.frame.origin, b.frame.origin
                if left.x ~= right.x then return left.x < right.x end
                if left.y ~= right.y then return left.y < right.y end
                return a.uuid < b.uuid
            end)
            local entries = {}
            for _, display in ipairs(displays) do
                if display.space then
                    for _, workspace in ipairs(query("workspace-layout", display.space)) do
                        if workspace.is_active then
                            table.insert(entries, {
                                uuid = display.uuid, name = display.name,
                                workspace = workspace.name, mode = workspace.layout_mode,
                            })
                            break
                        end
                    end
                end
            end
            if token == generation and stream and not pending.dirty then indicator:update(entries) end
        end)
        if indicatorPending == pending then indicatorPending = nil end
        if token ~= generation then return end
        if not ok then indicator:clear(); error(err) end
        if pending.dirty then M.refreshIndicator() end
    end)
end

local function context()
    -- Keep membership and active workspace in one snapshot across async queries.
    for _, workspace in ipairs(query("workspaces")) do
        if workspace.is_active then return workspace.windows, workspace.id end
    end
    return {}, "default"
end

local function nativeFocused(windows)
    local native = hs.window.focusedWindow()
    if not native then return nil, false end
    local app = native:application()
    for _, window in ipairs(windows) do
        if app and window.window_server_id == native:id() and window.id.pid == app:pid() then
            return window, true
        end
    end
    return nil, true -- Native focus outside this workspace is still real focus.
end

local function nativeWindow(window)
    local app = hs.application.applicationForPID(window.id.pid)
    local native = app and window.window_server_id and app:getWindow(window.window_server_id)
    assert(native and app:pid() == window.id.pid, "Rift window is no longer available")
    return native, app
end

local function stackFloats(windows, target)
    local failures = {}
    local function attempt(fn)
        local ok, err = pcall(fn)
        if not ok then table.insert(failures, tostring(err)) end
    end
    -- The target must already be focused. AXRaise alone can leave inactive
    -- windows below the foreground app, or change main within that same app.
    -- Do not yield or activate intermediate apps during this batch.
    for _, window in ipairs(windows) do
        if window.is_floating and not History.sameId(window.id, target.id) then
            attempt(function()
                local native = nativeWindow(window)
                assert(native:raise(), "Cannot raise Rift window " .. tostring(window.window_server_id))
            end)
        end
    end
    -- Same-app raises may have changed main. Restore the intended target last,
    -- even if an intermediate window closed or failed to raise.
    attempt(function()
        local native = nativeWindow(target)
        assert(native:becomeMain(), "Cannot restore Rift focus target")
        assert(native:raise(), "Cannot raise Rift focus target")
    end)
    return failures
end

local function focusedId()
    local window = hs.window.focusedWindow()
    return window and window:id()
end

local function frontmostPid()
    local app = hs.application.frontmostApplication()
    return app and app:pid()
end

local function floatsAboveTiles(windows, target)
    -- This is the WindowServer ID order used by hs.window.orderedWindows(),
    -- without enumerating every application's AX windows again.
    local positions = {}
    for index, id in ipairs(hs.window._orderedwinids()) do positions[id] = index end
    local firstFloat, lastFloat, firstTile = math.huge, 0, math.huge
    for _, window in ipairs(windows) do
        local position = positions[window.window_server_id]
        -- Windows absent from the on-screen order are hidden/minimized; do not
        -- reveal them or include inactive workspaces in the stacking contract.
        if position then
            if window.is_floating then
                firstFloat = math.min(firstFloat, position)
                lastFloat = math.max(lastFloat, position)
            else
                firstTile = math.min(firstTile, position)
            end
        end
    end
    return positions[target.window_server_id] == firstFloat and lastFloat < firstTile
end

local function watchInput()
    local cancelled = false
    local types = hs.eventtap.event.types
    local guard = hs.eventtap.new({ types.keyDown, types.leftMouseDown,
        types.rightMouseDown, types.otherMouseDown }, function()
        cancelled = true
        return false
    end):start()
    if not guard:isEnabled() then
        guard:stop()
        log.w("Cannot monitor input; skipping automatic focus restoration")
        return nil
    end
    inputGuards[guard] = true
    return guard, function() return not cancelled end
end

local function stopWatchingInput(guard)
    guard:stop()
    inputGuards[guard] = nil
end

local function setWindowBorder(window, floating)
    local id = window.window_server_id
    assert(type(id) == "number" and id > 0 and id % 1 == 0, "Invalid WindowServer ID")
    -- Keep the global default transparent. JankyBorders handles focus itself,
    -- using amber only for windows which Rift has identified as floating.
    -- Never pass hidpi here: it recreates borders and discards their overrides.
    run(bordersCli, {
        "apply-to=" .. tostring(id),
        "active_color=" .. (floating and "0xffffb454" or "0x00000000"),
        "inactive_color=0x00000000",
    })
end

local function focusWindow(window, afterFocus, expectedWorkspace, valid)
    local revision, initial, initialApp = workspaceRevision, focusedId(), frontmostPid()
    local windows, workspace = context()
    -- Queries yield to the event stream. Never apply an old action after a switch
    -- or after the user/app has selected a different native window.
    if revision ~= workspaceRevision or focusedId() ~= initial or frontmostPid() ~= initialApp
        or (valid and not valid())
        or (expectedWorkspace and workspace ~= expectedWorkspace) then return false end
    local available = History.find(windows, window)
    if not available then return false, "unavailable" end
    if available.is_floating ~= window.is_floating then return false end
    local native, app = nativeWindow(window)
    local id = native:id()
    if initial ~= id then
        -- Unlike hs.window:focus(), this has no delayed Finder becomeMain callback
        -- which could steal focus back after the user moves on.
        assert(native:becomeMain(), "Cannot make Rift window main")
        assert(app:setFrontmost(false), "Cannot activate Rift window application")
        assert(native:raise(), "Cannot raise Rift focus target")
    end
    local deadline = now() + 1
    local timeoutError = (afterFocus and "Floating window order did not settle for Rift window "
        or "Native focus did not reach Rift window ") .. tostring(window.window_server_id)
    local stacked, verified, reached = false, false, false
    local function stackAndRefresh(activeWindows)
        if afterFocus(activeWindows) == false then return false end
        if revision ~= workspaceRevision or (valid and not valid())
            or focusedId() ~= id or frontmostPid() ~= window.id.pid then return false end
        -- AXRaise orders app windows, not JankyBorders' separate windows.
        -- Reapplying the target's settings also reorders its border. Do this
        -- before the yielding verification queries leave a stale border visible.
        setWindowBorder(window, true)
        return true
    end
    while true do
        if revision ~= workspaceRevision or (valid and not valid()) then return false end
        local actual = focusedId()
        if actual == id then
            reached = true
            -- Each batch stays synchronous, but its success is checked against
            -- WindowServer order after yielding, not AXRaise's return value.
            if afterFocus and not stacked then
                stacked = stackAndRefresh(windows)
            end
            if focusedId() ~= id then return false end
            local activeWindows, activeWorkspace = context()
            if revision ~= workspaceRevision or workspace ~= activeWorkspace
                or (valid and not valid()) then return false end
            local member = History.find(activeWindows, window)
            if not member then return false, "unavailable" end
            local observed = nativeFocused(activeWindows)
            if member.is_floating ~= window.is_floating or not observed
                or not History.sameId(observed.id, window.id) then return false end
            if not afterFocus then return true end
            if now() >= deadline then error(timeoutError) end
            if stacked and floatsAboveTiles(activeWindows, member) then
                -- Require a second observation after another event-loop turn
                -- and fresh membership query to catch deferred activation raises.
                if verified then return true end
                verified = true
            else
                verified = false
                stacked = stackAndRefresh(activeWindows)
                if focusedId() ~= id then return false end
            end
            windows = activeWindows
        elseif reached or (actual and actual ~= initial) then
            return false
        end
        if now() >= deadline then error(timeoutError) end
        sleep(0.02)
    end
end

local function focus(window, afterFocus, expectedWorkspace, valid)
    local intent = focusIntent
    local guard, inputValid
    if afterFocus then
        guard, inputValid = watchInput()
        if not guard then return false end
    end
    local function currentIntent()
        return intent == focusIntent and (not valid or valid())
            and (not inputValid or inputValid())
    end
    -- Always remove the temporary input listener, including cancellation/error
    -- paths which yield through native tasks before returning here.
    local ok, selected, reason = pcall(focusWindow, window, afterFocus, expectedWorkspace, currentIntent)
    if guard then stopWatchingInput(guard) end
    if not ok then error(selected, 0) end
    return selected, reason
end

local function cachedWindow(windows, workspace, key, predicate)
    local window = History.find(windows, (cache[workspace] or {})[key])
    if window and predicate(window) then return window end
end

local function observeNativeFocus(native)
    local app = native:application()
    local id = native:id()
    if not app or not id or id <= 0 then return end
    -- A successor can be reported before the destruction notification.
    -- Keep its predecessor only if that AX window is already dead. Moving away
    -- from a live window is ordinary focus intent, not permission to restore it.
    if lastNativeFocus and lastNativeFocus.native ~= native then
        local role = lastNativeFocus.native:role()
        closingNativeFocus = (not role or role == "") and lastNativeFocus or nil
    end
    lastNativeFocus = { native = native, id = id, pid = app:pid() }
    for workspace, snapshot in pairs(workspaceSnapshots) do
        for _, window in ipairs(snapshot.windows) do
            if window.window_server_id == id and window.id.pid == lastNativeFocus.pid then
                lastNativeFocus.window, lastNativeFocus.workspace = window, workspace
                lastNativeFocus.last_tiled = (cache[workspace] or {}).last_tiled
            end
        end
    end
    nativeWindows[id] = lastNativeFocus
end

local function restoreAfterClose(native)
    local source
    -- Destruction callbacks may carry dead AX objects without usable IDs/PIDs.
    -- Compare the retained native objects instead of querying their properties.
    for id, record in pairs(nativeWindows) do
        if record.native == native then source = record; nativeWindows[id] = nil; break end
    end
    if not source or not history then return end
    local eligible = source == lastNativeFocus or source == closingNativeFocus
    if source == lastNativeFocus then lastNativeFocus = nil end
    if source == closingNativeFocus then closingNativeFocus = nil end
    local closed = history:takeClosed(source.id, source.pid)
    if not closed and source.window then
        closed = { window = source.window, workspace = source.workspace, last_tiled = source.last_tiled }
    end
    if not eligible or not closed or not closed.window.is_floating then return end
    local snapshot = workspaceSnapshots[closed.workspace]
    if not snapshot or not snapshot.active or snapshot.revision ~= workspaceRevision then return end
    closeRevision = closeRevision + 1
    local token, controller, revision = generation, history, workspaceRevision
    local intent, closing = focusIntent, closeRevision
    -- Observe only while this close is pending; never inspect/store input.
    local guard, inputValid = watchInput()
    if not guard then return end
    local function valid()
        return inputValid() and token == generation and revision == workspaceRevision
            and intent == focusIntent and closing == closeRevision
    end
    local function availableWindows(windows)
        local available = {}
        for _, window in ipairs(windows) do
            -- Rift can still list the confirmed dead source for several events.
            if not History.sameId(window.id, closed.window.id) then
                local found, candidate = pcall(nativeWindow, window)
                if found and candidate:isVisible() and not candidate:isMinimized() then
                    table.insert(available, window)
                end
            end
        end
        return available
    end
    -- Do the first native handoff right in the destruction callback. Do not put
    -- a sleep, CLI round trip, or the existing job backlog in front of it.
    local handedOff, handoffError = pcall(function()
        local windows = availableWindows(snapshot.windows)
        local target = controller:closeTarget(closed, windows)
        if not target or not valid() then return end
        local nativeTarget, app = nativeWindow(target)
        assert(nativeTarget:becomeMain(), "Cannot make close fallback main")
        assert(app:setFrontmost(false), "Cannot activate close fallback")
        assert(nativeTarget:raise(), "Cannot raise close fallback")
        if target.is_floating then stackFloats(windows, target) end
    end)
    if not handedOff then log.w("Immediate close handoff: " .. tostring(handoffError)) end
    local deadline = now() + 1
    enqueue(function()
        local ok, err = pcall(function()
            -- macOS/Rift may deliver their automatic successor after our first
            -- handoff (including Finder's ID 0 -> tile). This is still the same
            -- close operation, unless actual input/navigation supersedes it.
            while valid() do
                local windows, workspace = context()
                if not valid() or workspace ~= closed.workspace then return end
                if now() >= deadline then error("Close focus did not settle on " .. closed.workspace) end
                local available = availableWindows(windows)
                local target = controller:closeTarget(closed, available)
                if not target then return end
                local removed = not History.find(windows, closed.window)
                local failures = {}
                local selected = controller.focus(target, target.is_floating and function(activeWindows)
                    -- Verification may still query the dead source. Never try
                    -- to raise it while Rift catches up with AX destruction.
                    failures = stackFloats(availableWindows(activeWindows), target)
                    return #failures == 0
                end or nil, workspace, valid)
                if #failures > 0 then error("Cannot raise close fallback:\n" .. table.concat(failures, "\n")) end
                if selected and removed then
                    controller:remember(workspace, target)
                    return
                end
                -- A native automatic fallback can interrupt focus verification.
                -- Retry only this confirmed close, with fresh membership.
                if not valid() then return end
                if now() >= deadline then error("Close focus did not settle on " .. closed.workspace) end
                sleep(0.02)
            end
        end)
        stopWatchingInput(guard)
        if not ok then error(err) end
    end)
end

local function refreshBorder(space, force)
    if not space then
        local layout = query("layout")
        if not layout then return end
        space = layout.space_id
    end
    local workspaces = query("workspaces", space)
    local _, code = run("/usr/bin/pgrep", { "-x", "borders" }, true)
    if code ~= 0 then error("JankyBorders is stopped; restart Rift or Hammerspoon") end
    local seen = {}
    -- Include inactive virtual workspaces so their floats are configured before
    -- entry. Keep other native Spaces' records when reconciling this one.
    for _, workspace in ipairs(workspaces) do
        for _, window in ipairs(workspace.windows) do
            local id = window.window_server_id
            if id then
                seen[id] = true
                local floating = window.is_floating == true
                local previous = borderWindows[id]
                local same = previous and History.sameId(previous.id, window.id)
                if (floating and (force or not same or not previous.is_floating))
                    or (previous and previous.is_floating and not floating) then
                    setWindowBorder(window, floating)
                end
                borderWindows[id] = {
                    id = window.id, window_server_id = id,
                    is_floating = floating, space = space,
                }
            end
        end
    end
    for id, window in pairs(borderWindows) do
        if window.space == space and not seen[id] then
            if window.is_floating then setWindowBorder(window, false) end
            borderWindows[id] = nil
        end
    end
end

function M.refreshBorder(space, force)
    if not running or not stream then return end
    local key = space or "active"
    local pending = borderQueued[key]
    if pending then pending.force = pending.force or force; return end
    pending = { force = force }
    borderQueued[key] = pending
    enqueue(function()
        borderQueued[key] = nil
        refreshBorder(space, pending.force)
    end)
end

local function startBorders()
    local uid = run("/usr/bin/id", { "-u" }):match("%d+")
    local function ready()
        local bootstrap = run("/bin/launchctl", { "print", "gui/" .. uid })
        return bootstrap:match("%s git%.felix%.borders%s") ~= nil
    end
    local options = {
        "style=round", "width=5.0", "hidpi=on",
        "active_color=0x00000000", "inactive_color=0x00000000",
    }
    if ready() then
        run(bordersCli, options)
    else
        -- hs.task terminates its children when the Lua state closes. Detach the
        -- daemon so Hammerspoon reload/quit does not also stop JankyBorders.
        local args = {
            "-c", '/usr/bin/nohup "$@" </dev/null >/dev/null 2>&1 & echo "$!"',
            "rift-borders", bordersCli,
        }
        for _, option in ipairs(options) do table.insert(args, option) end
        local output = run("/bin/sh", args)
        local pid = tostring(assert(tonumber(output:match("%d+")), "Cannot start JankyBorders"))
        local deadline = now() + 5
        while not ready() do
            local _, code = run("/bin/kill", { "-0", pid }, true)
            if code ~= 0 then error("JankyBorders exited before becoming ready") end
            if now() >= deadline then
                run("/bin/kill", { "-TERM", pid }, true)
                error("JankyBorders startup timed out")
            end
            sleep(0.05)
        end
    end
    borderWindows = {}
    refreshBorder(nil, true)
end

local borderEvents = {
    workspace_changed = true, windows_changed = true, layout_changed = true,
}

local function disconnect()
    generation = generation + 1
    if picker then picker:cancel() end
    indicatorPending = nil
    if indicator then indicator:clear() end
    if stream then stream:terminate(); stream = nil end
    if closeWatcher then closeWatcher:delete(); closeWatcher = nil end
    for guard in pairs(inputGuards) do guard:stop() end
    inputGuards = {}
    lastNativeFocus, closingNativeFocus = nil, nil
    nativeWindows, workspaceSnapshots = {}, {}
    history, servers = nil, nil
end

local function connect(pids)
    disconnect()
    servers = pids
    history = History.new(cache, save, focus, now, stackFloats, nativeFocused)
    local token, buffered = generation, ""
    stream = hs.task.new(riftCli, function(code, _, stderr)
        if token ~= generation then return end
        stream = nil
        indicator:clear()
        if picker then picker:cancel() end
        if running then log.w("Rift event stream ended (" .. code .. "): " .. stderr) end
    end, function(_, stdout, stderr)
        if not running or token ~= generation then return false end
        if stderr ~= "" then log.w(stderr) end
        buffered = buffered .. stdout
        while true do
            local newline = buffered:find("\n", 1, true)
            if not newline then break end
            local line = buffered:sub(1, newline - 1)
            buffered = buffered:sub(newline + 1)
            local event = hs.json.decode(line)
            if type(event) == "table" then
                -- Observe switches immediately, not after a yielding focus action.
                if event.type == "workspace_changed" then
                    if picker then picker:cancel() end
                    workspaceRevision = workspaceRevision + 1
                    workspaceRevisions[event.space_id] = (workspaceRevisions[event.space_id] or 0) + 1
                end
                if event.type == "workspace_changed" or event.type == "layout_changed" then
                    M.refreshIndicator()
                end
                enqueue(function()
                    if token ~= generation then return end
                    if event.type == "workspace_changed" or event.type == "focused_window_changed"
                        or event.type == "windows_changed" or event.type == "layout_changed" then
                        local ok, err = pcall(function()
                            local revision = workspaceRevisions[event.space_id]
                            local workspaces = query("workspaces", event.space_id)
                            if revision == workspaceRevisions[event.space_id] then history:handle(event, workspaces) end
                        end)
                        if not ok then disconnect(); error(err) end
                    end
                    if borderEvents[event.type] then M.refreshBorder(event.space_id) end
                end)
            else
                log.e("Invalid Rift event: " .. line)
            end
        end
        return true
    end, { "subscribe", "mach", "*" })
    assert(stream and stream:start(), "Cannot subscribe to Rift events")
    M.refreshIndicator()
    local layout = query("layout")
    if layout then history:seed(layout.space_id, query("workspaces", layout.space_id)) end
    closeWatcher = hs.window.filter.new(true)
    closeWatcher:subscribe(hs.window.filter.windowFocused, observeNativeFocus)
    closeWatcher:subscribe(hs.window.filter.windowDestroyed, restoreAfterClose)
    local native = hs.window.focusedWindow()
    if native then observeNativeFocus(native) end
    enqueue(startBorders)
end

local function checkServer()
    local pids, code = run("/usr/bin/pgrep", { "-a", "-x", "rift" }, true)
    if code == 1 then disconnect(); return end
    assert(code == 0, "Cannot check Rift process")
    -- Mach subscriptions can remain alive after their Rift server dies.
    if not stream or pids ~= servers then
        local ok, err = pcall(connect, pids)
        if not ok then disconnect(); error(err) end
    end
end

-- A nil selector delegates last-workspace tracking to Rift. Explicit shortcuts
-- restore cached focus; app-driven entry and moved-window-follow stay native.
function M.switchWorkspace(selector)
    focusIntent = focusIntent + 1
    assert(selector == nil or type(selector) == "number" or type(selector) == "string",
        "Unsupported workspace selector")
    enqueue(function()
        local revision, initial = workspaceRevision, focusedId()
        local workspaces = query("workspaces")
        if revision ~= workspaceRevision or focusedId() ~= initial then return end
        local source, destination
        for _, workspace in ipairs(workspaces) do
            if workspace.is_active then source = workspace end
            if (type(selector) == "number" and workspace.index == selector)
                or (type(selector) == "string" and workspace.name == selector) then
                destination = workspace
            end
        end
        if not source or (selector ~= nil and not destination) then return end
        local controller = history or History.new(cache, save, focus, now, stackFloats, nativeFocused)
        controller:remember(source.id, nativeFocused(source.windows))
        -- Save references before the switch, not after automatic entry can record
        -- Rift's incoming tile. Snapshot every workspace for the unknown "last".
        local remembered = {}
        for workspace, state in pairs(cache) do remembered[workspace] = state.last_focused end
        local args = { "execute", "workspace", "last" }
        if destination then
            args = { "execute", "workspace", "switch", tostring(destination.index) }
        end
        cli(args)
        local switchedRevision = workspaceRevision
        -- Multiple observed transitions mean newer workspace intent.
        if switchedRevision > revision + 1 then return end
        local windows, workspace = context()
        -- Rift's own entry focus arrives after CLI completion. It is expected
        -- during this query; focus() establishes cancellation from that entry.
        if switchedRevision ~= workspaceRevision then return end
        if workspace == source.id or (destination and workspace ~= destination.id) then return end
        local target = History.find(windows, remembered[workspace])
        if not target then return end
        controller:selectGroup(workspace, target, target.is_floating)
    end)
end

function M.toggleAllFloating()
    focusIntent = focusIntent + 1
    enqueue(function()
        local revision, initial = workspaceRevision, focusedId()
        local windows, workspace = context()
        if revision ~= workspaceRevision or focusedId() ~= initial then return end
        local window = nativeFocused(windows)
        local wasFloating = window and window.is_floating == true
        if not window then wasFloating = (cache[workspace] or {}).floats_up == true end
        local controller = history or History.new(cache, save, focus, now, stackFloats, nativeFocused)
        controller:remember(workspace, window)
        local predicate = function(w) return (w.is_floating == true) ~= wasFloating end
        local target = controller:recentWindow(workspace, windows, predicate)
            or cachedWindow(windows, workspace,
                wasFloating and "last_tiled" or "last_floating", predicate)
        if not target then
            for _, candidate in ipairs(windows) do
                if predicate(candidate) then target = candidate end
            end
        end
        if not target then return end
        if not controller:selectGroup(workspace, target, not wasFloating) then return end
        -- Commit explicit group intent only after verified native focus.
        -- Generic focus events (including workspace entry) never change it.
        cache[workspace] = cache[workspace] or {}
        cache[workspace].floats_up = not wasFloating
        persist()
    end)
end

function M.toggleFinder()
    focusIntent = focusIntent + 1
    enqueue(function()
        local windows, workspace = context()
        local window = nativeFocused(windows)
        local function nonFinder(w) return w.bundle_id ~= "com.apple.finder" end
        if window and not nonFinder(window) then
            local target = cachedWindow(windows, workspace, "last_non_finder", nonFinder)
            if not target then
                for _, candidate in ipairs(windows) do
                    if nonFinder(candidate) then target = candidate; break end
                end
            end
            if target then focus(target, nil, workspace) end
            return
        end
        if window then save(workspace, "last_non_finder", window) end
        local found = false
        for _, candidate in ipairs(windows) do
            if not nonFinder(candidate) then
                found = true
                -- One closed Finder window must not prevent visiting the remaining ones.
                local ok, focused, reason = pcall(focus, candidate, nil, workspace)
                -- A vanished member is skippable; new focus/workspace intent is not.
                if ok and not focused and reason ~= "unavailable" then return end
                if ok and focused and not candidate.is_floating then
                    pcall(cli, { "execute", "window", "toggle-float" })
                end
            end
        end
        if not found then
            run("/usr/bin/osascript", {
                "-e", 'tell application "Finder" to make new Finder window',
                "-e", 'tell application "Finder" to activate',
            }, false, false) -- First-run Automation consent must not be killed by the CLI timeout.
        end
    end)
end

function M.layoutPreserveFocus(operation)
    focusIntent = focusIntent + 1
    assert(operation == "toggle-stack" or operation == "toggle-orientation", "Unsupported layout operation")
    enqueue(function()
        local windows, workspace = context()
        local previous = nativeFocused(windows)
        cli({ "execute", "layout", operation })
        if not previous then return end
        sleep(0.05)
        local currentWindows, currentWorkspace = context()
        if currentWorkspace ~= workspace then return end
        local window = History.find(currentWindows, previous)
        if window then focus(window, nil, workspace) end
    end)
end

function M.toggleFloat()
    focusIntent = focusIntent + 1
    enqueue(function()
        local revision, initial = workspaceRevision, focusedId()
        local windows = query("windows")
        if revision ~= workspaceRevision or focusedId() ~= initial then return end
        local window = nativeFocused(windows)
        if window and window.is_floating and window.window_server_id then
            -- Hide before tiling, rather than waiting for a layout event to
            -- remove the former float's per-window amber setting afterward.
            setWindowBorder(window, false)
            borderWindows[window.window_server_id] = nil
            if revision ~= workspaceRevision or focusedId() ~= initial then
                refreshBorder()
                return
            end
        end
        local ok, err = pcall(cli, { "execute", "window", "toggle-float" })
        refreshBorder()
        if not ok then error(err) end
    end)
end

local function requestPicker(done)
    focusIntent = focusIntent + 1
    local intent, revision, token = focusIntent, workspaceRevision, generation
    local initial, initialApp = focusedId(), frontmostPid()
    enqueue(function()
        local ok, snapshot = pcall(function()
            if not stream then return end
            local workspaces = query("workspaces")
            if intent ~= focusIntent or revision ~= workspaceRevision or token ~= generation
                or focusedId() ~= initial or frontmostPid() ~= initialApp then return end
            local active
            for _, workspace in ipairs(workspaces) do
                if workspace.is_focused then active = workspace; break end
                if workspace.is_active and not active then active = workspace end
            end
            if not active then return end
            local entries, seen, icons = {}, {}, {}
            local function add(window)
                if not window or seen[window.window_server_id] then return end
                local available = pcall(nativeWindow, window)
                if not available then return end
                seen[window.window_server_id] = true
                local bundle = window.bundle_id
                if bundle and icons[bundle] == nil then
                    icons[bundle] = hs.image.imageFromAppBundle(bundle) or false
                end
                table.insert(entries, { window = window, icon = icons[bundle] or nil })
            end
            local focused = nativeFocused(active.windows)
            add(focused)
            for _, record in ipairs(history and history.recent[active.id] or {}) do
                add(History.find(active.windows, record.window))
            end
            for _, window in ipairs(active.windows) do add(window) end
            return { entries = entries, workspace = active.id, name = active.name,
                focused = focused ~= nil, intent = intent, revision = revision, generation = token,
                initial = initial, initialApp = initialApp }
        end)
        done(ok and snapshot or nil)
        if not ok then error(snapshot) end
    end)
end

local function selectPicker(window, snapshot)
    if not running or not stream then return end
    local guard, inputValid = watchInput()
    if not guard then return end
    local function valid()
        return inputValid() and snapshot.intent == focusIntent
            and snapshot.revision == workspaceRevision and snapshot.generation == generation
    end
    enqueue(function()
        local ok, err = pcall(function()
            if not valid() or focusedId() ~= snapshot.initial or frontmostPid() ~= snapshot.initialApp then return end
            -- Resolve membership again: a window can close or move while the
            -- overlay is open. Never focus a stale selection in another workspace.
            local active
            for _, workspace in ipairs(query("workspaces")) do
                if workspace.id == snapshot.workspace and workspace.is_active then active = workspace; break end
            end
            if not active or not valid() or focusedId() ~= snapshot.initial
                or frontmostPid() ~= snapshot.initialApp then return end
            local member = History.find(active.windows, window)
            if not member then return end
            local native = nativeWindow(member)
            if native:isMinimized() then native:unminimize() end
            if history then history:selectGroup(active.id, member, member.is_floating, valid) end
        end)
        stopWatchingInput(guard)
        if not ok then error(err) end
    end)
end

function M.start()
    if running then return end
    indicator = Indicator.new()
    picker = Picker.new(requestPicker, selectPicker)
    running = true
    picker:start()
    local function displayChanged()
        picker:cancel()
        M.refreshIndicator()
    end
    screenWatcher = hs.screen.watcher.new(displayChanged):start()
    spaceWatcher = hs.spaces.watcher.new(displayChanged):start()
    enqueue(checkServer)
    heartbeat = hs.timer.doEvery(2, function()
        enqueue(function()
            checkServer()
            -- Reconcile after sleep or display changes missed by native watchers.
            M.refreshIndicator()
            -- apply-to silently ignores windows not yet known to JankyBorders.
            -- Reapply float overrides to recover from creation/recreation races.
            M.refreshBorder(nil, true)
        end)
    end)
    expiry = hs.timer.doEvery(0.05, function()
        if expiryQueued or not history then return end
        local due = false
        for _, pending in pairs(history.pending) do
            if pending.deadline and now() >= pending.deadline then due = true; break end
        end
        if not due then return end
        expiryQueued = true
        enqueue(function()
            expiryQueued = false
            if history then
                history:expire(function(space)
                    local revision = workspaceRevisions[space]
                    local workspaces = query("workspaces", space)
                    return revision == workspaceRevisions[space] and workspaces or {}
                end)
            end
        end)
    end)
end

function M.stop()
    running = false
    if picker then picker:stop(); picker = nil end
    disconnect()
    if screenWatcher then screenWatcher:stop(); screenWatcher = nil end
    if spaceWatcher then spaceWatcher:stop(); spaceWatcher = nil end
    if indicator then indicator:delete(); indicator = nil end
    if heartbeat then heartbeat:stop(); heartbeat = nil end
    if expiry then expiry:stop(); expiry = nil end
    for timer in pairs(timers) do timer:stop() end
    for task in pairs(tasks) do task:terminate() end
    -- JankyBorders is an independent daemon, not owned by a Hammerspoon reload.
    jobs, tasks, timers = {}, {}, {}
    current, expiryQueued = nil, nil
    borderQueued = {}
end

function M.status()
    return {
        running = running, connected = stream ~= nil, queued = #jobs,
        busy = current ~= nil, lastError = lastError, borderWindows = borderWindows,
        indicator = indicator and indicator:status(), picker = picker and picker:status(),
    }
end

return M
