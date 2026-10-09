-- MovementEngine.lua - Bunnyhop, TextureBug sliding, and related movement features

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MovementEngine = {}
MovementEngine.__index = MovementEngine

function MovementEngine.new()
    local self = setmetatable({}, MovementEngine)
    
    self.Player = Players.LocalPlayer
    self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.HumanoidRootPart = self.Character:WaitForChild("HumanoidRootPart")
    
    -- Feature flags
    self.BunnyhopEnabled = false
    self.TextureBugEnabled = false
    
    -- Bunnyhop state
    self.LastJumpTime = 0
    self.BunnyhopCooldown = 0.15  -- seconds between allowed bunnyhops
    self.BunnyhopForce = 50       -- upward velocity applied on hop
    
    -- TextureBug state
    self.SlideActive = false
    self.SlideSpeed = 0.85        -- speed multiplier while sliding
    self.NormalWalkSpeed = self.Humanoid.WalkSpeed
    self.NormalJumpPower = self.Humanoid.JumpPower
    
    self:_SetupCharacterTracking()
    self:_SetupInputHandling()
    
    return self
end

function MovementEngine:_SetupCharacterTracking()
    self.Player.CharacterAdded:Connect(function(character)
        self.Character = character
        self.Humanoid = character:WaitForChild("Humanoid")
        self.HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
        self.NormalWalkSpeed = self.Humanoid.WalkSpeed
        self.NormalJumpPower = self.Humanoid.JumpPower
    end)
end

function MovementEngine:_SetupInputHandling()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            if self.TextureBugEnabled then
                self:StartSlide()
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            self:StopSlide()
        end
    end)
end

function MovementEngine:ToggleBunnyhop()
    self.BunnyhopEnabled = not self.BunnyhopEnabled
    
    if self.BunnyhopEnabled then
        self:_StartBunnyhopMonitoring()
    else
        self:_StopBunnyhopMonitoring()
    end
end

function MovementEngine:_StartBunnyhopMonitoring()
    self.BunnyhopConnection = RunService.Heartbeat:Connect(function()
        self:_CheckBunnyhop()
    end)
end

function MovementEngine:_StopBunnyhopMonitoring()
    if self.BunnyhopConnection then
        self.BunnyhopConnection:Disconnect()
        self.BunnyhopConnection = nil
    end
end

function MovementEngine:_CheckBunnyhop()
    if not self.Humanoid or not self.HumanoidRootPart then return end
    
    local now = os.clock()
    local grounded = self:_IsGrounded()
    
    -- Detect if the player is holding jump
    local isJumpHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
    
    if grounded and isJumpHeld then
        -- Only trigger bunnyhop if within cooldown window
        if now - self.LastJumpTime > self.BunnyhopCooldown then
            self:_ApplyBunnyhopImpulse()
            self.LastJumpTime = now
        end
    end
end

function MovementEngine:_IsGrounded()
    if not self.HumanoidRootPart then return false end
    
    local rayOrigin = self.HumanoidRootPart.Position
    local rayDirection = Vector3.new(0, -3.5, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    return rayResult ~= nil
end

function MovementEngine:_ApplyBunnyhopImpulse()
    if not self.Humanoid then return end
    
    local rootVelocity = self.HumanoidRootPart.AssemblyLinearVelocity
    local newVelocity = Vector3.new(rootVelocity.X, self.BunnyhopForce, rootVelocity.Z)
    
    self.HumanoidRootPart.AssemblyLinearVelocity = newVelocity
end

function MovementEngine:TriggerBunnyhop()
    if not self.BunnyhopEnabled then
        self.BunnyhopEnabled = true
        self:_StartBunnyhopMonitoring()
    end
    
    self:_ApplyBunnyhopImpulse()
end

function MovementEngine:ToggleTextureBug()
    self.TextureBugEnabled = not self.TextureBugEnabled
    
    if self.TextureBugEnabled then
        self:_EnableTextureBug()
    else
        self:_DisableTextureBug()
    end
end

function MovementEngine:_EnableTextureBug()
    -- Reduce friction/speed to create a "sliding" feel against surfaces
    if self.Humanoid then
        self.Humanoid.WalkSpeed = self.NormalWalkSpeed * self.SlideSpeed
        self.Humanoid.JumpPower = self.NormalJumpPower * 0.7
    end
    
    -- Apply surface glitch effect by lowering friction on the root part
    if self.HumanoidRootPart then
        self.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(
            0.7,    -- Density
            0.05,   -- Friction (low = slippery)
            0.1     -- Elasticity
        )
    end
end

function MovementEngine:_DisableTextureBug()
    if self.Humanoid then
        self.Humanoid.WalkSpeed = self.NormalWalkSpeed
        self.Humanoid.JumpPower = self.NormalJumpPower
    end
    
    if self.HumanoidRootPart then
        self.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(
            0.7,
            0.5,
            0.5
        )
    end
end

function MovementEngine:StartSlide()
    if not self.TextureBugEnabled then return end
    
    self.SlideActive = true
    
    -- Apply forward slide velocity
    if self.HumanoidRootPart and self.Humanoid then
        local moveDirection = self.Humanoid.MoveDirection
        if moveDirection.Magnitude > 0 then
            local slideVelocity = moveDirection.Unit * (self.Humanoid.WalkSpeed * 1.5)
            self.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(
                slideVelocity.X,
                self.HumanoidRootPart.AssemblyLinearVelocity.Y,
                slideVelocity.Z
            )
        end
    end
end

function MovementEngine:StopSlide()
    self.SlideActive = false
end

function MovementEngine:SetBunnyhopForce(force)
    self.BunnyhopForce = force
end

function MovementEngine:SetSlideSpeed(speed)
    self.SlideSpeed = speed
end

function MovementEngine:GetState()
    return {
        BunnyhopEnabled = self.BunnyhopEnabled,
        TextureBugEnabled = self.TextureBugEnabled,
        SlideActive = self.SlideActive
    }
end

function MovementEngine:Cleanup()
    self:_StopBunnyhopMonitoring()
    self:_DisableTextureBug()
end

return MovementEngine
