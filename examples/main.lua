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
			protocol = "ws",
		},
		{
			name = "ws_gate_2",
			type = "websocket",
			port = 8892,
			protocol = "ws",
		},
	}
}

-- 游戏服务配置
local GAME_CONF = {
	instance_count = 2,  -- 游戏服务实例数量
}

-- 启动游戏服务组
local function start_game_services(balance_service)
	local game_services = {}
	for i = 1, GAME_CONF.instance_count do
		local game = skynet.newservice("game")
		skynet.error(string.format("Starting game service %d", game))
		
		-- 初始化游戏服务，传入负载均衡服务
		local ok = skynet.call(game, "lua", "start", {
			balance = balance_service
		})
		
		if ok then
			skynet.error(string.format("Game service %d started successfully", game))
			table.insert(game_services, game)
		else
			skynet.error(string.format("Failed to start game service %d", game))
		end
	end
	
	if #game_services == 0 then
		error("No game services started successfully")
	end
	
	return game_services
end

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

	skynet.error(string.format("Starting %s gate %s on port %d", 
		conf.type, conf.name, conf.port))

	local addr, port = skynet.call(watchdog, "lua", "start", {
		port = conf.port,
		maxclient = max_client,
		nodelay = true,
		balance = balance_service,
		protocol = conf.protocol,
	})
	
	if not addr then
		skynet.error(string.format("Failed to start gate %s: %s", conf.name, port))
		return false
	end
	
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
	
	-- 先启动负载均衡服务
	local balance_service = start_balance_service()
	
	-- 启动游戏服务组，传入负载均衡服务
	local game_services = start_game_services(balance_service)
	
	-- 注册游戏服务到负载均衡服务
	skynet.call(balance_service, "lua", "register_game_services", game_services)
	
	-- 启动所有网关组的网关
	for group_name, gates in pairs(GATE_CONF) do
		skynet.error(string.format("Starting gate group: %s", group_name))
		for _, gate_conf in ipairs(gates) do
			local ok = start_gate(gate_conf, balance_service)
			if not ok then
				skynet.error(string.format("Failed to start gate group %s", group_name))
			end
		end
	end
	
	skynet.exit()
end)
