local skynet = require "skynet"
local netpack = require "skynet.netpack"

local CMD = {}
local SOCKET = {}
local gate
local balance    -- 负载均衡服务
local connection = {}   -- fd -> connection
local forwarding = {}   -- source -> connection

local function update_load()
    if balance then
        local load = {
            connections = #connection,
            cpu = 0,  -- 可以添加CPU使用率统计
            memory = 0,  -- 可以添加内存使用统计
        }
        -- 计算综合负载值 (可以根据实际需求调整权重)
        local total_load = load.connections * 0.6 + load.cpu * 0.2 + load.memory * 0.2
        
        skynet.send(balance, "lua", "update_gate_status", 
            "tcp_gates",  -- 网关组名
            skynet.self(), -- 网关服务ID
            #connection,  -- 当前连接数
            total_load    -- 综合负载
        )
    end
end

-- 定期更新负载信息
local function start_load_update()
    skynet.fork(function()
        while true do
            update_load()
            skynet.sleep(100)  -- 每10秒更新一次
        end
    end)
end

function SOCKET.open(fd, addr)
    skynet.error("New client from : " .. addr)
    local c = {
        fd = fd,
        ip = addr,
    }
    connection[fd] = c
    skynet.send(gate, "lua", "accept", fd)
    update_load()  -- 更新负载信息
end

function SOCKET.close(fd)
    print("socket close",fd)
    local c = connection[fd]
    if c then
        connection[fd] = nil
        update_load()  -- 更新负载信息
    end
end

-- ... 其他现有代码 ...

function CMD.start(conf)
    skynet.call(gate, "lua", "open" , conf)
    balance = conf.balance  -- 保存负载均衡服务引用
    start_load_update()     -- 启动负载监控
    return skynet.self()
end

-- ... 其他现有代码 ... 