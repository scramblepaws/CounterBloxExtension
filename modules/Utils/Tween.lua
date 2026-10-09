-- Tween.lua - Animation helper functions

local TweenService = game:GetService("TweenService")

local Tween = {}

function Tween.TweenProperty(object, property, targetValue, duration, easingStyle, easingDirection)
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    easingDirection = easingDirection or Enum.EasingDirection.Out
    
    local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
    local tween = TweenService:Create(object, tweenInfo, { [property] = targetValue })
    
    tween:Play()
    return tween
end

function Tween.TweenSize(object, targetSize, duration, easingStyle, easingDirection)
    return Tween.TweenProperty(object, "Size", targetSize, duration, easingStyle, easingDirection)
end

function Tween.TweenPosition(object, targetPosition, duration, easingStyle, easingDirection)
    return Tween.TweenProperty(object, "Position", targetPosition, duration, easingStyle, easingDirection)
end

function Tween.TweenTransparency(object, targetTransparency, duration, easingStyle, easingDirection)
    return Tween.TweenProperty(object, "BackgroundTransparency", targetTransparency, duration, easingStyle, easingDirection)
end

function Tween.FadeInOut(object, fadeInDuration, fadeOutDuration, holdTime)
    fadeInDuration = fadeInDuration or 0.3
    fadeOutDuration = fadeOutDuration or 0.3
    holdTime = holdTime or 1
    
    -- Fade in
    Tween.TweenTransparency(object, 0, fadeInDuration)
    
    -- Wait and fade out
    task.wait(fadeInDuration + holdTime)
    Tween.TweenTransparency(object, 1, fadeOutDuration)
end

function Tween.ShakeGuiObject(object, intensity, duration)
    intensity = intensity or 10
    duration = duration or 0.2
    
    local originalPos = object.Position
    local startTime = tick()
    
    coroutine.wrap(function()
        while tick() - startTime < duration do
            local elapsed = (tick() - startTime) / duration
            local damping = 1 - elapsed
            local offsetX = (math.random() * 2 - 1) * intensity * damping
            local offsetY = (math.random() * 2 - 1) * intensity * damping
            
            object.Position = UDim2.new(
                originalPos.X.Scale, originalPos.X.Offset + offsetX,
                originalPos.Y.Scale, originalPos.Y.Offset + offsetY
            )
            
            task.wait()
        end
        
        object.Position = originalPos
    end)()
end

return Tween
