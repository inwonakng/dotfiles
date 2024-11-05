-- https://www.hammerspoon.org/go/

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
		action = "reload",
		text = "Reload",
		subText = "Reload Hammerspoon configuration",
		func = function()
			hs.reload()
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

