local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local PianoController = require(StarterPlayer.StarterPlayerScripts.Client["PianoController.module"])
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local PianoMain = require(script.Parent.Parent.PianoMain)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)

local story = {
	fusion = Fusion,
	controls = {
		Sustain = false,
		Layout = "FL",
	},
	story = function(props)
		local scope = props.scope
		local state = PianoController.state

		PianoController.initAudio()

		scope:Observer(props.controls.Layout):onChange(function()
			PianoController.SetLayout(Fusion.peek(props.controls.Layout))
		end)

		local main = PianoMain({
			Scope = scope,
			PressedKeys = state.pressedKeys,
			SustainActive = props.controls.Sustain,
			SoundfontName = state.currentSoundfontName,
			CurrentLayout = state.currentLayout,
			CustomMapping = state.customMapping,
			BindingMidi = state.bindingMidi,
			IsPreloading = state.isPreloading,

			OnKeyPressed = function(midi)
				PianoController.captureInput(midi, 127, true)
			end,
			OnKeyReleased = function(midi)
				PianoController.captureInput(midi, 0, false)
			end,
			OnSustainToggled = function()
				props.controls.Sustain:set(not Fusion.peek(props.controls.Sustain))
			end,
			OnSetLayout = function(layout)
				PianoController.SetLayout(layout)
				props.controls.Layout:set(layout)
			end,
			OnStartBinding = PianoController.StartBinding,
			OnClearMapping = PianoController.ClearMapping,
		})

		local userInput = UILabs.Environment.UserInput
		local shiftHeld = false

		local conn1 = userInput.InputBegan:Connect(function(input, _processed)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = true
				return
			end

			local midi = KeyConfig.getNote(input.KeyCode, shiftHeld, Fusion.peek(state.currentLayout))
			if midi then
				PianoController.captureInput(midi, 127, true)
			end
		end)

		local conn2 = userInput.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = false
			end
			local midi = KeyConfig.getNote(input.KeyCode, true, Fusion.peek(state.currentLayout))
			local midi2 = KeyConfig.getNote(input.KeyCode, false, Fusion.peek(state.currentLayout))

			if midi then
				PianoController.captureInput(midi, 0, false)
			end
			if midi2 and midi2 ~= midi then
				PianoController.captureInput(midi2, 0, false)
			end
		end)

		UILabs.Environment.GetJanitor():Add(function()
			conn1:Disconnect()
			conn2:Disconnect()
		end)

		main.Parent = props.target
	end,
}

return story
