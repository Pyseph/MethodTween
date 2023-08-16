--!strict
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Signal = require(script.Packages.Signal)

local builtInLerps = {
	CFrame = true,
	Vector3 = true,
	Vector2 = true,
	UDim2 = true,
	Color3 = true,
}

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end
local function lerpValue(ValueA: any, ValueB: any, Alpha: number)
	local Type = typeof(ValueA)

	if Type == "boolean" or Type == "EnumItem" then
		return ValueB
	elseif Type == "number" then
		return lerp(ValueA, ValueB, Alpha)
	elseif builtInLerps[Type] then
		return ValueA:Lerp(ValueB, Alpha)
	elseif Type == "Rect" then
		return Rect.new(ValueA.Min:Lerp(ValueB.Min, Alpha), ValueA.Max:Lerp(ValueB.Max, Alpha))
	elseif Type == "UDim" then
		return UDim.new(lerp(ValueA.Scale, ValueB.Scale, Alpha), lerp(ValueA.Offset, ValueB.Offset, Alpha))
	elseif Type == "Vector2int16" then
		return Vector2int16.new(lerp(ValueA.X, ValueB.X, Alpha), lerp(ValueA.Y, ValueB.Y, Alpha))
	end

	error(`lerpValue: Unsupported type {Type}`)
end

local MethodTween = {}
MethodTween.__index = MethodTween

local activeTweens = setmetatable({}, {
	__mode = "v",
})
function MethodTween.new(instance: Instance, tweenInfo: TweenInfo, propertyTable: {[string]: {any}})
	for _, propData in propertyTable do
		local initialValue, finalValue = propData[1], propData[2]
		assert(typeof(initialValue) == typeof(finalValue), "Initial and final values must be of the same type")
	end

	local self = setmetatable({
		Instance = instance,
		TweenInfo = tweenInfo,
		PlaybackState = Enum.PlaybackState.Begin,
		Completed = Signal.new(),

		_propertyTable = propertyTable,
		_time = 0,
		_updateConnection = nil,
		_delayedThread = nil,
	}, MethodTween)

	return self
end

function MethodTween:Play()
	if activeTweens[self.Instance] then
		activeTweens[self.Instance]:Cancel()
	end
	self:_stop()

	if self.PlaybackState ~= Enum.PlaybackState.Paused then
		self._time = 0
	end
	--[[
		I could set this to only Delayed since it's set to Playing in the delayed thread, but then the following could occur:
		```lua
		local tween = MethodTween.new(...)
		tween:Play()
		print(tween.PlaybackState) -- Delayed
		```
	]]
	activeTweens[self.Instance] = self
	self.PlaybackState = self.TweenInfo.DelayTime > 0 and Enum.PlaybackState.Delayed or Enum.PlaybackState.Playing

	self._delayedThread = task.delay(self.TweenInfo.DelayTime, function()
		self.PlaybackState = Enum.PlaybackState.Playing
		local initialValues = {}
		for name, propData in self._propertyTable do
			initialValues[name] = propData[1]
		end

		local easingStyle = self.TweenInfo.EasingStyle
		local easingDirection = self.TweenInfo.EasingDirection
		local repeatCount: number = self.TweenInfo.RepeatCount
		local reverses = self.TweenInfo.Reverses

		local numRepeats = (repeatCount + 1) * (reverses and 2 or 1)
		local timesRepeated = 0
		self._updateConnection = RunService.Stepped:Connect(function(_, step)
			self._time += step

			local alpha = math.min(self._time / self.TweenInfo.Time - timesRepeated, 1)
			local tweenAlpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
			if reverses and timesRepeated % 2 == 1 then
				tweenAlpha = 1 - tweenAlpha
			end

			for name, propData in self._propertyTable do
				local initialValue = initialValues[name]

				local newValue = lerpValue(initialValue, propData[2], tweenAlpha)
				self.Instance[name](self.Instance, newValue)
			end

			if alpha >= 1 then
				timesRepeated += 1
			end

			if timesRepeated >= numRepeats then
				self:_stop()
				self.PlaybackState = Enum.PlaybackState.Completed
				self.Completed:Fire()
			end
		end)
	end)
end
function MethodTween:_stop()
	activeTweens[self.Instance] = nil
	if self._updateConnection then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end

	if self._delayedThread and coroutine.status(self._delayedThread) == "suspended" then
		task.cancel(self._delayedThread)
	end

	self._delayedThread = nil
end

function MethodTween:Cancel()
	if self.PlaybackState ~= Enum.PlaybackState.Begin then
		self:_stop()
		self.PlaybackState = Enum.PlaybackState.Cancelled
	end
end

function MethodTween:Pause()
	if self.PlaybackState == Enum.PlaybackState.Playing then
		self:_stop()
		self.PlaybackState = Enum.PlaybackState.Paused
	end
end

return MethodTween
