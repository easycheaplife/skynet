local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local WATCHDOG
local client_fd
local game     -- 游戏服务

local CMD = {}
local CLIENT = {}

function CMD.start(conf)
    local fd = conf.fd
    client_fd = fd
    
    -- 从watchdog配置中获取负载均衡服务
    local balance = assert(conf.balance, "balance service not found")
    skynet.error(string.format("Agent(%d) getting game service from balance(%d)", skynet.self(), balance))
    game = assert(skynet.call(balance, "lua", "get_game_service"))
    skynet.error(string.format("Agent(%d) got game service(%d)", skynet.self(), game))
    
    skynet.call(WATCHDOG, "lua", "forward", fd)
end

function CMD.disconnect()
    -- 通知游戏服务客户端断开
    if game then
        skynet.error(string.format("Agent(%d) notify game(%d) client disconnect, fd=%d", skynet.self(), game, client_fd))
        skynet.send(game, "lua", "client_disconnect", client_fd, skynet.self())
    end
    skynet.exit()
end

function CMD.message(msg, msg_type)
    -- 转发消息到游戏服务
    if game then
        skynet.error(string.format("Agent(%d) forward message to game(%d), fd=%d, type=%s", 
            skynet.self(), game, client_fd, msg_type))
        skynet.send(game, "lua", "client_message", client_fd, msg, msg_type, skynet.self())
    end
end

-- 发送消息给客户端
function CMD.send_client(msg)
    skynet.error(string.format("Agent(%d) send to client, fd=%d, msg=%s", 
        skynet.self(), client_fd, tostring(msg)))
    -- 这里可以根据需要选择文本或二进制格式
    local ok, err = websocket.write(client_fd, msg, "text")
    if not ok then
        skynet.error(string.format("Agent(%d) send to client error: %s", skynet.self(), err))
    end
end

skynet.start(function()
    WATCHDOG = skynet.self()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.ret(skynet.pack({"Unknown command"}))
        end
    end)
end) 