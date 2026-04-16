local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)

local PianoSpatializer = {}

function PianoSpatializer.init()
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local camPos = camera.CFrame.Position
		for piano, sg in pairs(VoiceProvider.PianoSoundGroups) do
			if not piano.Parent then
				sg:Destroy()
				VoiceProvider.PianoSoundGroups[piano] = nil
				continue
			end

			local pianoPos = piano:GetPivot().Position
			local dist = (camPos - pianoPos).Magnitude

			if dist <= 5 then
				sg.Volume = 1
			elseif dist >= 80 then
				sg.Volume = 0
			else
				sg.Volume = 1 - ((dist - 5) / 75)
			end
		end
	end)
end

return PianoSpatializer
