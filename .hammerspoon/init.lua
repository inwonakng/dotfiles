-- https://www.hammerspoon.org/go/
local yabai = require("yabai")
hs.loadSpoon("RecursiveBinder")
hs.loadSpoon("hs_select_window")

spoon.RecursiveBinder.escapeKeys = { { {}, "escape" }, { { "ctrl" }, "[" } }

local singleKey = spoon.RecursiveBinder.singleKey

local function focusTerminal()
	print("i want to show terminal")
	local term = hs.application.get("wezterm")
	print(term)
	if term == nil then
		hs.application.launchOrFocus("wezterm")
		return
	else
		if not term:isFrontmost() then
			-- 	term:hide()
			-- else
			term:setFrontmost()
		end
	end
end

local keyMap = {
	[singleKey({}, "space", "terminal")] = focusTerminal,
	[singleKey({}, "return", "terminal")] = function()
		yabai({ "-m", "space", "balance" })
	end,
	[singleKey({}, "l", "w-right")] = function()
		yabai({ "-m", "window", "--focus", "east" })
	end,
	[singleKey({}, "h", "w-left")] = function()
		yabai({ "-m", "window", "--focus", "west" })
	end,
	[singleKey({}, "k", "w-up")] = function()
		yabai({ "-m", "window", "--focus", "north" })
	end,
	[singleKey({}, "j", "w-down")] = function()
		yabai({ "-m", "window", "--focus", "south" })
	end,
	[singleKey({}, "]", "d-left")] = function()
		yabai({ "-m", "display", "--focus", "east" })
	end,
	[singleKey({}, "[", "d-right")] = function()
		yabai({ "-m", "display", "--focus", "west" })
	end,
	[singleKey({}, "f", "float")] = function()
		yabai({ "-m", "window", "--float", "--grid", "4:4:1:1:2:2" })
	end,
	[singleKey({}, "z", "zoom")] = function()
		yabai({ "-m", "window", "--toggle", "zoom-fullscreen" })
	end,
	[singleKey({ "shift" }, "z", "zoom parent")] = function()
		yabai({ "-m", "window", "--toggle", "zoom-parent" })
	end,
	[singleKey({ "control" }, "h", "move left")] = function()
		yabai({ "-m", "window", "--swap", "west" })
		yabai({ "-m", "window", "--display", "west" })
		yabai({ "-m", "display", "--focus", "west" })
	end,
	[singleKey({ "control" }, "l", "move right")] = function()
		yabai({ "-m", "window", "--swap", "east" })
		yabai({ "-m", "window", "--display", "east" })
		yabai({ "-m", "display", "--focus", "east" })
	end,
	[singleKey({}, "m", "move+")] = {
		[singleKey({}, "h", "switch left")] = function()
			yabai({ "-m", "window", "--swap", "west" })
		end,
		[singleKey({}, "l", "switch right")] = function()
			yabai({ "-m", "window", "--swap", "east" })
		end,
		[singleKey({}, "k", "switch up")] = function()
			yabai({ "-m", "window", "--swap", "north" })
		end,
		[singleKey({}, "j", "switch down")] = function()
			yabai({ "-m", "window", "--swap", "south" })
		end,
		[singleKey({ "control" }, "h", "switch left")] = function()
			yabai({ "-m", "window", "--warp", "west" })
		end,
		[singleKey({ "control" }, "l", "switch right")] = function()
			yabai({ "-m", "window", "--warp", "east" })
		end,
		[singleKey({ "control" }, "k", "switch up")] = function()
			yabai({ "-m", "window", "--warp", "north" })
		end,
		[singleKey({ "control" }, "j", "switch down")] = function()
			yabai({ "-m", "window", "--warp", "south" })
		end,
	},
	[singleKey({}, "r", "resize+")] = {
		[singleKey({}, "h", "increase-left")] = function()
			yabai({ "-m", "window", "--resize", "left:-20:0" })
		end,
		[singleKey({}, "l", "increase-right")] = function()
			yabai({ "-m", "window", "--resize", "right:20:0" })
		end,
		[singleKey({}, "k", "increase-top")] = function()
			yabai({ "-m", "window", "--resize", "top:0:-20" })
		end,
		[singleKey({}, "j", "increase-bottom")] = function()
			yabai({ "-m", "window", "--resize", "bottom:0:20" })
		end,
	},
	[singleKey({}, "s", "search+")] = {
		[singleKey({}, "s", "search all")] = function()
			spoon.hs_select_window:selectWindow(false, false)
		end,
		[singleKey({}, "a", "search current app")] = function()
			spoon.hs_select_window:selectWindow(true, false)
		end,
	},
}

hs.hotkey.bind({ "cmd" }, "space", spoon.RecursiveBinder.recursiveBind(keyMap))
