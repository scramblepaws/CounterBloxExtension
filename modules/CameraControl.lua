-- CameraControl.lua - Frees mouse while menu is open without breaking the camera

local UserInputService = game:GetService("UserInputService")

local CameraControl = {}
CameraControl.__index = CameraControl

function CameraControl.new()
    local self = setmetatable({}, CameraControl)
    self.SavedMouseBehavior = nil
    return self
end

function CameraControl:SetLock(locked)
    if locked then
        self.SavedMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    else
        if self.SavedMouseBehavior then
            UserInputService.MouseBehavior = self.SavedMouseBehavior
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    end
end

function CameraControl:RestoreCamera()
    self:SetLock(false)
end

function CameraControl:Cleanup()
    self:RestoreCamera()
end

return CameraControl
