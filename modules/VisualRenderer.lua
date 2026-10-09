-- VisualRenderer.lua - Box ESP, visual effects, and rendering

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VisualRenderer = {}
VisualRenderer.__index = VisualRenderer

function VisualRenderer.new()
    local self = setmetatable({}, VisualRenderer)
    
    self.Player = Players.LocalPlayer
    self.ESPEnabled = false
    self.ESPBoxes = {}
    self.ESPConnection = nil
    
    return self
end

function VisualRenderer:Initialize()
    -- Placeholder for future initialization
end

function VisualRenderer:SetVisible(visible)
    -- Toggle visual elements when menu opens/closes
    if not visible then
        -- Keep ESP running regardless of menu state
        return
    end
end

function VisualRenderer:ToggleESP()
    self.ESPEnabled = not self.ESPEnabled
    
    if self.ESPEnabled then
        self:_StartESP()
    else
        self:_StopESP()
    end
end

function VisualRenderer:_StartESP()
    self.ESPConnection = RunService.RenderStepped:Connect(function()
        self:_RenderESP()
    end)
end

function VisualRenderer:_StopESP()
    if self.ESPConnection then
        self.ESPConnection:Disconnect()
        self.ESPConnection = nil
    end
    
    self:_ClearESPBoxes()
end

function VisualRenderer:_RenderESP()
    -- Iterate all players and draw boxes around their characters
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= self.Player then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                
                if humanoid and rootPart and humanoid.Health > 0 then
                    self:_DrawESPBox(player, character, rootPart)
                end
            end
        end
    end
end

function VisualRenderer:_DrawESPBox(player, character, rootPart)
    local espBox = self.ESPBoxes[player.Name]
    
    if not espBox then
        espBox = self:_CreateESPBox(player)
        self.ESPBoxes[player.Name] = espBox
    end
    
    -- Update box position based on character
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
    
    if onScreen then
        espBox.Visible = true
        espBox.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
        
        -- Update health bar if present
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            local healthBar = espBox:FindFirstChild("HealthBar")
            if healthBar then
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                healthBar.Size = UDim2.new(healthPercent, 0, 0, 4)
                healthBar.BackgroundColor3 = self:_HealthColor(healthPercent)
            end
        end
    else
        espBox.Visible = false
    end
end

function VisualRenderer:_CreateESPBox(player)
    local box = Instance.new("Frame")
    box.Name = "ESP_" .. player.Name
    box.Size = UDim2.new(0, 50, 0, 60)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    box.BackgroundTransparency = 0.7
    box.BorderSizePixel = 1
    box.BorderColor3 = Color3.fromRGB(255, 0, 0)
    box.ZIndex = 10
    box.Parent = self.Player.PlayerGui
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, -20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = player.Name
    nameLabel.ZIndex = 11
    nameLabel.Parent = box
    
    -- Health bar
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 0, 4)
    healthBar.Position = UDim2.new(0, 0, 0, -28)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.ZIndex = 11
    healthBar.Parent = box
    
    return box
end

function VisualRenderer:_HealthColor(healthPercent)
    if healthPercent > 0.6 then
        return Color3.fromRGB(0, 255, 0)
    elseif healthPercent > 0.3 then
        return Color3.fromRGB(255, 255, 0)
    else
        return Color3.fromRGB(255, 0, 0)
    end
end

function VisualRenderer:_ClearESPBoxes()
    for _, box in pairs(self.ESPBoxes) do
        box:Destroy()
    end
    self.ESPBoxes = {}
end

-- Additional visual features

function VisualRenderer:HighlightPlayer(player, color)
    color = color or Color3.fromRGB(255, 255, 0)
    
    local character = player.Character
    if not character then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "Highlight"
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.2
    highlight.Parent = character
end

function VisualRenderer:CreateTracer(fromPart, toPosition)
    -- Simple tracer effect using a beam
    local attachment0 = Instance.new("Attachment")
    attachment0.Parent = fromPart
    
    local attachment1 = Instance.new("Attachment")
    attachment1.WorldPosition = toPosition
    attachment1.Parent = workspace.Terrain
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.Transparency = NumberSequence.new(0.5)
    beam.Parent = workspace
    
    -- Cleanup after short duration
    task.delay(0.3, function()
        beam:Destroy()
        attachment0:Destroy()
        attachment1:Destroy()
    end)
end

function VisualRenderer:Cleanup()
    self:_StopESP()
    self:_ClearESPBoxes()
end

return VisualRenderer
