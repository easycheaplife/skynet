local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local WATCHDOG
local client_fd
local game     -- 游戏服务

-- WebSocket 帧构建函数
local function build_websocket_frame(data, opcode)
    local payload_len = #data
    local header = {}
    
    -- 第一个字节: FIN + RSV + OPCODE
    -- FIN = 1, RSV1-3 = 0
    local first_byte = 0x80  -- 10000000
    if opcode == "text" then
        first_byte = 0x81  -- 10000001 for text
    elseif opcode == "binary" then
        first_byte = 0x82  -- 10000010 for binary
    end
    table.insert(header, string.char(first_byte))
    
    -- 第二个字节开始: MASK + PAYLOAD LEN
    -- MASK = 0 (服务器发送不需要掩码)
    if payload_len < 126 then
        table.insert(header, string.char(payload_len))
    elseif payload_len < 0xFFFF then
        table.insert(header, string.char(126))
        -- 拆分 16 位长度为两个字节
        local high = math.floor(payload_len / 256)
        local low = payload_len % 256
        table.insert(header, string.char(high))
        table.insert(header, string.char(low))
    else
        table.insert(header, string.char(127))
        -- 拆分 64 位长度为 8 个字节
        local len = payload_len
        local bytes = {}
        for i = 1, 8 do
            table.insert(bytes, 1, string.char(len % 256))
            len = math.floor(len / 256)
        end
        for _, b in ipairs(bytes) do
            table.insert(header, b)
        end
    end
    
    -- 拼接头部和数据
    return table.concat(header) .. data
end

local CMD = {}
local CLIENT = {}

function CMD.start(conf)
    local fd = conf.fd
    client_fd = fd
    
    -- 直接使用传入的游戏服务
    game = assert(conf.game, "game service not found")
    skynet.error(string.format("Agent(%d) got game service(%d)", skynet.self(), game))
    
    skynet.call(WATCHDOG, "lua", "forward", fd)
end

function CMD.disconnect()
    -- 通知游戏服务客户端断开
    if game then
        skynet.error(string.format("Agent(%d) notify game(%d) client disconnect, fd=%d", 
            skynet.self(), game, client_fd))
        skynet.send(game, "lua", "client_disconnect", client_fd)
    end
    skynet.exit()
end

function CMD.message(msg, msg_type)
    -- 转发消息到游戏服务
    if game then
        skynet.error(string.format("Agent(%d) forward message to game(%d), fd=%d, type=%s", 
            skynet.self(), game, client_fd, msg_type))
        skynet.send(game, "lua", "client_message", client_fd, msg, msg_type)
    end
end

-- 发送消息给客户端
function CMD.send_client(msg)
    skynet.error(string.format("Agent(%d) send to client, fd=%d, msg=%s", 
        skynet.self(), client_fd, tostring(msg)))
    
    -- 构建并发送 WebSocket 帧
    local frame = build_websocket_frame(msg, "text")
    socket.write(client_fd, frame)
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