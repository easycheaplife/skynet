local skynet = require "skynet"
local socket = require "skynet.socket"

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
    if msg_type == "text" then
        -- 直接处理文本消息
        print("received text:", msg)
        -- 这里可以添加消息处理逻辑
    elseif msg_type == "binary" then
        -- 处理二进制消息
        print("received binary message, length:", #msg)
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