-- Counter-Blox Extension Loader
-- Load this via: loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()

local GIT_REF = "5f1b3b7"

local function notify(text, color)
    local ok, gui = pcall(function()
        local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        local g = Instance.new("ScreenGui")
        g.Name = "CBXNotify"
        g.ResetOnSpawn = false
        g.Parent = playerGui
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 320, 0, 28)
        label.Position = UDim2.new(0.5, -160, 0, 12)
        label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        label.BackgroundTransparency = 0.2
        label.TextColor3 = color or Color3.fromRGB(120, 255, 120)
        label.Text = text
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 15
        label.TextStrokeTransparency = 0.8
        label.Parent = g
        task.delay(6, function() g:Destroy() end)
    end)
    if not ok then
        warn("[CBX] " .. text)
    end
end

local function loadModule(name)
    local src = game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@" .. GIT_REF .. "/modules/" .. name .. ".lua")
    local fn = loadstring(src)
    if not fn then
        error("[CBX] Failed to load module: " .. name)
    end
    return fn()
end

local function main()
    local Signal = loadModule("Utils/Signal")
    local Tween = loadModule("Utils/Tween")
    local MenuManager = loadModule("MenuManager")
    local InputHandler = loadModule("InputHandler")
    local MovementEngine = loadModule("MovementEngine")
    local VisualRenderer = loadModule("VisualRenderer")
    local CameraControl = loadModule("CameraControl")

    local menuManager = MenuManager.new(Signal, Tween)
    local inputHandler = InputHandler.new(menuManager)
    local movementEngine = MovementEngine.new()
    local visualRenderer = VisualRenderer.new()
    local cameraControl = CameraControl.new()

    inputHandler:ConnectToMenu(menuManager)
    inputHandler:ConnectToMovement(movementEngine)
    inputHandler:ConnectToVisuals(visualRenderer)
    visualRenderer:Initialize()

    menuManager.OnMenuToggled:Connect(function(isOpen)
        cameraControl:SetLock(isOpen)
    end)

    menuManager.OnFunctionSelected:Connect(function(index)
        local actions = {
            [1] = function() movementEngine:ToggleBunnyhop() end,
            [2] = function() movementEngine:ToggleTextureBug() end,
            [3] = function() visualRenderer:ToggleESP() end,
        }
        if actions[index] then
            actions[index]()
        end
    end)

    _G.CounterBloxExt = {
        Menu = menuManager,
        Input = inputHandler,
        Movement = movementEngine,
        Visuals = visualRenderer,
        Camera = cameraControl
    }

    notify("Counter-Blox Extension Loaded (F4 = menu)")
    menuManager:Open()
end

local ok, err = pcall(main)
if not ok then
    notify("CBX ERROR: " .. tostring(err), Color3.fromRGB(255, 100, 100))
    warn("[CBX] " .. tostring(err))
end
