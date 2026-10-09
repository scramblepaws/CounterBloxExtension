--[[
    Counter-Blox Extension
    Single-file Roblox script.

    Menu: neverlose-ui (https://github.com/ImInsane-1337/neverlose-ui)

    Load with:
    loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()

    Menu key: DELETE
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ====================== LIBRARY DETECTION ======================
local hasDrawing = (Drawing ~= nil and type(Drawing.new) == "function")

-- ====================== NEVERLOSE UI ======================
local Library
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/refs/heads/main/source/library.lua"))()
    end)
    if ok and result then
        Library = result
    else
        warn("[CBX] Failed to load neverlose-ui library")
        return
    end
end

Library.LogsEnabled = true

-- ====================== STATE ======================
local state = {
    Aim = false,
    AimFov = 120,
    AimSmooth = 8,
    Trigger = false,

    Esp = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspTracer = false,
    EspDistance = false,
    EspColor = Color3.fromRGB(84, 134, 255),
    Crosshair = false,
    Fov = 70,

    Bhop = false,
    Speed = false,
    SpeedVal = 16,
    Fly = false,
    TextureBug = false,
}

-- ====================== ESP ======================
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
    self.Targets = {}
    self.Connection = nil
    return self
end

function ESP:Start()
    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function() self:Render() end)
end

function ESP:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:Clear()
end

function ESP:AddCharacter()
    local o = {}
    if hasDrawing then
        o.Box = Drawing.new("Square")
        o.Box.Thickness = 1
        o.Box.Filled = false
        o.Box.Transparency = 1
        o.Box.Visible = false
        o.Box.Color = state.EspColor

        o.Name = Drawing.new("Text")
        o.Name.Font = Drawing.Fonts.UI
        o.Name.Size = 13
        o.Name.Center = true
        o.Name.Outline = true
        o.Name.Transparency = 1
        o.Name.Visible = false
        o.Name.Color = Color3.new(1, 1, 1)

        o.HealthBg = Drawing.new("Square")
        o.HealthBg.Filled = true
        o.HealthBg.Transparency = 1
        o.HealthBg.Visible = false
        o.HealthBg.Color = Color3.new(0, 0, 0)

        o.Health = Drawing.new("Square")
        o.Health.Filled = true
        o.Health.Transparency = 1
        o.Health.Visible = false
        o.Health.Color = Color3.new(0, 1, 0)

        o.Tracer = Drawing.new("Line")
        o.Tracer.Thickness = 1
        o.Tracer.Transparency = 1
        o.Tracer.Visible = false
        o.Tracer.Color = Color3.new(1, 1, 1)

        o.Distance = Drawing.new("Text")
        o.Distance.Font = Drawing.Fonts.UI
        o.Distance.Size = 13
        o.Distance.Center = true
        o.Distance.Outline = true
        o.Distance.Transparency = 1
        o.Distance.Visible = false
        o.Distance.Color = Color3.new(1, 1, 1)
    end
    return o
end

function ESP:RemoveObjects(o)
    for _, d in pairs(o) do pcall(function() d:Remove() end) end
end

function ESP:Render()
    if not hasDrawing then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

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

        if not humanoid or humanoid.Health <= 0 then
            local target = self.Targets[player]
            if target then
                self:RemoveObjects(target.objects)
                self.Targets[player] = nil
            end
            continue
        end

        local target = self.Targets[player]
        if not target or target.character ~= character then
            if target then self:RemoveObjects(target.objects) end
            target = { character = character, objects = self:AddCharacter() }
            self.Targets[player] = target
        end

        local min, max, onscreen = getBoundingBox(character)
        local o = target.objects

        if not onscreen then
            o.Box.Visible = false
            o.Name.Visible = false
            o.HealthBg.Visible = false
            o.Health.Visible = false
            o.Tracer.Visible = false
            o.Distance.Visible = false
            continue
        end

        local width = max.X - min.X
        local height = max.Y - min.Y
        local centerX = (min.X + max.X) / 2
        local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

        if state.EspBox then
            o.Box.Position = min
            o.Box.Size = Vector2.new(width, height)
            o.Box.Color = state.EspColor
            o.Box.Visible = true
        else
            o.Box.Visible = false
        end

        if state.EspName then
            o.Name.Text = player.Name
            o.Name.Position = Vector2.new(centerX, min.Y - 15)
            o.Name.Visible = true
        else
            o.Name.Visible = false
        end

        if state.EspHealth then
            local barX = min.X - 5
            o.HealthBg.Position = Vector2.new(barX, min.Y)
            o.HealthBg.Size = Vector2.new(3, height)
            o.HealthBg.Visible = true
            o.Health.Position = Vector2.new(barX, min.Y + height * (1 - health))
            o.Health.Size = Vector2.new(3, height * health)
            o.Health.Color = (health > 0.6 and Color3.new(0, 1, 0))
                or (health > 0.3 and Color3.new(1, 1, 0))
                or Color3.new(1, 0, 0)
            o.Health.Visible = true
        else
            o.HealthBg.Visible = false
            o.Health.Visible = false
        end

        if state.EspTracer then
            o.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            o.Tracer.To = Vector2.new(centerX, max.Y)
            o.Tracer.Visible = true
        else
            o.Tracer.Visible = false
        end

        if state.EspDistance then
            local dist = (camera.CFrame.Position - character:GetPivot().Position).Magnitude
            o.Distance.Text = tostring(math.floor(dist)) .. "m"
            o.Distance.Position = Vector2.new(centerX, max.Y + 4)
            o.Distance.Visible = true
        else
            o.Distance.Visible = false
        end
    end
end

function ESP:Clear()
    for _, target in pairs(self.Targets) do
        self:RemoveObjects(target.objects)
    end
    self.Targets = {}
end

-- ====================== AIMBOT ======================
local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new()
    local self = setmetatable({}, Aimbot)
    self.Connection = nil
    return self
end

function Aimbot:Start()
    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function() self:Step() end)
end

function Aimbot:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

function Aimbot:FindTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, state.AimFov / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if head and humanoid and humanoid.Health > 0 then
                local pos, onScreen = camera:WorldToScreenPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = head
                    end
                end
            end
        end
    end
    return best
end

function Aimbot:Step()
    if not state.Aim then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local target = self:FindTarget()
    if not target then return end

    local goal = CFrame.lookAt(camera.CFrame.Position, target.Position)
    if state.AimSmooth and state.AimSmooth > 1 then
        local alpha = math.clamp(1 / state.AimSmooth, 0.05, 1)
        camera.CFrame = camera.CFrame:Lerp(goal, alpha)
    else
        camera.CFrame = goal
    end
end

-- ====================== TRIGGERBOT ======================
local Triggerbot = {}
Triggerbot.__index = Triggerbot

function Triggerbot.new()
    local self = setmetatable({}, Triggerbot)
    self.Connection = nil
    return self
end

function Triggerbot:Start()
    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function() self:Step() end)
end

function Triggerbot:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

function Triggerbot:Step()
    if not state.Trigger then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true

    local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000, params)
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
        if hitPlayer and hitPlayer ~= LocalPlayer then
            pcall(function() mouse1click() end)
        end
    end
end

-- ====================== BHOP ======================
local Bhop = {}
Bhop.__index = Bhop

function Bhop.new()
    local self = setmetatable({}, Bhop)
    self.Connection = nil
    return self
end

function Bhop:Start()
    if self.Connection then return end
    self.Connection = RunService.Heartbeat:Connect(function() self:Step() end)
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
    if not humanoid or humanoid.Health <= 0 then return end

    if humanoid.MoveDirection.Magnitude <= 0 then
        humanoid.Jump = false
        return
    end

    if humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid.Jump = true
    else
        humanoid.Jump = false
    end
end

-- ====================== SPEED ======================
local Speed = {}
Speed.__index = Speed

function Speed.new()
    local self = setmetatable({}, Speed)
    self.Value = 16
    return self
end

function Speed:Apply()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = state.Speed and self.Value or 16
    end
end

function Speed:Set(value)
    self.Value = value
    self:Apply()
end

-- ====================== FLY ======================
local Fly = {}
Fly.__index = Fly

function Fly.new()
    local self = setmetatable({}, Fly)
    self.Connection = nil
    self.BodyGyro = nil
    self.BodyVel = nil
    return self
end

function Fly:Start()
    local character = LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    self.BodyGyro = Instance.new("BodyGyro")
    self.BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    self.BodyGyro.P = 9000
    self.BodyGyro.D = 100
    self.BodyGyro.Parent = root

    self.BodyVel = Instance.new("BodyVelocity")
    self.BodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    self.BodyVel.Velocity = Vector3.new(0, 0, 0)
    self.BodyVel.Parent = root

    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function() self:Step() end)
end

function Fly:Step()
    if not (self.BodyVel and self.BodyGyro) then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    self.BodyGyro.CFrame = camera.CFrame

    local dir = Vector3.new(0, 0, 0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

    if dir.Magnitude > 0 then
        self.BodyVel.Velocity = dir.Unit * 50
    else
        self.BodyVel.Velocity = Vector3.new(0, 0, 0)
    end
end

function Fly:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    if self.BodyGyro then self.BodyGyro:Destroy() self.BodyGyro = nil end
    if self.BodyVel then self.BodyVel:Destroy() self.BodyVel = nil end
end

-- ====================== CROSSHAIR ======================
local Crosshair = {}
Crosshair.__index = Crosshair

function Crosshair.new()
    local self = setmetatable({}, Crosshair)
    self.Lines = {}
    self.Connection = nil
    return self
end

function Crosshair:Start()
    if not hasDrawing then return end
    if self.Connection then return end

    local size, gap, thickness = 6, 4, 2
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = thickness
        line.Transparency = 1
        line.Color = Color3.new(0, 1, 0.6)
        line.Visible = true
        table.insert(self.Lines, line)
    end

    self.Connection = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local cx = camera.ViewportSize.X / 2
        local cy = camera.ViewportSize.Y / 2

        self.Lines[1].From = Vector2.new(cx - gap - size, cy)
        self.Lines[1].To = Vector2.new(cx - gap, cy)
        self.Lines[2].From = Vector2.new(cx + gap, cy)
        self.Lines[2].To = Vector2.new(cx + gap + size, cy)
        self.Lines[3].From = Vector2.new(cx, cy - gap - size)
        self.Lines[3].To = Vector2.new(cx, cy - gap)
        self.Lines[4].From = Vector2.new(cx, cy + gap)
        self.Lines[4].To = Vector2.new(cx, cy + gap + size)
    end)
end

function Crosshair:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    for _, line in ipairs(self.Lines) do pcall(function() line:Remove() end) end
    self.Lines = {}
end

-- ====================== FOV ======================
local function setFov(value)
    local camera = workspace.CurrentCamera
    if camera then camera.FieldOfView = value end
end

-- ====================== TEXTURE BUG ======================
local TextureBug = {}
TextureBug.__index = TextureBug
TextureBug.Enabled = false

function TextureBug:Toggle()
    self.Enabled = not self.Enabled
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return end
    if self.Enabled then
        self.OldWalkSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = humanoid.WalkSpeed * 0.8
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.1)
    else
        if self.OldWalkSpeed then humanoid.WalkSpeed = self.OldWalkSpeed end
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.5, 0.5)
    end
end

-- ====================== INSTANCES ======================
local EspInst = ESP.new()
local AimbotInst = Aimbot.new()
local TriggerInst = Triggerbot.new()
local BhopInst = Bhop.new()
local SpeedInst = Speed.new()
local FlyInst = Fly.new()
local CrosshairInst = Crosshair.new()
local TextureBugInst = setmetatable({}, TextureBug)

-- ====================== BUILD MENU ======================
Library.Folders = {
    Directory = "CounterBlox",
    Configs = "CounterBlox/Configs",
    Assets = "CounterBlox/Assets",
}

local Accent = Color3.fromRGB(84, 134, 255)
Library.Theme.Accent = Accent
pcall(function()
    Library:ChangeTheme("Accent", Accent)
    Library:ChangeTheme("AccentGradient", Color3.fromRGB(40, 70, 160))
end)

local Window = Library:Window({
    Name = "Counter-Blox",
    SubName = "Extension",
    MenuKeybind = Enum.KeyCode.Delete,
})

local KeybindList = Library:KeybindList("Keybinds")

Window:Category("Main")

-- AIMBOT
local aimPage = Window:Page({ Name = "Aimbot" })
local aimSection = aimPage:Section({ Name = "Aimbot", Side = 1 })

local aimToggle = aimSection:Toggle({
    Name = "Enabled",
    Flag = "AimEnabled",
    Default = false,
    Callback = function(v)
        state.Aim = v
        if v then AimbotInst:Start() else AimbotInst:Stop() end
    end,
})

aimToggle:Slider({
    Name = "FOV",
    Flag = "AimFov",
    Min = 30, Max = 360, Default = 120,
    Callback = function(v) state.AimFov = v end,
})

aimToggle:Slider({
    Name = "Smoothness",
    Flag = "AimSmooth",
    Min = 1, Max = 30, Default = 8,
    Callback = function(v) state.AimSmooth = v end,
})

local triggerSection = aimPage:Section({ Name = "Triggerbot", Side = 2 })
triggerSection:Toggle({
    Name = "Auto Fire",
    Flag = "TriggerEnabled",
    Default = false,
    Callback = function(v)
        state.Trigger = v
        if v then TriggerInst:Start() else TriggerInst:Stop() end
    end,
})

-- VISUALS
local visPage = Window:Page({ Name = "Visuals" })
local espSection = visPage:Section({ Name = "ESP", Side = 1 })

espSection:Toggle({
    Name = "Enabled",
    Flag = "EspEnabled",
    Default = false,
    Callback = function(v)
        state.Esp = v
        if v then EspInst:Start() else EspInst:Stop() end
    end,
})
espSection:Toggle({ Name = "Box", Flag = "EspBox", Default = true, Callback = function(v) state.EspBox = v end })
espSection:Toggle({ Name = "Name", Flag = "EspName", Default = true, Callback = function(v) state.EspName = v end })
espSection:Toggle({ Name = "Health", Flag = "EspHealth", Default = true, Callback = function(v) state.EspHealth = v end })
espSection:Toggle({ Name = "Tracer", Flag = "EspTracer", Default = false, Callback = function(v) state.EspTracer = v end })
espSection:Toggle({ Name = "Distance", Flag = "EspDistance", Default = false, Callback = function(v) state.EspDistance = v end })
espSection:Label("Box Color"):Colorpicker({
    Name = "Color",
    Flag = "EspColor",
    Default = Color3.fromRGB(84, 134, 255),
    Callback = function(c) state.EspColor = c end,
})

local otherSection = visPage:Section({ Name = "Other", Side = 2 })
otherSection:Toggle({
    Name = "Crosshair",
    Flag = "CrosshairEnabled",
    Default = false,
    Callback = function(v)
        state.Crosshair = v
        if v then CrosshairInst:Start() else CrosshairInst:Stop() end
    end,
})
otherSection:Slider({
    Name = "Field of View",
    Flag = "Fov",
    Min = 30, Max = 140, Default = 70,
    Callback = function(v)
        state.Fov = v
        setFov(v)
    end,
})

-- MISC
local miscPage = Window:Page({ Name = "Misc" })
local moveSection = miscPage:Section({ Name = "Movement", Side = 1 })

moveSection:Toggle({
    Name = "Bunnyhop",
    Flag = "BhopEnabled",
    Default = false,
    Callback = function(v)
        state.Bhop = v
        if v then BhopInst:Start() else BhopInst:Stop() end
    end,
})
moveSection:Toggle({
    Name = "Speed",
    Flag = "SpeedEnabled",
    Default = false,
    Callback = function(v)
        state.Speed = v
        SpeedInst:Apply()
    end,
})
moveSection:Slider({
    Name = "Speed Value",
    Flag = "SpeedValue",
    Min = 16, Max = 100, Default = 16,
    Callback = function(v)
        state.SpeedVal = v
        SpeedInst:Set(v)
    end,
})
moveSection:Toggle({
    Name = "Fly",
    Flag = "FlyEnabled",
    Default = false,
    Callback = function(v)
        state.Fly = v
        if v then FlyInst:Start() else FlyInst:Stop() end
    end,
})

local miscOther = miscPage:Section({ Name = "Other", Side = 2 })
miscOther:Toggle({
    Name = "Texture Bug",
    Flag = "TextureBugEnabled",
    Default = false,
    Callback = function(v)
        state.TextureBug = v
        TextureBugInst:Toggle()
    end,
})

-- Settings (scale, configs, watermark) + init
Library:CreateSettingsPage(Window, KeybindList)
Window:Init()

-- ====================== EXPOSE ======================
pcall(function()
    getgenv().CBX = {
        Library = Library,
        Window = Window,
        ESP = EspInst,
        Aimbot = AimbotInst,
        Triggerbot = TriggerInst,
        Bhop = BhopInst,
        Speed = SpeedInst,
        Fly = FlyInst,
        Crosshair = CrosshairInst,
        TextureBug = TextureBugInst,
    }
end)

pcall(function()
    Library:Notification({
        Title = "Counter-Blox",
        Description = "Loaded. Press DELETE to open the menu.",
        Duration = 6,
    })
end)
