local skynet = require "skynet"

-- 简化网关配置，只保留一个 WebSocket 网关
local GATE_CONF = {
	port = 8891,          -- WebSocket 端口
	protocol = "ws",      -- WebSocket 协议
}

-- 游戏服务配置
local GAME_CONF = {
	instance_count = 2,  -- 游戏服务实例数量
}

-- 启动游戏服务组
local function start_game_services()
	local game_services = {}
	for i = 1, GAME_CONF.instance_count do
		local game = skynet.newservice("game")
		skynet.error(string.format("Starting game service %d", game))
		
		-- 初始化游戏服务
		local ok = skynet.call(game, "lua", "start")
		
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
	
	return game_services[1]  -- 返回第一个游戏服务
end

-- 启动网关
local function start_gate(game_service)
	local watchdog = skynet.newservice("ws_watchdog")
	local addr, port = skynet.call(watchdog, "lua", "start", {
		port = GATE_CONF.port,
		protocol = GATE_CONF.protocol,
		game = game_service,  -- 直接传入游戏服务
	})
	
	if addr then
		skynet.error(string.format("WebSocket gate listening on %s:%d", addr, port))
		return watchdog
	else
		error("Failed to start WebSocket gate")
	end
end

skynet.start(function()
	skynet.error("Server start")
	
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	
	skynet.newservice("debug_console", 8000)
	
	-- 启动游戏服务
	local game_service = start_game_services()
	
	-- 启动网关服务
	local gate = start_gate(game_service)
	
	skynet.exit()
end)
