--[[
    Counter-Blox Extension
    Single-file Roblox script.

    Menu: LinoriaLib (https://github.com/violin-suzutsuki/LinoriaLib)

    Load with:
    loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()

    Menu key: DELETE
]]

local SCRIPT_VERSION = "2.3"
local LOADER_URL = "https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"
local VERSION_URL = "https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/VERSION"

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
        local existing = pg:FindFirstChild("CBXNotify")
        if existing then existing:Destroy() end
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

    -- ragebot
    Rage = false,
    RageFov = 200,
    RageHitbox = "Head",
    RagePriority = "FOV",
    RageAutoFire = true,
    RageDelay = 0.08,
    RageTeamCheck = false,
    RageWallbang = true,
    RageFovCircle = true,

    -- esp
    Esp = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspTracer = false,
    EspDistance = false,
    EspColor = Color3.fromRGB(84, 134, 255),
    EspTeamCheck = false,
    EspChams = false,
    EspChamsColor = Color3.fromRGB(84, 134, 255),
    EspHeadDot = false,

    Crosshair = false,

    -- kill effects
    KillEffect = false,
    KillEffectSound = true,
    KillEffectColor = Color3.fromRGB(255, 80, 80),

    -- misc
    Bhop = false,
    BhopSpeed = 30,
    Speed = false,
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
-- Two screen projections per player (head-top + feet), no per-part loop.
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

    o.HeadDot = Drawing.new("Square")
    o.HeadDot.Filled = true
    o.HeadDot.Thickness = 0
    o.HeadDot.Transparency = 0
    o.HeadDot.Visible = false
    o.HeadDot.Color = state.EspColor

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
    o.HeadDot.Transparency = a
end

function ESP:Hide(o)
    o.BoxOuter.Visible = false
    o.BoxInner.Visible = false
    o.Name.Visible = false
    o.HealthBg.Visible = false
    o.Health.Visible = false
    o.Tracer.Visible = false
    o.Distance.Visible = false
    o.HeadDot.Visible = false
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

        -- chams (Highlight through walls)
        if character then
            local hl = character:FindFirstChild("CBXChams")
            if state.EspChams and show then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "CBXChams"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.OutlineTransparency = 1
                    hl.Parent = character
                end
                hl.FillColor = state.EspChamsColor
                hl.FillTransparency = 0.5
            elseif hl then
                hl:Destroy()
            end
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
        if onscreen then
            target.lastMin, target.lastMax = min, max
        elseif (target.dead or not player.Parent) and target.lastMin then
            -- keep the last known box so the death fade is visible
            min, max = target.lastMin, target.lastMax
        else
            self:Hide(o)
            continue
        end

        local width = max.X - min.X
        local height = max.Y - min.Y
        local cx = (min.X + max.X) / 2
        local humanoid = target.character:FindFirstChildOfClass("Humanoid")
        local health = humanoid and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0

        if state.Esp and state.EspBox then
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

        if state.Esp and state.EspName then
            o.Name.Text = player.Name
            o.Name.Position = Vector2.new(cx, min.Y - 15)
            o.Name.Visible = true
        else
            o.Name.Visible = false
        end

        if state.Esp and state.EspHealth then
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

        if state.Esp and state.EspTracer then
            o.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            o.Tracer.To = Vector2.new(cx, max.Y)
            o.Tracer.Visible = true
        else
            o.Tracer.Visible = false
        end

        if state.Esp and state.EspDistance then
            local dist = (camera.CFrame.Position - target.character:GetPivot().Position).Magnitude
            o.Distance.Text = tostring(math.floor(dist)) .. "m"
            o.Distance.Position = Vector2.new(cx, max.Y + 4)
            o.Distance.Visible = true
        else
            o.Distance.Visible = false
        end

        if state.Esp and state.EspHeadDot then
            local head = target.character:FindFirstChild("HeadHB") or target.character:FindFirstChild("Head")
            if head then
                local hp, hv = camera:WorldToViewportPoint(head.Position)
                if hv then
                    o.HeadDot.Position = Vector2.new(hp.X - 3, hp.Y - 3)
                    o.HeadDot.Size = Vector2.new(6, 6)
                    o.HeadDot.Color = state.EspColor
                    o.HeadDot.Visible = true
                else
                    o.HeadDot.Visible = false
                end
            else
                o.HeadDot.Visible = false
            end
        else
            o.HeadDot.Visible = false
        end

        self:SetAlpha(o, target.alpha)
    end
end

function ESP:Clear()
    for _, target in pairs(self.Targets) do
        self:RemoveObjects(target.objects)
    end
    self.Targets = {}
    -- remove chams highlights
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hl = character and character:FindFirstChild("CBXChams")
        if hl then hl:Destroy() end
    end
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
    -- camera priority so the snap beats the game's camera script
    RunService:BindToRenderStep("CBXAimbot", Enum.RenderPriority.Camera.Value + 1, function()
        self:Step()
    end)
    self.Connection = true
end

function Aimbot:Stop()
    if self.Connection then
        RunService:UnbindFromRenderStep("CBXAimbot")
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

-- ====================== RAGEBOT ======================
-- Instant-snap aim + auto fire. Aims at a chosen hitbox (HeadHB on Counter-Blox),
-- prioritises by FOV or distance, optionally shoots through walls.
local Ragebot = {}
Ragebot.__index = Ragebot

Ragebot.BIND = "CBXRagebot"

function Ragebot.new()
    local self = setmetatable({}, Ragebot)
    self.Running = false
    self.LastFire = 0
    self.Circle = {}
    self.Locked = false
    return self
end

function Ragebot:Start()
    if self.Running then return end
    self.Running = true
    -- camera priority so our snap wins over the game's camera update
    RunService:BindToRenderStep(Ragebot.BIND, Enum.RenderPriority.Camera.Value + 1, function()
        self:Step()
    end)
end

function Ragebot:Stop()
    if not self.Running then return end
    self.Running = false
    RunService:UnbindFromRenderStep(Ragebot.BIND)
    self.Locked = false
    for _, line in ipairs(self.Circle) do pcall(function() line:Remove() end) end
    self.Circle = {}
end

function Ragebot:Hitbox(player)
    local character = player.Character
    if not character then return nil end
    local cfg = state.RageHitbox
    if cfg == "Head" then
        return character:FindFirstChild("HeadHB") or character:FindFirstChild("Head")
    elseif cfg == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif cfg == "Body" then
        return character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild("HeadHB") or character:FindFirstChild("Head")
end

function Ragebot:Visible(character, part)
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

function Ragebot:FindTarget(camera)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestPart, bestScore = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not (state.RageTeamCheck and sameTeam(player)) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local part = self:Hitbox(player)
                if part then
                    local pos, onScreen = camera:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local screenDist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if screenDist <= state.RageFov then
                            if state.RageWallbang or self:Visible(character, part) then
                                local score = (state.RagePriority == "Distance")
                                    and (camera.CFrame.Position - part.Position).Magnitude
                                    or screenDist
                                if score < bestScore then
                                    bestScore = score
                                    bestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

function Ragebot:Fire()
    local now = os.clock()
    if now - self.LastFire < state.RageDelay then return end
    self.LastFire = now
    if type(mouse1click) == "function" then
        pcall(mouse1click)
    elseif type(mouse1press) == "function" then
        pcall(mouse1press)
        task.delay(0.02, function()
            if type(mouse1release) == "function" then pcall(mouse1release) end
        end)
    end
end

function Ragebot:Step()
    local camera = workspace.CurrentCamera
    if not camera then return end

    if not state.Rage then
        self.Locked = false
        self:DrawCircle(camera)
        return
    end

    local target = self:FindTarget(camera)
    self.Locked = target ~= nil
    self:DrawCircle(camera)

    if not target then return end

    -- instant snap
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.Position)

    if state.RageAutoFire and not UserInputService:GetFocusedTextBox() then
        self:Fire()
    end
end

function Ragebot:DrawCircle(camera)
    if not hasDrawing then return end
    local show = state.Rage and state.RageFovCircle
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local radius = state.RageFov
    local color = self.Locked and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)

    for i = 1, CIRCLE_SEGMENTS do
        local line = self.Circle[i]
        if not line then
            line = Drawing.new("Line")
            line.Thickness = 1
            line.Transparency = 1
            line.Visible = false
            self.Circle[i] = line
        end
        line.Visible = show
        if show then
            local a1 = (i / CIRCLE_SEGMENTS) * math.pi * 2
            local a2 = (((i % CIRCLE_SEGMENTS) + 1) / CIRCLE_SEGMENTS) * math.pi * 2
            line.Color = color
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

    -- only bhop while holding Space and actively moving
    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude <= 0 then return end

    local speed = state.BhopSpeed
    local unit = moveDir.Unit
    local airborne = humanoid:GetState() == Enum.HumanoidStateType.Freefall

    -- auto-jump the instant we touch the ground
    if not airborne then
        humanoid.Jump = true
    end

    -- push horizontal speed (slider value), keep vertical momentum
    root.AssemblyLinearVelocity = Vector3.new(
        unit.X * speed,
        root.AssemblyLinearVelocity.Y,
        unit.Z * speed
    )
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
    self.Gyro = nil
    self.Vel = nil
    self.Speed = 60
    return self
end

function Fly:Start()
    if self.Connection then return end
    local character = LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- PlatformStand stops the Humanoid from fighting the BodyMovers
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true end

    self.Gyro = Instance.new("BodyGyro")
    self.Gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    self.Gyro.P = 1e4
    self.Gyro.D = 200
    self.Gyro.Parent = root

    self.Vel = Instance.new("BodyVelocity")
    self.Vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    self.Vel.Velocity = Vector3.new(0, 0, 0)
    self.Vel.Parent = root

    self.Connection = RunService.RenderStepped:Connect(function() self:Step() end)
end

function Fly:Step()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (root and self.Vel and self.Gyro) then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    self.Gyro.CFrame = camera.CFrame

    local dir = Vector3.new(0, 0, 0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

    self.Vel.Velocity = dir.Magnitude > 0 and dir.Unit * self.Speed or Vector3.new(0, 0, 0)
end

function Fly:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    if self.Vel then self.Vel:Destroy() self.Vel = nil end
    if self.Gyro then self.Gyro:Destroy() self.Gyro = nil end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = false end
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

    -- hit / impact replication -> hitmarker + remember impact position
    self:On("HatObject", function(part, x, y, z, _, _, _, weapon)
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            self.LastHitPos = Vector3.new(x, y, z)
        end
        if state.Hitmarker then
            self:FlashHit()
        end
    end)

    -- kills: AddToKillfeed carries { killer, victim, weapon, ... }
    self:On("AddToKillfeed", function(data)
        if type(data) ~= "table" then return end
        local killer = data.killer or data.Killer or data.killerName or data.killername
        local victim = data.victim or data.Victim or data.victimName or data.victimname
        if killer ~= LocalPlayer.Name then return end

        if state.KillNotify and victim then
            notify("Kill", "You killed " .. tostring(victim))
        end
        if state.KillEffect then
            self:SpawnKillEffect(victim)
        end
    end)

    if hasDrawing then
        table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
            self:Render(dt)
        end))
    end
end

function Game:Stop()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    self.Started = false
    for _, line in ipairs(self.Lines) do pcall(function() line:Remove() end) end
    self.Lines = {}
end

function Game:FlashHit()
    self.HitAlpha = 1
end

function Game:SpawnKillEffect(victimName)
    -- prefer the victim's own position, fall back to the last bullet impact
    local pos
    if victimName then
        local victim = Players:FindFirstChild(victimName)
        local character = victim and victim.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then pos = root.Position end
        if not pos then
            local model = workspace:FindFirstChild(victimName)
            if model and model:IsA("Model") then
                local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if part then pos = part.Position end
            end
        end
    end
    pos = pos or self.LastHitPos
    if not pos then return end

    local part = Instance.new("Part")
    part.Name = "CBXKillEffect"
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.Position = pos
    part.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(state.KillEffectColor)
    emitter.LightEmission = 1
    emitter.Lifetime = NumberRange.new(0.4, 0.8)
    emitter.Speed = NumberRange.new(12, 26)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Rate = 0
    emitter.Parent = part
    emitter:Emit(60)

    if state.KillEffectSound then
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
        sound.Volume = 1
        sound.Parent = part
        sound:Play()
    end

    -- floating "KILL" text
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 80, 0, 24)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "KILL"
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 18
    label.TextColor3 = state.KillEffectColor
    label.TextStrokeTransparency = 0.5
    label.Parent = billboard

    task.delay(1.5, function()
        pcall(function() part:Destroy() end)
    end)
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

-- ====================== MOVEMENT EXTRAS ======================
-- Techniques ported from Counter-Blox movement cheats (pivo.ware):
-- noclip, airstuck, edgebug, pixelsurf, jumpbug, auto-strafe.
local Extras = {}
Extras.__index = Extras

function Extras.new()
    local self = setmetatable({}, Extras)
    self.Connection = nil
    self.StrafeConnection = nil
    self.SurfVel = nil
    self.NoclipCache = nil
    self.NoclipCharacter = nil
    self.NoClip = false
    self.AirStuck = false
    self.PixelSurf = false
    self.Edgebug = false
    self.Jumpbug = false
    self.JumpbugHeight = 2.5
    self.AutoStrafe = false
    self.AirAccel = 2
    self.EdgebugDebounce = false
    return self
end

function Extras:Start()
    if self.Connection then return end
    self.Connection = RunService.Stepped:Connect(function() self:Step() end)
    self.StrafeConnection = UserInputService.InputChanged:Connect(function(input) self:OnMouseMove(input) end)
end

function Extras:Stop()
    if self.Connection then self.Connection:Disconnect() self.Connection = nil end
    if self.StrafeConnection then self.StrafeConnection:Disconnect() self.StrafeConnection = nil end
    self.NoClip = false
    self.AirStuck = false
    self.PixelSurf = false
    self:RestoreNoclip()
    if self.SurfVel then self.SurfVel:Destroy() self.SurfVel = nil end
end

function Extras:Character()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if character and humanoid and root and humanoid.Health > 0 then
        return character, humanoid, root
    end
    return nil
end

-- poll the Linoria keypickers (Hold mode)
function Extras:ReadBinds()
    local O = Options
    if not O then return end
    if O.NoclipBind then self.NoClip = O.NoclipBind:GetState() end
    if O.AirstuckBind then self.AirStuck = O.AirstuckBind:GetState() end
    if O.EdgebugBind then self.Edgebug = O.EdgebugBind:GetState() end
    if O.PixelsurfBind then self.PixelSurf = O.PixelsurfBind:GetState() end
    if O.JumpbugBind then self.Jumpbug = O.JumpbugBind:GetState() end
end

function Extras:CaptureNoclip(character)
    if self.NoclipCharacter == character and self.NoclipCache then return end
    self.NoclipCharacter = character
    self.NoclipCache = {}
    for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" }) do
        local part = character:FindFirstChild(name)
        if part then
            self.NoclipCache[part] = part.CanCollide
        end
    end
end

function Extras:RestoreNoclip()
    if not self.NoclipCache then return end
    for part, collide in pairs(self.NoclipCache) do
        if part.Parent then part.CanCollide = collide end
    end
    self.NoclipCache = nil
    self.NoclipCharacter = nil
end

function Extras:IsTouchingWall(character, root)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local origin = root.Position
    for _, dir in ipairs({ root.CFrame.RightVector, -root.CFrame.RightVector, root.CFrame.LookVector, -root.CFrame.LookVector }) do
        if workspace:Raycast(origin, dir * 2, params) then return true end
    end
    return false
end

function Extras:UpdateSurf(character, root)
    if not self.PixelSurf then
        if self.SurfVel then
            self.SurfVel.MaxForce = Vector3.new()
            self.SurfVel.Parent = nil
        end
        return
    end
    if not self.SurfVel then
        self.SurfVel = Instance.new("BodyVelocity")
    end
    if self:IsTouchingWall(character, root) then
        self.SurfVel.MaxForce = Vector3.new(1500, 1500, 1500)
        self.SurfVel.Velocity = Vector3.new()
        self.SurfVel.Parent = root
    else
        self.SurfVel.MaxForce = Vector3.new()
        self.SurfVel.Parent = nil
    end
end

function Extras:TryEdgebug(humanoid, root)
    if humanoid:GetState() ~= Enum.HumanoidStateType.Landed then return end
    self.EdgebugDebounce = true
    task.spawn(function()
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vel.X * 1.8, -7, vel.Z * 1.8)
        task.wait()
        local saved = root.AssemblyLinearVelocity
        for _ = 1, 4 do
            task.wait()
            root.AssemblyLinearVelocity = saved - Vector3.new(0, 2, 0)
        end
        task.wait()
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * Vector3.new(1.8, 1, 1.8)
        task.wait(0.2)
        self.EdgebugDebounce = false
    end)
end

function Extras:OnMouseMove(input)
    if not self.AutoStrafe then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local character, humanoid = self:Character()
    if not character then return end
    local st = humanoid:GetState()
    if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then return end

    local delta = input.Delta.X
    local strafeKey = (delta < 0 and UserInputService:IsKeyDown(Enum.KeyCode.A))
        or (delta > 0 and UserInputService:IsKeyDown(Enum.KeyCode.D))
    if strafeKey then
        local gain = math.abs(delta) / 25 * self.AirAccel
        humanoid.WalkSpeed = math.clamp(humanoid.WalkSpeed + gain, 0, 120)
    end
end

function Extras:Step()
    self:ReadBinds()

    local character, humanoid, root = self:Character()
    if not character then return end

    -- Noclip
    if self.NoClip then
        self:CaptureNoclip(character)
        for part in pairs(self.NoclipCache) do
            part.CanCollide = false
        end
    elseif self.NoclipCache then
        self:RestoreNoclip()
    end

    -- Airstuck
    if self.AirStuck then
        root.Anchored = true
        root.AssemblyLinearVelocity = Vector3.new()
    elseif root.Anchored then
        root.Anchored = false
    end

    -- Jumpbug
    if self.Jumpbug then
        humanoid.JumpHeight = self.JumpbugHeight
    end

    -- Pixelsurf
    self:UpdateSurf(character, root)

    -- Edgebug
    if self.Edgebug and not self.EdgebugDebounce then
        self:TryEdgebug(humanoid, root)
    end
end

-- ====================== INSTANCES ======================
local EspInst = ESP.new()
local AimbotInst = Aimbot.new()
local RagebotInst = Ragebot.new()
local TriggerInst = Triggerbot.new()
local BhopInst = Bhop.new()
local SpeedInst = Speed.new()
local FlyInst = Fly.new()
local CrosshairInst = Crosshair.new()
local TextureBugInst = setmetatable({}, TextureBug)
local ReconInst = Recon.new()
local GameInst = Game.new()
GameInst:Start()
local ExtrasInst = Extras.new()
ExtrasInst:Start()

-- ====================== UPDATER ======================
local Updater = {}

function Updater:Check()
    local ok, latest = pcall(function() return game:HttpGet(VERSION_URL) end)
    if not ok or not latest then return false, nil end
    latest = latest:gsub("%s+", "")
    return latest ~= SCRIPT_VERSION, latest
end

function Updater:Unload()
    pcall(function() EspInst:Stop() end)
    pcall(function() AimbotInst:Stop() end)
    pcall(function() RagebotInst:Stop() end)
    pcall(function() TriggerInst:Stop() end)
    pcall(function() BhopInst:Stop() end)
    pcall(function() FlyInst:Stop() end)
    pcall(function() CrosshairInst:Stop() end)
    pcall(function() GameInst:Stop() end)
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        local hl = c and c:FindFirstChild("CBXChams")
        if hl then hl:Destroy() end
    end
    pcall(function() Library:Unload() end)
    pcall(function() getgenv().CBX = nil end)
end

function Updater:Run()
    local changed, latest = self:Check()
    if not changed then
        notify("Updater", "Already up to date (v" .. SCRIPT_VERSION .. ")")
        return
    end
    notify("Updater", "Updating to v" .. tostring(latest) .. " - reloading...")
    task.wait(0.75)
    self:Unload()
    task.wait(0.3)
    local ok, err = pcall(function()
        loadstring(game:HttpGet(LOADER_URL))()
    end)
    if not ok then
        warn("[CBX] Update failed: " .. tostring(err))
    end
end

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

local rageGroup = Tabs.Rage:AddRightGroupbox("Ragebot")
rageGroup:AddToggle("RageEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        state.Rage = v
        if v then RagebotInst:Start() else RagebotInst:Stop() end
    end,
})
rageGroup:AddToggle("RageAutoFire", { Text = "Auto Fire", Default = true, Callback = function(v) state.RageAutoFire = v end })
rageGroup:AddSlider("RageFov", { Text = "FOV", Default = 200, Min = 30, Max = 600, Rounding = 0, Suffix = "px", Callback = function(v) state.RageFov = v end })
rageGroup:AddSlider("RageDelay", { Text = "Fire Delay", Default = 0.08, Min = 0.01, Max = 0.5, Rounding = 2, Suffix = "s", Callback = function(v) state.RageDelay = v end })
rageGroup:AddDropdown("RageHitbox", { Text = "Hitbox", Values = { "Head", "Torso", "Body" }, Default = 1, Callback = function(v) state.RageHitbox = v end })
rageGroup:AddDropdown("RagePriority", { Text = "Priority", Values = { "FOV", "Distance" }, Default = 1, Callback = function(v) state.RagePriority = v end })
rageGroup:AddToggle("RageWallbang", { Text = "Wallbang (shoot through walls)", Default = true, Callback = function(v) state.RageWallbang = v end })
rageGroup:AddToggle("RageTeamCheck", { Text = "Team Check", Default = false, Callback = function(v) state.RageTeamCheck = v end })
rageGroup:AddToggle("RageFovCircle", { Text = "FOV Circle", Default = true, Callback = function(v) state.RageFovCircle = v end })

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
espGroup:AddToggle("EspHeadDot", { Text = "Head Dot", Default = false, Callback = function(v) state.EspHeadDot = v end })
espGroup:AddLabel("Box Color"):AddColorPicker("EspColor", {
    Default = Color3.fromRGB(84, 134, 255),
    Callback = function(v) state.EspColor = v end,
})

local chamsGroup = Tabs.Visuals:AddRightGroupbox("Chams")
chamsGroup:AddToggle("EspChams", {
    Text = "Enabled",
    Default = false,
    Callback = function(v)
        state.EspChams = v
        if v and not EspInst.Connection then EspInst:Start() end
    end,
})
chamsGroup:AddLabel("Chams Color"):AddColorPicker("EspChamsColor", {
    Default = Color3.fromRGB(84, 134, 255),
    Callback = function(v) state.EspChamsColor = v end,
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
visOther:AddSlider("Fov", { Text = "Field of View", Default = 70, Min = 30, Max = 140, Rounding = 0, Callback = function(v) setFov(v) end })

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
movGroup:AddSlider("SpeedValue", { Text = "Speed Value", Default = 16, Min = 16, Max = 100, Rounding = 0, Callback = function(v) SpeedInst:Set(v) end })
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

-- Movement+ (techniques from Counter-Blox movement cheats)
local moveExtra = Tabs.Misc:AddRightGroupbox("Movement+")
moveExtra:AddLabel("Noclip"):AddKeyPicker("NoclipBind", { Default = "V", Mode = "Hold", Text = "Noclip (hold)" })
moveExtra:AddLabel("Airstuck"):AddKeyPicker("AirstuckBind", { Default = "C", Mode = "Hold", Text = "Airstuck (hold)" })
moveExtra:AddLabel("Edgebug"):AddKeyPicker("EdgebugBind", { Default = "E", Mode = "Hold", Text = "Edgebug (hold)" })
moveExtra:AddLabel("Pixelsurf"):AddKeyPicker("PixelsurfBind", { Default = "F", Mode = "Hold", Text = "Pixelsurf (hold)" })
moveExtra:AddLabel("Jumpbug"):AddKeyPicker("JumpbugBind", { Default = "G", Mode = "Hold", Text = "Jumpbug (hold)" })
moveExtra:AddSlider("JumpbugHeight", { Text = "Jumpbug Height", Default = 2.5, Min = 2, Max = 4, Rounding = 2, Callback = function(v) ExtrasInst.JumpbugHeight = v end })
moveExtra:AddToggle("AutoStrafe", { Text = "Auto Strafe", Default = false, Callback = function(v) ExtrasInst.AutoStrafe = v end })
moveExtra:AddSlider("AirAccel", { Text = "Air Acceleration", Default = 2, Min = 0, Max = 6, Rounding = 1, Callback = function(v) ExtrasInst.AirAccel = v end })

-- GAME
local hitGroup = Tabs.Game:AddLeftGroupbox("Hit feedback")
hitGroup:AddToggle("Hitmarker", { Text = "Hitmarker", Default = false, Callback = function(v) state.Hitmarker = v end })
hitGroup:AddToggle("KillNotify", { Text = "Kill notifications", Default = false, Callback = function(v) state.KillNotify = v end })
hitGroup:AddLabel("Driven by ReplicatedStorage.Events")

local killGroup = Tabs.Game:AddRightGroupbox("Kill effects")
killGroup:AddToggle("KillEffect", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) state.KillEffect = v end,
})
killGroup:AddToggle("KillEffectSound", { Text = "Sound", Default = true, Callback = function(v) state.KillEffectSound = v end })
killGroup:AddLabel("Effect Color"):AddColorPicker("KillEffectColor", {
    Default = Color3.fromRGB(255, 80, 80),
    Callback = function(v) state.KillEffectColor = v end,
})

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
reconButton("Dump env: 'Animate'", function() ReconInst:DumpEnv("Animate") end)
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
menuGroup:AddButton({ Text = "Check for updates", Func = function() Updater:Run() end })
menuGroup:AddLabel("Version v" .. SCRIPT_VERSION)
menuGroup:AddButton({ Text = "Unload", Func = function() Updater:Unload() end })
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
        Ragebot = RagebotInst,
        Triggerbot = TriggerInst,
        Bhop = BhopInst,
        Speed = SpeedInst,
        Fly = FlyInst,
        Crosshair = CrosshairInst,
        TextureBug = TextureBugInst,
        Recon = ReconInst,
        Extras = ExtrasInst,
        Updater = Updater,
        Version = SCRIPT_VERSION,
        Game = GameInst,
        Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events"),
    }
end)

notify("Counter-Blox", "Loaded. Press DELETE for the menu.")
