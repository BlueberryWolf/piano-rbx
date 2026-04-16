local KeyConfig = {
	Presets = {
		FL = {
			[Enum.KeyCode.Z] = 60,
			[Enum.KeyCode.X] = 62,
			[Enum.KeyCode.C] = 64,
			[Enum.KeyCode.V] = 65,
			[Enum.KeyCode.B] = 67,
			[Enum.KeyCode.N] = 69,
			[Enum.KeyCode.M] = 71,
			[Enum.KeyCode.Comma] = 72,
			[Enum.KeyCode.Period] = 74,
			[Enum.KeyCode.Slash] = 76,
			[Enum.KeyCode.Q] = 72,
			[Enum.KeyCode.W] = 74,
			[Enum.KeyCode.E] = 76,
			[Enum.KeyCode.R] = 77,
			[Enum.KeyCode.T] = 79,
			[Enum.KeyCode.Y] = 81,
			[Enum.KeyCode.U] = 83,
			[Enum.KeyCode.I] = 84,
			[Enum.KeyCode.O] = 86,
			[Enum.KeyCode.P] = 88,
			[Enum.KeyCode.LeftBracket] = 89,
			[Enum.KeyCode.RightBracket] = 91,

			[Enum.KeyCode.S] = 61,
			[Enum.KeyCode.D] = 63,
			[Enum.KeyCode.G] = 66,
			[Enum.KeyCode.H] = 68,
			[Enum.KeyCode.J] = 70,
			[Enum.KeyCode.L] = 73,
			[Enum.KeyCode.Semicolon] = 75,
			[Enum.KeyCode.Two] = 73,
			[Enum.KeyCode.Three] = 75,
			[Enum.KeyCode.Five] = 78,
			[Enum.KeyCode.Six] = 80,
			[Enum.KeyCode.Seven] = 82,
			[Enum.KeyCode.Nine] = 85,
			[Enum.KeyCode.Zero] = 87,
			[Enum.KeyCode.Equals] = 90,
		},

		VirtualPiano = {
			[Enum.KeyCode.One] = 48,
			[Enum.KeyCode.Two] = 50,
			[Enum.KeyCode.Three] = 52,
			[Enum.KeyCode.Four] = 53,
			[Enum.KeyCode.Five] = 55,
			[Enum.KeyCode.Six] = 57,
			[Enum.KeyCode.Seven] = 59,
			[Enum.KeyCode.Eight] = 60,
			[Enum.KeyCode.Nine] = 62,
			[Enum.KeyCode.Zero] = 64,

			[Enum.KeyCode.Q] = 65,
			[Enum.KeyCode.W] = 67,
			[Enum.KeyCode.E] = 69,
			[Enum.KeyCode.R] = 71,
			[Enum.KeyCode.T] = 72,
			[Enum.KeyCode.Y] = 74,
			[Enum.KeyCode.U] = 76,
			[Enum.KeyCode.I] = 77,
			[Enum.KeyCode.O] = 79,
			[Enum.KeyCode.P] = 81,

			[Enum.KeyCode.A] = 83,
			[Enum.KeyCode.S] = 84,
			[Enum.KeyCode.D] = 86,
			[Enum.KeyCode.F] = 88,
			[Enum.KeyCode.G] = 89,
			[Enum.KeyCode.H] = 91,
			[Enum.KeyCode.J] = 93,
			[Enum.KeyCode.K] = 95,
			[Enum.KeyCode.L] = 96,

			[Enum.KeyCode.Z] = 98,
			[Enum.KeyCode.X] = 100,
			[Enum.KeyCode.C] = 101,
			[Enum.KeyCode.V] = 103,
			[Enum.KeyCode.B] = 105,
			[Enum.KeyCode.N] = 107,
			[Enum.KeyCode.M] = 108,
		},
	},

	ShiftNames = {
		[Enum.KeyCode.One] = "!",
		[Enum.KeyCode.Two] = "@",
		[Enum.KeyCode.Three] = "#",
		[Enum.KeyCode.Four] = "$",
		[Enum.KeyCode.Five] = "%",
		[Enum.KeyCode.Six] = "^",
		[Enum.KeyCode.Seven] = "&",
		[Enum.KeyCode.Eight] = "*",
		[Enum.KeyCode.Nine] = "(",
		[Enum.KeyCode.Zero] = ")",
		[Enum.KeyCode.Equals] = "+",
	},

	ShortNames = {
		[Enum.KeyCode.Comma] = ",",
		[Enum.KeyCode.Period] = ".",
		[Enum.KeyCode.Slash] = "/",
		[Enum.KeyCode.Semicolon] = ";",
		[Enum.KeyCode.LeftBracket] = "[",
		[Enum.KeyCode.RightBracket] = "]",
		[Enum.KeyCode.One] = "1",
		[Enum.KeyCode.Two] = "2",
		[Enum.KeyCode.Three] = "3",
		[Enum.KeyCode.Four] = "4",
		[Enum.KeyCode.Five] = "5",
		[Enum.KeyCode.Six] = "6",
		[Enum.KeyCode.Seven] = "7",
		[Enum.KeyCode.Eight] = "8",
		[Enum.KeyCode.Nine] = "9",
		[Enum.KeyCode.Zero] = "0",
		[Enum.KeyCode.Equals] = "=",
	},
}

function KeyConfig.getShortName(keyCode: Enum.KeyCode, isShift: boolean?): string
	if isShift then
		local shiftSym = KeyConfig.ShiftNames[keyCode]
		if shiftSym then
			return shiftSym
		end
		return (KeyConfig.ShortNames[keyCode] or keyCode.Name):upper()
	end

	return (KeyConfig.ShortNames[keyCode] or keyCode.Name):lower()
end

function KeyConfig.getNote(keyCode: Enum.KeyCode, isShiftDown: boolean, layout: string): number?
	local preset = KeyConfig.Presets[layout] or KeyConfig.Presets.FL
	local midi = preset[keyCode]

	if midi and layout == "VirtualPiano" and isShiftDown then
		local mod = midi % 12
		-- C, D, F, G, A have sharps
		local hasSharp = (mod == 0 or mod == 2 or mod == 5 or mod == 7 or mod == 9)
		if hasSharp then
			return midi + 1
		end
	end

	return midi
end

return KeyConfig
