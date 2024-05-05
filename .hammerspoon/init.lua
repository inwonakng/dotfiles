-- https://www.hammerspoon.org/go/
local yabai = require("yabai")
hs.loadSpoon("RecursiveBinder")

spoon.RecursiveBinder.escapeKeys = {
	{ {}, "escape" },
	{ { "ctrl" }, "[" },
	{ { "alt" }, "space" },
}

local singleKey = spoon.RecursiveBinder.singleKey

----------------------------------------
-- Builds callback function to show the windows in chooser
----------------------------------------

local function getWindowsCallback(condition)
	return function(stdout, stderr)
		windows = hs.json.decode(stdout)
		local availableWindows = {}
		for i, w in ipairs(windows) do
			-- if w["has-focus"] then
			-- 	currentWindow = w
			-- else
			if condition(w) then
				local text = w["app"]
				if w["title"] ~= "" then
					text = w["title"] .. " ‑ " .. w["app"]
				end
				appBundleId = hs.application.get(w["app"]):bundleID()
				appImage = hs.image.imageFromAppBundle(appBundleId)
				table.insert(availableWindows, {
					text = text,
					image = appImage,
					winId = tostring(w["id"]),
				})
				print("available" .. w["app"] .. " ‑ " .. w["app"])
			end
		end

		local windowChooser = hs.chooser.new(function(choice)
			if not choice then
				return
			else
				yabai({ "-m", "window", "--focus", choice["winId"] })
			end
		end)

		local function handleChooserCancel(event)
			local mods = event:getFlags()
			local key = event:getCharacters()
			local keycode = event:getKeyCode()
			if not windowChooser:isVisible() then
				return
			end
			-- "[" is keycode 33
			if keycode == 33 and mods.ctrl and not (mods.cmd or mods.shift or mods.alt) then
				-- If 'ctrl+[' is pressed without any modifiers, hide the chooser
				windowChooser:hide()
				return true
			end
			return false
		end

		windowChooser:width(50)
		windowChooser:choices(availableWindows)
		windowChooser:rows(10)
		windowChooser:query(nil)
		windowChooser:showCallback(function()
			hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleChooserCancel):start()
		end)
		windowChooser:show()
	end
end

----------------------------------------
-- Special case for searching for specific app
----------------------------------------
local function getAppWindows(stdout, stderr)
	current = hs.json.decode(stdout)
	yabai(
		{ "-m", "query", "--windows" },
		getWindowsCallback(function(w)
			return w["app"] == current["app"]
		end)
	)
end

----------------------------------------
-- Recursive keymap similar to which-keys of nvim
----------------------------------------
local baseKeyMap = {
	[singleKey({}, "space", "balance")] = function()
		yabai({ "-m", "space", "balance" })
	end,
	[singleKey({}, "w", "select window")] = function()
		visibleWindows = hs.window.visibleWindows()
		validWindows = {}
		for i, window in ipairs(visibleWindows) do
			if window:isVisible() and not window:isMinimized() then
				table.insert(validWindows, window)
			end
		end
		-- hs.spaces.toggleMissionControl()
		hs.hints.showTitleThresh = 10
		hs.hints.titleMaxSize = 30
		hs.hints.windowHints(validWindows)
		-- print("screen"..screen..", space"..space)
	end,
	[singleKey({}, "h", "move left")] = function()
		yabai({ "-m", "window", "--swap", "west" }, function(_, _)
			yabai({ "-m", "window", "--display", "west" }, function(_, _)
				yabai({ "-m", "display", "--focus", "west" })
			end)
		end)
	end,
	[singleKey({}, "l", "move right")] = function()
		yabai({ "-m", "window", "--swap", "east" }, function(_, _)
			yabai({ "-m", "window", "--display", "east" }, function(_, _)
				yabai({ "-m", "display", "--focus", "east" })
			end)
		end)
	end,
	[singleKey({}, "s", "search windows+")] = {
		[singleKey({}, "return", "search all")] = function()
			yabai(
				{ "-m", "query", "--windows" },
				getWindowsCallback(function(_)
					return true
				end)
			)
		end,
		[singleKey({}, "d", "search in display")] = function()
			yabai(
				{ "-m", "query", "--windows", "--display" },
				getWindowsCallback(function(_)
					return true
				end)
			)
		end,
		[singleKey({}, "s", "search in space")] = function()
			yabai(
				{ "-m", "query", "--windows", "--space" },
				getWindowsCallback(function(_)
					return true
				end)
			)
		end,
		[singleKey({}, "a", "search in app")] = function()
			yabai({ "-m", "query", "--windows", "--window" }, getAppWindows)
		end,
	},
	[singleKey({}, "n", "new space")] = function()
		yabai({ "-m", "space", "--create" }, function(_, _)
			yabai({ "-m", "query", "--spaces", "--display" }, function(stdout, stderr)
				spaces = hs.json.decode(stdout)
				local target_index = nil
				for index = 1, #spaces do
					local space = spaces[#spaces + 1 - index]
					if not space["is-native-fullscreen"] then
						target_index = space["index"]
						break
					end
				end
				if target_index == nil then
					return
				else
					yabai({ "-m", "space", "--focus", tostring(target_index) })
				end
			end)
		end)
	end,
	-- [singleKey({}, "n", "new space")] = function()
	-- 	yabai({ "-m", "space", "--create" })
	-- end,
	[singleKey({}, "d", "delete space")] = function()
		yabai({ "-m", "space", "--destroy" })
	end,
	[singleKey({}, "o", "open app")] = function()
		yabai({ "-m", "space", "--destroy" })
	end,
}

hs.hotkey.bind({ "alt" }, "space", spoon.RecursiveBinder.recursiveBind(baseKeyMap))

-- local movementKeyMap = {
-- 	[singleKey({}, "space", "balance")] = function()
-- 		yabai({ "-m", "space", "balance" })
-- 	end,
-- }

-- hs.hotkey.bind({ "ctrl" }, "e", spoon.RecursiveBinder.recursiveBind(baseKeyMap))
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "r", function()
	hs.reload()
end)

----------------------------------------
-- Show Mission Control
----------------------------------------
hs.hotkey.bind({ "cmd", "ctrl" }, "space", function()
	hs.spaces.toggleMissionControl()
end)

----------------------------------------
-- Window movments
----------------------------------------
hs.hotkey.bind({ "cmd", "ctrl" }, "l", function()
	yabai({ "-m", "window", "--focus", "east" })
end)
hs.hotkey.bind({ "cmd", "ctrl" }, "h", function()
	yabai({ "-m", "window", "--focus", "west" })
end)
hs.hotkey.bind({ "cmd", "ctrl" }, "k", function()
	yabai({ "-m", "window", "--focus", "north" })
end)
hs.hotkey.bind({ "cmd", "ctrl" }, "j", function()
	yabai({ "-m", "window", "--focus", "south" })
end)

----------------------------------------
-- Resize Windows
----------------------------------------
hs.hotkey.bind({ "alt", "shift" }, "h", function()
	yabai({ "-m", "window", "--resize", "left:-20:0" })
end)
hs.hotkey.bind({ "alt", "shift" }, "l", function()
	yabai({ "-m", "window", "--resize", "right:20:0" })
end)
hs.hotkey.bind({ "alt", "shift" }, "k", function()
	yabai({ "-m", "window", "--resize", "top:0:-20" })
end)
hs.hotkey.bind({ "alt", "shift" }, "j", function()
	yabai({ "-m", "window", "--resize", "bottom:0:20" })
end)

----------------------------------------
-- Pin window
----------------------------------------
hs.hotkey.bind({ "alt", "ctrl" }, "return", function()
	yabai({ "-m", "window", "--toggle", "float", "--grid", "4:4:1:1:2:2", "--toggle", "sticky" })
end)

----------------------------------------
-- Rotate window
----------------------------------------
hs.hotkey.bind({ "alt", "shift" }, "return", function()
	yabai({ "-m", "window", "--toggle", "split" })
end)

----------------------------------------
-- Window swapping
----------------------------------------
hs.hotkey.bind({ "cmd", "alt", "shift" }, "l", function()
	yabai({ "-m", "window", "--swap", "east" })
end)
hs.hotkey.bind({ "cmd", "alt", "shift" }, "h", function()
	yabai({ "-m", "window", "--swap", "west" })
end)
hs.hotkey.bind({ "cmd", "alt", "shift" }, "k", function()
	yabai({ "-m", "window", "--swap", "north" })
end)
hs.hotkey.bind({ "cmd", "alt", "shift" }, "j", function()
	yabai({ "-m", "window", "--swap", "south" })
end)

----------------------------------------
-- Window warping
----------------------------------------
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "l", function()
	yabai({ "-m", "window", "--warp", "east" })
end)
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "h", function()
	yabai({ "-m", "window", "--warp", "west" })
end)
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "k", function()
	yabai({ "-m", "window", "--warp", "north" })
end)
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "j", function()
	yabai({ "-m", "window", "--warp", "south" })
end)

----------------------------------------
-- Simple window zooms
----------------------------------------
hs.hotkey.bind({ "cmd", "ctrl" }, "return", function()
	yabai({ "-m", "window", "--toggle", "zoom-fullscreen" })
end)
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "return", function()
	yabai({ "-m", "window", "--toggle", "zoom-parent" })
end)

----------------------------------------
-- Display movements
----------------------------------------
hs.hotkey.bind({ "cmd", "ctrl" }, "]", function()
	yabai({ "-m", "display", "--focus", "east" })
end)

hs.hotkey.bind({ "cmd", "ctrl" }, "[", function()
	yabai({ "-m", "display", "--focus", "west" })
end)

----------------------------------------
-- Space movements
----------------------------------------
hs.hotkey.bind({ "alt", "ctrl" }, "]", function()
	yabai({ "-m", "space", "--focus", "next" })
end)

hs.hotkey.bind({ "alt", "ctrl" }, "[", function()
	yabai({ "-m", "space", "--focus", "prev" })
end)
