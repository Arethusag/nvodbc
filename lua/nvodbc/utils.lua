local M = {}

local job = require("plenary.job")
local config = require("nvodbc.config")

-- Service class to manage background processes
local Service = {}
Service.__index = Service

-- Private variable to hold the singleton instance
local service_instance = nil

function Service.new(command, args)
    assert(service_instance == nil, "Service is already running.")
    local self = setmetatable({}, Service)
    self.command = command
    self.args = args or {}
    self.job = nil
    return self
end

function Service:start()
    if self.job then
        print("Process is already running.")
        return
    end

    self.job = job:new({
        command = self.command,
        args = self.args,
        on_exit = function(j, return_val)
            print("Process exited with code", return_val)
            self.job = nil         -- Make sure to clear the job reference
            service_instance = nil -- Clear the singleton instance
        end,
        on_stdout = function(err, data)
            print("stdout:", data)
        end,
        on_stderr = function(err, data)
            print("stderr:", data)
        end,
    })

    self.job:start()
    print("Background process started.")
    service_instance = self
end

function Service:stop()
    if self.job then
        self.job:shutdown()
        self.job = nil
        print("Background process stopped.")
    else
        print("Process is not running.")
    end
end

function Service.get_instance(command, args)
    if not service_instance then
        service_instance = Service.new(command, args)
    end
    return service_instance
end

-- Session management class
local Session = {}
Session.__index = Session

function Session.new(profile)
    if not config.options.connections[profile] then
        print("Profile not found:", profile)
        return nil
    end

    local self = setmetatable({}, Session)
    self.profile = config.options.connections[profile]
    self.attached_buffers = {}
    self.socket = nil -- TCP socket will be stored here
    return self
end

function Session:connect()
    print("Connecting to the server...")
    print("Host:", config.options.host)
    print("Port:", config.options.port)

    self.socket = vim.loop.new_tcp()

    self.socket:connect(config.options.host, config.options.port, function(err)
        if err then
            print("Error connecting to the server:", err)
        else
            print("Connected to the server")
            -- Send the connection string
            local conn_str = string.format(
                "Dbconnect DSN=%s;UID=%s;PWD=%s\n",
                self.profile.dsn,
                self.profile.uname or '',
                self.profile.pwd or ''
            )
            self:send(conn_str)
        end
    end)
end

function Session:send(data)
    if self.socket then
        self.socket:write(data)
    else
        print("Not connected to the server")
    end
end

function Session:disconnect()
    if self.socket then
        self.socket:close()
        self.socket = nil
    end
end

local SessionManager = {}
SessionManager.__index = SessionManager

local session_manager_instance = nil

function SessionManager.new()
    local self = setmetatable({}, SessionManager)
    self.active_sessions = {}
    return self
end

function SessionManager:get_instance()
    print("Getting session manager instance")
    if not session_manager_instance then
        print("Creating new session manager instance")
        session_manager_instance = SessionManager.new()
    end
    return session_manager_instance
end

function SessionManager:create_session(profile)
    if not profile then
        print("Invalid profile")
        return
    end

    --print(vim.inspect(profile))
    --print(vim.inspect(config.options.connections[profile]))
    print("Creating session for profile:", profile)

    local session = self.active_sessions[profile]

    if not session then
        session = Session.new(profile)
        print(vim.inspect(session.profile.dsn))
        if session then
            print("Session created for profile:", profile)
            self.active_sessions[profile] = session
            print(vim.inspect(self.active_sessions))

            --try to connect
            local success, err = pcall(function()
                session:connect()
            end)

            if not success then
                print("Error connecting to database profile:", err)
            end
        else
            print("Failed to create session for profile:", profile)
            return nil
        end
    else
        print("Session already exists for profile:", profile)
    end
end

function SessionManager:disconnect_session(profile)
    local session = self.active_sessions[profile]
    if session then
        session:disconnect()
        self.active_sessions[profile] = nil
        print("Session disconnected for profile:", profile)
    else
        print("No active session found for profile:", profile)
    end
end

function SessionManager:attach_buffer(profile, bufnr)
    local session = self.active_sessions[profile]
    if not session then
        print("No active session found for profile:", profile)
        return nil
    elseif session.attached_buffers[bufnr] then
        print("Buffer is already attached to a session.")
        return nil
    end

    session.attached_buffers[bufnr] = true
end

function SessionManager:get_buffer_session_profile(bufnr)
    for profile, session in pairs(self.active_sessions) do
        if session.attached_buffers[bufnr] == true then
            return session, profile
        else
            print("No session found for buffer: " .. bufnr)
            return nil
        end
    end
end

function SessionManager:detach_buffer(bufnr)
    session, profile = self:get_buffer_session_profile(bufnr)
    if not session then
        print("No active session found for buffer:", bufnr)
        return nil
    elseif not session.attached_buffers[bufnr] then
        print("Buffer is not attached to this session.")
        return nil
    end
    print("Detaching buffer", bufnr, "from session.", profile)
    session.attached_buffers[bufnr] = nil
    return true
end

M.SessionManager = SessionManager
M.Session = Session
M.Service = Service

return M
