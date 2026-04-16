local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)

type Props = {
	Scope: any,
	IsOpen: Fusion.UsedAs<boolean>,
	CurrentLayout: Fusion.UsedAs<string>,
	CustomMapping: Fusion.UsedAs<{ [Enum.KeyCode]: number }>,
	BindingMidi: Fusion.UsedAs<number?>,
	OnClose: () -> (),
	OnSetLayout: (layout: string) -> (),
	OnStartBinding: (midi: number) -> (),
	OnClearMapping: (midi: number) -> (),
}

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local function getNoteName(midi: number): string
	local octave = math.floor(midi / 12) - 1
	return NOTE_NAMES[(midi % 12) + 1] .. tostring(octave)
end

return function(props: Props)
	local scope = props.Scope
	local currentTab = scope:Value("General")

	local openValue = scope:Computed(function(use)
		return use(props.IsOpen) and 1 or 0
	end)
	local openSpring = scope:Spring(openValue, Theme.Springs.Standard.speed, Theme.Springs.Standard.damping)

	local function TabButton(label: string)
		local isActive = scope:Computed(function(use)
			return use(currentTab) == label
		end)
		return scope:New("TextButton")({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = scope:Computed(function(use)
				return use(isActive) and 0.8 or 1
			end),
			BackgroundColor3 = Theme.Colors.Zinc700,
			Text = label,
			TextColor3 = scope:Computed(function(use)
				return use(isActive) and Theme.Colors.AccentNeon or Theme.Colors.Zinc400
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = 14,
			AutoButtonColor = false,
			[Fusion.OnEvent("Activated")] = function()
				currentTab:set(label)
			end,
			[Fusion.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			},
		})
	end

	return scope:New("Frame")({
		Name = "SettingsModal",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(openSpring) > 0.001
		end),
		ZIndex = 10,

		[Fusion.Children] = {
			scope:New("TextButton")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = scope:Computed(function(use)
					return 1 - use(openSpring) * 0.6
				end),
				BackgroundColor3 = Color3.new(0, 0, 0),
				Text = "",
				AutoButtonColor = false,
				[Fusion.OnEvent("Activated")] = props.OnClose,
			}),

			scope:New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use)
					return UDim2.fromScale(0.5, 0.5 - (1 - use(openSpring)) * 0.05)
				end),
				Size = UDim2.fromOffset(600, 450),
				BackgroundColor3 = Theme.Colors.Zinc950,
				GroupTransparency = scope:Computed(function(use)
					return 1 - use(openSpring)
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Zinc800,
						Thickness = 2,
						Transparency = scope:Computed(function(use)
							return 1 - use(openSpring)
						end),
					}),

					scope:New("Frame")({
						Size = UDim2.new(0, 160, 1, 0),
						BackgroundColor3 = Theme.Colors.Zinc900,
						BorderSizePixel = 0,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
							scope:New("Frame")({
								Position = UDim2.new(1, -12, 0, 0),
								Size = UDim2.new(0, 12, 1, 0),
								BackgroundColor3 = Theme.Colors.Zinc900,
								ZIndex = 0,
								BorderSizePixel = 0,
							}),

							scope:New("Frame")({
								Name = "SidebarContent",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ZIndex = 1,
								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 20),
										PaddingLeft = UDim.new(0, 10),
										PaddingRight = UDim.new(0, 10),
									}),
									scope:New("UIListLayout")({ Padding = UDim.new(0, 5) }),

									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 30),
										BackgroundTransparency = 1,
										Text = "SETTINGS",
										TextColor3 = Theme.Colors.Zinc600,
										FontFace = Theme.Fonts.Heading,
										TextSize = 10,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									TabButton("General"),
									TabButton("Controls"),
									TabButton("Keybinds"),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Position = UDim2.fromOffset(160, 0),
						Size = UDim2.new(1, -160, 1, 0),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, 24),
								PaddingLeft = UDim.new(0, 24),
								PaddingRight = UDim.new(0, 24),
								PaddingBottom = UDim.new(0, 24),
							}),

							scope:New("Frame")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Visible = scope:Computed(function(use)
									return use(currentTab) == "General"
								end),
								[Fusion.Children] = {
									scope:New("UIListLayout")({ Padding = UDim.new(0, 20) }),
									scope:New("TextLabel")({
										Text = "General Settings",
										TextColor3 = Theme.Colors.Zinc100,
										FontFace = Theme.Fonts.Heading,
										TextSize = 24,
										BackgroundTransparency = 1,
										Size = UDim2.new(1, 0, 0, 30),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("TextLabel")({
										Text = "Customize your piano experience with the settings below.",
										TextColor3 = Theme.Colors.Zinc400,
										FontFace = Theme.Fonts.Body,
										TextSize = 14,
										BackgroundTransparency = 1,
										Size = UDim2.new(1, 0, 0, 20),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),

							scope:New("Frame")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Visible = scope:Computed(function(use)
									return use(currentTab) == "Controls"
								end),
								[Fusion.Children] = {
									scope:New("UIListLayout")({ Padding = UDim.new(0, 20) }),
									scope:New("TextLabel")({
										Text = "Keyboard Layout",
										TextColor3 = Theme.Colors.Zinc100,
										FontFace = Theme.Fonts.Heading,
										TextSize = 24,
										BackgroundTransparency = 1,
										Size = UDim2.new(1, 0, 0, 30),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("Frame")({
										Size = UDim2.new(1, 0, 0, 60),
										BackgroundTransparency = 1,
										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												Padding = UDim.new(0, 10),
											}),

											scope:New("TextButton")({
												Text = "FL Studio Style",
												Size = UDim2.fromOffset(130, 40),
												BackgroundColor3 = scope:Computed(function(use)
													return use(props.CurrentLayout) == "FL" and Theme.Colors.AccentNeon
														or Theme.Colors.Zinc800
												end),
												TextColor3 = scope:Computed(function(use)
													return use(props.CurrentLayout) == "FL" and Theme.Colors.Zinc950
														or Theme.Colors.Zinc100
												end),
												FontFace = Theme.Fonts.Body,
												[Fusion.OnEvent("Activated")] = function()
													props.OnSetLayout("FL")
												end,
												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
												},
											}),

											scope:New("TextButton")({
												Text = "Virtual Piano",
												Size = UDim2.fromOffset(130, 40),
												BackgroundColor3 = scope:Computed(function(use)
													return use(props.CurrentLayout) == "VirtualPiano"
															and Theme.Colors.AccentNeon
														or Theme.Colors.Zinc800
												end),
												TextColor3 = scope:Computed(function(use)
													return use(props.CurrentLayout) == "VirtualPiano"
															and Theme.Colors.Zinc950
														or Theme.Colors.Zinc100
												end),
												FontFace = Theme.Fonts.Body,
												[Fusion.OnEvent("Activated")] = function()
													props.OnSetLayout("VirtualPiano")
												end,
												[Fusion.Children] = {
													scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
												},
											}),
										},
									}),
									scope:New("TextLabel")({
										Text = "FL Studio: 2-row layout (Z/X and Q/W).\nVirtual Piano: Full linear keyboard range with Shift for sharps.",
										TextColor3 = Theme.Colors.Zinc500,
										FontFace = Theme.Fonts.Body,
										TextSize = 13,
										BackgroundTransparency = 1,
										Size = UDim2.new(1, 0, 0, 40),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),

							scope:New("Frame")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Visible = scope:Computed(function(use)
									return use(currentTab) == "Keybinds"
								end),
								[Fusion.Children] = {
									scope:New("UIListLayout")({ Padding = UDim.new(0, 15) }),
									scope:New("TextLabel")({
										Text = "Custom Keybinds",
										TextColor3 = Theme.Colors.Zinc100,
										FontFace = Theme.Fonts.Heading,
										TextSize = 24,
										BackgroundTransparency = 1,
										Size = UDim2.new(1, 0, 0, 30),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("ScrollingFrame")({
										Size = UDim2.new(1, 0, 1, -50),
										BackgroundTransparency = 1,
										BorderSizePixel = 0,
										ScrollBarThickness = 2,
										ScrollBarImageColor3 = Theme.Colors.Zinc700,
										CanvasSize = UDim2.new(0, 0, 0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										[Fusion.Children] = {
											scope:New("UIListLayout")({ Padding = UDim.new(0, 4) }),
											scope:ForValues(
												scope:Computed(function(use)
													local layout = use(props.CurrentLayout)
													local preset = KeyConfig.Presets[layout]
													local uniqueMidis = {}
													local midis = {}
													for _, midi in pairs(preset) do
														if not uniqueMidis[midi] then
															uniqueMidis[midi] = true
															table.insert(midis, midi)
														end
													end
													table.sort(midis)
													return midis
												end),
												function(_use, innerScope, midi)
													local isBinding = innerScope:Computed(function(use)
														return use(props.BindingMidi) == midi
													end)

													local currentBind = innerScope:Computed(function(use)
														local layout = use(props.CurrentLayout)
														local custom = use(props.CustomMapping)
														for key, m in pairs(custom) do
															if m == midi then
																return KeyConfig.getShortName(key)
															end
														end
														for key, m in pairs(KeyConfig.Presets[layout]) do
															if m == midi then
																return KeyConfig.getShortName(key)
															end
														end
														return "None"
													end)

													return innerScope:New("Frame")({
														Size = UDim2.new(1, -10, 0, 36),
														BackgroundColor3 = Theme.Colors.Zinc900,
														[Fusion.Children] = {
															innerScope:New("UICorner")({
																CornerRadius = UDim.new(0, 4),
															}),
															innerScope:New("TextLabel")({
																Size = UDim2.fromScale(0.3, 1),
																Position = UDim2.fromOffset(10, 0),
																BackgroundTransparency = 1,
																Text = getNoteName(midi),
																TextColor3 = Theme.Colors.Zinc100,
																FontFace = Theme.Fonts.Body,
																TextXAlignment = Enum.TextXAlignment.Left,
															}),
															innerScope:New("TextLabel")({
																Size = UDim2.fromScale(0.2, 1),
																Position = UDim2.new(0.3, 10, 0, 0),
																BackgroundTransparency = 1,
																Text = currentBind,
																TextColor3 = Theme.Colors.Zinc500,
																FontFace = Theme.Fonts.Body,
																TextSize = 12,
																TextXAlignment = Enum.TextXAlignment.Left,
															}),
															innerScope:New("TextButton")({
																Size = UDim2.fromOffset(80, 24),
																AnchorPoint = Vector2.new(1, 0.5),
																Position = UDim2.new(1, -50, 0.5, 0),
																BackgroundColor3 = innerScope:Computed(function(use)
																	return use(isBinding) and Theme.Colors.AccentNeon
																		or Theme.Colors.Zinc800
																end),
																Text = innerScope:Computed(function(use)
																	return use(isBinding) and "..." or "EDIT"
																end),
																TextColor3 = innerScope:Computed(function(use)
																	return use(isBinding) and Theme.Colors.Zinc950
																		or Theme.Colors.Zinc100
																end),
																FontFace = Theme.Fonts.Body,
																TextSize = 11,
																[Fusion.OnEvent("Activated")] = function()
																	props.OnStartBinding(midi)
																end,
																[Fusion.Children] = {
																	innerScope:New("UICorner")({
																		CornerRadius = UDim.new(0, 4),
																	}),
																},
															}),
															innerScope:New("TextButton")({
																Size = UDim2.fromOffset(30, 24),
																AnchorPoint = Vector2.new(1, 0.5),
																Position = UDim2.new(1, -10, 0.5, 0),
																BackgroundColor3 = Theme.Colors.Zinc800,
																Text = "✕",
																TextColor3 = Theme.Colors.Zinc500,
																FontFace = Theme.Fonts.Body,
																TextSize = 10,
																[Fusion.OnEvent("Activated")] = function()
																	props.OnClearMapping(midi)
																end,
																[Fusion.Children] = {
																	innerScope:New("UICorner")({
																		CornerRadius = UDim.new(0, 4),
																	}),
																},
															}),
														},
													})
												end
											),
										},
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end
