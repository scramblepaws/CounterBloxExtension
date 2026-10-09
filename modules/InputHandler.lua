-- InputHandler.lua - Key/mouse binding registration and routing

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(MenuManager)
    local self = setmetatable({}, InputHandler)
    
    self.MenuManager = MenuManager
    self.Bindings = {}       -- Maps key/button -> function name
    self.Actions = {}        -- Maps function name -> callback
    self.Debounce = {}       -- Prevents rapid re-trigger
    
    self.MovementEngine = nil
    self.VisualRenderer = nil
    
    self:_SetupInputListening()
    
    return self
end

function InputHandler:_SetupInputListening()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        self:_ProcessInput(input)
    end)
end

function InputHandler:_ProcessInput(input)
    local bindingKey = nil
    
    if input.UserInputType == Enum.UserInputType.Keyboard then
        bindingKey = "key_" .. input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        bindingKey = "mouse_1"
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        bindingKey = "mouse_2"
    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
        bindingKey = "mouse_3"
    end
    -- ponytail: Roblox's UserInputType only exposes MouseButton1/2/3.
    -- Side buttons (4/5) aren't natively surfaced; add an executor-specific
    -- bridge if one becomes available.
    
    if not bindingKey then return end
    
    -- Debounce check
    if self.Debounce[bindingKey] and os.clock() - self.Debounce[bindingKey] < 0.05 then
        return
    end
    self.Debounce[bindingKey] = os.clock()
    
    local actionName = self.Bindings[bindingKey]
    if actionName and self.Actions[actionName] then
        self.Actions[actionName]()
    end
end

function InputHandler:ConnectToMenu(menuManager)
    self.MenuManager = menuManager
    
    -- When user binds a key/mouse, register the default action
    menuManager.OnFunctionSelected:Connect(function(index)
        -- Placeholder: user selects which function to bind
    end)
end

function InputHandler:ConnectToMovement(movementEngine)
    self.MovementEngine = movementEngine
    
    self:RegisterAction("ToggleBunnyhop", function() movementEngine:ToggleBunnyhop() end)
    self:RegisterAction("ToggleTextureBug", function() movementEngine:ToggleTextureBug() end)
    self:RegisterAction("TriggerBunnyhop", function() movementEngine:TriggerBunnyhop() end)
    
    -- Default bindings for movement features
    self:Bind("key_B", "ToggleBunnyhop")
    self:Bind("key_T", "ToggleTextureBug")
    self:Bind("mouse_3", "TriggerBunnyhop")
end

function InputHandler:ConnectToVisuals(visualRenderer)
    self.VisualRenderer = visualRenderer
    
    self:RegisterAction("ToggleESP", function() visualRenderer:ToggleESP() end)
    self:Bind("key_E", "ToggleESP")
end

function InputHandler:Bind(bindingKey, actionName)
    self.Bindings[bindingKey] = actionName
end

function InputHandler:Unbind(bindingKey)
    self.Bindings[bindingKey] = nil
end

function InputHandler:RegisterAction(actionName, callback)
    self.Actions[actionName] = callback
end

function InputHandler:UnregisterAction(actionName)
    self.Actions[actionName] = nil
end

function InputHandler:GetBindingForAction(actionName)
    for bindingKey, boundAction in pairs(self.Bindings) do
        if boundAction == actionName then
            return bindingKey
        end
    end
    return nil
end

function InputHandler:SetBindingForAction(bindingKey, actionName)
    -- Remove any existing binding for this action
    local existing = self:GetBindingForAction(actionName)
    if existing then
        self:Unbind(existing)
    end
    
    self:Bind(bindingKey, actionName)
end

function InputHandler:BlockGameInput(enabled)
    if enabled then
        ContextActionService:BindAction("BlockGameInput", function() return Enum.ContextActionResult.Sink end, false, Enum.PlayerActions.All)
    else
        ContextActionService:UnbindAction("BlockGameInput")
    end
end

return InputHandler
