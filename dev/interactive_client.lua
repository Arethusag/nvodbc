local socket = require("socket")

-- Configure the server address and port
local host = "localhost"
local port = 12475

local client, err = socket.connect(host, port)
if not client then
    print("Error connecting to server: ", err)
    return
end

print("Connected to server at " .. host .. ":" .. port)
print("Type your message and press enter to send. Type 'quit' to exit.")

-- Main loop for user input and server communication
while true do
    io.write("> ")
    local userInput = io.read()
    if userInput == "quit" then
        client:send("quit\n")
        client:close()
        break
    else
        client:send(userInput .. "\n")
    end

    local response, err = client:receive("*l")
    if response then
        print("Received: " .. response)
    elseif err == "timeout" then
        print("Error receiving response: ", err)
    end
end
