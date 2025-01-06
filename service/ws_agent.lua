local skynet = require "skynet"
local socket = require "skynet.socket"
local cjson = require "cjson"

local WATCHDOG
local client_fd

local CMD = {}
local CLIENT = {}

function CMD.start(conf)
    local fd = conf.fd
    client_fd = fd
    skynet.call(WATCHDOG, "lua", "forward", fd)
end

function CMD.disconnect()
    -- todo: do something before exit
    skynet.exit()
end

function CMD.message(msg, msg_type)
    -- 处理接收到的消息
    print("receive message", msg, msg_type)
    
    -- 这里处理业务逻辑
    -- 如果是文本消息，可以解析 JSON
    if msg_type == "text" then
        local ok, data = pcall(cjson.decode, msg)
        if ok then
            -- 处理 JSON 数据
            print("received json:", data)
        end
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