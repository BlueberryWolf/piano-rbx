local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local KeyConfig = require(ReplicatedStorage.Shared.KeyConfig)

local scope = Fusion.scoped(Fusion)

local PianoState = {
	scope = scope,

	pressedKeys = scope:Value({} :: { [number]: boolean }),
	sustainActive = scope:Value(false),
	currentSoundfontIndex = scope:Value(1),
	currentSoundfontName = scope:Value(SoundFonts.Fonts[1].Name),
	currentLayout = scope:Value("FL"),
	customMapping = scope:Value(KeyConfig.Presets.FL),
	bindingMidi = scope:Value(nil :: number?),
	activePiano = scope:Value(nil :: Instance?),
	isPreloading = scope:Value(false),

	settingsOpen = scope:Value(false),

	sustainToggle = false,
	sustainedNotes = {} :: { [number]: boolean },
	trackedNotes = {} :: { [Enum.KeyCode]: number },
}

return PianoState
