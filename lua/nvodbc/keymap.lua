local utils = require('nvodbc.utils')
local config = require('nvodbc.config')

local Keymap = {}

function Keymap.setup()
    local cmd = vim.api.nvim_create_user_command

    cmd('Dbconnect', function(opts)
        local profile = opts.args
        print("Connecting to profile:", profile)

        local status, err = pcall(function()
            local session_manager = utils.SessionManager.get_instance(profile)
            session_manager:create_session(profile)

            --add buffer to session
            local bufnr = vim.api.nvim_get_current_buf()
            session_manager:attach_buffer(profile, bufnr)
        end)

        if not status then
            print("Error connecting to database profile:", err)
        end

        --add current buffer
    end, {
        nargs = 1,
        complete = function()
            -- Get completions from the keys of the connections table
            return vim.tbl_keys(config.options.connections)
        end,
    })

    cmd('Dbdisconnect', function()
        local bufnr = vim.api.nvim_get_current_buf()
        session_manager = utils.SessionManager.get_instance()
        session, profile = session_manager:get_buffer_session_profile(bufnr)
        if not session then
            print("No active session found for buffer:", bufnr)
            return
        end
        session_manager:detach_buffer(bufnr)

        if session.attached_buffers == {} then
            print("All buffers disconnected from session.", profile)
            session_manager:disconnect_session(profile)
        end
    end, { nargs = 0 })

    cmd('Dblist', function()
        print("Active sessions:")
        local session_manager = utils.SessionManager.get_instance()
        local sessions = session_manager.active_sessions
        print(vim.inspect(sessions))
    end, { nargs = 0 })

    cmd('Dbexecute', function(sql)
        local bufnr = vim.api.nvim_get_current_buf()
        local session, _ = utils.SessionManager:get_session_profile(bufnr)
        if not session then
            print("No active session found for buffer:", bufnr)
            return
        end
        if not session.attached_buffers[bufnr] then
            print("Buffer is not attached to this session.")
            return
        end
        session:send(sql)
    end, { nargs = 0 })

    cmd('Dbresults', function(opts)
        if opts.args == nil or opts.args == "" then
            print("Please provide a valid file path.")
            return
        end

        local height = math.floor(vim.o.lines * 0.3)
        local cmd = "vd " .. opts.args
        local current_win = vim.api.nvim_get_current_win()
        vim.cmd(height .. "split")

        -- Configure the new window for VisiData
        local win_set = vim.api.nvim_win_set_option
        win_set(0, 'number', false)         -- Disable line numbers
        win_set(0, 'relativenumber', false) -- Disable relative line numbers
        win_set(0, 'signcolumn', 'no')      -- Disable the sign column
        win_set(0, 'cursorline', false)     -- Disable cursor line
        win_set(0, 'cursorcolumn', false)   -- Disable cursor column
        win_set(0, 'wrap', false)           -- Disable wrapping
        win_set(0, 'statusline', '')        -- Clear status line
        win_set(0, 'winbar', '')            -- Clear winbar (Neovim 0.7+)

        -- Open VisiData in a terminal in the new window
        vim.cmd("terminal " .. cmd)
        vim.api.nvim_set_current_win(current_win) -- Revert focus to original
    end, { nargs = 1 })
end

return Keymap
