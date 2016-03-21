local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("---server start---")

	skynet.newservice("dbservice")
	skynet.newservice("gameservice")

	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 9999,
		maxclient = max_client,
		nodelay = true,
	})
	print("Watchdog listen on ", 9999)

	skynet.exit()
end)
