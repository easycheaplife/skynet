local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

local GATE_CONF = {
	-- TCP网关组
	tcp_gates = {
		{
			name = "tcp_gate_1",
			type = "socket", 
			port = 8881,
		},
		{
			name = "tcp_gate_2",
			type = "socket", 
			port = 8882,
		},
	},
	-- WebSocket网关组
	ws_gates = {
		{
			name = "ws_gate_1",
			type = "websocket",
			port = 8891,
		},
		{
			name = "ws_gate_2",
			type = "websocket",
			port = 8892,
		},
	}
}

-- 负载均衡服务
local function start_balance_service()
	local balance = skynet.newservice("balance")
	-- 注册所有网关到负载均衡服务
	for group_name, gates in pairs(GATE_CONF) do
		for _, gate_conf in ipairs(gates) do
			skynet.call(balance, "lua", "register_gate", group_name, gate_conf)
		end
	end
	return balance
end

local function start_gate(conf, balance_service)
	local watchdog
	if conf.type == "socket" then
		watchdog = skynet.newservice("watchdog")
	elseif conf.type == "websocket" then
		watchdog = skynet.newservice("ws_watchdog")
	else
		error("Unknown gate type: " .. conf.type)
	end

	local addr, port = skynet.call(watchdog, "lua", "start", {
		port = conf.port,
		maxclient = max_client,
		nodelay = true,
		balance = balance_service, -- 传入负载均衡服务
	})
	
	skynet.error(string.format("%s(%s) listen on %s:%s", 
		conf.name, conf.type, addr, port))
	
	return watchdog
end

skynet.start(function()
	skynet.error("Server start")
	skynet.uniqueservice("protoloader")
	
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	
	skynet.newservice("debug_console", 8000)
	skynet.newservice("simpledb")
	
	-- 启动游戏服务
	local game = skynet.newservice("game")
	
	-- 启动负载均衡服务
	local balance_service = start_balance_service()
	
	-- 启动所有网关组的网关
	for _, gates in pairs(GATE_CONF) do
		for _, gate_conf in ipairs(gates) do
			start_gate(gate_conf, balance_service)
		end
	end
	
	skynet.exit()
end)
