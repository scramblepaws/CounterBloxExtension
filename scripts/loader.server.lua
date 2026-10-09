-- loader.server.lua - Server-side loader script
-- Place in ServerScriptService to auto-load the extension on all clients

local function loadForPlayer(player)
    local success, err = pcall(function()
        local loader = game:HttpGet("https://raw.githubusercontent.com/scramblepaws/CounterBloxExtension/main/loader.lua")
        local scriptFunction = loadstring(loader)
        
        if scriptFunction then
            -- Execute in client context
            scriptFunction()
        end
    end)
    
    if not success then
        warn("Failed to load extension for " .. player.Name .. ": " .. tostring(err))
    end
end

-- Load for players already in game
for _, player in ipairs(game.Players:GetPlayers()) do
    loadForPlayer(player)
end

-- Load for new players
game.Players.PlayerAdded:Connect(loadForPlayer)
