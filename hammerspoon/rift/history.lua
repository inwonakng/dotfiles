-- Rift owns workspace focus; remember only observations confirmed by native focus.
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

function History.new(cache, save, focus, now, stackFloats, nativeFocused)
    return setmetatable({
        cache = cache, save = save, focus = focus, now = now,
        stackFloats = stackFloats, nativeFocused = nativeFocused, active = {}, pending = {},
    }, History)
end

function History:remember(workspace, window)
    if not window then return end
    self.save(workspace, "last_focused", window)
    self.save(workspace, window.is_floating and "last_floating" or "last_tiled", window)
end

function History:seed(space, workspaces)
    for _, workspace in ipairs(workspaces) do
        if workspace.is_active then
            self.active[space] = workspace.id
            self:remember(workspace.id, self.nativeFocused(workspace.windows))
        end
    end
end

function History:selectGroup(workspace, target, up)
    local failures = {}
    local selected = self.focus(target, up and function(windows)
        failures = self.stackFloats(windows, target)
    end or nil, workspace)
    if selected then self:remember(workspace, target) end
    if #failures > 0 then error("Cannot raise Rift floats:\n" .. table.concat(failures, "\n"), 0) end
    return selected
end

function History:enter(space, workspace)
    local window, hasFocus = self.nativeFocused(workspace.windows)
    if not window then return false, hasFocus end
    self.pending[space] = nil
    -- Native incoming focus (including moved-window-follow) always wins over
    -- stale floats_up/last_focused state. Restore stacking and the original main
    -- window in one synchronous batch, never activate a different application.
    local failures = window.is_floating and self.stackFloats(workspace.windows, window) or {}
    local observed = self.nativeFocused(workspace.windows)
    local selected = observed ~= nil and History.sameId(observed.id, window.id)
    if selected then self:remember(workspace.id, window) end
    if #failures > 0 then error("Cannot raise Rift floats:\n" .. table.concat(failures, "\n"), 0) end
    return selected, true
end

function History:handle(event, workspaces)
    local space = event.space_id
    local identity = event.workspace_id
    local workspaceId = string.format("VirtualWorkspaceId(%dv%d)", identity.idx, identity.version)
    local workspace
    for _, candidate in ipairs(workspaces) do
        if candidate.id == workspaceId and candidate.is_active then workspace = candidate; break end
    end
    if not workspace then return end

    if event.type == "workspace_changed" then
        self.active[space] = workspaceId
        self.pending[space] = { workspace = workspaceId, deadline = self.now() + 0.2 }
        self:enter(space, workspace)
        return
    end

    self.active[space] = self.active[space] or workspaceId
    if self.active[space] ~= workspaceId then return end
    local window = self.nativeFocused(workspace.windows)
    -- Queued events can arrive after native focus has already moved on. Do not
    -- let an intermediate observation replace the last genuinely used float.
    if not window or not History.sameId(window.id, event.window_id) then return end
    if self.pending[space] then
        self:enter(space, workspace)
    else
        self:remember(workspaceId, window)
    end
end

function History:expire(query)
    for space, pending in pairs(self.pending) do
        if pending.deadline and self.now() >= pending.deadline then
            local workspace
            for _, candidate in ipairs(query(space)) do
                if candidate.id == pending.workspace and candidate.is_active then
                    workspace = candidate
                    break
                end
            end
            self.pending[space] = nil
            if workspace then
                local entered, hasFocus = self:enter(space, workspace)
                if not entered and hasFocus then
                    -- Outgoing/unmanaged native focus is not permission to take
                    -- focus. Keep waiting for a real entry event without polling.
                    pending.deadline = nil
                    self.pending[space] = pending
                elseif not entered then
                    -- Only an entry with no actual incoming focus may use history.
                    local state = self.cache[workspace.id] or {}
                    local target = History.find(workspace.windows, state.last_focused)
                    if target then self:selectGroup(workspace.id, target, target.is_floating) end
                end
            end
        end
    end
end

return History
