-- Remember each workspace's focused window in Rift event order.
local History = {}
History.__index = History

function History.sameId(a, b)
    return a ~= nil and b ~= nil and a.pid == b.pid and a.idx == b.idx
end

function History.find(windows, ref)
    if not ref then return nil end
    for _, window in ipairs(windows) do
        if History.sameId(window.id, ref.id)
            and (not ref.window_server_id or window.window_server_id == ref.window_server_id) then
            return window
        end
    end
end

function History.focused(windows)
    for _, window in ipairs(windows) do
        if window.is_focused then return window end
    end
end

function History.new(cache, save, focus, now)
    return setmetatable({
        cache = cache, save = save, focus = focus, now = now,
        active = {}, lastFocus = {}, pending = {},
    }, History)
end

function History:remember(space, workspace, window)
    self.save(workspace, "last_focused", window)
    if window and window.is_floating ~= nil then
        self.save(workspace, window.is_floating and "last_floating" or "last_tiled", window)
    end
    self.lastFocus[space] = window
end

function History:seed(space, workspaces)
    for _, workspace in ipairs(workspaces) do
        if workspace.is_active then
            self.active[space] = workspace.id
            self:remember(space, workspace.id, History.focused(workspace.windows))
        end
    end
end

-- Prefer recent focus within the intended group, then the explicit-toggle cache.
local function groupTarget(windows, state, up)
    local function matches(window) return window and (window.is_floating == true) == up end
    local target = History.find(windows, state.last_focused)
    if matches(target) then return target end
    target = History.find(windows, state[up and "last_floating" or "last_tiled"])
    if matches(target) then return target end
    for _, window in ipairs(windows) do
        if matches(window) then target = window end
    end
    if matches(target) then return target end
end

function History:target(pending, workspace)
    local target = History.find(workspace.windows, pending.target)
    if not target and not pending.requested and pending.floatsUp ~= nil then
        target = groupTarget(workspace.windows, self.cache[workspace.id] or {}, pending.floatsUp)
            or History.focused(workspace.windows) or workspace.windows[#workspace.windows]
    end
    return target
end

function History:restore(pending, target, automatic, windows)
    pending.requested = true
    pending.automatic = automatic and automatic.id
    pending.deadline = self.now() + 1
    pending.generated = {}
    local failures = {}
    local function visit(window)
        -- Continue past a closed window, but report every CLI/start/timeout error.
        local ok, err = pcall(self.focus, window)
        if ok then
            table.insert(pending.generated, window)
            pending.target = window
        else
            table.insert(failures, tostring(err))
        end
    end
    if pending.floatsUp then
        for _, window in ipairs(windows) do
            if window.is_floating and not History.sameId(window.id, target.id) then visit(window) end
        end
    end
    visit(target)
    if #failures > 0 then
        -- Successful commands may still have queued focus events to drain. A
        -- wholly failed operation has no generated events and must not linger.
        if #pending.generated == 0 then
            for space, active in pairs(self.pending) do
                if active == pending then self.pending[space] = nil end
            end
        end
        error("Cannot restore Rift focus:\n" .. table.concat(failures, "\n"), 0)
    end
end

function History:selectGroup(workspace, windows, target, up)
    local pending = { workspace = workspace, target = target, floatsUp = up }
    for space, active in pairs(self.active) do
        if active == workspace then self.pending[space] = pending; break end
    end
    self:restore(pending, target, History.focused(windows), windows)
end

function History:handle(event, workspaces)
    local space = event.space_id
    local identity = event.workspace_id
    local workspaceId = string.format("VirtualWorkspaceId(%dv%d)", identity.idx, identity.version)
    local workspace
    for _, candidate in ipairs(workspaces) do
        if candidate.id == workspaceId then workspace = candidate; break end
    end
    if not workspace then return end

    if event.type == "workspace_changed" then
        local previous = self.active[space]
        self.active[space] = workspaceId
        local state = self.cache[workspaceId] or {}
        local target = History.find(workspace.windows, state.last_focused)
        if state.floats_up ~= nil then
            target = groupTarget(workspace.windows, state, state.floats_up) or target
                or History.focused(workspace.windows) or workspace.windows[#workspace.windows]
        end
        -- A window moved with follow takes precedence over older destination focus,
        -- even if it is outside the workspace's explicitly selected group.
        if previous ~= workspaceId then
            target = History.find(workspace.windows, self.lastFocus[space]) or target
        end
        self.pending[space] = {
            workspace = workspaceId, target = target, floatsUp = state.floats_up,
            deadline = self.now() + 0.2,
        }
        return
    end

    self.active[space] = self.active[space] or workspaceId
    if self.active[space] ~= workspaceId then return end
    -- Record event order, not the possibly newer query snapshot.
    local ref = { id = event.window_id }
    for _, ws in ipairs(workspaces) do
        local observed = History.find(ws.windows, ref)
        if observed then
            ref.window_server_id = observed.window_server_id
            ref.is_floating = observed.is_floating == true
            break
        end
    end
    local pending = self.pending[space]
    if not History.find(workspace.windows, ref)
        and (workspace.is_active or (pending and not pending.automatic)) then
        -- Rift can label outgoing focus with the incoming workspace during rapid switches.
        return
    end
    if not pending then self:remember(space, workspaceId, ref); return end
    -- Group focus commands generate ordered intermediate events. Consume only
    -- those we issued; a different focus still supersedes automatic restoration.
    for index, generated in ipairs(pending.generated or {}) do
        if History.sameId(generated.id, ref.id) then
            for _ = 1, index do table.remove(pending.generated, 1) end
            if #pending.generated == 0 then
                self.pending[space] = nil
                self:remember(space, workspaceId, ref)
            end
            return
        end
    end
    local target = self:target(pending, workspace)
    if not target or (not pending.floatsUp and History.sameId(target.id, ref.id)) then
        self.pending[space] = nil
        self:remember(space, workspaceId, ref)
        return
    end
    if not pending.automatic then
        pending.automatic = ref.id
    elseif not History.sameId(ref.id, pending.automatic) then
        -- A different focus is newer user/app intent, including on inactive workspaces.
        self.pending[space] = nil
        self:remember(space, workspaceId, ref)
        return
    end
    local window = History.focused(workspace.windows)
    if not pending.requested and workspace.is_active and window
        and History.sameId(window.id, ref.id) then
        self:restore(pending, target, window, workspace.windows)
    end
end

function History:expire(query)
    for space, pending in pairs(self.pending) do
        if self.now() >= pending.deadline then
            local workspace
            for _, candidate in ipairs(query(space)) do
                if candidate.id == pending.workspace and candidate.is_active then
                    workspace = candidate
                    break
                end
            end
            if not workspace then
                self.pending[space] = nil
            else
                local window = History.focused(workspace.windows)
                local target = self:target(pending, workspace)
                if not pending.requested and target
                    and (pending.floatsUp or not window or not History.sameId(window.id, target.id)) then
                    -- Empty-workspace round trips may emit no entry-focus event.
                    self:restore(pending, target, window, workspace.windows)
                else
                    self.pending[space] = nil
                    self:remember(space, workspace.id, window)
                end
            end
        end
    end
end

return History
