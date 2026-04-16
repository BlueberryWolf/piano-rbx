local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PianoState = require(script.Parent.Parent.PianoState)

local PianoSeating = {}

function PianoSeating.init()
	local LocalPlayer = Players.LocalPlayer

	local function updateSeat()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then
			local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, "Piano") then
				PianoState.activePiano:set(model)
				workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
				return
			end
		end

		if Fusion.peek(PianoState.activePiano) ~= nil then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		end
		PianoState.activePiano:set(nil)
	end

	LocalPlayer.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum:GetPropertyChangedSignal("SeatPart"):Connect(updateSeat)
			updateSeat()
		end
	end)

	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:GetPropertyChangedSignal("SeatPart"):Connect(updateSeat)
			updateSeat()
		end
	end
end

return PianoSeating
