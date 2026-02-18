-- Helper: Get screens sorted by physical position (Left -> Right)
local function getSortedScreens()
	local screens = hs.screen.allScreens()
	table.sort(screens, function(a, b)
		return a:frame().x < b:frame().x
	end)
	return screens
end

-- Focus Function
local function focusScreen(direction)
	local sortedScreens = getSortedScreens()

	-- 1. Identify current screen
	local focusedWindow = hs.window.focusedWindow()
	local currentScreen = focusedWindow and focusedWindow:screen() or hs.mouse.getCurrentScreen()

	-- 2. Find index of current screen in the sorted list
	local currentIndex = 1
	for i, s in ipairs(sortedScreens) do
		if s:id() == currentScreen:id() then
			currentIndex = i
			break
		end
	end

	-- 3. Calculate target index (with wrapping)
	local targetIndex = currentIndex
	if direction == "next" then
		targetIndex = currentIndex + 1
	else
		targetIndex = currentIndex - 1
	end

	-- STOP if we try to go past the first or last monitor
	if targetIndex < 1 or targetIndex > #sortedScreens then
		return
	end

	local targetScreen = sortedScreens[targetIndex]

	local windows = hs.window.orderedWindows()
	for _, w in ipairs(windows) do
		if w:screen() == targetScreen and w:isStandard() and w:isVisible() then
			w:focus()
			return
		end
	end
end

-- Bindings: Alt + [ (Left/Prev) and Alt + ] (Right/Next)
hs.hotkey.bind({ "alt" }, "[", function()
	focusScreen("prev")
end)
hs.hotkey.bind({ "alt" }, "]", function()
	focusScreen("next")
end)

hs.alert.show("Hammerspoon Spaces config loaded!")
