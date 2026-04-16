local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)

local Theme = require(script.Parent.Theme)
local PianoKey = require(script.Parent.components.PianoKey)
local ControlPanel = require(script.Parent.components.ControlPanel)
local SettingsModal = require(script.Parent.components.SettingsModal)

local function isBlackKey(midi: number)
	local mod = midi % 12
	return mod == 1 or mod == 3 or mod == 6 or mod == 8 or mod == 10
end

type Props = {
	Scope: any,
	PressedKeys: Fusion.UsedAs<{ [number]: boolean }>,
	SustainActive: Fusion.UsedAs<boolean>,
	SoundfontName: Fusion.UsedAs<string>,
	CurrentLayout: Fusion.UsedAs<string>,
	CustomMapping: Fusion.UsedAs<{ [Enum.KeyCode]: number }>,
	BindingMidi: Fusion.UsedAs<number?>,
	OnKeyPressed: (midi: number) -> (),
	OnKeyReleased: (midi: number) -> (),
	OnSustainToggled: () -> (),
	OnSetLayout: (layout: string) -> (),
	OnStartBinding: (midi: number) -> (),
	OnClearMapping: (midi: number) -> (),
	IsPreloading: Fusion.UsedAs<boolean>,
	OnPanic: (() -> ())?,
}

return function(props: Props)
	local scope = props.Scope

	local settingsOpen = scope:Value(false)
	local dragging = scope:Value(false)
	local dragOffset = scope:Value(Vector2.new(0, 0))
	local position = scope:Value(UDim2.new(0.5, 0, 1, -40))

	local mouseActiveMidi = scope:Value(nil :: number?)
	local isMouseDown = scope:Value(false)

	local geometry = scope:Computed(function(use)
		local layout = use(props.CurrentLayout)
		local preset = KeyConfig.Presets[layout]

		local min, max = 127, 0
		for _, midi in pairs(preset) do
			if midi < min then
				min = midi
			end
			if midi > max then
				max = midi
			end
		end

		local keys = {}
		local whiteKeyCount = 0
		for midi = min, max do
			local isBlack = isBlackKey(midi)
			local xOffset = 0
			if not isBlack then
				xOffset = whiteKeyCount * (Theme.Layout.KeyWidth + Theme.Layout.Padding)
				whiteKeyCount += 1
			else
				local lastWhiteX = (whiteKeyCount - 1) * (Theme.Layout.KeyWidth + Theme.Layout.Padding)
				local nextWhiteX = whiteKeyCount * (Theme.Layout.KeyWidth + Theme.Layout.Padding)
				local gapCenter = (lastWhiteX + Theme.Layout.KeyWidth + nextWhiteX) / 2
				xOffset = gapCenter - (Theme.Layout.BlackKeyWidth / 2)
			end
			table.insert(keys, {
				midi = midi,
				isBlack = isBlack,
				xOffset = xOffset,
			})
		end

		return {
			keys = keys,
			width = whiteKeyCount * (Theme.Layout.KeyWidth + Theme.Layout.Padding),
		}
	end)

	local function getMidiAtPosition(localX: number, localY: number): number?
		local geo = Fusion.peek(geometry)
		for _, keyInfo in ipairs(geo.keys) do
			if keyInfo.isBlack then
				local left = keyInfo.xOffset
				local right = left + Theme.Layout.BlackKeyWidth
				if localX >= left and localX <= right and localY >= 0 and localY <= Theme.Layout.BlackKeyHeight then
					return keyInfo.midi
				end
			end
		end
		for _, keyInfo in ipairs(geo.keys) do
			if not keyInfo.isBlack then
				local left = keyInfo.xOffset
				local right = left + Theme.Layout.KeyWidth
				if localX >= left and localX <= right and localY >= 0 and localY <= Theme.Layout.KeyHeight then
					return keyInfo.midi
				end
			end
		end
		return nil
	end

	local PianoBoard: Frame

	local function updateGlide(input: InputObject)
		if not Fusion.peek(isMouseDown) then
			return
		end
		if not PianoBoard then
			return
		end
		local localPos = Vector2.new(input.Position.X, input.Position.Y) - PianoBoard.AbsolutePosition
		local midi = getMidiAtPosition(localPos.X, localPos.Y)
		local lastMidi = Fusion.peek(mouseActiveMidi)
		if midi ~= lastMidi then
			if lastMidi then
				props.OnKeyReleased(lastMidi)
			end
			if midi then
				props.OnKeyPressed(midi)
			end
			mouseActiveMidi:set(midi)
		end
	end

	PianoBoard = scope:New("Frame")({
		Name = "PianoBoard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = scope:Computed(function(use)
			return UDim2.fromOffset(use(geometry).width, Theme.Layout.KeyHeight)
		end),
		BackgroundTransparency = 1,
		Active = true,

		[Fusion.OnEvent("InputBegan")] = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isMouseDown:set(true)
				updateGlide(input)
			end
		end,
		[Fusion.OnEvent("InputChanged")] = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				updateGlide(input)
			end
		end,
		[Fusion.OnEvent("InputEnded")] = function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				isMouseDown:set(false)
				local m = Fusion.peek(mouseActiveMidi)
				if m then
					props.OnKeyReleased(m)
				end
				mouseActiveMidi:set(nil)
			end
		end,

		[Fusion.Children] = scope:ForValues(
			scope:Computed(function(use)
				return use(geometry).keys
			end),
			function(_use, innerScope, keyInfo)
				local isPressed = innerScope:Computed(function(use)
					return use(props.PressedKeys)[keyInfo.midi] or false
				end)

				local label = innerScope:Computed(function(use)
					local layout = use(props.CurrentLayout)
					local custom = use(props.CustomMapping)

					for key, midi in pairs(custom) do
						if midi == keyInfo.midi then
							return KeyConfig.getShortName(key, false)
						end
					end

					local preset = KeyConfig.Presets[layout]

					if layout == "VirtualPiano" and keyInfo.isBlack then
						for key, midi in pairs(preset) do
							if midi == keyInfo.midi - 1 then
								return KeyConfig.getShortName(key, true)
							end
						end
					else
						for key, midi in pairs(preset) do
							if midi == keyInfo.midi then
								return KeyConfig.getShortName(key, false)
							end
						end
					end

					return ""
				end)

				return PianoKey({
					Scope = innerScope,
					NoteName = tostring(keyInfo.midi),
					IsBlack = keyInfo.isBlack,
					KeyBind = label,
					IsPressed = isPressed,
					Position = UDim2.fromOffset(keyInfo.xOffset, 0),
					IsActive = innerScope:Computed(function(use)
						return use(label) ~= nil
					end),
				})
			end
		),
	})

	return scope:New("Frame")({
		Name = "PianoMain",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "MainContainer",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = position,
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(use(geometry).width + 20, Theme.Layout.KeyHeight + 80)
				end),
				BackgroundColor3 = Theme.Colors.Zinc950,
				BackgroundTransparency = 0.5,
				ClipsDescendants = false,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Zinc800, Thickness = 2 }),

					ControlPanel({
						Scope = scope,
						SustainActive = props.SustainActive,
						SoundfontName = props.SoundfontName,
						IsPreloading = props.IsPreloading,
						OnSustainToggled = props.OnSustainToggled,
						OnSettingsOpened = function()
							settingsOpen:set(true)
						end,
						OnPanic = props.OnPanic,
					}),

					scope:New("Frame")({
						Name = "DragArea",
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Fusion.OnEvent("InputBegan")] = function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseButton1
								or input.UserInputType == Enum.UserInputType.Touch
							then
								dragging:set(true)
								dragOffset:set(input.Position)
							end
						end,
						[Fusion.OnEvent("InputChanged")] = function(input)
							if
								Fusion.peek(dragging)
								and (
									input.UserInputType == Enum.UserInputType.MouseMovement
									or input.UserInputType == Enum.UserInputType.Touch
								)
							then
								local delta = input.Position - Fusion.peek(dragOffset)
								dragOffset:set(input.Position)
								local cp = Fusion.peek(position)
								position:set(
									UDim2.new(cp.X.Scale, cp.X.Offset + delta.X, cp.Y.Scale, cp.Y.Offset + delta.Y)
								)
							end
						end,
						[Fusion.OnEvent("InputEnded")] = function(input)
							if
								input.UserInputType == Enum.UserInputType.MouseButton1
								or input.UserInputType == Enum.UserInputType.Touch
							then
								dragging:set(false)
							end
						end,
					}),

					PianoBoard,
				},
			}),

			SettingsModal({
				Scope = scope,
				IsOpen = settingsOpen,
				CurrentLayout = props.CurrentLayout,
				CustomMapping = props.CustomMapping,
				BindingMidi = props.BindingMidi,
				OnClose = function()
					settingsOpen:set(false)
				end,
				OnSetLayout = props.OnSetLayout,
				OnStartBinding = props.OnStartBinding,
				OnClearMapping = props.OnClearMapping,
			}),
		},
	})
end
