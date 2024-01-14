-- https://www.hammerspoon.org/go/

hs.hotkey.bind({"shift", "alt" }, "space", function()
  hs.application.launchOrFocus("Wezterm")
end)
