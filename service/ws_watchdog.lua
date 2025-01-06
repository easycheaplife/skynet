local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local WATCHDOG
local connection = {}  -- fd -> agent
local handler = {}
local game_service    -- 游戏服务

function handler.connect(fd)
    skynet.error(string.format("Watchdog(%d) new client connect, fd=%d", skynet.self(), fd))
    local agent = skynet.newservice("ws_agent")
    skynet.error(string.format("Watchdog(%d) created agent(%d) for fd=%d", 
        skynet.self(), agent, fd))
    
    skynet.call(agent, "lua", "start", { 
        fd = fd,
        game = game_service  -- 直接传入游戏服务
    })
    connection[fd] = agent
end

function handler.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    print("ws handshake from", addr, "url", url)
    print("----header----")
    for k,v in pairs(header) do
        print(k,v)
    end
    print("--------------")
end

function handler.message(fd, msg, msg_type)
    local agent = connection[fd]
    if agent then
        skynet.error(string.format("Watchdog(%d) forward message to agent(%d), fd=%d, type=%s", 
            skynet.self(), agent, fd, msg_type))
        skynet.send(agent, "lua", "message", msg, msg_type)
    else
        skynet.error(string.format("Watchdog(%d) no agent for fd=%d", skynet.self(), fd))
    end
end

function handler.ping(fd)
    print("ws ping from: " .. tostring(fd))
end

function handler.pong(fd)
    print("ws pong from: " .. tostring(fd))
end

function handler.close(fd, code, reason)
    skynet.error(string.format("Watchdog(%d) client close, fd=%d, code=%s, reason=%s", 
        skynet.self(), fd, tostring(code), tostring(reason)))
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

function handler.error(fd)
    print("ws error from: " .. tostring(fd))
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

local CMD = {}

function CMD.start(conf)
    game_service = assert(conf.game, "game service not found")
    local protocol = conf.protocol or "ws"
    local port = assert(conf.port)
    
    -- 添加日志
    skynet.error(string.format("WS_Watchdog(%d) starting on port %d, protocol: %s", 
        skynet.self(), port, protocol))
    
    local id = socket.listen("0.0.0.0", port)
    if not id then
        skynet.error(string.format("WS_Watchdog(%d) failed to listen on port %d", 
            skynet.self(), port))
        return nil, "listen failed"
    end
    
    skynet.error(string.format("WS_Watchdog(%d) listening on port %d", skynet.self(), port))
    
    socket.start(id, function(fd, addr)
        skynet.error(string.format("WS_Watchdog(%d) new connection from %s", skynet.self(), addr))
        local ok, err = websocket.accept(fd, handler, protocol, addr)
        if not ok then
            skynet.error(string.format("WS_Watchdog(%d) websocket accept failed: %s", 
                skynet.self(), err))
        end
    end)
    
    return "0.0.0.0", port
end

skynet.start(function()
    WATCHDOG = skynet.self()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = handler[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)
end) 