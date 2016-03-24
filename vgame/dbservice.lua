local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"

local db 
local CMD = {}

function CMD.query(sql)
		print("--- dbserver query:" .. sql)
		return db:query(sql)
end

function CMD.user_register(account, password) 
		assert(account)
		if account == nil then
				return false
		end
		local password = password or ""
		LOG_INFO("Register account: "..account .. " password: "..password)
		local sql = "select * from tb_account where account = '"..account.."'"
		local result = db:query(sql)
		if #result > 0 then  --already exist
				return false
		end
		local id = os.time()
		sql = "insert into tb_account(account, password, accountid) values('".. account .."' ,'"..password .. "',"..id ..")"
		result = db:query(sql)
		return true
end

skynet.start(function()
		skynet.dispatch("lua", function(session, address, cmd, ...)
				local f = CMD[cmd]
				skynet.ret(skynet.pack(f(...)))
		end)

		db = mysql.connect {
				host = "123.56.207.55",
				port = 3306,
				database = "vgame",
				user = "vgame",
				password = "fgd",
				max_packet_size = 1024 * 1024
		}
		print(db)
		if not db then
				print("failedi to connect mysql")
		end

		skynet.register "dbservice"
end)

