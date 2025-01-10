local skynet = require "skynet"
local pb = require "pb"
local protoloader = require "protoloader"

local function test_person()
    -- 创建测试数据
    local data = {
        name = "Alice",
        age = 30,
        email = "alice@example.com",
        phones = {
            {
                number = "123456789",
                type = 0  -- MOBILE
            },
            {
                number = "987654321",
                type = 1  -- HOME
            }
        }
    }
    
    -- 编码
    local ok, bytes = pcall(pb.encode, "test.Person", data)
    if not ok then
        skynet.error("编码失败:", bytes)
        return
    end
    skynet.error("编码后的数据长度:", #bytes)
    
    -- 解码
    local ok, decoded = pcall(pb.decode, "test.Person", bytes)
    if not ok then
        skynet.error("解码失败:", decoded)
        return
    end
    
    -- 打印解码后的数据
    skynet.error("解码后的数据:")
    skynet.error("名字:", decoded.name)
    skynet.error("年龄:", decoded.age)
    skynet.error("邮箱:", decoded.email)
    for i, phone in ipairs(decoded.phones) do
        skynet.error(string.format("电话 #%d: %s (%s)",
            i, phone.number,
            phone.type == 0 and "移动" or
            phone.type == 1 and "家庭" or
            phone.type == 2 and "工作" or "未知"
        ))
    end
end

skynet.start(function()
    skynet.error("Proto test service start")
    
    -- 加载所有proto文件
    if not protoloader.load_directory("./proto") then
        skynet.error("Failed to load proto files")
        return
    end
    
    -- 运行测试
    test_person()
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. " not found")
        skynet.ret(skynet.pack(f(...)))
    end)
end)
