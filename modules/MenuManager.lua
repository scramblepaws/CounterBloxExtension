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
    
    -- Create ScreenGui
    self.MenuGui = Instance.new("ScreenGui")
    self.MenuGui.Name = "CounterBloxMenu"
    self.MenuGui.ResetOnSpawn = false
    self.MenuGui.Enabled = false
    self.MenuGui.Parent = playerGui
    
    -- Background overlay
    self.Background = Instance.new("Frame")
    self.Background.Name = "Background"
    self.Background.Size = UDim2.new(1, 0, 1, 0)
    self.Background.Position = UDim2.new(0, 0, 0, 0)
    self.Background.BackgroundColor3 = Color3.new(0, 0, 0)
    self.Background.BackgroundTransparency = 0.4
    self.Background.Visible = false
    self.Background.Parent = self.MenuGui
    
    -- Main container
    self.Container = Instance.new("Frame")
    self.Container.Name = "MenuContainer"
    self.Container.Size = UDim2.new(0, 400, 0, 500)
    self.Container.Position = UDim2.new(0.5, -200, 0.5, -250)
    self.Container.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    self.Container.BorderSizePixel = 0
    self.Container.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Container.Parent = self.MenuGui
    
    -- Title bar
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 40)
    self.TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.Container
    
    self.Title = Instance.new("TextLabel")
    self.Title.Name = "Title"
    self.Title.Size = UDim2.new(1, -80, 1, 0)
    self.Title.Position = UDim2.new(0, 10, 0, 0)
    self.Title.BackgroundTransparency = 1
    self.Title.Text = "COUNTER-BLOX EXTENSION"
    self.Title.Font = Enum.Font.SourceSansBold
    self.Title.TextSize = 18
    self.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.Title.TextXAlignment = Enum.TextXAlignment.Left
    self.Title.Parent = self.TitleBar
    
    self.CloseButton = Instance.new("TextButton")
    self.CloseButton.Name = "CloseButton"
    self.CloseButton.Size = UDim2.new(0, 30, 1, -10)
    self.CloseButton.Position = UDim2.new(1, -40, 0, 5)
    self.CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    self.CloseButton.Font = Enum.Font.SourceSansBold
    self.CloseButton.Text = "X"
    self.CloseButton.TextColor3 = Color3.new(1, 1, 1)
    self.CloseButton.TextSize = 16
    self.CloseButton.Parent = self.TitleBar
    
    self.CloseButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Function buttons container
    self.ButtonContainer = Instance.new("Frame")
    self.ButtonContainer.Name = "ButtonContainer"
    self.ButtonContainer.Size = UDim2.new(1, -20, 1, -100)
    self.ButtonContainer.Position = UDim2.new(0, 10, 0, 50)
    self.ButtonContainer.BackgroundTransparency = 1
    self.ButtonContainer.Parent = self.Container
    
    self:_CreateFunctionButtons()
    self:_CreateStatusPanel()
    self:_CreateBindingControls()
end

function MenuManager:_CreateFunctionButtons()
    self.FunctionButtons = {}
    
    for i = 1, 5 do
        local button = Instance.new("TextButton")
        button.Name = "FunctionBtn_" .. i
        button.Size = UDim2.new(1, -20, 0, 50)
        button.Position = UDim2.new(0, 0, 0, (i - 1) * 55)
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        button.BorderSizePixel = 1
        button.BorderColor3 = Color3.fromRGB(60, 60, 60)
        button.Font = Enum.Font.SourceSans
        button.TextSize = 14
        button.TextColor3 = Color3.fromRGB(200, 200, 200)
        button.Text = "Function " .. i
        button.Parent = self.ButtonContainer
        
        button.MouseButton1Click:Connect(function()
            self:OnFunctionButtonClicked(i)
        end)
        
        self.FunctionButtons[i] = button
    end
end

function MenuManager:_CreateStatusPanel()
    self.StatusPanel = Instance.new("Frame")
    self.StatusPanel.Name = "StatusPanel"
    self.StatusPanel.Size = UDim2.new(1, 0, 0, 100)
    self.StatusPanel.Position = UDim2.new(0, 0, 1, -105)
    self.StatusPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    self.StatusPanel.BorderSizePixel = 0
    self.StatusPanel.Parent = self.Container
    
    self.StatusLabel = Instance.new("TextLabel")
    self.StatusLabel.Name = "StatusLabel"
    self.StatusLabel.Size = UDim2.new(1, -10, 1, -10)
    self.StatusLabel.Position = UDim2.new(0, 5, 0, 5)
    self.StatusLabel.BackgroundTransparency = 1
    self.StatusLabel.Font = Enum.Font.SourceSans
    self.StatusLabel.TextSize = 12
    self.StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self.StatusLabel.TextWrapped = true
    self.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.StatusLabel.Text = "Bindings:\nNone assigned"
    self.StatusLabel.Parent = self.StatusPanel
end

function MenuManager:_CreateBindingControls()
    self.BindingPanel = Instance.new("Frame")
    self.BindingPanel.Name = "BindingPanel"
    self.BindingPanel.Size = UDim2.new(1, -20, 0, 40)
    self.BindingPanel.Position = UDim2.new(0, 10, 0, 35)
    self.BindingPanel.BackgroundTransparency = 1
    self.BindingPanel.Parent = self.Container
    
    self.BindKeyButton = Instance.new("TextButton")
    self.BindKeyButton.Name = "BindKeyButton"
    self.BindKeyButton.Size = UDim2.new(0, 120, 1, 0)
    self.BindKeyButton.Position = UDim2.new(0, 0, 0, 0)
    self.BindKeyButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    self.BindKeyButton.Font = Enum.Font.SourceSans
    self.BindKeyButton.TextSize = 12
    self.BindKeyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.BindKeyButton.Text = "BIND KEY"
    self.BindKeyButton.Parent = self.BindingPanel
    
    self.BindMouseButton = Instance.new("TextButton")
    self.BindMouseButton.Name = "BindMouseButton"
    self.BindMouseButton.Size = UDim2.new(0, 120, 1, 0)
    self.BindMouseButton.Position = UDim2.new(0, 125, 0, 0)
    self.BindMouseButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    self.BindMouseButton.Font = Enum.Font.SourceSans
    self.BindMouseButton.TextSize = 12
    self.BindMouseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.BindMouseButton.Text = "BIND MOUSE"
    self.BindMouseButton.Parent = self.BindingPanel
    
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
    self.Background.Visible = true
    self.Container.Size = UDim2.new(0, 400, 0, 500)
    self.OnMenuToggled:Fire(true)
end

function MenuManager:Close()
    if not self.IsOpen then return end
    self.IsOpen = false
    self.MenuGui.Enabled = false
    self.Background.Visible = false
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
