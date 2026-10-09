-- Counter-Blox Extension Loader
-- Load this via: loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/CounterBloxExtension/main/loader.lua"))()

local function loadModule(name)
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/CounterBloxExtension/main/modules/" .. name .. ".lua"))()
end

-- Load utility modules
local Signal = loadModule("Utils/Signal")
local Tween = loadModule("Utils/Tween")

-- Load core modules
local MenuManager = loadModule("MenuManager")
local InputHandler = loadModule("InputHandler")
local MovementEngine = loadModule("MovementEngine")
local VisualRenderer = loadModule("VisualRenderer")
local CameraControl = loadModule("CameraControl")

-- Initialize components
local menuManager = MenuManager.new(Signal, Tween)
local inputHandler = InputHandler.new(menuManager)
local movementEngine = MovementEngine.new()
local visualRenderer = VisualRenderer.new()
local cameraControl = CameraControl.new()

-- Connect input handling
inputHandler:ConnectToMenu(menuManager)
inputHandler:ConnectToMovement(movementEngine)
inputHandler:ConnectToVisuals(visualRenderer)

-- Initialize visual renderer with ESP settings
visualRenderer:Initialize()

-- Start listening for game events
menuManager.OnMenuToggled:Connect(function(isOpen)
    cameraControl:SetLock(isOpen)
    visualRenderer:SetVisible(isOpen)
end)

-- Expose API for external access (optional)
_G.CounterBloxExt = {
    Menu = menuManager,
    Input = inputHandler,
    Movement = movementEngine,
    Visuals = visualRenderer,
    Camera = cameraControl
}

return _G.CounterBloxExt
