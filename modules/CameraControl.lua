-- CameraControl.lua - Camera locking during menu interaction + custom cursor

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local CameraControl = {}
CameraControl.__index = CameraControl

function CameraControl.new()
    local self = setmetatable({}, CameraControl)
    
    self.Player = Players.LocalPlayer
    self.Camera = workspace.CurrentCamera
    
    -- Saved state for restoration
    self.SavedCameraSubject = nil
    self.SavedMouseBehavior = nil
    self.SavedMouseIcon = nil
    
    -- Custom cursor
    self.CursorGui = nil
    self.CursorImage = nil
    self.CursorConnection = nil
    
    self:_CreateCustomCursor()
    
    return self
end

function CameraControl:SetLock(locked)
    if locked then
        self:_LockCamera()
    else
        self:_UnlockCamera()
    end
end

function CameraControl:_LockCamera()
    -- Save current state
    self.SavedCameraSubject = self.Camera.CameraSubject
    self.SavedMouseBehavior = UserInputService.MouseBehavior
    self.SavedMouseIcon = self.Player:GetMouse().Icon
    
    -- Freeze camera
    self.Camera.CameraSubject = nil
    self.Camera.CameraType = Enum.CameraType.Scriptable
    
    -- Show custom cursor
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    self.Player:GetMouse().Icon = "" -- Hide default cursor
    
    self:_StartCursorTracking()
end

function CameraControl:_UnlockCamera()
    -- Restore camera
    self.Camera.CameraSubject = self.SavedCameraSubject
    self.Camera.CameraType = Enum.CameraType.Custom
    
    -- Restore mouse
    UserInputService.MouseBehavior = self.SavedMouseBehavior
    self.Player:GetMouse().Icon = self.SavedMouseIcon
    
    self:_StopCursorTracking()
end

function CameraControl:_CreateCustomCursor()
    local playerGui = self.Player:WaitForChild("PlayerGui")
    
    self.CursorGui = Instance.new("ScreenGui")
    self.CursorGui.Name = "CustomCursor"
    self.CursorGui.ResetOnSpawn = false
    self.CursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.CursorGui.Parent = playerGui
    
    self.CursorImage = Instance.new("ImageLabel")
    self.CursorImage.Name = "CursorImage"
    self.CursorImage.Size = UDim2.new(0, 24, 0, 24)
    self.CursorImage.AnchorPoint = Vector2.new(0.5, 0.5)
    self.CursorImage.BackgroundTransparency = 1
    self.CursorImage.Image = "rbxasset://textures/ui/mouse_cursor.png"
    self.CursorImage.ZIndex = 999
    self.CursorImage.Visible = false
    self.CursorImage.Parent = self.CursorGui
end

function CameraControl:_StartCursorTracking()
    local mouse = self.Player:GetMouse()
    
    self.CursorImage.Visible = true
    
    self.CursorConnection = RunService.RenderStepped:Connect(function()
        if self.CursorImage.Visible then
            self.CursorImage.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
        end
    end)
end

function CameraControl:_StopCursorTracking()
    if self.CursorConnection then
        self.CursorConnection:Disconnect()
        self.CursorConnection = nil
    end
    
    if self.CursorImage then
        self.CursorImage.Visible = false
    end
end

function CameraControl:SetCursorImage(assetId)
    self.CursorImage.Image = assetId
end

function CameraControl:RestoreCamera()
    self:_UnlockCamera()
    self:_StopCursorTracking()
end

function CameraControl:Cleanup()
    self:RestoreCamera()
    
    if self.CursorGui then
        self.CursorGui:Destroy()
    end
end

return CameraControl
