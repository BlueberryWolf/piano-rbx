local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local NoteUtils = require(ReplicatedStorage.Shared.NoteUtils)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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
local customMapping = scope:Value(KeyConfig.Presets.FL)
local bindingMidi = scope:Value(nil :: number?)
local activePiano = scope:Value(nil :: Instance?)
local isPreloading = scope:Value(false)

PianoController.state = {
	pressedKeys = pressedKeys,
	sustainActive = sustainActive,
	currentSoundfontName = currentSoundfontName,
	currentLayout = currentLayout,
	customMapping = customMapping,
	bindingMidi = bindingMidi,
	activePiano = activePiano,
	isPreloading = isPreloading,
}

local currentSoundfontIndex = 1
local sustainToggle = false
local sustainedNotes = {}

local trackedNotes: { [Enum.KeyCode]: number } = {}
local remotePlayerStates = {}

local eventQueue = {}
local batchStartTime = 0
local currentFrame = 0

local function queueEvent(noteId: number, velocity: number, isPressed: boolean)
	local now = os.clock()
	if #eventQueue == 0 then
		batchStartTime = now
	end

	local offset = math.floor((now - batchStartTime) * 1000)

	table.insert(eventQueue, {
		NoteId = noteId,
		Velocity = velocity,
		IsPressed = isPressed,
		TimestampOffset = math.clamp(offset, 0, 255),
	})
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

local function getAssetForNote(midi: number, soundfontIndex: number?): string?
	local name = NoteUtils.getNoteName(midi)
	local index = soundfontIndex or currentSoundfontIndex
	local fontData = SoundFonts.Fonts[index]
	if not fontData then
		return nil
	end
	local font = fontData.Data[name]
	if not font then
		return nil
	end
	return if type(font) == "table" then font[127] else font
end

local function releaseSustainedNotes()
	for midi in pairs(sustainedNotes) do
		VoiceProvider.stop(midi, 0, 0.5)
	end
	table.clear(sustainedNotes)
end

local function triggerPreload(index: number)
	isPreloading:set(true)
	local mapping = SoundFonts.getFontMapping(index)
	VoiceProvider.updatePersistentFonts(0, mapping)

	VoiceProvider.preload(SoundFonts.getFontAssetIds(index), function()
		isPreloading:set(false)
	end)
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

	queueEvent(midi, velocity, isPressed)
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
		queueEvent(0, sustainToggle and 127 or 0, sustainToggle)
		if not sustainToggle then
			releaseSustainedNotes()
		end
		return
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
		midi = KeyConfig.getNote(input.KeyCode, shiftPressed, Fusion.peek(currentLayout))
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

function PianoController.initAudio()
	local initialMapping = SoundFonts.getFontMapping(1)
	VoiceProvider.init(initialMapping)
end

function PianoController.init()
	PianoController.initAudio()

	local LocalPlayer = Players.LocalPlayer

	local function updateSeat()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then
			local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, "Piano") then
				activePiano:set(model)
				workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
				return
			end
		end

		if Fusion.peek(activePiano) ~= nil then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
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
			queueEvent(0, sustainToggle and 127 or 0, sustainToggle)
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
			queueEvent(0, 0, false)
			table.clear(sustainedNotes)
		end,
	})
	app.Parent = playerGui

	local function setAppVisible(visible: boolean)
		if app:IsA("ScreenGui") then
			app.Enabled = visible
		else
			app.Visible = visible
		end
	end

	scope:Observer(activePiano):onChange(function()
		setAppVisible(Fusion.peek(activePiano) ~= nil)
	end)
	setAppVisible(Fusion.peek(activePiano) ~= nil)

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
			table.clear(eventQueue)
			batchStartTime = 0
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
			task.delay(event.TimestampOffset / 1000, function()
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
			end)
		end
	end)
end

PianoController.captureInput = captureInput
PianoController.onInputBegan = onInputBegan
PianoController.onInputEnded = onInputEnded

return PianoController
