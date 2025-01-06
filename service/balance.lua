local skynet = require "skynet"

local gates = {
    tcp_gates = {},
    ws_gates = {},
}

local stats = {
    tcp_gates = {},
    ws_gates = {},
    game_services = {},
}

local game_services = {}  -- 游戏服务列表

local CMD = {}

-- 注册网关
function CMD.register_gate(group_name, gate_conf)
    local group = gates[group_name]
    if not group then
        group = {}
        gates[group_name] = group
    end
    
    table.insert(group, gate_conf)
    stats[group_name][gate_conf.name] = {
        connections = 0,
        load = 0
    }
end

-- 注册游戏服务
function CMD.register_game_services(services)
    game_services = services
    for _, service in ipairs(services) do
        stats.game_services[service] = {
            connections = 0,
            load = 0
        }
    end
end

-- 更新服务状态
function CMD.update_service_status(service_type, service_id, connections, load)
    if stats[service_type] then
        stats[service_type][service_id] = {
            connections = connections,
            load = load
        }
    end
end

-- 获取最佳游戏服务
function CMD.get_game_service()
    local best_service = nil
    local min_load = math.huge
    
    for service, stat in pairs(stats.game_services) do
        if stat.load < min_load then
            min_load = stat.load
            best_service = service
        end
    end
    
    return best_service
end

-- 获取最佳网关
function CMD.get_best_gate(group_name)
    local group_stats = stats[group_name]
    if not group_stats then
        return nil
    end
    
    local best_gate = nil
    local min_load = math.huge
    
    for gate_name, stat in pairs(group_stats) do
        if stat.load < min_load then
            min_load = stat.load
            best_gate = gates[group_name][gate_name]
        end
    end
    
    return best_gate
end

-- 获取所有状态
function CMD.get_all_stats()
    return stats
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.ret(skynet.pack(nil, "invalid command"))
        end
    end)
end) 