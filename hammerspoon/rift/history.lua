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

function History:restore(pending, target, automatic)
    pending.requested = true
    pending.automatic = automatic and automatic.id
    pending.deadline = self.now() + 1
    self.focus(target)
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
        local target = History.find(workspace.windows, (self.cache[workspaceId] or {}).last_focused)
        -- A window moved with follow takes precedence over older destination focus.
        if previous ~= workspaceId then
            target = History.find(workspace.windows, self.lastFocus[space]) or target
        end
        self.pending[space] = {
            workspace = workspaceId, target = target, deadline = self.now() + 0.2,
        }
        return
    end

    self.active[space] = self.active[space] or workspaceId
    if self.active[space] ~= workspaceId then return end
    -- Record event order, not the possibly newer query snapshot.
    local ref = { id = event.window_id }
    for _, ws in ipairs(workspaces) do
        local observed = History.find(ws.windows, ref)
        if observed then ref.window_server_id = observed.window_server_id; break end
    end
    local pending = self.pending[space]
    if not History.find(workspace.windows, ref)
        and (workspace.is_active or (pending and not pending.automatic)) then
        -- Rift can label outgoing focus with the incoming workspace during rapid switches.
        return
    end
    if not pending then self:remember(space, workspaceId, ref); return end
    local target = History.find(workspace.windows, pending.target)
    if not target or History.sameId(target.id, ref.id) then
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
        self:restore(pending, target, window)
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
                local target = History.find(workspace.windows, pending.target)
                if not pending.requested and target
                    and (not window or not History.sameId(window.id, target.id)) then
                    -- Empty-workspace round trips may emit no entry-focus event.
                    self:restore(pending, target, window)
                else
                    self.pending[space] = nil
                    self:remember(space, workspace.id, window)
                end
            end
        end
    end
end

return History
