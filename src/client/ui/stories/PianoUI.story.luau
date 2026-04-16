local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local PianoController = require(StarterPlayer.StarterPlayerScripts.Client["PianoController.module"])
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local Maid = require(ReplicatedStorage.Shared.Maid)
local PianoMain = require(script.Parent.Parent.PianoMain)

local story = {
	fusion = Fusion,
	controls = {
		Sustain = false,
		Layout = "FL",
	},
	story = function(props)
		local scope = props.scope

		local pressedKeys = scope:Value({})
		local currentLayout = scope:Value("FL")
		local customMapping = scope:Value({})
		local bindingMidi = scope:Value(nil :: number?)
		local soundfont = scope:Value("Grand Piano")
		local isPreloading = scope:Value(false)

		PianoController.InitAssets()

		scope:Observer(props.controls.Layout):onChange(function()
			currentLayout:set(Fusion.peek(props.controls.Layout))
		end)

		local function onKeyPressed(midi)
			local current = Fusion.peek(pressedKeys)
			local next = table.clone(current)
			next[midi] = true
			pressedKeys:set(next)
			PianoController.captureInput(midi, 127, true)
		end

		local function onKeyReleased(midi)
			local current = Fusion.peek(pressedKeys)
			local next = table.clone(current)
			next[midi] = nil
			pressedKeys:set(next)
			PianoController.captureInput(midi, 0, false)
		end

		local main = PianoMain({
			Scope = scope,
			PressedKeys = pressedKeys,
			SustainActive = props.controls.Sustain,
			SoundfontName = soundfont,
			CurrentLayout = currentLayout,
			CustomMapping = customMapping,
			BindingMidi = bindingMidi,
			IsPreloading = isPreloading,

			OnKeyPressed = onKeyPressed,
			OnKeyReleased = onKeyReleased,
			OnSustainToggled = function()
				props.controls.Sustain:set(not Fusion.peek(props.controls.Sustain))
			end,
			OnSetLayout = function(layout)
				currentLayout:set(layout)
				props.controls.Layout:set(layout)
			end,
			OnStartBinding = function(midi)
				bindingMidi:set(midi)
			end,
			OnClearMapping = function()
				customMapping:set({})
			end,
		})

		local userInput = UILabs.Environment.UserInput
		local conn1 = userInput.InputBegan:Connect(function(input, processed)
			local shiftPressed = userInput:IsKeyDown(Enum.KeyCode.LeftShift)
				or userInput:IsKeyDown(Enum.KeyCode.RightShift)

			PianoController.onInputBegan(input, processed, shiftPressed)
		end)
		local conn2 = userInput.InputEnded:Connect(function(input, processed)
			PianoController.onInputEnded(input)
		end)

		UILabs.Environment.GetJanitor():Add(function()
			conn1:Disconnect()
			conn2:Disconnect()
		end)

		main.Parent = props.target
	end,
}

return story
