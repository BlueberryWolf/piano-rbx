local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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

		scope:Observer(props.controls.Layout):onChange(function()
			currentLayout:set(Fusion.peek(props.controls.Layout))
		end)

		local function onKeyPressed(midi)
			local current = Fusion.peek(pressedKeys)
			local next = table.clone(current)
			next[midi] = true
			pressedKeys:set(next)
		end

		local function onKeyReleased(midi)
			local current = Fusion.peek(pressedKeys)
			local next = table.clone(current)
			next[midi] = nil
			pressedKeys:set(next)
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

		main.Parent = props.target
	end,
}

return story
