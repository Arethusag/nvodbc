local copas = require("copas")
local socket = require("socket")
local luasql = require("luasql.odbc")
local os = require("os")
local io = require("io")

--Hostname and port to listen on
local host = arg[1] or "localhost"
local port = tonumber(arg[2]) or 12475

-- ODBC Driver Initialization
local env = luasql.odbc()

local ClientSession = {}
ClientSession.__index = ClientSession

function ClientSession.new(sock)
    local self = setmetatable({}, ClientSession)
    self.sock = sock
    self.conn = nil -- Database connection will be stored here
    return self
end

function ClientSession:connectToDatabase(dsn, uid, pwd)
    --TODO: credentials should be passed as parameters
    self.conn, err = env:connect(dsn, uid, pwd)
    if self.conn then
        print("Connected to the database")
        copas.send(self.sock, "Connected to the database\n")
    else
        print("Connection attempt failed: ", err)
        copas.send(self.sock, "Connection attempt failed: " .. err .. "\n")
    end
end

function ClientSession:executeSqlCommand(command)
    if not self.conn then
        print("No database connection")
        copas.send(self.sock, "No database connection\n")
        return
    end

    print("SQL command received: " .. command)
    local cursor, err = self.conn:execute(command)
    if not cursor then
        print("Error executing SQL statement: ", err)
        copas.send(self.sock, "Error executing SQL statement: " .. err .. "\n")
    else
        self:writeResultsToCSV(cursor)
    end
end

function ClientSession:writeResultsToCSV(cursor)
    local tmpFile = os.tmpname() .. ".csv"
    local file = io.open(tmpFile, "w")

    local colnames = cursor:getcolnames()
    file:write(table.concat(colnames, ", ") .. "\n")

    for row in self:rowIterator(cursor) do
        local values = {}
        for _, colname in ipairs(colnames) do
            table.insert(values, row[colname] or "")
        end
        file:write(table.concat(values, ", ") .. "\n")
    end

    file:close()
    cursor:close()
    print("Query results saved to: " .. tmpFile)
    copas.send(self.sock, "Query results saved to: " .. tmpFile .. "\n")
end

function ClientSession:rowIterator(cursor)
    return function()
        return cursor:fetch({}, "a")
    end
end

-- Handler function to create and manage a ClientSession for each connection
local function clientHandler(sock)
    local session = ClientSession.new(sock)

    while true do
        local command, err = copas.receive(sock, "*l")
        if not command or command == "quit" then
            print(err or "Client disconnected")
            break
        elseif string.sub(command, 1, 9) == "Dbconnect" then
            conn_str = string.match(command, "%s(.+)")
            local args = parse_conn_str(conn_str)
            session:connectToDatabase(args["DSN"], args["UID"], args["PWD"])
        else
            session:executeSqlCommand(command)
        end
    end
end

server = socket.bind(host, port)
print("Server started...")
copas.addserver(server, clientHandler)

copas()
