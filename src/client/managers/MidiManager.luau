--!native
--!optimize 2
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local MidiManager = {}

export type MidiEvent = {
	noteId: number,
	velocity: number,
	isPressed: boolean,
	channel: number,
}

local GAMEPAD_COUNT = 4

local ACTION_BUTTONS = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonB] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonY] = true,
}

local lastState: { [number]: { isPressed: boolean, velocity: number } } = {}

local controlsDisabled = false
local debugEnabled = false

function MidiManager.disableDefaultControls()
	if controlsDisabled then
		return
	end
	controlsDisabled = true

	local player = Players.LocalPlayer
	if not player then
		return
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local character = player.Character or player.CharacterAdded:Wait()
	local _humanoid = character:WaitForChild("Humanoid") :: Humanoid

	task.spawn(function()
		pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)

		if playerScripts then
			local PlayerModule = playerScripts:FindFirstChild("PlayerModule")
			if PlayerModule then
				local controls = require(PlayerModule):GetControls()
				controls:Disable()
			end
		end

		GuiService.AutoSelectGuiEnabled = false
		GuiService.SelectedObject = nil

		local sinkKeys = {}
		for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
			local n = item.Name
			if n:find("Button") or n:find("Thumbstick") or n:find("DPad") then
				table.insert(sinkKeys, item)
			end
		end

		ContextActionService:BindActionAtPriority("MidiInputSink", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1000, table.unpack(sinkKeys))

		ContextActionService:UnbindAction("FreecamToggle")
	end)
end

function MidiManager.enableDefaultControls()
	if not controlsDisabled then
		return
	end
	controlsDisabled = false

	local player = Players.LocalPlayer
	if not player then
		return
	end

	task.spawn(function()
		local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
		if pm then
			require(pm):GetControls():Enable()
		end
		GuiService.AutoSelectGuiEnabled = true
		ContextActionService:UnbindAction("MidiInputSink")
		ContextActionService:UnbindAction("FreecamBlock")
	end)
end

local function gpIndex(uit: Enum.UserInputType): number?
	local n = string.match(uit.Name, "Gamepad(%d+)")
	local i = if n then tonumber(n) else nil
	return if i and i >= 1 and i <= GAMEPAD_COUNT then i else nil
end

local function onInputBegan(input: InputObject, octaveOffset: number, callback: (MidiEvent) -> ())
	if not ACTION_BUTTONS[input.KeyCode] then
		return
	end

	local i = gpIndex(input.UserInputType)
	if not i then
		return
	end

	local state = UserInputService:GetGamepadState(input.UserInputType)

	local lt, rt = 0, 0
	for _, obj in ipairs(state) do
		if obj.KeyCode == Enum.KeyCode.ButtonL2 then
			lt = obj.Position.Z
		elseif obj.KeyCode == Enum.KeyCode.ButtonR2 then
			rt = obj.Position.Z
		end
	end

	local channel = 1
	if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonL1) then
		channel += 1
	end
	if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonR1) then
		channel += 2
	end
	if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonL3) then
		channel += 4
	end
	if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonR3) then
		channel += 8
	end

	local noteId = math.floor(lt * 127 + 0.5)
	local velocity = math.floor(rt * 127 + 0.5)

	noteId = noteId + octaveOffset * 12

	local isPressed = velocity > 0

	local last = lastState[noteId]
	if last and last.isPressed == isPressed and (not isPressed or last.velocity == velocity) then
		return
	end

	lastState[noteId] = { isPressed = isPressed, velocity = velocity }

	if debugEnabled then
		print(
			string.format(
				"[MIDI] Note %-4d  Vel %-3d  %s  GP%d  Ch%d",
				noteId,
				velocity,
				if isPressed then "ON " else "OFF",
				i,
				channel
			)
		)
	end

	callback({ noteId = noteId, velocity = velocity, isPressed = isPressed, channel = channel })
end

local connections: { RBXScriptConnection } = {}

function MidiManager.init(octaveOffsetValue: { get: () -> number }, callback: (MidiEvent) -> ())
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(lastState)

	table.insert(
		connections,
		RunService.PostSimulation:Connect(function()
			GuiService.SelectedObject = nil
		end)
	)

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input)
			onInputBegan(input, octaveOffsetValue.get(), callback)
		end)
	)
end

return MidiManager
