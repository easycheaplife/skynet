local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	skynet.error("Server start")
	skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console",8000)
	skynet.newservice("simpledb")
	local watchdog = skynet.newservice("watchdog")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.error("Socket Watchdog listen on " .. addr .. ":" .. port)
	
	local ws_watchdog = skynet.newservice("ws_watchdog")
	local ws_addr, ws_port = skynet.call(ws_watchdog, "lua", "start", {
		port = 8889,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.error("WebSocket Watchdog listen on " .. ws_addr .. ":" .. ws_port)
	
	skynet.exit()
end)
