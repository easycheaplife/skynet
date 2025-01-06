local skynet = require "skynet"

local gates = {
    tcp_gates = {},
    ws_gates = {},
}

local stats = {
    tcp_gates = {},
    ws_gates = {},
}

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

-- 更新网关状态
function CMD.update_gate_status(group_name, gate_name, connections, load)
    if stats[group_name] and stats[group_name][gate_name] then
        stats[group_name][gate_name].connections = connections
        stats[group_name][gate_name].load = load
    end
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

-- 获取所有网关状态
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