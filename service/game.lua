local skynet = require "skynet"

local game = {}
local users = {}  -- fd -> user_info
local CMD = {}
local HANDLER = {}

-- 消息处理函数
function HANDLER.hello(fd, msg)
    return string.format("Hello %s!", msg)
end

function HANDLER.echo(fd, msg)
    return msg
end

-- 处理客户端消息
function CMD.client_message(fd, msg, msg_type)
    local user = users[fd]
    if not user then
        user = {
            fd = fd,
            gate = skynet.source(),  -- 记录来源gate，使用source()获取消息来源
        }
        users[fd] = user
    end
    
    -- 解析消息
    if msg_type == "text" then
        -- 假设消息格式为: "cmd|params"
        local cmd, params = string.match(msg, "([^|]+)|?(.*)")
        local f = HANDLER[cmd]
        if f then
            -- 处理消息并返回结果
            local response = f(fd, params)
            if response then
                -- 通过gate返回给客户端
                skynet.send(user.gate, "lua", "send_client", fd, response)
            end
        else
            skynet.error("Unknown command:", cmd)
        end
    end
end

-- 客户端断开连接
function CMD.client_disconnect(fd)
    users[fd] = nil
end

skynet.start(function()
    -- 注册为唯一服务
    skynet.register("game")
    
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("Unknown command ", cmd)
        end
    end)
end)

return game 