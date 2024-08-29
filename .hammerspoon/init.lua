-- https://www.hammerspoon.org/go/
local yabai = require("yabai")
-- local windowAction = require("windowAction")

local display_keys = { "H", "J", "K", "L", "N", "M", "U", "I" }

local function getSafariTabs()
	local chooser_data = {}
	local stat, data = hs.osascript.applescript(
		'tell application "Safari"\nset winlist to tabs of windows\nset tablist to {}\nrepeat with i in winlist\nif (count of i) > 0 then\nrepeat with currenttab in i\nset tabinfo to {name of currenttab as unicode text, URL of currenttab}\ncopy tabinfo to the end of tablist\nend repeat\nend if\nend repeat\nreturn tablist\nend tell'
	)
	-- Notice `output` key and its `arg`. The built-in output contains `browser`, `safari`, `chrome`, `firefon`, `clipboard`, `keystrokes`. You can define new output type if you like.
	if stat then
		chooser_data = hs.fnutils.imap(data, function(item)
			return {
				text = item[1] .. "-" .. item[2],
				subText = item[2],
				image = hs.image.imageFromAppBundle("com.apple.Safari"),
				output = "safari",
				arg = item[2],
			}
		end)
	end
	return chooser_data
end

----------------------------------------
-- Builds callback function to show the windows in chooser
----------------------------------------

local function bindChooserKeys(chooser)
	local captureHotkeys = function(event)
		local mods = event:getFlags()
		local key = event:getCharacters(true) -- the true arg cleans any modifiers from the key
		local keycode = event:getKeyCode()
		if not chooser:isVisible() then
			return
		end
		if key == "[" and mods.ctrl and not (mods.cmd or mods.shift or mods.alt) then
			chooser:hide()
			return true
		elseif key == " " and mods.alt and not (mods.cmd or mods.shift or mods.ctrl) then
			chooser:hide()
			return true
		elseif key == "d" and mods.ctrl and not (mods.cmd or mods.shift or mods.alt) then
			local selected = chooser:selectedRow()
			chooser:selectedRow(selected + 5)
			return true
		elseif key == "u" and mods.ctrl and not (mods.cmd or mods.shift or mods.alt) then
			local selected = chooser:selectedRow()
			chooser:selectedRow(selected - 5)
			return true
		end
		return false
	end

	chooser:showCallback(function()
		hs.eventtap.new({ hs.eventtap.event.types.keyDown }, captureHotkeys):start()
	end)
end

----------------------------------------
-- Build chooser searching Safari tabs
----------------------------------------

local function buildTabsChooser()
	local tabs = getSafariTabs()
	local tabsChooser = hs.chooser
		.new(function(chosen)
			hs.urlevent.openURLWithBundle(chosen.arg, "com.apple.Safari")
		end)
		:choices(tabs)
	bindChooserKeys(tabsChooser)
	return tabsChooser
end

----------------------------------------
-- Build chooser opening app in new tab
----------------------------------------

local appsChooserMenu = {
	{
		text = "Safari",
		image = hs.image.imageFromAppBundle("com.apple.Safari"),
		func = function()
			hs.osascript.applescript('tell application "Safari"\nmake new document\nactivate\nend tell')
		end,
	},
	{
		text = "Finder",
		image = hs.image.imageFromAppBundle("com.apple.Finder"),
		func = function()
			hs.osascript.applescript('tell application "Finder"\nmake new Finder window\nactivate\nend tell')
		end,
	},
	{
		text = "WezTerm",
		image = hs.image.imageFromAppBundle("com.github.wez.WezTerm"),
		func = function()
			hs.task
				.new("/usr/bin/open", function(err, stdout, stderr) end, function(task, stdout, stderr)
					return true
				end, { "-na", "WezTerm" })
				:start()
		end,
	},
}

local appsChooserDescription = {}
local appsChooserActions = {}

for _, menuItem in ipairs(appsChooserMenu) do
	table.insert(appsChooserDescription, {
		text = menuItem.text,
		subText = menuItem.subText,
		image = menuItem.image,
	})
	appsChooserActions[menuItem.text] = menuItem.func
end

local appsChooser = hs.chooser
	.new(function(choice)
		if choice ~= nil then
			appsChooserActions[choice.text]()
		end
	end)
	:choices(appsChooserDescription)
bindChooserKeys(appsChooser)

----------------------------------------
-- Build and show chooser for windows given condition
----------------------------------------

local function buildAndShowWindowsChooser(condition)
	return function(stdout, stderr)
		windows = hs.json.decode(stdout)
		local availableWindows = {}
		for i, w in ipairs(windows) do
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

		local windowsChooser = hs.chooser.new(function(choice)
			if not choice then
				return
			else
				yabai({ "-m", "window", "--focus", choice["winId"] })
			end
		end)

		windowsChooser:choices(availableWindows)
		windowsChooser:width(50)
		windowsChooser:rows(10)
		windowsChooser:query(nil)
		bindChooserKeys(windowsChooser)
		windowsChooser:show()
	end
end

----------------------------------------
-- Special case for searching for specific app
----------------------------------------

local function getAppWindows(stdout, stderr)
	current = hs.json.decode(stdout)
	yabai(
		{ "-m", "query", "--windows" },
		buildAndShowWindowsChooser(function(w)
			return w["app"] == current["app"]
		end)
	)
end

local mainChooserMenu = {
	{
		action = "open_app_window",
		text = "Open new app window",
		subText = "Search windows in the current app",
		func = function()
			appsChooser:show()
		end,
	},
	{
		action = "search_in_app",
		text = "Search in app",
		subText = "Search windows in the current app",
		func = function()
			yabai({ "-m", "query", "--windows", "--window" }, getAppWindows)
		end,
	},
	{
		action = "search_in_space",
		text = "Search in space",
		subText = "Search windows in the current space",
		func = function()
			yabai(
				{ "-m", "query", "--windows", "--space" },
				buildAndShowWindowsChooser(function(_)
					return true
				end)
			)
		end,
	},
	{
		action = "search_all_windows",
		text = "Search all windows",
		subText = "Search all windows",
		func = function()
			yabai(
				{ "-m", "query", "--windows" },
				buildAndShowWindowsChooser(function(_)
					return true
				end)
			)
		end,
	},
	{
		action = "search_in_window",
		text = "Search in display",
		subText = "Search windows in the current display",
		func = function()
			yabai(
				{ "-m", "query", "--windows", "--display" },
				buildAndShowWindowsChooser(function(_)
					return true
				end)
			)
		end,
	},
	{
		action = "reload",
		text = "Reload",
		subText = "Reload Hammerspoon configuration",
		func = function()
			hs.reload()
		end,
	},
	{
		action = "toggle_gap",
		text = "Toggle Gap",
		subText = "Toggles padding and gaps around the current space",
		func = function()
			yabai({ "-m", "space", "--toggle", "padding" }, function()
				yabai({ "-m", "space", "--toggle", "gap" })
			end)
		end,
	},
	{
		action = "search_tabs",
		text = "Search Safari Tabs",
		subText = "Search for open tabs in safari",
		func = function()
			buildTabsChooser():show()
		end,
	},
}

local descriptions = {}
local actions = {}
for _, menuItem in ipairs(mainChooserMenu) do
	table.insert(descriptions, {
		action = menuItem.action,
		text = menuItem.text,
		subText = menuItem.subText,
	})
	actions[menuItem.action] = menuItem.func
end

----------------------------------------
-- Quick Menu
----------------------------------------
local mainChooser = hs.chooser.new(function(option)
	if option ~= nil then
		actions[option["action"]]()
	end
end)
mainChooser:choices(descriptions)
-- mainChooser:choices(mainChooserMenu)
bindChooserKeys(mainChooser)

--# reload config
hs.hotkey.bind({ "alt" }, "return", nil, function()
	hs.reload()
end)

--# open main chooser
hs.hotkey.bind({ "alt" }, "space", nil, function()
	mainChooser:show()
end)
--

----------------------------------------
-- Show windows
----------------------------------------

hs.hotkey.bind({ "alt" }, "w", function()
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
end)
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
-- Move windows through displays
----------------------------------------

hs.hotkey.bind({ "alt", "ctrl" }, "h", function()
	yabai({ "-m", "window", "--swap", "west" }, function(_, _)
		yabai({ "-m", "window", "--display", "west" }, function(_, _)
			yabai({ "-m", "display", "--focus", "west" })
		end)
	end)
end)

hs.hotkey.bind({ "alt", "ctrl" }, "l", function()
	yabai({ "-m", "window", "--swap", "east" }, function(_, _)
		yabai({ "-m", "window", "--display", "east" }, function(_, _)
			yabai({ "-m", "display", "--focus", "east" })
		end)
	end)
end)

local window_mover = hs.hotkey.modal.new({ "cmd", "ctrl" }, "w")

function window_mover:entered()
	yabai({ "-m", "query", "--displays" }, function(stdout, stderr)
		-- print stdout json table
		for k, v in pairs(hs.json.decode(stdout)) do
			local hs_display = hs.screen.find(v["uuid"])
			if not v["has-focus"] then
				print(v["index"])
				hs.alert.show(display_keys[v["index"]], { textSize = 50 }, hs_display, "")
			end
		end
	end)
end

for i, v in ipairs(display_keys) do
	window_mover:bind("", v:lower(), function()
		yabai({ "-m", "window", "--display", tostring(i) }, function(_, _)
			yabai({ "-m", "display", "--focus", tostring(i) })
		end)
		-- yabai({ "-m", "display", "--focus", tostring(i) })
		window_mover:exit()
	end)
end

window_mover:bind("", "escape", function()
	window_mover:exit()
end)

window_mover:bind({ "ctrl" }, "[", function()
	window_mover:exit()
end)

function window_mover:exited()
	hs.alert.closeAll(0)
	print("window mover exited")
end

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
hs.hotkey.bind({ "alt" }, "return", function()
	yabai({ "-m", "window", "--toggle", "float", "--grid", "4:4:1:1:2:2", "--layer", "above" })
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

local display_chooser = hs.hotkey.modal.new({ "cmd", "ctrl" }, "d")

function display_chooser:entered()
	yabai({ "-m", "query", "--displays" }, function(stdout, stderr)
		-- print stdout json table
		for k, v in pairs(hs.json.decode(stdout)) do
			local hs_display = hs.screen.find(v["uuid"])
			if not v["has-focus"] then
				print(v["index"])
				hs.alert.show(display_keys[v["index"]], { textSize = 50 }, hs_display, "")
			end
		end
	end)
end

for i, v in ipairs(display_keys) do
	display_chooser:bind("", v:lower(), function()
		yabai({ "-m", "display", "--focus", tostring(i) })
		display_chooser:exit()
	end)
end

display_chooser:bind("", "escape", function()
	display_chooser:exit()
end)

display_chooser:bind({ "ctrl" }, "[", function()
	display_chooser:exit()
end)

function display_chooser:exited()
	hs.alert.closeAll(0)
	print("display chooser exited")
end

----------------------------------------
-- Create/Delete space
----------------------------------------

local function getCurrentScreen()
	return hs.window.focusedWindow():screen()
end

hs.hotkey.bind({ "alt", "ctrl" }, "n", function()
	-- local current = getCurrentScreen():id()
	-- hs.spaces.addSpaceToScreen(current)
	yabai({ "-m", "space", "--create" }, function(_, _)
		yabai({ "-m", "query", "--spaces", "--space" }, function(stdout, stderr)
			current_space = hs.json.decode(stdout)["index"]

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
					yabai(
						{ "-m", "space", tostring(target_index), "--move", tostring(current_space + 1) },
						function(_, _)
							yabai({ "-m", "space", "--focus", tostring(current_space + 1) })
						end
					)
				end
			end)
		end)
	end)
end)

hs.hotkey.bind({ "alt", "ctrl" }, "d", function()
	yabai({ "-m", "query", "--spaces", "--space" }, function(stdout, stderr)
		current_space = hs.json.decode(stdout)["index"]
		yabai({ "-m", "space", "--focus", tostring(current_space - 1) }, function(_, _)
			yabai({ "-m", "space", tostring(current_space), "--destroy" })
		end)
	end)
end)

hs.hotkey.bind({ "alt", "shift" }, "space", function()
	yabai({ "-m", "query", "--spaces", "--space" }, function(stdout, stderr)
		layout = hs.json.decode(stdout)["type"]
		if layout == "bsp" then
			yabai({ "-m", "space", "--layout", "float" })
		else
			yabai({ "-m", "space", "--layout", "bsp" }, function()
				yabai({ "-m", "space", "--balance" })
			end)
		end
	end)
end)

local function get_space_in_display_direction(spaces, direction)
	local target_space = nil
	for i, space in ipairs(spaces) do
		if space["has-focus"] then
			if direction == "next" then
				if i < #spaces then
					target_space = i + 1
				else
					target_space = #spaces
					-- target_space = 1
				end
			else
				if i > 1 then
					target_space = i - 1
				else
					target_space = 1
					-- target_space = #spaces
				end
			end
			break
		end
	end
	if target_space ~= nil then
		return spaces[target_space]["index"]
	else
		return nil
	end
end

local function get_space_by_index(spaces, index)
	if index > #spaces then
		return nil
	else
		return spaces[index]["index"]
	end
end

----------------------------------------
-- Space movements -- better to set in mac settings
----------------------------------------

hs.hotkey.bind({ "alt", "ctrl" }, "]", function()
	yabai({ "-m", "query", "--spaces", "--display" }, function(stdout, stderr)
		spaces = hs.json.decode(stdout)
		local new_space = get_space_in_display_direction(spaces, "next")
		if new_space == nil then
			return
		end
		yabai({ "-m", "space", "--focus", tostring(new_space) })
	end)
end)

hs.hotkey.bind({ "alt", "ctrl" }, "[", function()
	yabai({ "-m", "query", "--spaces", "--display" }, function(stdout, stderr)
		spaces = hs.json.decode(stdout)
		local new_space = get_space_in_display_direction(spaces, "prev")
		if new_space == nil then
			return
		end
		yabai({ "-m", "space", "--focus", tostring(new_space) })
	end)
end)

for i = 1, 10 do
	local key = tostring(i)
	if i == 10 then
		key = "0"
	end
	hs.hotkey.bind({ "alt", "ctrl" }, key, function()
		print("we ant to go 1")
		yabai({ "-m", "query", "--spaces", "--display" }, function(stdout, stderr)
			spaces = hs.json.decode(stdout)
			local new_space = get_space_by_index(spaces, i)
			if new_space == nil then
				return
			end
			yabai({ "-m", "space", "--focus", tostring(new_space) })
		end)
	end)
end

----------------------------------------
-- Space swapping
----------------------------------------
hs.hotkey.bind({ "alt", "ctrl", "shift" }, "]", function()
	yabai({ "-m", "space", "--move", "next" })
end)

hs.hotkey.bind({ "alt", "ctrl", "shift" }, "[", function()
	yabai({ "-m", "space", "--move", "prev" })
end)
