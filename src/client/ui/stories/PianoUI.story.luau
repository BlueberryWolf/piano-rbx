local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local PianoController = require(StarterPlayer.StarterPlayerScripts.Client["PianoController.module"])
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local Maid = require(ReplicatedStorage.Shared.Maid)
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

		local pressedKeys = scope:Value({})
		local currentLayout = scope:Value("FL")
		local customMapping = scope:Value({})
		local bindingMidi = scope:Value(nil :: number?)
		local soundfont = scope:Value("Grand Piano")
		local isPreloading = scope:Value(false)

		PianoController.InitAssets()

		scope:Observer(props.controls.Layout):onChange(function()
			local newLayout = Fusion.peek(props.controls.Layout)
			currentLayout:set(newLayout)
			PianoController.SetLayout(newLayout)
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
		
		local manualShift = false

		local userInput = UILabs.Environment.UserInput
		local shiftHeld = false

		local conn1 = userInput.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = true
			end

			if processed then return end

			local midi = KeyConfig.getNote(input.KeyCode, shiftHeld, Fusion.peek(currentLayout))

			if midi then
				onKeyPressed(midi)
			end
		end)

		local conn2 = userInput.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
				shiftHeld = false
			end

			local midi = KeyConfig.getNote(input.KeyCode, true, Fusion.peek(currentLayout))
			local midi2 = KeyConfig.getNote(input.KeyCode, false, Fusion.peek(currentLayout))

			if midi then onKeyReleased(midi) end
			if midi2 and midi2 ~= midi then onKeyReleased(midi2) end
		end)

		UILabs.Environment.GetJanitor():Add(function()
			conn1:Disconnect()
			conn2:Disconnect()
		end)

		main.Parent = props.target
	end,
}

return story
