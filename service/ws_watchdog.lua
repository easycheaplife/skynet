local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local WATCHDOG
local connection = {}
local handler = {}

function handler.connect(fd)
    print("ws client connect", fd)
    local agent = skynet.newservice("ws_agent")
    skynet.call(agent, "lua", "start", { fd = fd })
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
    -- msg_type: binary or text
    local agent = connection[fd]
    if agent then
        skynet.send(agent, "lua", "message", msg, msg_type)
    end
end

function handler.ping(fd)
    print("ws ping from: " .. tostring(fd))
end

function handler.pong(fd)
    print("ws pong from: " .. tostring(fd))
end

function handler.close(fd, code, reason)
    print("ws close from: " .. tostring(fd), code, reason)
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
    local protocol = conf.protocol or "ws"
    local port = assert(conf.port)
    local id = socket.listen("0.0.0.0", port)
    skynet.error(string.format("Listening %s port:%d", protocol, port))
    
    socket.start(id, function(fd, addr)
        print(string.format("connect from %s", addr))
        local ok, err = websocket.accept(fd, handler, protocol, addr)
        if not ok then
            print(err)
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