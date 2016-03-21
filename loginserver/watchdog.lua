local skynet = require "skynet"
require "skynet.manager"
local socket = require "socket"
local netpack = require "netpack"
msgpack = require "msgpack.core"
local message = require "message"

local CMD = {}
local SOCKET = {}
local agent = {}
local gate
local protobuf = {}


local function send_response(fd, package)
		local data = msgpack.unpack(package)
		print("watchdog resp ok : ", data.msgno)
		socket.write(fd, netpack.pack(package))
end

--登陆验证
-- result 1   0:success  1:failed
-- result 2   msg
local function loginAuth(account, password)
		print("---process login---")

		LOG_INFO("loginAuth  account:"..account.." password:"..password)

		local tb = {result=1}  --0: 通过   1：校验失败   2：用户已经在线

		local ok, result
		local sql = "select * from tb_account where account = '" .. account .. "'" .." and password = ".."'" ..password .. "'"
		ok, result = pcall(skynet.call, "dbservice", "lua", "query", sql)
		--print ("query result=",dump( result ))

		if ok then
				print(#result)
				if #result > 0 then
						for key,value in pairs(result) do
								tb.result = 0
								tb.accountid = value["accountid"]
						end
				else
						tb.result = 1
				end
				--[[
				for k, v in pairs(value) do
				print(k, v)
				end
				]]--
		end
		local msgbody =  protobuf.encode("CMsgAccountLoginResponse", tb)
		return tb.result, msgpack.pack(message.MSG_ACCOUNT_LOGIN_RESPONSE_S2C, msgbody)
end

function SOCKET.open(fd, addr)
		skynet.error("new client from: " .. addr)
		LOG_INFO("new client from: " .. addr)

		skynet.call(gate, "lua", "accept", fd)

		--agent[fd] = skynet.newservice("agent")
		--skynet.call(agent[fd], "lua", "start", gate, fd, proto)
end

local function close_agnet(fd)
		local a = agent[fd]
		agent[fd] = nil
		if a then
				skynet.call(gate, "lua", "kick", fd)
				skynet.send(a, "lua", "disconnect")
		end

end

function SOCKET.close(fd)
		print("socket close", fd)
		LOG_INFO("socket close: " .. fd)
		close_agnet(fd)
end

function SOCKET.error(fd, msg)
		print("socket error", fd, msg)
		LOG_ERROR("socket error "..fd.." "..msg)
		close_agnet(fd)
end

--创建agent前，watchdog先验证，验证通过，再创建agent
function SOCKET.data(fd, msg)
		local d = msgpack.unpack(msg)	

		LOG_INFO("socket data  fd:"..fd..",msgno:"..d.msgno)
		skynet.error("socket data 2", fd, d.msgno)

		--Register request
		if d.msgno == message.MSG_ACCOUNT_REGIST_REQUEST_C2S then
				local data = protobuf.decode("CMsgAccountRegistRequest", d.msg);	
				if data.account then
						local ok = skynet.call("dbservice", "lua", "user_register", data.account, data.password)

						local tb = {}
						if ok then
								tb.result = 0
								tb.accountid = 0
								print("regist user success!!!!")
						else
								tb.result = 2
						end

						local msgbody = protobuf.encode("CMsgAccountRegistResponse", tb)
						local r = msgpack.pack(message.MSG_ACCOUNT_REGIST_RESPONSE_S2C, msgbody)

						send_response(fd, r)
				end
				return
		end


		-- login request
		if d.msgno == message.MSG_ACCOUNT_LOGIN_REQUEST_C2S then

				local data = protobuf.decode("CMsgAccountLoginRequest", d.msg)

				local ok
				local errno = 1
				local res

				if data and data.account then
						local account = data.account
						local password = data.password

						ok, res = loginAuth(account, password) --auth 

						local a = skynet.call("usermgr", "lua", "query", account)
						if a then   --已经登陆,先踢下线
								skynet.send(a, "lua", "disconnect")
						end

						if ok == 0 then  --auth success
								LOG_INFO("auth success")
								agent[fd] = skynet.newservice("agent")
								skynet.call(agent[fd], "lua", "start", gate, fd, account)

						else
								LOG_INFO("auth failed")
						end
				end

				send_response(fd, res)

		end
end

function CMD.start(conf)
		skynet.call(gate, "lua", "open", conf)
end

function CMD.close(fd)
		close_agnet(fd)
end

skynet.start(function()
		print("---start watchdog---")
		skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
				print("---watchdog cmd ", cmd)
				if cmd == "socket" then
						print("---watchdog subcmd ", subcmd)
						local f = SOCKET[subcmd]
						f(...)
						--socket api don't need return
				else
						local f = assert(CMD[cmd])
						skynet.ret(skynet.pack(f(subcmd, ...)))
				end
		end)

		gate = skynet.newservice("gate")

		protobuf = require "protobuf"
		local login_data = io.open("../proto/login_message.pb", "rb")
		local buffer = login_data:read "*a"
		login_data:close()
		protobuf.register(buffer)

end)
