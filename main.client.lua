-- Main entry point for the Counter-Blox extension
-- This file should be placed in StarterPlayerScripts

-- Wait for player to load
local Players = game:GetService("Players")
local player = Players.LocalPlayer

if not player.Character or not player.Character.Parent then
    player.CharacterAdded:Wait()
end

-- Load all modules
local function loadModule(path)
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/CounterBloxExtension/main/" .. path .. ".lua"))
    end)
    
    if not success then
        warn("Failed to load module: " .. path)
        return nil
    end
    
    return result()
end

-- Core utilities
local Signal = loadModule("modules/Utils/Signal")
local Tween = loadModule("modules/Utils/Tween")

-- Feature modules
local MenuManager = loadModule("modules/MenuManager")
local InputHandler = loadModule("modules/InputHandler")
local MovementEngine = loadModule("modules/MovementEngine")
local VisualRenderer = loadModule("modules/VisualRenderer")
local CameraControl = loadModule("modules/CameraControl")

-- Initialize all components
local menuManager = MenuManager.new(Signal, Tween)
local inputHandler = InputHandler.new(menuManager)
local movementEngine = MovementEngine.new()
local visualRenderer = VisualRenderer.new()
local cameraControl = CameraControl.new()

-- Setup connections
inputHandler:ConnectToMenu(menuManager)
inputHandler:ConnectToMovement(movementEngine)
inputHandler:ConnectToVisuals(visualRenderer)
visualRenderer:Initialize()

-- Handle menu toggling
menuManager.OnMenuToggled:Connect(function(menuOpen)
    cameraControl:SetLock(menuOpen)
    visualRenderer:SetVisible(menuOpen)
end)

-- Expose globally for debug access
_G.CounterBloxExt = {
    Menu = menuManager,
    Input = inputHandler,
    Movement = movementEngine,
    Visuals = visualRenderer,
    Camera = cameraControl
}
