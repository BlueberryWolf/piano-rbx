local NoteUtils = {}

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

function NoteUtils.getNoteName(midi: number): string
	local octave = math.floor(midi / 12) - 1
	return NOTE_NAMES[(midi % 12) + 1] .. tostring(octave)
end

return NoteUtils
