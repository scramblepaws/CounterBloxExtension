-- Signal.lua - Event/messaging utility for inter-module communication

local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._connections = {}
    self._connectionsList = {}
    return self
end

function Signal:Fire(...)
    for _, connection in ipairs(self._connectionsList) do
        connection(...)
    end
end

function Signal:Connect(callback)
    local connection = {
        callback = callback,
        connected = true
    }
    
    table.insert(self._connectionsList, connection)
    
    local function disconnect()
        if connection.connected then
            connection.connected = false
            for i, conn in ipairs(self._connectionsList) do
                if conn == connection then
                    table.remove(self._connectionsList, i)
                    break
                end
            end
        end
    end
    
    return {
        Disconnect = disconnect,
        DisconnectAll = disconnect -- Simplified
    }
end

function Signal:Wait()
    local result = nil
    local waitingCoroutine = coroutine.running()
    
    local conn
    conn = self:Connect(function(...)
        result = { ... }
        if conn then
            conn:Disconnect()
        end
        coroutine.resume(waitingCoroutine)
    end)
    
    coroutine.yield()
    
    return unpack(result or {})
end

function Signal:Destroy()
    self._connectionsList = {}
    self._connections = {}
end

return Signal
