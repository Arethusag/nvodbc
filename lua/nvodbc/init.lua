--[[

Entry point for nvodbc plugin.

--]]

local config = require("nvodbc.config")
local utils = require("nvodbc.utils")
local autocmd = require("nvodbc.autocmd")
local keymap = require("nvodbc.keymap")

local M = {}

--Initial setup defaults
M.setup = config.setup

-- Set up the autocmds anmd keymaps
autocmd.setup()
keymap.setup()

--Start the server
M.service = utils.Service.get_instance(
    config.options.lua_cmd, {
        config.options.server_path,
        config.options.host,
        config.options.port
    })
M.service:start()

return M
