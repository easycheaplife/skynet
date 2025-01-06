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
function CMD.client_message(fd, msg, msg_type, source)
    skynet.error(string.format("Game(%d) received message from agent(%d), fd=%d, type=%s", 
        skynet.self(), source, fd, msg_type))
    
    local user = users[fd]
    if not user then
        user = {
            fd = fd,
            agent = source,
        }
        users[fd] = user
        skynet.error(string.format("Game(%d) new client connected from agent(%d), fd=%d", 
            skynet.self(), user.agent, fd))
    end
    
    -- 解析消息
    if msg_type == "text" then
        -- 假设消息格式为: "cmd|params"
        local cmd, params = string.match(msg, "([^|]+)|?(.*)")
        skynet.error(string.format("Game(%d) parse message: cmd=%s, params=%s", 
            skynet.self(), cmd, params))
        
        local f = HANDLER[cmd]
        if f then
            -- 处理消息并返回结果
            local response = f(fd, params)
            if response then
                -- 通过agent返回给客户端
                skynet.error(string.format("Game(%d) send response to agent(%d): %s", 
                    skynet.self(), user.agent, response))
                skynet.send(user.agent, "lua", "send_client", response)
            end
        else
            skynet.error(string.format("Game(%d) unknown command: %s", skynet.self(), cmd))
        end
    end
end

-- 客户端断开连接
function CMD.client_disconnect(fd, source)
    local user = users[fd]
    if user then
        skynet.error(string.format("Game(%d) client disconnect, fd=%d, agent=%d", 
            skynet.self(), fd, user.agent))
    end
    users[fd] = nil
end

-- 负载更新函数
local function update_load()
    if balance then
        local load = {
            connections = #users,
            cpu = 0,
            memory = 0,
        }
        local total_load = load.connections * 0.6 + load.cpu * 0.2 + load.memory * 0.2
        
        skynet.error(string.format("Game(%d) update load: connections=%d, total_load=%.2f", 
            skynet.self(), load.connections, total_load))
        
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
    balance = assert(conf.balance, "balance service not found")
    start_load_update()
    return true
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(..., source)))
        else
            skynet.error("Unknown command ", cmd)
        end
    end)
end)

return game 