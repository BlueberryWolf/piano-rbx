local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VoiceProvider = {}

type Voice = {
	Instance: Sound,
	NoteId: number,
	Active: boolean,
	Fading: boolean,
	Tween: Tween?,
}

local wildcardPool: { Voice } = {}
local activeVoices: { [number]: { [number]: { Voice } } } = {}
local persistentVoices: { [number]: { [number]: { Voice } } } = {}
local pianoSoundGroups: { [Instance]: SoundGroup } = {}
local soundContainer: Instance? = nil

VoiceProvider.PianoSoundGroups = pianoSoundGroups

local MAX_WILDCARDS = 64
local MIN_MIDI = 21
local MAX_MIDI = 108

local function velocityToVolume(velocity: number): number
	return math.pow(velocity / 127, 2)
end

local function getSoundContainer(): Instance
	if soundContainer then
		return soundContainer
	end

	local container: Instance
	if RunService:IsRunning() then
		container = SoundService
	else
		local UILabs = require(ReplicatedStorage.Packages.UILabs)
		local soundFolder = Instance.new("Folder")
		soundFolder.Name = "VoiceProvider_Sounds"
		soundFolder.Parent = UILabs.Environment.PluginWidget
		UILabs.Environment.GetJanitor():Add(soundFolder)
		container = soundFolder
	end

	soundContainer = container
	return container
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

function VoiceProvider.init(initialAssets: { [string]: string }?)
	local container = getSoundContainer()
	local root = container:FindFirstChild("LegacyVoicePool") or Instance.new("Folder")
	root.Name = "LegacyVoicePool"
	root.Parent = container

	local cache = container:FindFirstChild("LegacyVoicePool_Cache") or Instance.new("Folder")
	cache.Name = "LegacyVoicePool_Cache"
	cache.Parent = container

	persistentVoices[0] = {}
	for midi = MIN_MIDI, MAX_MIDI do
		local voices = {}
		for i = 1, 2 do
			local sound = Instance.new("Sound")
			sound.Name = "Voice_" .. midi .. "_" .. i
			sound.Parent = root

			local voice = {
				Instance = sound,
				NoteId = midi,
				Active = false,
				Fading = false,
				Tween = nil,
			}
			table.insert(voices, voice)
		end
		persistentVoices[0][midi] = voices
	end

	for i = 1, MAX_WILDCARDS do
		local sound = Instance.new("Sound")
		sound.Name = "Wildcard_" .. i
		sound.Parent = root

		table.insert(wildcardPool, {
			Instance = sound,
			NoteId = -1,
			Active = false,
			Fading = false,
			Tween = nil,
		})
	end

	if initialAssets then
		VoiceProvider.updatePersistentFonts(0, initialAssets)
	end
end

function VoiceProvider.updatePersistentFonts(sourceId: number, assets: { [string]: string })
	local playerVoices = persistentVoices[sourceId]
	if not playerVoices then
		return
	end

	local toPreload = {}
	for midi = MIN_MIDI, MAX_MIDI do
		local voices = playerVoices[midi]
		local noteName = require(ReplicatedStorage.Shared.NoteUtils).getNoteName(midi)
		local id = assets[noteName]
		if id then
			table.insert(toPreload, id)
			for _, voice in ipairs(voices) do
				if voice.Instance.SoundId ~= id then
					voice.Instance.SoundId = id
				end
			end
		end
	end

	if #toPreload > 0 then
		VoiceProvider.preload(toPreload)
	end
end

function VoiceProvider.preload(assetIds: { string }, onComplete: (() -> ())?)
	task.spawn(function()
		local container = getSoundContainer()
		local cacheFolder = container:FindFirstChild("LegacyVoicePool_Cache")
		local newInstances = {}

		for _, id in ipairs(assetIds) do
			if not id or id == "" then
				continue
			end
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Parent = cacheFolder
			table.insert(newInstances, s)
		end

		if #newInstances > 0 then
			ContentProvider:PreloadAsync(newInstances)
			for _, s in ipairs(newInstances) do
				s:Destroy()
			end
		end

		if onComplete then
			onComplete()
		end
	end)
end

local persistentToggle: { [number]: number } = {}

function VoiceProvider.play(
	midi: number,
	velocity: number,
	assetId: string,
	sourceId: number?,
	pianoInstance: Instance?
)
	local sid = sourceId or 0

	local voice: Voice? = nil

	if sid == 0 and persistentVoices[0] and persistentVoices[0][midi] then
		local voices = persistentVoices[0][midi]
		persistentToggle[midi] = if persistentToggle[midi] == 1 then 2 else 1
		local selectedMode = persistentToggle[midi]
		voice = voices[selectedMode]

		if voice then
			if voice.Active or voice.Fading then
				VoiceProvider.stopVoice(voice, 0.05)
			end
		end
	end

	if not voice then
		for _, v in ipairs(wildcardPool) do
			if not v.Active and not v.Fading then
				voice = v
				break
			end
		end
	end

	if not voice then
		local stolen = table.remove(wildcardPool, 1)
		if stolen then
			VoiceProvider.stopVoice(stolen, 0.1)
			voice = stolen
			table.insert(wildcardPool, stolen)
		end
	end

	if not voice then
		return
	end
	local v: Voice = voice

	if v.Tween then
		v.Tween:Cancel()
		v.Tween = nil
	end

	v.Active = true
	v.Fading = false
	v.NoteId = midi

	if v.Instance.SoundId ~= assetId then
		v.Instance.SoundId = assetId
	end

	v.Instance.Volume = velocityToVolume(velocity)
	v.Instance.TimePosition = 0
	v.Instance.SoundGroup = getSoundGroup(pianoInstance)
	v.Instance:Play()

	activeVoices[sid] = activeVoices[sid] or {}
	activeVoices[sid][midi] = activeVoices[sid][midi] or {}
	table.insert(activeVoices[sid][midi], v)
end

function VoiceProvider.stop(midi: number, sourceId: number?, fadeTime: number?)
	local sid = sourceId or 0
	local pool = activeVoices[sid] and activeVoices[sid][midi]
	if not pool then
		return
	end

	for _, voice in ipairs(pool) do
		VoiceProvider.stopVoice(voice, fadeTime or 2.0)
	end
	table.clear(activeVoices[sid][midi])
end

function VoiceProvider.stopVoice(voice: Voice, fadeTime: number)
	if not voice.Active or voice.Fading then
		return
	end
	voice.Active = false
	voice.Fading = true

	local tween = TweenService:Create(voice.Instance, TweenInfo.new(fadeTime, Enum.EasingStyle.Cubic), { Volume = 0 })
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
		for _, vlist in pairs(notes) do
			for _, v in ipairs(vlist) do
				VoiceProvider.stopVoice(v, 0.2)
			end
			table.clear(vlist)
		end
	end
	table.clear(activeVoices)
end

return VoiceProvider
