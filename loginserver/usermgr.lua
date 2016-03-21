local skynet = require "skynet"
require "skynet.manager"

local users = {}

local CMD = {}


function CMD.enroll(account, agent)
	skynet.error("usermgr enroll  account: "..account)
	users[account] = agent

end

function CMD.remove(account) 
	skynet.error("usermgr remove  account: "..account)
	users[account] = nil
end

function CMD.query(account)
	skynet.error("usermgr query  account: "..account)
	return users[account]
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		skynet.error("usermgr  cmd: "..cmd)
		local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
	end)

	skynet.register "usermgr"
end)
		
