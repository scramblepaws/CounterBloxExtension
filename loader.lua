--[[
    Counter-Blox Extension
    Single-file Roblox script.

    Load with:
    loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()

    Controls:
        F4   - open/close menu
        B    - toggle bunnyhop
        T    - toggle texture bug (slide)
        E    - toggle ESP
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ====================== CONFIG ======================
local config = {
    MenuKey = Enum.KeyCode.F4,
    BhopKey = Enum.KeyCode.B,
    TextureBugKey = Enum.KeyCode.T,
    EspKey = Enum.KeyCode.E,

    -- bhop
    BhopCooldown = 0.12,
    BhopBoost = 0.2,

    -- esp
    EspBoxColor = Color3.fromRGB(255, 255, 255),
    EspEnemyColor = Color3.fromRGB(255, 60, 60),
    EspFriendColor = Color3.fromRGB(60, 255, 60),
}

-- ====================== STATE ======================
local state = {
    Bhop = false,
    TextureBug = false,
    Esp = false,
}

-- ====================== LIBRARY DETECTION ======================
-- ponytail: Drawing is a userdata on most executors, not a table — check .new instead
local hasDrawing = (Drawing ~= nil and type(Drawing.new) == "function")

local function notify(text, color)
    pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "CBXNotify"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999999
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 320, 0, 26)
        label.Position = UDim2.new(0.5, -160, 0, 8)
        label.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
        label.BackgroundTransparency = 0.15
        label.TextColor3 = color or Color3.fromRGB(120, 255, 120)
        label.Text = text
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 14
        label.Parent = gui
        task.delay(5, function() gui:Destroy() end)
    end)
end

-- ====================== ESP ======================
-- vendored/adapted from tulontop/esp-lib.lua (bounding-box projection)
local ESP = {}
ESP.__index = ESP

local function getBoundingBox(character)
    local min = Vector2.new(math.huge, math.huge)
    local max = Vector2.new(-math.huge, -math.huge)
    local onscreen = false
    local camera = workspace.CurrentCamera
    if not camera then return min, max, false end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local size = part.Size / 2
            local cf = part.CFrame
            local corners = {
                Vector3.new( size.X,  size.Y,  size.Z),
                Vector3.new(-size.X,  size.Y,  size.Z),
                Vector3.new( size.X, -size.Y,  size.Z),
                Vector3.new(-size.X, -size.Y,  size.Z),
                Vector3.new( size.X,  size.Y, -size.Z),
                Vector3.new(-size.X,  size.Y, -size.Z),
                Vector3.new( size.X, -size.Y, -size.Z),
                Vector3.new(-size.X, -size.Y, -size.Z),
            }
            for _, offset in ipairs(corners) do
                local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                if visible then
                    local v2 = Vector2.new(pos.X, pos.Y)
                    min = min:Min(v2)
                    max = max:Max(v2)
                    onscreen = true
                end
            end
        end
    end

    return min, max, onscreen
end

function ESP.new()
    local self = setmetatable({}, ESP)
    self.Enabled = false
    self.Targets = {}   -- player -> { character, objects }
    self.Connection = nil
    return self
end

function ESP:Toggle()
    self.Enabled = not self.Enabled
    if self.Enabled then
        self:Start()
    else
        self:Stop()
    end
end

function ESP:Start()
    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function()
        self:Render()
    end)
end

function ESP:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:Clear()
end

-- create Drawing objects for a character
function ESP:AddCharacter(character)
    local objects = {}
    if hasDrawing then
        objects.Box = Drawing.new("Square")
        objects.Box.Thickness = 1
        objects.Box.Filled = false
        objects.Box.Transparency = 1
        objects.Box.Visible = false
        objects.Box.Color = config.EspBoxColor

        objects.Name = Drawing.new("Text")
        objects.Name.Font = Drawing.Fonts.UI
        objects.Name.Size = 13
        objects.Name.Center = true
        objects.Name.Outline = true
        objects.Name.Transparency = 1
        objects.Name.Visible = false
        objects.Name.Color = Color3.new(1, 1, 1)

        objects.HealthBg = Drawing.new("Square")
        objects.HealthBg.Thickness = 1
        objects.HealthBg.Filled = true
        objects.HealthBg.Transparency = 1
        objects.HealthBg.Visible = false
        objects.HealthBg.Color = Color3.new(0, 0, 0)

        objects.Health = Drawing.new("Square")
        objects.Health.Filled = true
        objects.Health.Transparency = 1
        objects.Health.Visible = false
        objects.Health.Color = Color3.new(0, 1, 0)
    end
    return objects
end

function ESP:RemoveObjects(objects)
    for _, drawing in pairs(objects) do
        pcall(function() drawing:Remove() end)
    end
end

function ESP:Render()
    if not hasDrawing then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    -- drop dead/left players
    for player, target in pairs(self.Targets) do
        if not player.Parent then
            self:RemoveObjects(target.objects)
            self.Targets[player] = nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local character = player.Character
        if not character or not character.Parent then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")

        -- death check: hide and skip if dead
        if not humanoid or humanoid.Health <= 0 then
            local target = self.Targets[player]
            if target then
                self:RemoveObjects(target.objects)
                self.Targets[player] = nil
            end
            continue
        end

        local target = self.Targets[player]

        -- respawn check: character changed
        if not target or target.character ~= character then
            if target then
                self:RemoveObjects(target.objects)
            end
            target = {
                character = character,
                objects = self:AddCharacter(character),
            }
            self.Targets[player] = target
        end

        local min, max, onscreen = getBoundingBox(character)
        local objects = target.objects

        if onscreen then
            local width = max.X - min.X
            local height = max.Y - min.Y
            local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

            objects.Box.Position = min
            objects.Box.Size = Vector2.new(width, height)
            objects.Box.Visible = true

            objects.Name.Text = player.Name
            objects.Name.Position = Vector2.new((min.X + max.X) / 2, min.Y - 15)
            objects.Name.Visible = true

            local barX = min.X - 5
            objects.HealthBg.Position = Vector2.new(barX, min.Y)
            objects.HealthBg.Size = Vector2.new(3, height)
            objects.HealthBg.Visible = true

            objects.Health.Position = Vector2.new(barX, min.Y + height * (1 - health))
            objects.Health.Size = Vector2.new(3, height * health)
            objects.Health.Color = (health > 0.6 and Color3.new(0, 1, 0))
                or (health > 0.3 and Color3.new(1, 1, 0))
                or Color3.new(1, 0, 0)
            objects.Health.Visible = true
        else
            objects.Box.Visible = false
            objects.Name.Visible = false
            objects.HealthBg.Visible = false
            objects.Health.Visible = false
        end
    end
end

function ESP:Clear()
    for _, target in pairs(self.Targets) do
        self:RemoveObjects(target.objects)
    end
    self.Targets = {}
end

-- ====================== BHOP ======================
local Bhop = {}
Bhop.__index = Bhop

function Bhop.new()
    local self = setmetatable({}, Bhop)
    self.Enabled = false
    self.Connection = nil
    self.LastJump = 0
    return self
end

function Bhop:Toggle()
    self.Enabled = not self.Enabled
    if self.Enabled then
        self:Start()
    else
        self:Stop()
    end
end

function Bhop:Start()
    if self.Connection then return end
    self.Connection = RunService.Heartbeat:Connect(function()
        self:Step()
    end)
end

function Bhop:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

function Bhop:Step()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return end

    -- only hop while moving and grounded
    if humanoid.MoveDirection.Magnitude <= 0 then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end

    local now = os.clock()
    if now - self.LastJump < config.BhopCooldown then return end

    local vel = root.AssemblyLinearVelocity
    local boost = humanoid.MoveDirection.Unit * (humanoid.WalkSpeed * config.BhopBoost)

    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    root.AssemblyLinearVelocity = Vector3.new(vel.X + boost.X, vel.Y, vel.Z + boost.Z)
    self.LastJump = now
end

-- ====================== TEXTURE BUG (slide) ======================
local TextureBug = {}
TextureBug.__index = TextureBug

function TextureBug.new()
    local self = setmetatable({}, TextureBug)
    self.Enabled = false
    return self
end

function TextureBug:Toggle()
    self.Enabled = not self.Enabled

    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return end

    if self.Enabled then
        self.OldWalkSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = humanoid.WalkSpeed * 0.8
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.1)
    else
        if self.OldWalkSpeed then
            humanoid.WalkSpeed = self.OldWalkSpeed
        end
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.5, 0.5)
    end
end

-- ====================== MENU ======================
local Menu = {}
Menu.__index = Menu

function Menu.new(esp, bhop, textureBug)
    local self = setmetatable({}, Menu)
    self.IsOpen = false
    self.Esp = esp
    self.Bhop = bhop
    self.TextureBug = textureBug
    self:_Build()
    self:_BindInput()
    return self
end

function Menu:_Build()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "CBXMenu"
    self.Gui.ResetOnSpawn = false
    self.Gui.Enabled = false
    self.Gui.DisplayOrder = 99999
    self.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.Gui.IgnoreGuiInset = true
    self.Gui.Parent = playerGui

    self.Container = Instance.new("Frame")
    self.Container.Size = UDim2.new(0, 300, 0, 240)
    self.Container.Position = UDim2.new(0.5, -150, 0.5, -120)
    self.Container.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    self.Container.BorderSizePixel = 0
    self.Container.Parent = self.Gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.Container

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.Container

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "COUNTER-BLOX"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 17
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 28, 0, 28)
    close.Position = UDim2.new(1, -34, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.BorderSizePixel = 0
    close.Text = "X"
    close.Font = Enum.Font.SourceSansBold
    close.TextColor3 = Color3.new(1, 1, 1)
    close.TextSize = 15
    close.Parent = titleBar
    close.MouseButton1Click:Connect(function() self:Toggle() end)

    local labels = {
        { "Bunnyhop", "Bhop" },
        { "Texture Bug", "TextureBug" },
        { "ESP", "Esp" },
    }

    for i, entry in ipairs(labels) do
        local btn = Instance.new("TextButton")
        btn.Name = "CBXBtn"
        btn.Size = UDim2.new(1, -28, 0, 44)
        btn.Position = UDim2.new(0, 14, 0, 46 + (i - 1) * 50)
        btn.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 15
        btn.TextColor3 = Color3.new(0.85, 0.85, 0.85)
        btn.Parent = self.Container

        btn:SetAttribute("Key", entry[2])
        btn:SetAttribute("Label", entry[1])

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            self:OnToggle(entry[2])
            self:RefreshLabels()
        end)
    end
end

function Menu:_BindInput()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == config.MenuKey then
            self:Toggle()
        end
    end)
end

function Menu:Toggle()
    self.IsOpen = not self.IsOpen
    self.Gui.Enabled = self.IsOpen

    if self.IsOpen then
        self.SavedMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        self:RefreshLabels()
    else
        if self.SavedMouseBehavior then
            UserInputService.MouseBehavior = self.SavedMouseBehavior
        end
    end
end

function Menu:OnToggle(key)
    if key == "Bhop" then
        state.Bhop = not state.Bhop
        self.Bhop:Toggle()
    elseif key == "TextureBug" then
        state.TextureBug = not state.TextureBug
        self.TextureBug:Toggle()
    elseif key == "Esp" then
        state.Esp = not state.Esp
        self.Esp:Toggle()
    end
end

function Menu:RefreshLabels()
    for _, child in ipairs(self.Container:GetChildren()) do
        if child:IsA("TextButton") and child.Name == "CBXBtn" then
            local key = child:GetAttribute("Key")
            local enabled = state[key]
            child.Text = child:GetAttribute("Label") .. (enabled and "  [ON]" or "  [OFF]")
            child.TextColor3 = enabled and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(0.85, 0.85, 0.85)
        end
    end
end

-- ====================== INIT ======================
local EspInst = ESP.new()
local BhopInst = Bhop.new()
local TextureBugInst = TextureBug.new()
local MenuInst = Menu.new(EspInst, BhopInst, TextureBugInst)

-- keybind toggles
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.BhopKey then
        state.Bhop = not state.Bhop
        BhopInst:Toggle()
    elseif input.KeyCode == config.TextureBugKey then
        state.TextureBug = not state.TextureBug
        TextureBugInst:Toggle()
    elseif input.KeyCode == config.EspKey then
        state.Esp = not state.Esp
        EspInst:Toggle()
    end
end)

-- expose for debugging
pcall(function()
    getgenv().CBX = {
        ESP = EspInst,
        Bhop = BhopInst,
        TextureBug = TextureBugInst,
        Menu = MenuInst,
    }
end)

notify("Counter-Blox loaded  |  F4 menu  |  B bhop  |  T slide  |  E esp")
