--[[
    Counter-Blox Extension
    Single-file Roblox script.

    Menu: LinoriaLib (https://github.com/violin-suzutsuki/LinoriaLib)

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

-- ====================== LINORIA UI ======================
local REPO = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library, ThemeManager, SaveManager
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(REPO .. "Library.lua"))()
    end)
    if ok and result then
        Library = result
    else
        warn("[CBX] Failed to load LinoriaLib")
        return
    end
    pcall(function() ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))() end)
    pcall(function() SaveManager = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))() end)
end

-- simple standalone notifier (works regardless of library version)
local function notify(title, desc)
    pcall(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui")
        local gui = Instance.new("ScreenGui")
        gui.Name = "CBXNotify"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999999
        gui.Parent = pg
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 320, 0, 40)
        frame.Position = UDim2.new(0.5, -160, 0, 60)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(84, 134, 255)
        stroke.Parent = frame
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title .. ": " .. desc
        lbl.Font = Enum.Font.SourceSansSemibold
        lbl.TextSize = 15
        lbl.TextColor3 = Color3.fromRGB(235, 235, 240)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        task.delay(4, function() gui:Destroy() end)
    end)
end

-- ====================== STATE ======================
local state = {
    -- aimbot
    Aim = false,
    AimFov = 120,
    AimSmooth = 4,
    AimPart = "Head",
    AimTeamCheck = false,
    AimVisible = false,
    AimHold = true,
    AimFovCircle = true,
    AimPrediction = 0,

    Trigger = false,

    -- esp
    Esp = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspTracer = false,
    EspDistance = false,
    EspColor = Color3.fromRGB(84, 134, 255),
    EspTeamCheck = false,
    EspBoxType = "normal",

    Crosshair = false,
    Fov = 70,

    -- misc
    Bhop = false,
    BhopSpeed = 30,
    Speed = false,
    SpeedVal = 16,
    Fly = false,
    TextureBug = false,

    -- game events
    Hitmarker = false,
    KillNotify = false,
}

local function sameTeam(player)
    local myTeam = LocalPlayer.Team
    return myTeam ~= nil and player.Team == myTeam
end

-- ====================== ESP (optimized Drawing) ======================
-- One bounding box per player via Model:GetBoundingBox (8 points total),
-- instead of projecting every body part's 8 corners each frame.
local ESP = {}
ESP.__index = ESP

local FADE_TIME = 0.15

-- Project head-top and feet to screen (2 points per player, very cheap).
-- Counter-Blox exposes a custom head hitbox (HeadHB); fall back to Head.
local function projectBox(character)
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local head = character:FindFirstChild("HeadHB") or character:FindFirstChild("Head")

    local topPos = (head and head.Position or root.Position) + Vector3.new(0, 1.2, 0)
    local bottomPos = root.Position - Vector3.new(0, 3, 0)

    local top, tv = camera:WorldToViewportPoint(topPos)
    local bottom, bv = camera:WorldToViewportPoint(bottomPos)
    if not (tv and bv) then return nil end

    local yTop = math.min(top.Y, bottom.Y)
    local yBottom = math.max(top.Y, bottom.Y)
    local height = math.max(yBottom - yTop, 1)
    local width = height * 0.45
    local cx = top.X

    local min = Vector2.new(cx - width / 2, yTop)
    local max = Vector2.new(cx + width / 2, yBottom)
    return min, max, true
end

function ESP.new()
    local self = setmetatable({}, ESP)
    self.Targets = {}
    self.Connection = nil
    return self
end

function ESP:IsEnemy(player)
    if state.EspTeamCheck and sameTeam(player) then
        return false
    end
    return true
end

function ESP:CreateObjects()
    local o = {}
    if not hasDrawing then return o end

    o.BoxOuter = Drawing.new("Square")
    o.BoxOuter.Thickness = 3
    o.BoxOuter.Filled = false
    o.BoxOuter.Transparency = 0
    o.BoxOuter.Color = Color3.new(0, 0, 0)
    o.BoxOuter.Visible = false

    o.BoxInner = Drawing.new("Square")
    o.BoxInner.Thickness = 1
    o.BoxInner.Filled = false
    o.BoxInner.Transparency = 0
    o.BoxInner.Color = state.EspColor
    o.BoxInner.Visible = false

    o.Name = Drawing.new("Text")
    o.Name.Font = Drawing.Fonts.UI
    o.Name.Size = 13
    o.Name.Center = true
    o.Name.Outline = true
    o.Name.Transparency = 0
    o.Name.Visible = false
    o.Name.Color = Color3.new(1, 1, 1)

    o.HealthBg = Drawing.new("Square")
    o.HealthBg.Filled = true
    o.HealthBg.Transparency = 0
    o.HealthBg.Visible = false
    o.HealthBg.Color = Color3.new(0, 0, 0)

    o.Health = Drawing.new("Square")
    o.Health.Filled = true
    o.Health.Transparency = 0
    o.Health.Visible = false
    o.Health.Color = Color3.new(0, 1, 0)

    o.Tracer = Drawing.new("Line")
    o.Tracer.Thickness = 1
    o.Tracer.Transparency = 0
    o.Tracer.Visible = false
    o.Tracer.Color = Color3.new(1, 1, 1)

    o.Distance = Drawing.new("Text")
    o.Distance.Font = Drawing.Fonts.UI
    o.Distance.Size = 13
    o.Distance.Center = true
    o.Distance.Outline = true
    o.Distance.Transparency = 0
    o.Distance.Visible = false
    o.Distance.Color = Color3.new(1, 1, 1)

    return o
end

function ESP:RemoveObjects(o)
    for _, d in pairs(o) do pcall(function() d:Remove() end) end
end

function ESP:SetAlpha(o, a)
    o.BoxOuter.Transparency = a
    o.BoxInner.Transparency = a
    o.Name.Transparency = a
    o.HealthBg.Transparency = a
    o.Health.Transparency = a
    o.Tracer.Transparency = a
    o.Distance.Transparency = a
end

function ESP:Hide(o)
    o.BoxOuter.Visible = false
    o.BoxInner.Visible = false
    o.Name.Visible = false
    o.HealthBg.Visible = false
    o.Health.Visible = false
    o.Tracer.Visible = false
    o.Distance.Visible = false
end

function ESP:Start()
    if self.Connection then return end
    self.Connection = RunService.RenderStepped:Connect(function(dt) self:Render(dt) end)
end

function ESP:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:Clear()
end

function ESP:Render(dt)
    if not hasDrawing then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local target = self.Targets[player]
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local alive = character and humanoid and humanoid.Health > 0
        local show = alive and self:IsEnemy(player)

        if show then
            if not target or target.character ~= character then
                if target then self:RemoveObjects(target.objects) end
                target = { character = character, objects = self:CreateObjects(), alpha = 0 }
                self.Targets[player] = target
            end
            target.dead = false
        elseif target then
            target.dead = true
        end
    end

    for player, target in pairs(self.Targets) do
        local o = target.objects
        local step = (dt or 0.016) / FADE_TIME

        if target.dead or not player.Parent then
            target.alpha = math.max(0, target.alpha - step)
            if target.alpha <= 0 then
                self:RemoveObjects(o)
                self.Targets[player] = nil
                continue
            end
        else
            target.alpha = math.min(1, target.alpha + step)
        end

        local min, max, onscreen = projectBox(target.character)
        if not onscreen then
            self:Hide(o)
            continue
        end

        local width = max.X - min.X
        local height = max.Y - min.Y
        local cx = (min.X + max.X) / 2
        local humanoid = target.character:FindFirstChildOfClass("Humanoid")
        local health = humanoid and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0

        if state.EspBox then
            o.BoxOuter.Position = min - Vector2.new(1, 1)
            o.BoxOuter.Size = Vector2.new(width + 2, height + 2)
            o.BoxOuter.Visible = true
            o.BoxInner.Position = min
            o.BoxInner.Size = Vector2.new(width, height)
            o.BoxInner.Color = state.EspColor
            o.BoxInner.Visible = true
        else
            o.BoxOuter.Visible = false
            o.BoxInner.Visible = false
        end

        if state.EspName then
            o.Name.Text = player.Name
            o.Name.Position = Vector2.new(cx, min.Y - 15)
            o.Name.Visible = true
        else
            o.Name.Visible = false
        end

        if state.EspHealth then
            local barX = min.X - 6
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
            o.Tracer.To = Vector2.new(cx, max.Y)
            o.Tracer.Visible = true
        else
            o.Tracer.Visible = false
        end

        if state.EspDistance then
            local dist = (camera.CFrame.Position - target.character:GetPivot().Position).Magnitude
            o.Distance.Text = tostring(math.floor(dist)) .. "m"
            o.Distance.Position = Vector2.new(cx, max.Y + 4)
            o.Distance.Visible = true
        else
            o.Distance.Visible = false
        end

        self:SetAlpha(o, target.alpha)
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

local CIRCLE_SEGMENTS = 64

function Aimbot.new()
    local self = setmetatable({}, Aimbot)
    self.Connection = nil
    self.Circle = {}
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
    for _, line in ipairs(self.Circle) do
        pcall(function() line:Remove() end)
    end
    self.Circle = {}
end

function Aimbot:aimKeyDown()
    if not state.AimHold then return true end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

function Aimbot:getAimPart(character)
    local which = state.AimPart
    if which == "Head" then
        -- Counter-Blox uses a custom head hitbox (HeadHB); fall back to Head
        return character:FindFirstChild("HeadHB")
            or character:FindFirstChild("Head")
    elseif which == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild("HumanoidRootPart")
end

function Aimbot:isVisible(character, part)
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    local origin = camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(character)
end

function Aimbot:FindTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local radius = state.AimFov

    local bestPart, bestScore = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not (state.AimTeamCheck and sameTeam(player)) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local part = self:getAimPart(character)
                if part then
                    local pos, onScreen = camera:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist <= radius and dist < bestScore then
                            if (not state.AimVisible) or self:isVisible(character, part) then
                                bestScore = dist
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

function Aimbot:Step()
    self:DrawCircle()

    if not state.Aim then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    if not self:aimKeyDown() then return end

    local part = self:FindTarget()
    if not part then return end

    local targetPos = part.Position
    if state.AimPrediction > 0 then
        local root = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (root.Position - camera.CFrame.Position).Magnitude
            targetPos = targetPos + root.AssemblyLinearVelocity * (dist / 1000) * state.AimPrediction
        end
    end

    local goal = CFrame.lookAt(camera.CFrame.Position, targetPos)
    local smooth = state.AimSmooth
    if smooth and smooth > 1 then
        camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(1 / smooth, 0.02, 1))
    else
        camera.CFrame = goal
    end
end

function Aimbot:DrawCircle()
    if not hasDrawing then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local show = state.AimFovCircle
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local radius = state.AimFov

    for i = 1, CIRCLE_SEGMENTS do
        local line = self.Circle[i]
        if not line then
            line = Drawing.new("Line")
            line.Thickness = 1
            line.Transparency = 1
            line.Color = Color3.new(1, 1, 1)
            line.Visible = false
            self.Circle[i] = line
        end

        line.Visible = show
        if show then
            local a1 = (i / CIRCLE_SEGMENTS) * math.pi * 2
            local a2 = (((i % CIRCLE_SEGMENTS) + 1) / CIRCLE_SEGMENTS) * math.pi * 2
            line.From = center + Vector2.new(math.cos(a1), math.sin(a1)) * radius
            line.To = center + Vector2.new(math.cos(a2), math.sin(a2)) * radius
        end
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
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return end
    if UserInputService:GetFocusedTextBox() then return end

    -- Counter-Blox bhop: hold Space, push horizontal velocity, auto-jump on landing
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local vel = root.AssemblyLinearVelocity
            local speed = state.BhopSpeed
            root.AssemblyLinearVelocity = Vector3.new(moveDir.Unit.X * speed, vel.Y, moveDir.Unit.Z * speed)
            self.LastVel = root.AssemblyLinearVelocity
        end
        humanoid.Jump = true
    elseif self.LastVel and humanoid.FloorMaterial == Enum.Material.Air then
        -- keep momentum while airborne after releasing Space
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(self.LastVel.X, vel.Y, self.LastVel.Z)
    else
        self.LastVel = nil
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

-- ====================== RECON (reverse engineering) ======================
local Recon = {}
Recon.__index = Recon

function Recon.new()
    local self = setmetatable({}, Recon)
    self.Logging = false
    self.Lines = {}
    return self
end

function Recon:Add(text)
    table.insert(self.Lines, text)
    print("[CBX] " .. text)
end

function Recon:Clear()
    self.Lines = {}
end

function Recon:Save()
    local path = "CounterBlox/recon.txt"
    local ok = pcall(function()
        if not isfolder("CounterBlox") then makefolder("CounterBlox") end
        writefile(path, table.concat(self.Lines, "\n"))
    end)
    return ok, path
end

function Recon:DumpRemotes()
    self:Add("===== REMOTES =====")
    local wanted = {
        RemoteEvent = true, RemoteFunction = true,
        UnreliableRemoteEvent = true,
        BindableEvent = true, BindableFunction = true,
    }
    local function scan(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if wanted[obj.ClassName] then
                self:Add(obj:GetFullName() .. "  [" .. obj.ClassName .. "]")
            end
        end
    end
    pcall(scan, game:GetService("ReplicatedStorage"))
    pcall(scan, game:GetService("ReplicatedFirst"))
    pcall(scan, workspace)
end

function Recon:DumpScripts()
    self:Add("===== LOADED MODULES =====")
    pcall(function()
        for _, s in ipairs(getloadedmodules()) do
            self:Add("Module: " .. s:GetFullName())
        end
    end)
    self:Add("===== RUNNING SCRIPTS =====")
    pcall(function()
        for _, s in ipairs(getrunningscripts()) do
            self:Add(s.ClassName .. ": " .. s:GetFullName())
        end
    end)
end

function Recon:DumpEnv(scriptName)
    self:Add("===== ENV: " .. tostring(scriptName) .. " =====")
    pcall(function()
        for _, s in ipairs(game:GetDescendants()) do
            if (s:IsA("LocalScript") or s:IsA("ModuleScript")) and s.Name == scriptName then
                local env = getsenv(s)
                local keys = {}
                for k, v in pairs(env) do
                    table.insert(keys, k .. "  (" .. type(v) .. ")")
                end
                table.sort(keys)
                self:Add("-- " .. s:GetFullName())
                for _, k in ipairs(keys) do
                    self:Add("   " .. k)
                end
            end
        end
    end)
end

function Recon:DumpSettings()
    self:Add("===== WORKSPACE.SETTINGS =====")
    pcall(function()
        local s = workspace:FindFirstChild("settings")
        if s then
            for _, v in ipairs(s:GetDescendants()) do
                if v:IsA("ValueBase") then
                    self:Add(v.Name .. " = " .. tostring(v.Value))
                end
            end
        end
    end)
end

function Recon:DumpGui()
    self:Add("===== PLAYERGUI =====")
    pcall(function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            self:Add(g:GetFullName() .. "  [" .. g.ClassName .. "]")
        end
    end)
end

function Recon:DumpCharacter()
    self:Add("===== CHARACTER =====")
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, c in ipairs(char:GetDescendants()) do
                self:Add(c:GetFullName() .. "  [" .. c.ClassName .. "]")
            end
        end
    end)
end

function Recon:ToggleRemoteLog()
    if self.Logging then
        self.Logging = false
        if self.HookRef then
            pcall(function() hookmetamethod(game, "__namecall", self.HookRef) end)
        end
        self:Add("Remote logging stopped")
        return false
    end

    self.Logging = true
    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self2, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local args = { ... }
                local parts = {}
                for i = 1, math.min(4, #args) do
                    parts[i] = tostring(args[i])
                end
                print("[CBX-REMOTE] " .. tostring(self2) .. " : " .. method .. "(" .. table.concat(parts, ", ") .. ")")
            end
            return old(self2, ...)
        end)
        self.HookRef = old
    end)
    self:Add(ok and "Remote logging started (see console)" or "hookmetamethod unavailable")
    return true
end

function Recon:FullReport()
    self:Clear()
    self:DumpRemotes()
    self:DumpScripts()
    self:DumpSettings()
    self:DumpGui()
    self:DumpCharacter()
    local ok, path = self:Save()
    if ok then
        self:Add("Report saved to " .. path)
    else
        self:Add("writefile unavailable - report only in console")
    end
    return #self.Lines
end

-- locate GC'd tables that expose a named key (e.g. Counter-Blox's controller)
function Recon:FindGCKey(key)
    self:Add("===== GC TABLES WITH KEY '" .. key .. "' =====")
    local count = 0
    pcall(function()
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, key) ~= nil then
                count = count + 1
                self:Add("#" .. count .. "  " .. key .. " = " .. type(rawget(obj, key)))
                for k, v in pairs(obj) do
                    if type(v) == "function" then
                        self:Add("     ." .. tostring(k) .. "()")
                    elseif type(v) ~= "table" then
                        self:Add("     ." .. tostring(k) .. " = " .. tostring(v))
                    end
                end
            end
        end
    end)
    if count == 0 then
        self:Add("(none found - key may not exist)")
    end
end

-- find functions whose bytecode constants mention a string (remote names, etc.)
function Recon:FindGCCallers(str)
    self:Add("===== FUNCTIONS REFERENCING '" .. str .. "' =====")
    local count = 0
    pcall(function()
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "function" then
                local ok, consts = pcall(debug.getconstants, obj)
                if ok and type(consts) == "table" then
                    for _, c in ipairs(consts) do
                        if type(c) == "string" and c:find(str, 1, true) then
                            count = count + 1
                            local info = debug.getinfo(obj)
                            self:Add("fn '" .. c .. "'  src=" .. tostring(info and info.short_src))
                            break
                        end
                    end
                end
            end
        end
    end)
    if count == 0 then
        self:Add("(no function constants matched)")
    end
end

-- dump the keys of every loaded ModuleScript's environment
function Recon:DumpModuleFunctions()
    self:Add("===== MODULE ENVIRONMENTS =====")
    pcall(function()
        for _, mod in ipairs(getloadedmodules()) do
            local ok, env = pcall(getsenv, mod)
            if ok and type(env) == "table" then
                self:Add("-- " .. mod:GetFullName())
                local keys = {}
                for k, v in pairs(env) do
                    if type(v) == "function" then
                        table.insert(keys, "  ." .. tostring(k) .. "()")
                    end
                end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    self:Add(k)
                end
            end
        end
    end)
end

-- try to locate Counter-Blox's client controller by its known member names
function Recon:FindController()
    for _, key in ipairs({ "moveFunc", "speedupdate", "shootFunc", "fireFunc" }) do
        self:FindGCKey(key)
    end
end

-- log everything the server sends to the client
function Recon:ToggleRemoteReceiver()
    if self.Receiving then
        self.Receiving = false
        for _, conn in ipairs(self.RecvConns or {}) do
            pcall(function() conn:Disconnect() end)
        end
        self.RecvConns = {}
        self:Add("Remote receiver stopped")
        return false
    end
    self.Receiving = true
    self.RecvConns = {}
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local conn = obj.OnClientEvent:Connect(function(...)
                    local args = {}
                    for i = 1, math.min(4, select("#", ...)) do
                        args[i] = tostring((select(i, ...)))
                    end
                    print("[CBX-RECV] " .. obj:GetFullName() .. "(" .. table.concat(args, ", ") .. ")")
                end)
                table.insert(self.RecvConns, conn)
            end
        end
    end)
    self:Add("Remote receiver started (" .. #self.RecvConns .. " events)")
    return true
end

-- ====================== GAME EVENTS (reverse-engineered) ======================
-- Hooks Counter-Blox's real ReplicatedStorage.Events signals.
local Game = {}
Game.__index = Game

local HITMARKER_SEGMENTS = 4

function Game.new()
    local self = setmetatable({}, Game)
    self.Connections = {}
    self.HitAlpha = 0
    self.Lines = {}
    self.Started = false
    return self
end

function Game:Events()
    return game:GetService("ReplicatedStorage"):FindFirstChild("Events")
end

function Game:On(eventName, callback)
    local events = self:Events()
    local remote = events and events:FindFirstChild(eventName)
    if remote and (remote:IsA("RemoteEvent") or remote:IsA("BindableEvent")) then
        table.insert(self.Connections, remote.OnClientEvent:Connect(callback))
        return true
    end
    return false
end

function Game:Start()
    if self.Started then return end
    self.Started = true

    -- hit / impact replication -> hitmarker
    self:On("HatObject", function(part, x, y, z, _, _, _, weapon)
        if state.Hitmarker then
            self:FlashHit()
        end
    end)

    -- kills
    self:On("CreateRagdoll", function(_, victim)
        if state.KillNotify and victim then
            notify("Kill", tostring(victim) .. " was killed")
        end
    end)

    if hasDrawing then
        table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
            self:Render(dt)
        end))
    end
end

function Game:FlashHit()
    self.HitAlpha = 1
end

function Game:EnsureLines()
    if not hasDrawing or #self.Lines > 0 then return end
    for i = 1, HITMARKER_SEGMENTS do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Transparency = 0
        line.Color = Color3.new(1, 1, 1)
        line.Visible = false
        self.Lines[i] = line
    end
end

function Game:Render(dt)
    self:EnsureLines()
    if #self.Lines == 0 then return end

    if self.HitAlpha > 0 then
        self.HitAlpha = math.max(0, self.HitAlpha - (dt or 0.016) / 0.4)
    end

    local camera = workspace.CurrentCamera
    local show = self.HitAlpha > 0 and camera
    if show then
        local cx = camera.ViewportSize.X / 2
        local cy = camera.ViewportSize.Y / 2
        local inner, outer = 6, 12
        local pts = {
            { Vector2.new(cx - outer, cy - outer), Vector2.new(cx - inner, cy - inner) },
            { Vector2.new(cx + inner, cy - inner), Vector2.new(cx + outer, cy - outer) },
            { Vector2.new(cx - outer, cy + outer), Vector2.new(cx - inner, cy + inner) },
            { Vector2.new(cx + inner, cy + inner), Vector2.new(cx + outer, cy + outer) },
        }
        for i = 1, HITMARKER_SEGMENTS do
            local line = self.Lines[i]
            line.From = pts[i][1]
            line.To = pts[i][2]
            line.Transparency = self.HitAlpha
            line.Visible = true
        end
    else
        for i = 1, #self.Lines do
            self.Lines[i].Visible = false
        end
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
local ReconInst = Recon.new()
local GameInst = Game.new()
GameInst:Start()


-- ====================== BUILD MENU ======================
local Window = Library:CreateWindow({
    Title = "Counter-Blox",
    Center = true,
    AutoShow = false,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Rage = Window:AddTab("Rage"),
    Visuals = Window:AddTab("Visuals"),
    Misc = Window:AddTab("Misc"),
    Game = Window:AddTab("Game"),
    Developer = Window:AddTab("Developer"),
    ["UI Settings"] = Window:AddTab("UI Settings"),
}

-- RAGE
local aimGroup = Tabs.Rage:AddLeftGroupbox("Aimbot")
aimGroup:AddToggle("AimEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        state.Aim = v
        if v then AimbotInst:Start() else AimbotInst:Stop() end
    end,
})
aimGroup:AddSlider("AimFov", { Text = "FOV", Default = 120, Min = 30, Max = 360, Rounding = 0, Suffix = "px", Callback = function(v) state.AimFov = v end })
aimGroup:AddSlider("AimSmooth", { Text = "Smoothness", Default = 4, Min = 1, Max = 30, Rounding = 0, Callback = function(v) state.AimSmooth = v end })
aimGroup:AddSlider("AimPrediction", { Text = "Prediction", Default = 0, Min = 0, Max = 2, Rounding = 2, Callback = function(v) state.AimPrediction = v end })
aimGroup:AddDropdown("AimPart", { Text = "Target Part", Values = { "Head", "Torso", "Nearest" }, Default = 1, Callback = function(v) state.AimPart = v end })
aimGroup:AddToggle("AimTeamCheck", { Text = "Team Check", Default = false, Callback = function(v) state.AimTeamCheck = v end })
aimGroup:AddToggle("AimVisible", { Text = "Visible Check", Default = false, Callback = function(v) state.AimVisible = v end })
aimGroup:AddToggle("AimHold", { Text = "Hold RMB", Default = true, Callback = function(v) state.AimHold = v end })
aimGroup:AddToggle("AimFovCircle", { Text = "FOV Circle", Default = true, Callback = function(v) state.AimFovCircle = v end })

local triggerGroup = Tabs.Rage:AddRightGroupbox("Triggerbot")
triggerGroup:AddToggle("TriggerEnabled", {
    Text = "Auto Fire",
    Default = false,
    Callback = function(v)
        state.Trigger = v
        if v then TriggerInst:Start() else TriggerInst:Stop() end
    end,
})

-- VISUALS
local espGroup = Tabs.Visuals:AddLeftGroupbox("ESP")
espGroup:AddToggle("EspEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        state.Esp = v
        if v then EspInst:Start() else EspInst:Stop() end
    end,
})
espGroup:AddToggle("EspBox", { Text = "Box", Default = true, Callback = function(v) state.EspBox = v end })
espGroup:AddToggle("EspName", { Text = "Name", Default = true, Callback = function(v) state.EspName = v end })
espGroup:AddToggle("EspHealth", { Text = "Health", Default = true, Callback = function(v) state.EspHealth = v end })
espGroup:AddToggle("EspTracer", { Text = "Tracer", Default = false, Callback = function(v) state.EspTracer = v end })
espGroup:AddToggle("EspDistance", { Text = "Distance", Default = false, Callback = function(v) state.EspDistance = v end })
espGroup:AddToggle("EspTeamCheck", { Text = "Team Check", Default = false, Callback = function(v) state.EspTeamCheck = v end })
espGroup:AddLabel("Box Color"):AddColorPicker("EspColor", {
    Default = Color3.fromRGB(84, 134, 255),
    Callback = function(v) state.EspColor = v end,
})

local visOther = Tabs.Visuals:AddRightGroupbox("Other")
visOther:AddToggle("CrosshairEnabled", {
    Text = "Crosshair",
    Default = false,
    Callback = function(v)
        state.Crosshair = v
        if v then CrosshairInst:Start() else CrosshairInst:Stop() end
    end,
})
visOther:AddSlider("Fov", { Text = "Field of View", Default = 70, Min = 30, Max = 140, Rounding = 0, Callback = function(v) state.Fov = v; setFov(v) end })

-- MISC
local movGroup = Tabs.Misc:AddLeftGroupbox("Movement")
movGroup:AddToggle("BhopEnabled", {
    Text = "Bunnyhop",
    Default = false,
    Callback = function(v)
        state.Bhop = v
        if v then BhopInst:Start() else BhopInst:Stop() end
    end,
})
movGroup:AddSlider("BhopSpeed", { Text = "Bhop Speed", Default = 30, Min = 18, Max = 500, Rounding = 0, Callback = function(v) state.BhopSpeed = v end })
movGroup:AddToggle("SpeedEnabled", { Text = "Speed Hack", Default = false, Callback = function(v) state.Speed = v; SpeedInst:Apply() end })
movGroup:AddSlider("SpeedValue", { Text = "Speed Value", Default = 16, Min = 16, Max = 100, Rounding = 0, Callback = function(v) state.SpeedVal = v; SpeedInst:Set(v) end })
movGroup:AddToggle("FlyEnabled", {
    Text = "Fly",
    Default = false,
    Callback = function(v)
        state.Fly = v
        if v then FlyInst:Start() else FlyInst:Stop() end
    end,
})

local miscOther = Tabs.Misc:AddRightGroupbox("Other")
miscOther:AddToggle("TextureBugEnabled", {
    Text = "Texture Bug",
    Default = false,
    Callback = function(v)
        state.TextureBug = v
        TextureBugInst:Toggle()
    end,
})

-- GAME
local hitGroup = Tabs.Game:AddLeftGroupbox("Hit feedback")
hitGroup:AddToggle("Hitmarker", { Text = "Hitmarker", Default = false, Callback = function(v) state.Hitmarker = v end })
hitGroup:AddToggle("KillNotify", { Text = "Kill notifications", Default = false, Callback = function(v) state.KillNotify = v end })
hitGroup:AddLabel("Driven by ReplicatedStorage.Events")

-- DEVELOPER
local reconGroup = Tabs.Developer:AddLeftGroupbox("Recon")
local function reconButton(name, fn)
    reconGroup:AddButton({
        Text = name,
        Func = function()
            ReconInst:Clear()
            fn()
            notify(name, #ReconInst.Lines .. " lines (console)")
        end,
    })
end
reconButton("Dump Remotes", function() ReconInst:DumpRemotes() end)
reconButton("Dump Scripts", function() ReconInst:DumpScripts() end)
reconButton("Dump settings values", function() ReconInst:DumpSettings() end)
reconButton("Dump PlayerGui", function() ReconInst:DumpGui() end)
reconButton("Dump Character", function() ReconInst:DumpCharacter() end)
reconButton("Full report (console + file)", function()
    local n = ReconInst:FullReport()
    notify("Recon", "Full report: " .. n .. " lines")
end)

local gameGroup = Tabs.Developer:AddRightGroupbox("Game functions")
local function gameButton(name, fn)
    gameGroup:AddButton({
        Text = name,
        Func = function()
            ReconInst:Clear()
            fn()
            notify(name, #ReconInst.Lines .. " lines (console)")
        end,
    })
end
gameButton("Find controller (moveFunc etc)", function() ReconInst:FindController() end)
gameButton("Dump module envs", function() ReconInst:DumpModuleFunctions() end)
gameButton("Find callers: FireServer", function() ReconInst:FindGCCallers("FireServer") end)
gameButton("Find callers: Shoot", function() ReconInst:FindGCCallers("Shoot") end)
gameGroup:AddToggle("ReconRemoteLog", { Text = "Log FireServer calls", Default = false, Callback = function(v)
    if v ~= ReconInst.Logging then ReconInst:ToggleRemoteLog() end
end })
gameGroup:AddToggle("ReconRemoteRecv", { Text = "Log server -> client events", Default = false, Callback = function(v)
    if v ~= ReconInst.Receiving then ReconInst:ToggleRemoteReceiver() end
end })

-- UI SETTINGS
local menuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
menuGroup:AddButton({ Text = "Unload", Func = function() Library:Unload() end })
menuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "Delete", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("CounterBlox")
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
end
if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("CounterBlox/configs")
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
end

Library:SetWatermarkVisibility(true)
Library:SetWatermark("Counter-Blox")

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
        Recon = ReconInst,
        Game = GameInst,
        Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events"),
    }
end)

notify("Counter-Blox", "Loaded. Press DELETE for the menu.")
