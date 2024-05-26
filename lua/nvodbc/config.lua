local M = {}

function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

local defaults = {
    connections = {},
    --[[ Ex.
                connections = {
                    connection1 = {
                        dsn = "data_source_name",
                        uname = "username",
                        pwd = "password"
                    },
                }
    --]]
    lua_cmd = "lua",
    server_path = script_path() .. "server.lua",
    host = "127.0.0.1",
    port = 12475,
}

function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
