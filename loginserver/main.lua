local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("---server start---")


	local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")


	LOG_INFO("---------- server start -----------")

	skynet.newservice("debug_console", 8000)
	skynet.uniqueservice("dbservice")
	skynet.uniqueservice("loginservice")
	--skynet.newservice("roleservice")
	
	skynet.uniqueservice("usermgr")

	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	print("Watchdog listen on ", 8888)

	skynet.exit()
end)
