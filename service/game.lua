local skynet = require "skynet"

local game = {}
local users = {}  -- fd -> user_info
local CMD = {}
local HANDLER = {}
local balance    -- 负载均衡服务

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
            gate = skynet.source(),  -- 记录来源gate
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

-- 在 game.lua 中添加负载更新函数
local function update_load()
    if balance then
        local load = {
            connections = #users,
            cpu = 0,  -- 可以添加CPU使用率统计
            memory = 0,  -- 可以添加内存使用统计
        }
        -- 计算综合负载
        local total_load = load.connections * 0.6 + load.cpu * 0.2 + load.memory * 0.2
        
        skynet.send(balance, "lua", "update_service_status", 
            "game_services",
            skynet.self(),
            #users,
            total_load
        )
    end
end

local function start_load_update()
    skynet.fork(function()
        while true do
            update_load()
            skynet.sleep(100)  -- 每10秒更新一次
        end
    end)
end

function CMD.start(conf)
    balance = conf.balance
    start_load_update()
end

skynet.start(function()
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