--[[
    Counter-Blox Extension
    Single-file Roblox script.

    Load with:
    loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()

    Menu key: INSERT  (also F4)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ====================== LIBRARY DETECTION ======================
local hasDrawing = (Drawing ~= nil and type(Drawing.new) == "function")

-- ====================== THEME ======================
local Theme = {
    Accent = Color3.fromRGB(108, 118, 255),
    AccentDim = Color3.fromRGB(70, 78, 190),
    Window = Color3.fromRGB(18, 18, 20),
    Sidebar = Color3.fromRGB(13, 13, 15),
    Panel = Color3.fromRGB(22, 22, 25),
    Widget = Color3.fromRGB(30, 30, 34),
    WidgetHover = Color3.fromRGB(38, 38, 44),
    Text = Color3.fromRGB(230, 230, 235),
    TextDim = Color3.fromRGB(140, 140, 150),
    Section = Color3.fromRGB(120, 125, 150),
    On = Color3.fromRGB(108, 118, 255),
    Off = Color3.fromRGB(55, 55, 62),
}

-- ====================== STATE ======================
local state = {
    -- aimbot
    Aim = false,
    AimFov = 120,
    AimSmooth = 8,
    AimKey = "LMB",
    -- triggerbot
    Trigger = false,
    -- visuals
    Esp = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspTracer = false,
    EspDistance = false,
    Crosshair = false,
    Fov = 70,
    -- misc
    Bhop = false,
    Speed = false,
    SpeedVal = 16,
    Fly = false,
    TextureBug = false,
}

-- ====================== NOTIFY ======================
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

-- ====================== UI (gamesense-style) ======================
local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    self.IsOpen = false
    self.Tabs = {}
    self.ActiveTab = nil
    self:_Build()
    self:_Bind()
    return self
end

function UI:_Build()
    local pg = LocalPlayer:WaitForChild("PlayerGui")

    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "CBXMenu"
    self.Gui.ResetOnSpawn = false
    self.Gui.Enabled = false
    self.Gui.DisplayOrder = 99999
    self.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.Gui.IgnoreGuiInset = true
    self.Gui.Parent = pg

    self.Window = Instance.new("Frame")
    self.Window.Size = UDim2.new(0, 600, 0, 400)
    self.Window.Position = UDim2.new(0.5, -300, 0.5, -200)
    self.Window.BackgroundColor3 = Theme.Window
    self.Window.BorderSizePixel = 0
    self.Window.Parent = self.Gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.Window

    -- sidebar
    self.Sidebar = Instance.new("Frame")
    self.Sidebar.Size = UDim2.new(0, 150, 1, 0)
    self.Sidebar.BackgroundColor3 = Theme.Sidebar
    self.Sidebar.BorderSizePixel = 0
    self.Sidebar.Parent = self.Window

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 8)
    sideCorner.Parent = self.Sidebar

    -- title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "COUNTER-BLOX"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.TextColor3 = Theme.Text
    title.Parent = self.Sidebar

    local titleAccent = Instance.new("Frame")
    titleAccent.Size = UDim2.new(0, 3, 0, 26)
    titleAccent.Position = UDim2.new(0, 0, 0, 12)
    titleAccent.BackgroundColor3 = Theme.Accent
    titleAccent.BorderSizePixel = 0
    titleAccent.Parent = self.Sidebar

    -- tab list container (below title)
    self.TabContainer = Instance.new("Frame")
    self.TabContainer.Size = UDim2.new(1, 0, 1, -50)
    self.TabContainer.Position = UDim2.new(0, 0, 0, 50)
    self.TabContainer.BackgroundTransparency = 1
    self.TabContainer.Parent = self.Sidebar

    self.TabList = Instance.new("UIListLayout")
    self.TabList.Padding = UDim.new(0, 2)
    self.TabList.Parent = self.TabContainer

    -- content area
    self.Content = Instance.new("Frame")
    self.Content.Size = UDim2.new(1, -150, 1, 0)
    self.Content.Position = UDim2.new(0, 150, 0, 0)
    self.Content.BackgroundTransparency = 1
    self.Content.Parent = self.Window

    -- close button
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 24, 0, 24)
    close.Position = UDim2.new(1, -30, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
    close.BorderSizePixel = 0
    close.Text = "x"
    close.Font = Enum.Font.SourceSansBold
    close.TextColor3 = Color3.new(1, 1, 1)
    close.TextSize = 14
    close.Parent = self.Window
    close.MouseButton1Click:Connect(function() self:Close() end)

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = close
end

function UI:_Bind()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.F4 then
            self:Toggle()
        end
    end)
end

function UI:Toggle()
    if self.IsOpen then self:Close() else self:Open() end
end

function UI:Open()
    self.IsOpen = true
    self.Gui.Enabled = true
    self.SavedMouse = UserInputService.MouseBehavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function UI:Close()
    self.IsOpen = false
    self.Gui.Enabled = false
    if self.SavedMouse then
        UserInputService.MouseBehavior = self.SavedMouse
    end
end

function UI:AddTab(name)
    local tab = {
        Name = name,
        Panel = nil,
        Sections = {},
        Layout = nil,
    }

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    btn.TextColor3 = Theme.TextDim
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = self.TabContainer

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 16)
    pad.Parent = btn

    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, -20, 1, -20)
    panel.Position = UDim2.new(0, 10, 0, 10)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 0
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.Visible = false
    panel.Parent = self.Content

    tab.Panel = panel
    tab.Layout = Instance.new("UIListLayout")
    tab.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    tab.Layout.Padding = UDim.new(0, 6)
    tab.Layout.Parent = panel

    btn.MouseButton1Click:Connect(function()
        self:SetTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:SetTab(tab)
    end
    return tab
end

function UI:SetTab(tab)
    self.ActiveTab = tab
    for i, t in ipairs(self.Tabs) do
        t.Panel.Visible = (t == tab)
    end
    -- highlight active tab button
    for i, child in ipairs(self.TabContainer:GetChildren()) do
        if child:IsA("TextButton") then
            local isActive = (child.Text == tab.Name)
            child.TextColor3 = isActive and Theme.Accent or Theme.TextDim
            child.Font = isActive and Enum.Font.SourceSansBold or Enum.Font.SourceSans
        end
    end
end

function UI:AddSection(tab, name)
    local section = Instance.new("TextLabel")
    section.Size = UDim2.new(1, 0, 0, 22)
    section.BackgroundTransparency = 1
    section.Text = name:upper()
    section.Font = Enum.Font.SourceSansBold
    section.TextSize = 12
    section.TextColor3 = Theme.Section
    section.TextXAlignment = Enum.TextXAlignment.Left
    section.Parent = tab.Panel

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingTop = UDim.new(0, 6)
    pad.Parent = section

    return section
end

function UI:AddToggle(tab, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = Theme.Widget
    row.BorderSizePixel = 0
    row.Parent = tab.Panel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextColor3 = Theme.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 34, 0, 18)
    switch.Position = UDim2.new(1, -44, 0.5, -9)
    switch.BackgroundColor3 = default and Theme.On or Theme.Off
    switch.BorderSizePixel = 0
    switch.Parent = row

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 9)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 7)
    knobCorner.Parent = knob

    local enabled = default
    local function set(value)
        enabled = value
        switch.BackgroundColor3 = value and Theme.On or Theme.Off
        knob.Position = value and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enabled = not enabled
            set(enabled)
            if callback then callback(enabled) end
        end
    end)

    return { Set = set, Get = function() return enabled end }
end

function UI:AddSlider(tab, text, min, max, default, decimals, callback)
    decimals = decimals or 0

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Theme.Widget
    row.BorderSizePixel = 0
    row.Parent = tab.Panel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 100, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextColor3 = Theme.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 60, 0, 20)
    valueLabel.Position = UDim2.new(1, -72, 0, 4)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.Font = Enum.Font.SourceSans
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = Theme.Accent
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 4)
    track.Position = UDim2.new(0, 12, 0, 30)
    track.BackgroundColor3 = Theme.Off
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = fill

    local value = default
    local function set(v)
        value = math.clamp(v, min, max)
        local frac = (value - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        valueLabel.Text = string.format("%." .. decimals .. "f", value)
        if callback then callback(value) end
    end

    local dragging = false
    local function updateFromMouse(x)
        local absX = track.AbsolutePosition.X
        local absW = track.AbsoluteSize.X
        local frac = math.clamp((x - absX) / absW, 0, 1)
        set(min + frac * (max - min))
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromMouse(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromMouse(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return { Set = set, Get = function() return value end }
end

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

function ESP:Toggle()
    self.Enabled = not self.Enabled
    if self.Enabled then self:Start() else self:Stop() end
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

function ESP:AddCharacter(character)
    local o = {}
    if hasDrawing then
        o.Box = Drawing.new("Square")
        o.Box.Thickness = 1
        o.Box.Filled = false
        o.Box.Transparency = 1
        o.Box.Visible = false
        o.Box.Color = Color3.new(1, 1, 1)

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
            target = { character = character, objects = self:AddCharacter(character) }
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
            o.Box.Color = Theme.Accent
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
    self.Enabled = false
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
    if not self.Enabled then return end
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
    self.Enabled = false
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
    if not self.Enabled then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true

    local origin = camera.CFrame.Position
    local direction = camera.CFrame.LookVector * 1000
    local result = workspace:Raycast(origin, direction, params)

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
    self.Enabled = false
    self.Connection = nil
    self.LastJump = 0
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
    if not (humanoid and root) then return end
    if humanoid.MoveDirection.Magnitude <= 0 then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end
    local now = os.clock()
    if now - self.LastJump < 0.12 then return end
    local vel = root.AssemblyLinearVelocity
    local boost = humanoid.MoveDirection.Unit * (humanoid.WalkSpeed * 0.2)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    root.AssemblyLinearVelocity = Vector3.new(vel.X + boost.X, vel.Y, vel.Z + boost.Z)
    self.LastJump = now
end

-- ====================== SPEED ======================
local Speed = {}
Speed.__index = Speed

function Speed.new()
    local self = setmetatable({}, Speed)
    self.Enabled = false
    self.Value = 16
    return self
end

function Speed:Apply()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = self.Enabled and self.Value or 16
    end
end

function Speed:Set(value)
    self.Value = value
    self:Apply()
end

function Speed:SetEnabled(enabled)
    self.Enabled = enabled
    self:Apply()
end

-- ====================== FLY ======================
local Fly = {}
Fly.__index = Fly

function Fly.new()
    local self = setmetatable({}, Fly)
    self.Enabled = false
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

    local speed = 50
    if dir.Magnitude > 0 then
        self.BodyVel.Velocity = dir.Unit * speed
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
    self.Enabled = false
    self.Lines = {}
    self.Connection = nil
    return self
end

function Crosshair:Start()
    if not hasDrawing then return end
    if self.Connection then return end

    local size, gap, thickness = 6, 4, 2
    local color = Color3.new(0, 1, 0.6)

    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = thickness
        line.Transparency = 1
        line.Color = color
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
    for _, line in ipairs(self.Lines) do
        pcall(function() line:Remove() end)
    end
    self.Lines = {}
end

-- ====================== FOV ======================
local Fov = {}
Fov.__index = Fov

function Fov.new()
    local self = setmetatable({}, Fov)
    self.Value = 70
    return self
end

function Fov:Set(value)
    self.Value = value
    local camera = workspace.CurrentCamera
    if camera then
        camera.FieldOfView = value
    end
end

-- ====================== TEXTURE BUG ======================
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

-- ====================== BUILD ======================
local ui = UI.new()

local aimTab = ui:AddTab("AIMBOT")
local visTab = ui:AddTab("VISUALS")
local miscTab = ui:AddTab("MISC")

local EspInst = ESP.new()
local AimbotInst = Aimbot.new()
local TriggerInst = Triggerbot.new()
local BhopInst = Bhop.new()
local SpeedInst = Speed.new()
local FlyInst = Fly.new()
local CrosshairInst = Crosshair.new()
local FovInst = Fov.new()
local TextureBugInst = TextureBug.new()

-- AIMBOT
ui:AddSection(aimTab, "Aimbot")
ui:AddToggle(aimTab, "Enabled", false, function(v)
    state.Aim = v
    if v then AimbotInst:Start() else AimbotInst:Stop() end
end)
ui:AddSlider(aimTab, "FOV", 30, 360, 120, 0, function(v) state.AimFov = v end)
ui:AddSlider(aimTab, "Smoothness", 1, 30, 8, 0, function(v) state.AimSmooth = v end)

ui:AddSection(aimTab, "Triggerbot")
ui:AddToggle(aimTab, "Auto fire", false, function(v)
    state.Trigger = v
    if v then TriggerInst:Start() else TriggerInst:Stop() end
end)

-- VISUALS
ui:AddSection(visTab, "ESP")
ui:AddToggle(visTab, "Enabled", false, function(v)
    state.Esp = v
    if v then EspInst:Start() else EspInst:Stop() end
end)
ui:AddToggle(visTab, "Box", true, function(v) state.EspBox = v end)
ui:AddToggle(visTab, "Name", true, function(v) state.EspName = v end)
ui:AddToggle(visTab, "Health", true, function(v) state.EspHealth = v end)
ui:AddToggle(visTab, "Tracer", false, function(v) state.EspTracer = v end)
ui:AddToggle(visTab, "Distance", false, function(v) state.EspDistance = v end)

ui:AddSection(visTab, "Other")
ui:AddToggle(visTab, "Crosshair", false, function(v)
    state.Crosshair = v
    if v then CrosshairInst:Start() else CrosshairInst:Stop() end
end)
ui:AddSlider(visTab, "Field of View", 30, 140, 70, 0, function(v)
    state.Fov = v
    FovInst:Set(v)
end)

-- MISC
ui:AddSection(miscTab, "Movement")
ui:AddToggle(miscTab, "Bunnyhop", false, function(v)
    state.Bhop = v
    if v then BhopInst:Start() else BhopInst:Stop() end
end)
ui:AddToggle(miscTab, "Speed", false, function(v)
    state.Speed = v
    SpeedInst:SetEnabled(v)
end)
ui:AddSlider(miscTab, "Speed Value", 16, 100, 16, 0, function(v)
    state.SpeedVal = v
    SpeedInst:Set(v)
end)
ui:AddToggle(miscTab, "Fly", false, function(v)
    state.Fly = v
    if v then FlyInst:Start() else FlyInst:Stop() end
end)

ui:AddSection(miscTab, "Other")
ui:AddToggle(miscTab, "Texture Bug", false, function(v)
    state.TextureBug = v
    TextureBugInst:Toggle()
end)

-- expose
pcall(function()
    getgenv().CBX = {
        UI = ui,
        ESP = EspInst,
        Aimbot = AimbotInst,
        Triggerbot = TriggerInst,
        Bhop = BhopInst,
        Speed = SpeedInst,
        Fly = FlyInst,
        Crosshair = CrosshairInst,
        Fov = FovInst,
        TextureBug = TextureBugInst,
    }
end)

notify("Counter-Blox loaded  |  INSERT to open menu")
