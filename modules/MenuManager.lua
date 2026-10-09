-- MenuManager.lua - Handles menu creation, toggle, and UI binding display

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MenuManager = {}
MenuManager.__index = MenuManager

function MenuManager.new(Signal, Tween)
    local self = setmetatable({}, MenuManager)
    
    self.Signal = Signal
    self.Tween = Tween
    self.Player = Players.LocalPlayer
    
    -- Events
    self.OnMenuToggled = Signal.new()
    self.OnBindingRequested = Signal.new()
    self.OnFunctionSelected = Signal.new()
    
    -- State
    self.IsOpen = false
    self.BoundFunctions = {}
    self.MenuGui = nil
    
    self:_CreateMenu()
    self:_SetupInput()
    
    return self
end

function MenuManager:_CreateMenu()
    local playerGui = self.Player:WaitForChild("PlayerGui")
    
    self.MenuGui = Instance.new("ScreenGui")
    self.MenuGui.Name = "CounterBloxMenu"
    self.MenuGui.ResetOnSpawn = false
    self.MenuGui.Enabled = false
    self.MenuGui.IgnoreGuiInset = true
    self.MenuGui.Parent = playerGui
    
    self.Container = Instance.new("Frame")
    self.Container.Name = "MenuContainer"
    self.Container.Size = UDim2.new(0, 360, 0, 460)
    self.Container.Position = UDim2.new(0.5, -180, 0.5, -230)
    self.Container.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    self.Container.BorderSizePixel = 0
    self.Container.Parent = self.MenuGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.Container
    
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 44)
    self.TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.Container
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = self.TitleBar
    
    self.Title = Instance.new("TextLabel")
    self.Title.Name = "Title"
    self.Title.Size = UDim2.new(1, -70, 1, 0)
    self.Title.Position = UDim2.new(0, 14, 0, 0)
    self.Title.BackgroundTransparency = 1
    self.Title.Text = "COUNTER-BLOX"
    self.Title.Font = Enum.Font.SourceSansBold
    self.Title.TextSize = 18
    self.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.Title.TextXAlignment = Enum.TextXAlignment.Left
    self.Title.Parent = self.TitleBar
    
    self.CloseButton = Instance.new("TextButton")
    self.CloseButton.Name = "CloseButton"
    self.CloseButton.Size = UDim2.new(0, 30, 0, 30)
    self.CloseButton.Position = UDim2.new(1, -38, 0, 7)
    self.CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    self.CloseButton.BorderSizePixel = 0
    self.CloseButton.Font = Enum.Font.SourceSansBold
    self.CloseButton.Text = "X"
    self.CloseButton.TextColor3 = Color3.new(1, 1, 1)
    self.CloseButton.TextSize = 16
    self.CloseButton.Parent = self.TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = self.CloseButton
    
    self.CloseButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    self:_CreateFunctionButtons()
    self:_CreateBindingControls()
    self:_CreateStatusPanel()
end

function MenuManager:_CreateFunctionButtons()
    self.FunctionButtons = {}
    
    local labels = {
        "Bunnyhop",
        "Texture Bug",
        "Box ESP",
        "Function 4",
        "Function 5"
    }
    
    for i = 1, 5 do
        local button = Instance.new("TextButton")
        button.Name = "FunctionBtn_" .. i
        button.Size = UDim2.new(1, -28, 0, 46)
        button.Position = UDim2.new(0, 14, 0, 52 + (i - 1) * 52)
        button.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.SourceSans
        button.TextSize = 15
        button.TextColor3 = Color3.fromRGB(220, 220, 220)
        button.Text = labels[i]
        button.Parent = self.Container
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            self:OnFunctionButtonClicked(i)
        end)
        
        self.FunctionButtons[i] = button
    end
end

function MenuManager:_CreateStatusPanel()
    self.StatusPanel = Instance.new("Frame")
    self.StatusPanel.Name = "StatusPanel"
    self.StatusPanel.Size = UDim2.new(1, -28, 0, 88)
    self.StatusPanel.Position = UDim2.new(0, 14, 0, 366)
    self.StatusPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    self.StatusPanel.BorderSizePixel = 0
    self.StatusPanel.Parent = self.Container
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = self.StatusPanel
    
    self.StatusLabel = Instance.new("TextLabel")
    self.StatusLabel.Name = "StatusLabel"
    self.StatusLabel.Size = UDim2.new(1, -20, 1, -12)
    self.StatusLabel.Position = UDim2.new(0, 10, 0, 6)
    self.StatusLabel.BackgroundTransparency = 1
    self.StatusLabel.Font = Enum.Font.SourceSans
    self.StatusLabel.TextSize = 12
    self.StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self.StatusLabel.TextWrapped = true
    self.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.StatusLabel.Text = "Status: Loaded\nB - Bunnyhop | T - TextureBug | E - ESP"
    self.StatusLabel.Parent = self.StatusPanel
end

function MenuManager:_CreateBindingControls()
    self.BindingPanel = Instance.new("Frame")
    self.BindingPanel.Name = "BindingPanel"
    self.BindingPanel.Size = UDim2.new(1, -28, 0, 40)
    self.BindingPanel.Position = UDim2.new(0, 14, 0, 318)
    self.BindingPanel.BackgroundTransparency = 1
    self.BindingPanel.Parent = self.Container
    
    self.BindKeyButton = Instance.new("TextButton")
    self.BindKeyButton.Name = "BindKeyButton"
    self.BindKeyButton.Size = UDim2.new(0, 160, 1, 0)
    self.BindKeyButton.Position = UDim2.new(0, 0, 0, 0)
    self.BindKeyButton.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
    self.BindKeyButton.BorderSizePixel = 0
    self.BindKeyButton.Font = Enum.Font.SourceSans
    self.BindKeyButton.TextSize = 13
    self.BindKeyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.BindKeyButton.Text = "BIND KEY"
    self.BindKeyButton.Parent = self.BindingPanel
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 6)
    keyCorner.Parent = self.BindKeyButton
    
    self.BindMouseButton = Instance.new("TextButton")
    self.BindMouseButton.Name = "BindMouseButton"
    self.BindMouseButton.Size = UDim2.new(0, 160, 1, 0)
    self.BindMouseButton.Position = UDim2.new(1, -160, 0, 0)
    self.BindMouseButton.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
    self.BindMouseButton.BorderSizePixel = 0
    self.BindMouseButton.Font = Enum.Font.SourceSans
    self.BindMouseButton.TextSize = 13
    self.BindMouseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.BindMouseButton.Text = "BIND MOUSE"
    self.BindMouseButton.Parent = self.BindingPanel
    
    local mouseCorner = Instance.new("UICorner")
    mouseCorner.CornerRadius = UDim.new(0, 6)
    mouseCorner.Parent = self.BindMouseButton
    
    self.BindKeyButton.MouseButton1Click:Connect(function()
        self:RequestBinding("key")
    end)
    
    self.BindMouseButton.MouseButton1Click:Connect(function()
        self:RequestBinding("mouse")
    end)
end

function MenuManager:_SetupInput()
    local UserInputService = game:GetService("UserInputService")
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F4 then
            self:Toggle()
        end
    end)
    
    -- Make titlebar draggable
    self.TitleBar.Active = true
    self.TitleBar.Draggable = true
end

function MenuManager:Open()
    if self.IsOpen then return end
    self.IsOpen = true
    self.MenuGui.Enabled = true
    self.OnMenuToggled:Fire(true)
end

function MenuManager:Close()
    if not self.IsOpen then return end
    self.IsOpen = false
    self.MenuGui.Enabled = false
    self.OnMenuToggled:Fire(false)
end

function MenuManager:Toggle()
    if self.IsOpen then
        self:Close()
    else
        self:Open()
    end
end

function MenuManager:OnFunctionButtonClicked(index)
    self.OnFunctionSelected:Fire(index)
end

function MenuManager:RequestBinding(bindingType)
    self.BindingMode = bindingType
    self.BindingIndex = nil
    
    if bindingType == "key" then
        self.BindKeyButton.Text = "PRESS KEY..."
        self:_ListenForBindingInput()
    elseif bindingType == "mouse" then
        self.BindMouseButton.Text = "PRESS MOUSE BTN..."
        self:_ListenForBindingInput()
    end
end

function MenuManager:_ListenForBindingInput()
    local UserInputService = game:GetService("UserInputService")
    local connection
    
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if self.BindingMode == "key" and input.UserInputType == Enum.UserInputType.Keyboard then
            self:_AssignBinding(self.BindingMode, input.KeyCode.Value)
            connection:Disconnect()
        elseif self.BindingMode == "mouse" then
            local btn = nil
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                btn = 1
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                btn = 2
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                btn = 3
            end
            if btn then
                self:_AssignBinding(self.BindingMode, btn)
                connection:Disconnect()
            end
        end
    end)
    
    -- Auto-cancel after 5 seconds
    task.delay(5, function()
        if connection.Connected then
            connection:Disconnect()
            self:_ResetBindingButtons()
        end
    end)
end

function MenuManager:_AssignBinding(bindingType, index)
    self.BoundFunctions[bindingType .. "_" .. index] = true
    self:_UpdateStatusDisplay()
    self:_ResetBindingButtons()
end

function MenuManager:_ResetBindingButtons()
    self.BindKeyButton.Text = "BIND KEY"
    self.BindMouseButton.Text = "BIND MOUSE"
    self.BindingMode = nil
end

function MenuManager:_UpdateStatusDisplay()
    local text = "Bindings:\n"
    
    for binding, assigned in pairs(self.BoundFunctions) do
        if assigned then
            text = text .. binding .. " - Active\n"
        end
    end
    
    if #text == 12 then -- Just the header
        text = "Bindings:\nNone assigned"
    end
    
    self.StatusLabel.Text = text
end

function MenuManager:Destroy()
    if self.MenuGui then
        self.MenuGui:Destroy()
    end
    
    self.OnMenuToggled:Destroy()
    self.OnBindingRequested:Destroy()
    self.OnFunctionSelected:Destroy()
end

return MenuManager
