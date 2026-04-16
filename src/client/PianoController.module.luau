local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local BlinkClient = require(ReplicatedStorage.Shared.PianoSchemaClient)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)

local PianoApp = require(script.Parent.ui.PianoApp)

local PianoController = {}

local scope = Fusion.scoped(Fusion)
local isRunning = RunService:IsRunning()

local pressedKeys = scope:Value({})
local sustainActive = scope:Value(false)
local currentSoundfontName = scope:Value(SoundFonts.Fonts[1].Name)
local currentLayout = scope:Value("FL")
local customMapping = scope:Value({})
local bindingMidi = scope:Value(nil :: number?)
local activePiano = scope:Value(nil :: Instance?)

local currentSoundfontIndex = 1
local isPreloading = scope:Value(false)

local trackedNotes: { [Enum.KeyCode]: number } = {}
local sustainToggle = false
local sustainedNotes = {}

local remotePlayerStates = {}

local eventPool = {}
local eventQueue = {}
local currentFrame = 0

local function acquireEvent()
	return table.remove(eventPool) or { NoteId = 0, Velocity = 0, TimestampOffset = 0, IsPressed = false }
end

local function releaseEvent(event)
	table.insert(eventPool, event)
end

local function queueSustainEvent(isPressed: boolean)
	local timestampOffset = math.floor((workspace:GetServerTimeNow() % (1 / 60)) * 1000)
	local event = acquireEvent()
	event.NoteId = 0
	event.Velocity = isPressed and 127 or 0
	event.TimestampOffset = timestampOffset
	event.IsPressed = isPressed
	table.insert(eventQueue, event)
end

local function getRemoteState(userId: number)
	if not remotePlayerStates[userId] then
		remotePlayerStates[userId] = {
			sustainActive = false,
			sustainedNotes = {},
		}
	end
	return remotePlayerStates[userId]
end

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local function getNoteName(midi: number): string
	local octave = math.floor(midi / 12) - 1
	return NOTE_NAMES[(midi % 12) + 1] .. tostring(octave)
end

local function getAssetForNote(midi: number, soundfontIndex: number?): string?
	local name = getNoteName(midi)
	local index = soundfontIndex or currentSoundfontIndex
	local fontData = SoundFonts.Fonts[index]
	if not fontData then
		return nil
	end

	local font = fontData.Data[name]
	if not font then
		return nil
	end
	return type(font) == "table" and font[127] or font
end

local function releaseSustainedNotes()
	for midi in pairs(sustainedNotes) do
		VoiceProvider.stop(midi, 0, 0.5)
	end
	table.clear(sustainedNotes)
end

local function captureInput(midi: number, velocity: number, isPressed: boolean)
	local currentPiano: Instance?

	if isRunning then
		currentPiano = Fusion.peek(activePiano)
		if not currentPiano and isPressed then
			return
		end
	end

	if isPressed then
		local assetId = getAssetForNote(midi)
		if assetId then
			VoiceProvider.play(midi, velocity, assetId, 0, currentPiano)
		end
		sustainedNotes[midi] = nil
	else
		if sustainToggle then
			sustainedNotes[midi] = true
		else
			VoiceProvider.stop(midi, 0, 0.4)
		end
	end

	local current = Fusion.peek(pressedKeys)
	if current[midi] == isPressed then
		return
	end

	local next = table.clone(current)
	if isPressed then
		next[midi] = true
	else
		next[midi] = nil
	end
	pressedKeys:set(next)

	local timestampOffset = math.floor((workspace:GetServerTimeNow() % (1 / 60)) * 1000)
	local event = acquireEvent()
	event.NoteId = midi
	event.Velocity = velocity
	event.TimestampOffset = timestampOffset
	event.IsPressed = isPressed
	table.insert(eventQueue, event)
end

local function onInputBegan(input: InputObject, processed: boolean, shiftPressed: boolean)
	if processed then
		return
	end

	if isRunning then
		local currentPiano = Fusion.peek(activePiano)
		if not currentPiano then
			return
		end
	end

	local midiToBind = Fusion.peek(bindingMidi)
	if midiToBind and input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if key ~= Enum.KeyCode.Escape then
			local current = Fusion.peek(customMapping)
			local next = table.clone(current)
			next[key] = midiToBind
			customMapping:set(next)
		end
		bindingMidi:set(nil)
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		sustainToggle = not sustainToggle
		sustainActive:set(sustainToggle)
		queueSustainEvent(sustainToggle)
		if not sustainToggle then
			releaseSustainedNotes()
		end
		return
	end

	local isShift = shiftPressed
	local layout = Fusion.peek(currentLayout)

	local function triggerPreload(index)
		isPreloading:set(true)
		local font = SoundFonts.Fonts[index]
		local fontAssets = {}
		for _, data in pairs(font.Data) do
			local id = type(data) == "table" and data[127] or data
			if id then
				table.insert(fontAssets, id)
			end
		end
		VoiceProvider.preload(fontAssets, function()
			isPreloading:set(false)
		end)
	end

	if input.KeyCode == Enum.KeyCode.Left then
		currentSoundfontIndex -= 1
		if currentSoundfontIndex < 1 then
			currentSoundfontIndex = #SoundFonts.Fonts
		end
		currentSoundfontName:set(SoundFonts.Fonts[currentSoundfontIndex].Name)
		triggerPreload(currentSoundfontIndex)
	elseif input.KeyCode == Enum.KeyCode.Right then
		currentSoundfontIndex += 1
		if currentSoundfontIndex > #SoundFonts.Fonts then
			currentSoundfontIndex = 1
		end
		currentSoundfontName:set(SoundFonts.Fonts[currentSoundfontIndex].Name)
		triggerPreload(currentSoundfontIndex)
	end

	local midi = Fusion.peek(customMapping)[input.KeyCode]
	if not midi then
		midi = KeyConfig.getNote(input.KeyCode, isShift, layout)
	end

	if midi then
		trackedNotes[input.KeyCode] = midi
		captureInput(midi, 127, true)
	end
end

local function onInputEnded(input: InputObject)
	local midi = trackedNotes[input.KeyCode]
	if midi then
		captureInput(midi, 0, false)
		trackedNotes[input.KeyCode] = nil
	end
end

function PianoController.SetLayout(layout: string)
	if KeyConfig.Presets[layout] then
		currentLayout:set(layout)
	end
end

function PianoController.StartBinding(midi: number)
	bindingMidi:set(midi)
end

function PianoController.ClearMapping(midi: number)
	local current = Fusion.peek(customMapping)
	local next = table.clone(current)
	for key, m in pairs(next) do
		if m == midi then
			next[key] = nil
		end
	end
	customMapping:set(next)
end

function PianoController.InitAssets()
	local assets = {}
	for _, fontGroup in ipairs(SoundFonts.Fonts) do
		for _, data in pairs(fontGroup.Data) do
			local id = type(data) == "table" and data[127] or data
			if id then
				table.insert(assets, id)
			end
		end
	end

	VoiceProvider.init(assets)
end

function PianoController.init()
	local assets = {}
	for _, fontGroup in ipairs(SoundFonts.Fonts) do
		for _, data in pairs(fontGroup.Data) do
			local id = type(data) == "table" and data[127] or data
			if id then
				table.insert(assets, id)
			end
		end
	end
	VoiceProvider.init(assets)

	local LocalPlayer = Players.LocalPlayer

	local function updateSeat()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then
			local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, "Piano") then
				activePiano:set(model)
				Camera.CameraType = Enum.CameraType.Scriptable
				return
			end
		end

		if Fusion.peek(activePiano) ~= nil then
			Camera.CameraType = Enum.CameraType.Custom
		end
		activePiano:set(nil)
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

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local app = PianoApp({
		Scope = scope,
		PressedKeys = pressedKeys,
		SustainActive = sustainActive,
		SoundfontName = currentSoundfontName,
		CurrentLayout = currentLayout,
		CustomMapping = customMapping,
		BindingMidi = bindingMidi,
		OnKeyPressed = function(midi)
			captureInput(midi, 127, true)
		end,
		OnKeyReleased = function(midi)
			captureInput(midi, 0, false)
		end,
		OnSustainToggled = function()
			sustainToggle = not sustainToggle
			sustainActive:set(sustainToggle)
			queueSustainEvent(sustainToggle)
			if not sustainToggle then
				releaseSustainedNotes()
			end
		end,
		OnSetLayout = PianoController.SetLayout,
		OnStartBinding = PianoController.StartBinding,
		OnClearMapping = PianoController.ClearMapping,
		IsPreloading = isPreloading,
		OnPanic = function()
			VoiceProvider.stopAll()
			sustainToggle = false
			sustainActive:set(false)
			queueSustainEvent(false)
			table.clear(sustainedNotes)
		end,
	})
	app.Parent = playerGui

	if app:IsA("ScreenGui") then
		scope:Observer(activePiano):onChange(function()
			app.Enabled = (Fusion.peek(activePiano) ~= nil)
		end)
		app.Enabled = (Fusion.peek(activePiano) ~= nil)
	else
		scope:Observer(activePiano):onChange(function()
			app.Visible = (Fusion.peek(activePiano) ~= nil)
		end)
		app.Visible = (Fusion.peek(activePiano) ~= nil)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		local shiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		onInputBegan(input, processed, shiftPressed)
	end)
	UserInputService.InputEnded:Connect(onInputEnded)

	RunService.Heartbeat:Connect(function()
		currentFrame += 1
		if #eventQueue > 0 then
			BlinkClient.SendNoteBatch.Fire({
				FrameNumber = currentFrame,
				Events = eventQueue,
				SoundfontId = currentSoundfontIndex,
				Piano = Fusion.peek(activePiano),
			})
			for _, event in ipairs(eventQueue) do
				releaseEvent(event)
			end
			table.clear(eventQueue)
		end

		local camera = workspace.CurrentCamera
		if camera then
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
		end
	end)

	BlinkClient.RecvNoteBatch.On(function(data)
		if data.UserId == Players.LocalPlayer.UserId then
			return
		end
		local userId = data.UserId
		local batch = data.Batch
		local remoteState = getRemoteState(userId)

		for _, event in ipairs(batch.Events) do
			if event.NoteId == 0 then
				local wasActive = remoteState.sustainActive
				remoteState.sustainActive = event.IsPressed
				if wasActive and not remoteState.sustainActive then
					for midi in pairs(remoteState.sustainedNotes) do
						VoiceProvider.stop(midi, userId, 0.5)
					end
					table.clear(remoteState.sustainedNotes)
				end
			elseif event.IsPressed then
				local assetId = getAssetForNote(event.NoteId, batch.SoundfontId)
				if assetId then
					VoiceProvider.play(event.NoteId, event.Velocity, assetId, userId, batch.Piano)
				end
			else
				if remoteState.sustainActive then
					remoteState.sustainedNotes[event.NoteId] = true
				else
					VoiceProvider.stop(event.NoteId, userId, 0.5)
				end
			end
		end
	end)
end

PianoController.captureInput = captureInput
PianoController.onInputBegan = onInputBegan
PianoController.onInputEnded = onInputEnded

return PianoController
