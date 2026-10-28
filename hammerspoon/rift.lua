-- Rift owns workspace/window definitions; Hammerspoon owns the custom automation.
-- hs.task captures its loading Lua state for late stream callbacks. Load native
-- extensions on the main thread before any queued coroutine can first use them.
require("hs.task")
require("hs.timer")
require("hs.json")
require("hs.fs")
require("hs.logger")
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
local heartbeat, expiry, expiryQueued
local borderQueued, borderColor
local lastError
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

local function focus(window)
    local args = { "execute", "window", "focus", "--window-id", hs.json.encode(window.id) }
    if window.window_server_id then
        table.insert(args, "--window-server-id")
        table.insert(args, tostring(window.window_server_id))
    end
    cli(args)
end

local function context()
    local windows = query("windows")
    for _, workspace in ipairs(query("workspaces")) do
        if workspace.is_active then return windows, workspace.id end
    end
    return windows, "default"
end

local function cachedWindow(windows, workspace, key, predicate)
    local window = History.find(windows, (cache[workspace] or {})[key])
    if window and predicate(window) then return window end
end

local function refreshBorder()
    local color = "0x00000000"
    local window = History.focused(query("windows"))
    if window and window.is_floating then color = "0xffffb454" end
    if color == borderColor then return end
    local _, code = run("/usr/bin/pgrep", { "-x", "borders" }, true)
    if code ~= 0 then error("JankyBorders is stopped; restart Rift or Hammerspoon") end
    -- Never pass hidpi on ordinary events: doing so recreates every border.
    run(bordersCli, { "active_color=" .. color })
    borderColor = color
end

function M.refreshBorder()
    if not running or borderQueued then return end
    borderQueued = true
    enqueue(function()
        borderQueued = false
        refreshBorder()
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
    borderColor = "0x00000000"
    refreshBorder()
end

local borderEvents = {
    focused_window_changed = true, workspace_changed = true,
    windows_changed = true, layout_changed = true,
}

local function disconnect()
    generation = generation + 1
    if stream then stream:terminate(); stream = nil end
    history, servers = nil, nil
end

local function connect(pids)
    disconnect()
    servers = pids
    history = History.new(cache, save, focus, now)
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
                enqueue(function()
                    if token ~= generation then return end
                    if event.type == "workspace_changed" or event.type == "focused_window_changed" then
                        local ok, err = pcall(function()
                            history:handle(event, query("workspaces", event.space_id))
                        end)
                        if not ok then disconnect(); error(err) end
                    end
                    if borderEvents[event.type] then M.refreshBorder() end
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

function M.toggleAllFloating()
    enqueue(function()
        local windows, workspace = context()
        local window = History.focused(windows)
        local wasFloating = window and window.is_floating == true
        if not window then wasFloating = (cache[workspace] or {}).floats_up == true end
        if window then save(workspace, wasFloating and "last_floating" or "last_tiled", window) end
        local predicate = function(w) return (w.is_floating == true) ~= wasFloating end
        local target = cachedWindow(windows, workspace,
            wasFloating and "last_tiled" or "last_floating", predicate)
        if not target then
            for _, candidate in ipairs(windows) do
                if predicate(candidate) then target = candidate end
            end
        end
        if not target then return end
        local controller = history or History.new(cache, save, focus, now)
        controller:selectGroup(workspace, windows, target, not wasFloating)
        -- Commit explicit group intent only after an error-free traversal.
        -- Generic focus events (including workspace entry) never change it.
        cache[workspace] = cache[workspace] or {}
        cache[workspace].floats_up = not wasFloating
        persist()
    end)
end

function M.toggleFinder()
    enqueue(function()
        local windows, workspace = context()
        local window = History.focused(windows)
        local function nonFinder(w) return w.bundle_id ~= "com.apple.finder" end
        if window and not nonFinder(window) then
            local target = cachedWindow(windows, workspace, "last_non_finder", nonFinder)
            if not target then
                for _, candidate in ipairs(windows) do
                    if nonFinder(candidate) then target = candidate; break end
                end
            end
            if target then focus(target) end
            return
        end
        if window then save(workspace, "last_non_finder", window) end
        local found = false
        for _, candidate in ipairs(windows) do
            if not nonFinder(candidate) then
                found = true
                -- One closed Finder window must not prevent visiting the remaining ones.
                local ok = pcall(focus, candidate)
                if ok and not candidate.is_floating then
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
        local previous = History.focused(windows)
        cli({ "execute", "layout", operation })
        if not previous then return end
        sleep(0.05)
        local currentWindows, currentWorkspace = context()
        if currentWorkspace ~= workspace then return end
        local window = History.find(currentWindows, previous)
        if window then focus(window) end
    end)
end

function M.toggleFloat()
    enqueue(function()
        cli({ "execute", "window", "toggle-float" })
        refreshBorder()
    end)
end

function M.start()
    if running then return end
    running = true
    enqueue(checkServer)
    heartbeat = hs.timer.doEvery(2, function() enqueue(checkServer) end)
    expiry = hs.timer.doEvery(0.05, function()
        if expiryQueued or not history or not next(history.pending) then return end
        expiryQueued = true
        enqueue(function()
            expiryQueued = false
            if history then history:expire(function(space) return query("workspaces", space) end) end
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
    current, expiryQueued, borderQueued = nil, nil, nil
end

function M.status()
    return {
        running = running, connected = stream ~= nil, queued = #jobs,
        busy = current ~= nil, lastError = lastError, borderColor = borderColor,
    }
end

return M
