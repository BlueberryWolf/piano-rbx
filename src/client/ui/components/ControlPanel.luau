local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

type Props = {
	Scope: any,
	SustainActive: Fusion.UsedAs<boolean>,
	SoundfontName: Fusion.UsedAs<string>,
	IsPreloading: Fusion.UsedAs<boolean>,
	OnSustainToggled: () -> (),
	OnSettingsOpened: () -> (),
	OnPanic: (() -> ())?,
}

return function(props: Props)
	local scope = props.Scope

	local loadingOpacity = scope:Spring(
		scope:Computed(function(use)
			return use(props.IsPreloading) and 1 or 0
		end),
		Theme.Springs.Standard.speed,
		Theme.Springs.Standard.damping
	)

	return scope:New("Frame")({
		Name = "ControlPanel",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Colors.Zinc950,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),

			scope:New("UIGradient")({
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 0.2),
				}),
			}),

			scope:New("UIStroke")({
				Color = Theme.Colors.Zinc700,
				Transparency = 0.5,
				Thickness = 1,
			}),

			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 20),
					}),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 20),
						PaddingRight = UDim.new(0, 20),
					}),

					scope:New("Frame")({
						Size = UDim2.fromOffset(250, 44),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 10),
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromOffset(160, 44),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use)
									return "Instrument: " .. use(props.SoundfontName)
								end),
								TextColor3 = Theme.Colors.Zinc100,
								TextXAlignment = Enum.TextXAlignment.Left,
								FontFace = Theme.Fonts.Heading,
								TextSize = 13,
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromOffset(60, 44),
								BackgroundTransparency = 1,
								Text = "LOADING...",
								TextColor3 = Theme.Colors.Zinc500,
								TextTransparency = scope:Computed(function(use)
									return 1 - use(loadingOpacity)
								end),
								FontFace = Theme.Fonts.Body,
								TextSize = 11,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),

					scope:New("Frame")({
						Size = UDim2.new(1, -550, 0, 0),
						BackgroundTransparency = 1,
					}),

					scope:New("TextButton")({
						Name = "PanicButton",
						Size = UDim2.fromOffset(32, 28),
						BackgroundColor3 = Theme.Colors.Zinc800:Lerp(Color3.new(1, 0, 0), 0.1),
						Text = "⏹",
						TextColor3 = Theme.Colors.Zinc100,
						FontFace = Theme.Fonts.Body,
						TextSize = 14,
						AutoButtonColor = true,
						[Fusion.OnEvent("Activated")] = props.OnPanic,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
							scope:New("UIStroke")({ Color = Theme.Colors.Zinc700, Thickness = 1 }),
						},
					}),

					scope:New("TextButton")({
						Name = "SustainButton",
						Size = UDim2.fromOffset(100, 28),
						BackgroundColor3 = Theme.Colors.Zinc800,
						Text = "SUSTAIN",
						TextColor3 = scope:Computed(function(use)
							return use(props.SustainActive) and Theme.Colors.SustainActive or Theme.Colors.Zinc400
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = 11,
						AutoButtonColor = false,

						[Fusion.OnEvent("Activated")] = props.OnSustainToggled,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
							scope:New("UIStroke")({
								Color = scope:Computed(function(use)
									return use(props.SustainActive) and Theme.Colors.SustainActive
										or Theme.Colors.Zinc700
								end),
								Thickness = 1,
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "SettingsButton",
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Text = "⚙",
						TextColor3 = Theme.Colors.Zinc400,
						TextSize = 20,
						FontFace = Theme.Fonts.Body,

						[Fusion.OnEvent("Activated")] = props.OnSettingsOpened,
					}),
				},
			}),
		},
	})
end
