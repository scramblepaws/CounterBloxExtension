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

-- silence the library's own harmless "SetOpen before defined" warning
do
    local origSafeCall = Library.SafeCall
    Library.SafeCall = function(self, func, ...)
        local args = table.pack(...)
        local ok, err = pcall(func, table.unpack(args, 1, args.n))
        if not ok then
            local msg = tostring(err)
            if not msg:find("SetOpen") then
                warn(err)
            end
        end
        return ok
    end
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
}

local function sameTeam(player)
    local myTeam = LocalPlayer.Team
    return myTeam ~= nil and player.Team == myTeam
end

-- ====================== ESP (tulontop/esp-lib.lua) ======================
-- Purpose-built Drawing ESP library: normal/corner boxes, health bars,
-- name tags, distances and tracers, with automatic cleanup.
local espLib
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/tulontop/esp-lib.lua/refs/heads/main/source.lua"))()
    end)
    if ok and result then
        espLib = result
    else
        warn("[CBX] Failed to load esp-lib")
    end
end

local ESP = {}
ESP.__index = ESP

function ESP.new()
    local self = setmetatable({}, ESP)
    self.Added = {}
    self.Connection = nil
    return self
end

function ESP:IsEnemy(player)
    if state.EspTeamCheck and sameTeam(player) then
        return false
    end
    return true
end

function ESP:ApplySettings()
    local e = espLib and getgenv().esplib
    if not e then return end
    local on = state.Esp
    e.box.enabled = on and state.EspBox
    e.box.type = state.EspBoxType
    e.box.fill = state.EspColor
    e.box.outline = Color3.new(0, 0, 0)
    e.name.enabled = on and state.EspName
    e.healthbar.enabled = on and state.EspHealth
    e.distance.enabled = on and state.EspDistance
    e.tracer.enabled = on and state.EspTracer
end

function ESP:AddPlayer(player)
    if not espLib or player == LocalPlayer then return end
    if not self:IsEnemy(player) then return end
    local character = player.Character
    if not character then return end
    if self.Added[character] then return end
    self.Added[character] = true

    local ok = pcall(function()
        espLib.add_box(character)
        espLib.add_healthbar(character)
        espLib.add_name(character)
        espLib.add_distance(character)
        espLib.add_tracer(character)
    end)
    if not ok then
        self.Added[character] = nil
    end
end

function ESP:Start()
    if self.Connection then return end
    self:ApplySettings()

    local function hookPlayer(player)
        if player ~= LocalPlayer then
            player.CharacterAdded:Connect(function()
                task.wait(2)
                self:AddPlayer(player)
            end)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        self:AddPlayer(player)
        hookPlayer(player)
    end
    Players.PlayerAdded:Connect(hookPlayer)

    self.Connection = RunService.RenderStepped:Connect(function()
        self:ApplySettings()
        for _, player in ipairs(Players:GetPlayers()) do
            self:AddPlayer(player)
        end
    end)
end

function ESP:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:ApplySettings()
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
        return character:FindFirstChild("Head")
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

Library.MenuKeybind = tostring(Enum.KeyCode.Delete)

local Window = Library:Window({
    Name = "Counter-Blox",
    SubName = "Extension",
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

aimSection:Slider({
    Name = "FOV",
    Flag = "AimFov",
    Min = 30, Max = 360, Default = 120,
    Callback = function(v) state.AimFov = v end,
})

aimSection:Slider({
    Name = "Smoothness",
    Flag = "AimSmooth",
    Min = 1, Max = 30, Default = 4,
    Callback = function(v) state.AimSmooth = v end,
})

aimSection:Slider({
    Name = "Prediction",
    Flag = "AimPrediction",
    Min = 0, Max = 2, Default = 0, Decimals = 2,
    Callback = function(v) state.AimPrediction = v end,
})

aimSection:Dropdown({
    Name = "Target Part",
    Flag = "AimPart",
    Items = {"Head", "Torso", "Nearest"},
    Default = "Head",
    Multi = false,
    Callback = function(v) state.AimPart = v end,
})

aimSection:Toggle({ Name = "Team Check", Flag = "AimTeamCheck", Default = false, Callback = function(v) state.AimTeamCheck = v end })
aimSection:Toggle({ Name = "Visible Check", Flag = "AimVisible", Default = false, Callback = function(v) state.AimVisible = v end })
aimSection:Toggle({ Name = "Hold RMB", Flag = "AimHold", Default = true, Callback = function(v) state.AimHold = v end })
aimSection:Toggle({ Name = "FOV Circle", Flag = "AimFovCircle", Default = true, Callback = function(v) state.AimFovCircle = v end })

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
espSection:Toggle({ Name = "Team Check", Flag = "EspTeamCheck", Default = false, Callback = function(v) state.EspTeamCheck = v end })
espSection:Dropdown({
    Name = "Box Style",
    Flag = "EspBoxType",
    Items = { "normal", "corner" },
    Default = "normal",
    Multi = false,
    Callback = function(v) state.EspBoxType = v end,
})
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
moveSection:Slider({
    Name = "Bhop Speed",
    Flag = "BhopSpeed",
    Min = 18, Max = 500, Default = 30,
    Callback = function(v) state.BhopSpeed = v end,
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

-- DEVELOPER (reverse engineering)
local devPage = Window:Page({ Name = "Developer" })
local reconSection = devPage:Section({ Name = "Recon", Side = 1 })

local function reconButton(name, fn)
    reconSection:Button({
        Name = name,
        Callback = function()
            ReconInst:Clear()
            fn()
            Library:Log(name .. " done (" .. #ReconInst.Lines .. " lines -> console)", 4)
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
    Library:Log("Full report: " .. n .. " lines", 4)
end)
reconButton("Dump env: 'Animate'", function() ReconInst:DumpEnv("Animate") end)

local logSection = devPage:Section({ Name = "Remote logging", Side = 2 })
logSection:Toggle({
    Name = "Log FireServer calls",
    Flag = "ReconRemoteLog",
    Default = false,
    Callback = function(v)
        if v ~= ReconInst.Logging then
            ReconInst:ToggleRemoteLog()
        end
    end,
})
logSection:Label("Output goes to the console (and CounterBlox/recon.txt)")

-- Settings (scale, configs, watermark) + init
Window:Category("Settings")
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
        Recon = ReconInst,
        EspLib = espLib,
    }
end)

pcall(function()
    Library:Notification({
        Title = "Counter-Blox",
        Description = "Loaded. Press DELETE to open the menu.",
        Duration = 6,
    })
end)
