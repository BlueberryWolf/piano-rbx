local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local PianoState = require(script.Parent.PianoState)
local PianoInput = require(script.Parent.managers.PianoInput)
local PianoNetworking = require(script.Parent.managers.PianoNetworking)
local PianoSpatializer = require(script.Parent.managers.PianoSpatializer)
local PianoSeating = require(script.Parent.managers.PianoSeating)

local PianoApp = require(script.Parent.ui.PianoApp)

local PianoController = {}

PianoController.state = {
	pressedKeys = PianoState.pressedKeys,
	sustainActive = PianoState.sustainActive,
	currentSoundfontName = PianoState.currentSoundfontName,
	currentLayout = PianoState.currentLayout,
	customMapping = PianoState.customMapping,
	bindingMidi = PianoState.bindingMidi,
	activePiano = PianoState.activePiano,
	isPreloading = PianoState.isPreloading,
}

function PianoController.SetLayout(layout: string)
	if KeyConfig.Presets[layout] then
		PianoState.currentLayout:set(layout)
	end
end

function PianoController.StartBinding(midi: number)
	PianoState.bindingMidi:set(midi)
end

function PianoController.ClearMapping(midi: number)
	local current = Fusion.peek(PianoState.customMapping)
	local next = table.clone(current)
	for key, m in pairs(next) do
		if m == midi then
			next[key] = nil
		end
	end
	PianoState.customMapping:set(next)
end

function PianoController.initAudio()
	local initialMapping = SoundFonts.getFontMapping(1)
	VoiceProvider.init(initialMapping)
end

function PianoController.init()
	PianoController.initAudio()

	-- Initialize managers
	PianoNetworking.init()
	PianoSpatializer.init()
	PianoSeating.init()
	PianoInput.init()

	local LocalPlayer = Players.LocalPlayer
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local app = PianoApp({
		Scope = PianoState.scope,
		PressedKeys = PianoState.pressedKeys,
		SustainActive = PianoState.sustainActive,
		SoundfontName = PianoState.currentSoundfontName,
		CurrentLayout = PianoState.currentLayout,
		CustomMapping = PianoState.customMapping,
		BindingMidi = PianoState.bindingMidi,
		OnKeyPressed = function(midi)
			PianoInput.captureInput(midi, 127, true)
		end,
		OnKeyReleased = function(midi)
			PianoInput.captureInput(midi, 0, false)
		end,
		OnSustainToggled = function()
			PianoState.sustainToggle = not PianoState.sustainToggle
			PianoState.sustainActive:set(PianoState.sustainToggle)
			PianoNetworking.queueEvent(0, PianoState.sustainToggle and 127 or 0, PianoState.sustainToggle)
			if not PianoState.sustainToggle then
				PianoInput.releaseSustainedNotes()
			end
		end,
		OnSetLayout = PianoController.SetLayout,
		OnStartBinding = PianoController.StartBinding,
		OnClearMapping = PianoController.ClearMapping,
		IsPreloading = PianoState.isPreloading,
		OnPanic = function()
			VoiceProvider.stopAll()
			PianoState.sustainToggle = false
			PianoState.sustainActive:set(false)
			PianoNetworking.queueEvent(0, 0, false)
			table.clear(PianoState.sustainedNotes)
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

	PianoState.scope:Observer(PianoState.activePiano):onChange(function()
		setAppVisible(Fusion.peek(PianoState.activePiano) ~= nil)
	end)
	setAppVisible(Fusion.peek(PianoState.activePiano) ~= nil)
end

-- Export captureInput for use in UI or other places if needed
PianoController.captureInput = PianoInput.captureInput

return PianoController
