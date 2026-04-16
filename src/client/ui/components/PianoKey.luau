local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

type Props = {
	Scope: any,
	NoteName: Fusion.UsedAs<string>,
	IsPressed: Fusion.UsedAs<boolean>,
	IsBlack: boolean,
	KeyBind: Fusion.UsedAs<string?>,
	Position: Fusion.UsedAs<UDim2>?,
	IsActive: boolean?,
}

return function(props: Props)
	local scope = props.Scope

	local pressLevel = scope:Spring(
		scope:Computed(function(use)
			return use(props.IsPressed) and 1 or 0
		end),
		Theme.Springs.Snappy.speed,
		Theme.Springs.Snappy.damping
	)

	local keyColor = scope:Computed(function(use)
		local level = use(pressLevel)
		if props.IsBlack then
			return Color3.new(0.08, 0.08, 0.08):Lerp(Theme.Colors.AccentNeon, level * 0.4)
		else
			return Color3.new(1, 1, 1):Lerp(Theme.Colors.AccentNeon, level * 0.15)
		end
	end)

	local combinedPosition = scope:Computed(function(use)
		local basePos = Fusion.peek(props.Position) or UDim2.new()
		local level = use(pressLevel)
		return basePos + UDim2.fromOffset(0, level * 5)
	end)

	local gradientColor = scope:Computed(function(use)
		local level = use(pressLevel)
		if props.IsBlack then
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(0.3, 0.3, 0.3):Lerp(Color3.new(0, 0, 0), level)),
			})
		else
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(0.9, 0.9, 0.9):Lerp(Color3.new(0.6, 0.6, 0.6), level)),
			})
		end
	end)

	return scope:New("Frame")({
		Name = props.NoteName,
		BackgroundColor3 = keyColor,
		BorderSizePixel = 0,
		Position = combinedPosition,

		Size = if props.IsBlack
			then UDim2.fromOffset(Theme.Layout.BlackKeyWidth, Theme.Layout.BlackKeyHeight)
			else UDim2.fromOffset(Theme.Layout.KeyWidth, Theme.Layout.KeyHeight),

		ZIndex = if props.IsBlack then 2 else 1,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),

			scope:New("UIGradient")({
				Color = gradientColor,
				Rotation = 90,
			}),

			scope:New("Frame")({
				Name = "GlowBeam",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(1.8, 3),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIGradient")({
						Color = ColorSequence.new(Theme.Colors.AccentNeon),
						Transparency = scope:Computed(function(use)
							local level = use(pressLevel)
							return NumberSequence.new({
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(0.85, 1 - (level * 0.4)),
								NumberSequenceKeypoint.new(1, 1 - (level * 0.2)),
							})
						end),
						Rotation = 90,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "KeyBindTag",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = if props.IsBlack then Theme.Colors.Zinc950 else Theme.Colors.Zinc100,
				BackgroundTransparency = if props.KeyBind then 0.2 else 1,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("UIStroke")({
						Color = scope:Computed(function(use)
							local level = use(pressLevel)
							return level > 0.1 and Theme.Colors.AccentNeon or Theme.Colors.Zinc400
						end),
						Transparency = 0.5,
						Thickness = 1,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = props.KeyBind or "",
						TextColor3 = scope:Computed(function(use)
							local level = use(pressLevel)
							if level > 0.1 then
								return Theme.Colors.AccentNeon
							end
							return if props.IsBlack then Theme.Colors.Zinc100 else Theme.Colors.Zinc700
						end),
						TextSize = 10,
						FontFace = Theme.Fonts.KeyLabel,
					}),
				},
			}),
		},
	})
end
