-- Hammerspoon config for navigating spaces and displays

-- Function: go to next space on the current display
local function nextSpaceOnCurrentDisplay()
    local curScreen = hs.mouse.getCurrentScreen()  -- get the screen under the mouse
    if not curScreen then
        hs.alert.show("No current screen found!")
        return
    end

    local spacesForScreen = hs.spaces.spacesForScreen(curScreen)
    local activeSpace = hs.spaces.activeSpaceOnScreen(curScreen)
    if not spacesForScreen or not activeSpace then
        hs.alert.show("No spaces found for current screen!")
        return
    end

    -- Find the index of the active space in this screen’s spaces list.
    local currentIndex = nil
    for i, space in ipairs(spacesForScreen) do
        if space == activeSpace then
            currentIndex = i
            break
        end
    end

    if not currentIndex then
        hs.alert.show("Could not determine current space index.")
        return
    end

    -- Determine the next space index (cycling back to 1 when at the end)
    local nextIndex = currentIndex + 1
    if nextIndex > #spacesForScreen then
        nextIndex = 1
    end

    hs.spaces.gotoSpace(spacesForScreen[nextIndex])
end


-- Function: go to the active space of the next display
local function nextDisplayActiveSpace()
    local allScreens = hs.screen.allScreens()
    if #allScreens <= 1 then
        hs.alert.show("Only one display detected!")
        return
    end

    local curScreen = hs.mouse.getCurrentScreen()
    if not curScreen then
        hs.alert.show("No current screen found!")
        return
    end

    -- Find current screen's position in the list (order is arbitrary but
    -- consistent during a session).
    local currentIndex = nil
    for i, scr in ipairs(allScreens) do
        if scr == curScreen then
            currentIndex = i
            break
        end
    end

    if not currentIndex then
        hs.alert.show("Could not determine current screen index.")
        return
    end

    -- Determine next display (cycle back to first when at the end)
    local nextIndex = currentIndex + 1
    if nextIndex > #allScreens then
        nextIndex = 1
    end

    local nextScreen = allScreens[nextIndex]
    local spacesForScreen = hs.spaces.spacesForScreen(nextScreen)
    if not spacesForScreen or (#spacesForScreen == 0) then
        hs.alert.show("No spaces found for the next screen.")
        return
    end

    -- Try to get the active space on that screen; if not found, just pick the first one.
    local activeSpace = hs.spaces.activeSpaceOnScreen(nextScreen) or spacesForScreen[1]
    hs.spaces.gotoSpace(activeSpace)
end


-- Bind hotkeys

-- Shift + Option + [  ==> Go to next space on the current display
hs.hotkey.bind({"shift", "alt"}, "[", function()
    nextSpaceOnCurrentDisplay()
end)


-- Control + Option + [  ==> Go to the active space on the next display
hs.hotkey.bind({"ctrl", "alt"}, "[", function()
    nextDisplayActiveSpace()
end)

-- Optional: show an alert that the config has been loaded
hs.alert.show("Hammerspoon Spaces config loaded!")
