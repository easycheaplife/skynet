local pb = require "pb"
local protoc = require "protoc"
local skynet = require "skynet"

local M = {}

function M.load(proto_file)
	local f = io.open(proto_file, "r")
	if not f then
		skynet.error("Failed to open proto file:", proto_file)
		return false
	end
	local content = f:read("*a")
	f:close()

	local ok, err = pcall(protoc.load, protoc, content)
	if not ok then
		skynet.error("Failed to load proto file:", proto_file, "error:", err)
		return false
	end
	return true
end

function M.load_directory(proto_dir)
	local dir = io.popen('ls ' .. proto_dir .. '/*.proto')
	if not dir then
		skynet.error("Failed to open proto directory:", proto_dir)
		return false
	end

	for file in dir:lines() do
		if not M.load(file) then
			dir:close()
			return false
		end
	end
	dir:close()
	return true
end

return M
