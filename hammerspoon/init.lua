require("hs.ipc")

rift = require("rift")
rift.start()

local editPopup = require("edit-popup")
editPopup.start()

hs.shutdownCallback = function()
    editPopup.stop()
    rift.stop()
end
