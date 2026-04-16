local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PianoState = require(script.Parent.Parent.PianoState)
local PianoNetworking = require(script.Parent.PianoNetworking)
local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local PianoInput = {}

local isRunning = RunService:IsRunning()

local function triggerPreload(index: number)
	PianoState.isPreloading:set(true)
	local mapping = SoundFonts.getFontMapping(index)
	VoiceProvider.updatePersistentFonts(0, mapping)

	VoiceProvider.preload(SoundFonts.getFontAssetIds(index), function()
		PianoState.isPreloading:set(false)
	end)
end

function PianoInput.releaseSustainedNotes()
	for midi in pairs(PianoState.sustainedNotes) do
		VoiceProvider.stop(midi, 0, 0.5)
	end
	table.clear(PianoState.sustainedNotes)
end

function PianoInput.captureInput(midi: number, velocity: number, isPressed: boolean)
	local currentPiano: Instance?

	if isRunning then
		currentPiano = Fusion.peek(PianoState.activePiano)
		if not currentPiano and isPressed then
			return
		end
	end

	if isPressed then
		local assetId = SoundFonts.getAssetForNote(midi, Fusion.peek(PianoState.currentSoundfontIndex))
		if assetId then
			VoiceProvider.play(midi, velocity, assetId, 0, currentPiano)
		end
		PianoState.sustainedNotes[midi] = nil
	else
		if PianoState.sustainToggle then
			PianoState.sustainedNotes[midi] = true
		else
			VoiceProvider.stop(midi, 0, 0.4)
		end
	end

	local current = Fusion.peek(PianoState.pressedKeys)
	if current[midi] == isPressed then
		return
	end

	local next = table.clone(current)
	if isPressed then
		next[midi] = true
	else
		next[midi] = nil
	end
	PianoState.pressedKeys:set(next)

	PianoNetworking.queueEvent(midi, velocity, isPressed)
end

local function onInputBegan(input: InputObject, processed: boolean, shiftPressed: boolean)
	if processed then
		return
	end

	if isRunning then
		local currentPiano = Fusion.peek(PianoState.activePiano)
		if not currentPiano then
			return
		end
	end

	local midiToBind = Fusion.peek(PianoState.bindingMidi)
	if midiToBind and input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if key ~= Enum.KeyCode.Escape then
			local current = Fusion.peek(PianoState.customMapping)
			local next = table.clone(current)
			next[key] = midiToBind
			PianoState.customMapping:set(next)
		end
		PianoState.bindingMidi:set(nil)
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		PianoState.sustainToggle = not PianoState.sustainToggle
		PianoState.sustainActive:set(PianoState.sustainToggle)
		PianoNetworking.queueEvent(0, PianoState.sustainToggle and 127 or 0, PianoState.sustainToggle)
		if not PianoState.sustainToggle then
			PianoInput.releaseSustainedNotes()
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Left then
		local index = Fusion.peek(PianoState.currentSoundfontIndex) - 1
		if index < 1 then
			index = #SoundFonts.Fonts
		end
		PianoState.currentSoundfontIndex:set(index)
		PianoState.currentSoundfontName:set(SoundFonts.Fonts[index].Name)
		triggerPreload(index)
	elseif input.KeyCode == Enum.KeyCode.Right then
		local index = Fusion.peek(PianoState.currentSoundfontIndex) + 1
		if index > #SoundFonts.Fonts then
			index = 1
		end
		PianoState.currentSoundfontIndex:set(index)
		PianoState.currentSoundfontName:set(SoundFonts.Fonts[index].Name)
		triggerPreload(index)
	end

	local midi = Fusion.peek(PianoState.customMapping)[input.KeyCode]
	if not midi then
		midi = KeyConfig.getNote(input.KeyCode, shiftPressed, Fusion.peek(PianoState.currentLayout))
	end

	if midi then
		PianoState.trackedNotes[input.KeyCode] = midi
		PianoInput.captureInput(midi, 127, true)
	end
end

local function onInputEnded(input: InputObject)
	local midi = PianoState.trackedNotes[input.KeyCode]
	if midi then
		PianoInput.captureInput(midi, 0, false)
		PianoState.trackedNotes[input.KeyCode] = nil
	end
end

function PianoInput.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		local shiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		onInputBegan(input, processed, shiftPressed)
	end)

	UserInputService.InputEnded:Connect(onInputEnded)
end

return PianoInput
