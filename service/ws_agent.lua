local skynet = require "skynet"
local socket = require "skynet.socket"

local WATCHDOG
local client_fd
local game     -- 游戏服务

local CMD = {}
local CLIENT = {}

function CMD.start(conf)
    local fd = conf.fd
    client_fd = fd
    
    -- 从负载均衡服务获取游戏服务
    local balance = conf.balance
    game = skynet.call(balance, "lua", "get_game_service")
    
    skynet.call(WATCHDOG, "lua", "forward", fd)
end

function CMD.disconnect()
    -- 通知游戏服务客户端断开
    if game then
        skynet.send(game, "lua", "client_disconnect", client_fd)
    end
    skynet.exit()
end

function CMD.message(msg, msg_type)
    -- 转发消息到游戏服务
    if game then
        skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
    end
end

-- 发送消息给客户端
function CMD.send_client(msg)
    -- 这里可以根据需要选择文本或二进制格式
    local ok, err = websocket.write(client_fd, msg, "text")
    if not ok then
        skynet.error("Send to client error:", err)
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