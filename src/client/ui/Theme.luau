local Theme = {
	Colors = {
		Zinc950 = Color3.fromHex("#09090b"),
		Zinc900 = Color3.fromHex("#18181b"),
		Zinc800 = Color3.fromHex("#27272a"),
		Zinc700 = Color3.fromHex("#3f3f46"),
		Zinc600 = Color3.fromHex("#52525b"),
		Zinc500 = Color3.fromHex("#71717a"),
		Zinc400 = Color3.fromHex("#a1a1aa"),
		Zinc100 = Color3.fromHex("#f4f4f5"),

		AccentNeon = Color3.fromHex("#0ea5e9"),
		AccentGlow = Color3.fromHex("#0284c7"),

		WhiteKey = Color3.fromHex("#ffffff"),
		WhiteKeyGrad = Color3.fromHex("#e5e5e7"),
		BlackKey = Color3.fromHex("#18181b"),
		BlackKeyGrad = Color3.fromHex("#000000"),

		SustainActive = Color3.fromHex("#10b981"),
	},

	Fonts = {
		Heading = Font.fromName("Montserrat", Enum.FontWeight.Bold),
		Body = Font.fromName("Montserrat", Enum.FontWeight.Medium),
		KeyLabel = Font.fromName("Montserrat", Enum.FontWeight.SemiBold),
	},

	Springs = {
		Standard = { damping = 1, speed = 10 },
		Snappy = { damping = 1, speed = 30 },
		Smooth = { damping = 1, speed = 5 },
	},

	Layout = {
		KeyWidth = 28,
		KeyHeight = 140,
		BlackKeyWidth = 18,
		BlackKeyHeight = 85,
		Padding = 1,
	},
}

return Theme
