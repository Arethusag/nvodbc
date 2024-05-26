local SessionManager = require('nvodbc.utils').SessionManager
local Service = require('nvodbc.utils').Service

local Autocmd = {}

function Autocmd.setup()
    -- Detach buffer when closed
    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(args)
            local bufnr = args.buf
            SessionManager:detach_buffer(bufnr)
        end,
    })

    -- Stop the service when Vim quits
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            SessionManager:stop_all_sessions()
            Service:stop()
        end,
    })
end

return Autocmd
