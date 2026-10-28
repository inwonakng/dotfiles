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
local History = require("rift.history")
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
local nativeWindows = {}
local heartbeat, expiry, expiryQueued
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
    local args = { "query", kind }
    if space then table.insert(args, "--space-id"); table.insert(args, tostring(space)) end
    local output = cli(args)
    local value = hs.json.decode(output)
    assert(value ~= nil or output:match("^%s*null%s*$"), "Invalid Rift JSON: " .. output)
    return value
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

local function focus(window, afterFocus, expectedWorkspace)
    local revision, initial, initialApp = workspaceRevision, focusedId(), frontmostPid()
    local windows, workspace = context()
    -- Queries yield to the event stream. Never apply an old action after a switch
    -- or after the user/app has selected a different native window.
    if revision ~= workspaceRevision or focusedId() ~= initial or frontmostPid() ~= initialApp
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
    while true do
        if revision ~= workspaceRevision then return false end
        local actual = focusedId()
        if actual == id then
            -- Focus first, then stack/restore synchronously. Intermediate AXRaise
            -- focus changes are ours, not cancellation; verify the final target.
            if afterFocus then afterFocus(windows) end
            if focusedId() ~= id then return false end
            local activeWindows, activeWorkspace = context()
            if revision ~= workspaceRevision or workspace ~= activeWorkspace then return false end
            local member = History.find(activeWindows, window)
            if not member then return false, "unavailable" end
            local observed = nativeFocused(activeWindows)
            return member.is_floating == window.is_floating
                and observed ~= nil and History.sameId(observed.id, window.id)
        end
        if actual and actual ~= initial then return false end
        if now() >= deadline then
            error("Native focus did not reach Rift window " .. tostring(window.window_server_id))
        end
        sleep(0.02)
    end
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
    local successor = source == closingNativeFocus and lastNativeFocus
    if source == lastNativeFocus then lastNativeFocus = nil end
    if source == closingNativeFocus then closingNativeFocus = nil end
    local closed = history:takeClosed(source.id, source.pid)
    if not eligible or not closed or not closed.window.is_floating then return end
    -- Accept the immediate automatic successor, even in another app, but not an
    -- unrelated windowless application activation while destruction was queued.
    if frontmostPid() ~= source.pid and (not successor or successor.pid ~= frontmostPid()
        or successor.id ~= focusedId()) then return end
    local token, controller, revision = generation, history, workspaceRevision
    local initial, app = focusedId(), frontmostPid()
    local function unchanged()
        return token == generation and revision == workspaceRevision
            and focusedId() == initial and frontmostPid() == app
    end
    enqueue(function()
        -- AX destruction can precede Rift's removal. Wait only for this confirmed
        -- close, and abandon it on newer native focus or workspace intent.
        local deadline = now() + 0.5
        local windows, workspace
        repeat
            if not unchanged() then return end
            windows, workspace = context()
            if not unchanged() or workspace ~= closed.workspace then return end
            if not History.find(windows, closed.window) then break end
            if now() >= deadline then return end
            sleep(0.02)
        until false
        local available = {}
        for _, window in ipairs(windows) do
            local ok, candidate = pcall(nativeWindow, window)
            if ok and candidate:isVisible() and not candidate:isMinimized() then
                table.insert(available, window)
            end
        end
        local target = controller:closeTarget(closed, available)
        if target and unchanged() then controller:selectGroup(workspace, target, target.is_floating) end
    end)
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
    if stream then stream:terminate(); stream = nil end
    if closeWatcher then closeWatcher:delete(); closeWatcher = nil end
    lastNativeFocus, closingNativeFocus = nil, nil
    nativeWindows = {}
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
                    workspaceRevision = workspaceRevision + 1
                    workspaceRevisions[event.space_id] = (workspaceRevisions[event.space_id] or 0) + 1
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
    enqueue(function()
        local revision, initial = workspaceRevision, focusedId()
        local windows, workspace = context()
        if revision ~= workspaceRevision or focusedId() ~= initial then return end
        local window = nativeFocused(windows)
        local wasFloating = window and window.is_floating == true
        if not window then wasFloating = (cache[workspace] or {}).floats_up == true end
        if window then
            save(workspace, "last_focused", window)
            save(workspace, wasFloating and "last_floating" or "last_tiled", window)
        end
        local predicate = function(w) return (w.is_floating == true) ~= wasFloating end
        local target = cachedWindow(windows, workspace,
            wasFloating and "last_tiled" or "last_floating", predicate)
        if not target then
            for _, candidate in ipairs(windows) do
                if predicate(candidate) then target = candidate end
            end
        end
        if not target then return end
        local controller = history or History.new(cache, save, focus, now, stackFloats, nativeFocused)
        if not controller:selectGroup(workspace, target, not wasFloating) then return end
        -- Commit explicit group intent only after verified native focus.
        -- Generic focus events (including workspace entry) never change it.
        cache[workspace] = cache[workspace] or {}
        cache[workspace].floats_up = not wasFloating
        persist()
    end)
end

function M.toggleFinder()
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

function M.start()
    if running then return end
    running = true
    enqueue(checkServer)
    heartbeat = hs.timer.doEvery(2, function()
        enqueue(function()
            checkServer()
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
    disconnect()
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
    }
end

return M
