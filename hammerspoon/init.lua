require("hs.ipc")

rift = require("rift")
rift.start()

hs.shutdownCallback = function()
    rift.stop()
end
