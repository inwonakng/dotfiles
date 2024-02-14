-- https://www.hammerspoon.org/go/

hs.hotkey.bind({"alt" }, "space", function()
  local term = hs.application.get("kitty")
  if term == nil then
    hs.application.launchOrFocus("kitty")
    return
  else
    if term:isFrontmost() then
      term:hide()
    else
      term:setFrontmost()
    end
  end
end)


local movewindows = hs.hotkey.modal.new()

hyper:bind({}, 'm', nil, function() movewindows:enter() end)
