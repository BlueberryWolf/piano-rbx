local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local UILabs = require(ReplicatedStorage.Packages.UILabs)

local VoiceProvider = {}

type Voice = {
	Instance: Sound,
	NoteId: number,
	Active: boolean,
	Fading: boolean,
	Tween: Tween?,
}

local voicePool: { Voice } = {}
local activeVoices: { [number]: { [number]: { Voice } } } = {}
local soundContainer: Instance? = nil
local MAX_VOICES = 128

local pianoSoundGroups: { [Instance]: SoundGroup } = {}
VoiceProvider.PianoSoundGroups = pianoSoundGroups

local function velocityToVolume(velocity: number): number
	return math.pow(velocity / 127, 2)
end

local function getSoundContainer(): Instance
	if soundContainer then
		return soundContainer
	end

	if RunService:IsRunning() then
		soundContainer = SoundService
		return soundContainer :: any
	else
		local soundFolder = Instance.new("Folder")
		soundFolder.Name = "VoiceProvider_Sounds"
		soundFolder.Parent = UILabs.Environment.PluginWidget
		UILabs.Environment.GetJanitor():Add(soundFolder)
		soundContainer = soundFolder
		return soundFolder
	end
end

local function getSoundGroup(pianoInstance: Instance?): SoundGroup?
	if not pianoInstance then
		return nil
	end

	local existing = pianoSoundGroups[pianoInstance]
	if existing then
		return existing
	end

	local sg = Instance.new("SoundGroup")
	sg.Name = "Piano_" .. pianoInstance.Name
	sg.Volume = 1
	sg.Parent = getSoundContainer()

	pianoSoundGroups[pianoInstance] = sg
	return sg
end

local function ensureSoundLoaded(sound: Sound)
	if sound.IsLoaded then
		return
	end
	pcall(function()
		(sound :: any):LoadAsync()
	end)
end

local masterCache: { [string]: Sound } = {}

function VoiceProvider.init(preloads: { string }?)
	local root = Instance.new("Folder")
	root.Name = "LegacyVoicePool"
	root.Parent = getSoundContainer()

	local cache = Instance.new("Folder")
	cache.Name = "LegacyVoicePool_Cache"
	cache.Parent = getSoundContainer()

	for i = 1, MAX_VOICES do
		local sound = Instance.new("Sound")
		sound.Name = "WildcardSound_" .. i
		sound.Parent = root

		table.insert(voicePool, {
			Instance = sound,
			NoteId = -1,
			Active = false,
			Fading = false,
			Tween = nil,
		})
	end

	if preloads then
		VoiceProvider.preload(preloads)
	end
end

function VoiceProvider.preload(assetIds: { string }, onComplete: (() -> ())?)
	task.spawn(function()
		local cacheFolder = getSoundContainer():FindFirstChild("LegacyVoicePool_Cache")
		local newInstances = {}

		for _, id in ipairs(assetIds) do
			if not id or id == "" or masterCache[id] then
				continue
			end

			local s = Instance.new("Sound")
			s.SoundId = id
			s.Name = "Cache_" .. id:gsub("[^%d]", "")
			s.Parent = cacheFolder

			masterCache[id] = s
			table.insert(newInstances, s)
		end

		if #newInstances > 0 then
			ContentProvider:PreloadAsync(newInstances)
		end

		if onComplete then
			onComplete()
		end
	end)
end

function VoiceProvider.play(
	noteId: number,
	velocity: number,
	assetId: string,
	sourceId: number?,
	pianoInstance: Instance?
)
	sourceId = sourceId or 0

	if not activeVoices[sourceId :: number] then
		activeVoices[sourceId :: number] = {}
	end
	if not activeVoices[sourceId :: number][noteId] then
		activeVoices[sourceId :: number][noteId] = {}
	end

	local voice: Voice = nil
	for _, v in ipairs(voicePool) do
		if not v.Active and not v.Fading then
			voice = v
			break
		end
	end

	if not voice then
		voice = table.remove(voicePool, 1) :: Voice
		VoiceProvider.stopVoice(voice :: any, 0.1)
		table.insert(voicePool, voice :: any)
	end

	if voice.Tween then
		voice.Tween:Cancel()
		voice.Tween = nil
	end

	voice.Active = true
	voice.Fading = false
	voice.NoteId = noteId

	if voice.Instance.SoundId ~= assetId then
		voice.Instance.SoundId = assetId
	end

	voice.Instance.SoundGroup = getSoundGroup(pianoInstance)

	ensureSoundLoaded(voice.Instance)
	voice.Instance.Volume = velocityToVolume(velocity)
	voice.Instance.TimePosition = 0
	voice.Instance:Play()

	table.insert(activeVoices[sourceId :: number][noteId], voice)
end

function VoiceProvider.stop(noteId: number, sourceId: number?, fadeTime: number?)
	sourceId = sourceId or 0
	local voices = activeVoices[sourceId :: number] and activeVoices[sourceId :: number][noteId]
	if not voices then
		return
	end

	for _, voice in ipairs(voices) do
		VoiceProvider.stopVoice(voice, fadeTime or 3.0)
	end

	table.clear(activeVoices[sourceId :: number][noteId])
end

function VoiceProvider.stopVoice(voice: Voice, fadeTime: number)
	if not voice.Active or voice.Fading then
		return
	end
	voice.Active = false
	voice.Fading = true

	local tween = TweenService:Create(
		voice.Instance,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ Volume = 0 }
	)
	voice.Tween = tween

	task.spawn(function()
		tween:Play()
		tween.Completed:Wait()

		if voice.Fading and voice.Tween == tween then
			voice.Instance:Stop()
			voice.Fading = false
			voice.Tween = nil
		end
	end)
end

function VoiceProvider.stopAll()
	for _, notes in pairs(activeVoices) do
		for _, voices in pairs(notes) do
			for _, voice in ipairs(voices) do
				VoiceProvider.stopVoice(voice, 0.3)
			end
			table.clear(voices)
		end
	end
end

return VoiceProvider
