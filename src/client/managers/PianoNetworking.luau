--!native
--!optimize 2
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PianoState = require(ReplicatedStorage.Shared.PianoState)
local VoiceProvider = require(ReplicatedStorage.Shared.VoiceProvider)
local SoundFonts = require(ReplicatedStorage.Shared.SoundFonts)
local BlinkClient = require(ReplicatedStorage.Shared.PianoSchemaClient)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local PianoNetworking = {}

local eventQueue = {}
local batchStartTime = 0
local currentFrame = 0

type RemoteState = {
	sustainActive: boolean,
	sustainedNotes: { [number]: boolean },
	baseRemoteTime: number?,
	baseLocalTime: number?,
}
local remotePlayerStates: { [number]: RemoteState } = {}

local function getRemoteState(userId: number): RemoteState
	if not remotePlayerStates[userId] then
		remotePlayerStates[userId] = {
			sustainActive = false,
			sustainedNotes = {},
			baseRemoteTime = nil,
			baseLocalTime = nil,
		}
	end
	return remotePlayerStates[userId]
end

local function getAssetForNote(midi: number, soundfontIndex: number?): string?
	local index = soundfontIndex or Fusion.peek(PianoState.currentSoundfontIndex)
	return SoundFonts.getAssetForNote(midi, index)
end

function PianoNetworking.queueEvent(noteId: number, velocity: number, isPressed: boolean)
	local now = os.clock()
	if #eventQueue == 0 then
		batchStartTime = now
	end

	local offset = math.floor((now - batchStartTime) * 1000)

	table.insert(eventQueue, {
		NoteId = noteId,
		Velocity = velocity,
		IsPressed = isPressed,
		TimestampOffset = math.clamp(offset, 0, 255),
	})
end

function PianoNetworking.init()
	RunService.Heartbeat:Connect(function()
		currentFrame += 1
		if #eventQueue > 0 then
			BlinkClient.SendNoteBatch.Fire({
				FrameNumber = currentFrame,
				SentAt = os.clock(),
				Events = eventQueue,
				SoundfontId = Fusion.peek(PianoState.currentSoundfontIndex),
				Piano = Fusion.peek(PianoState.activePiano),
			})
			table.clear(eventQueue)
			batchStartTime = 0
		end
	end)

	BlinkClient.RecvNoteBatch.On(function(data)
		if data.UserId == Players.LocalPlayer.UserId then
			return
		end
		local userId = data.UserId
		local batch = data.Batch
		local remoteState = getRemoteState(userId)

		local now = os.clock()
		local bufferLatency = Fusion.peek(PianoState.networkBufferLatency)

		if
			not remoteState.baseRemoteTime
			or math.abs((batch.SentAt - remoteState.baseRemoteTime) - (now - remoteState.baseLocalTime)) > 1.0
		then
			remoteState.baseRemoteTime = batch.SentAt
			remoteState.baseLocalTime = now + bufferLatency
		end

		local batchPlaybackTime = remoteState.baseLocalTime + (batch.SentAt - remoteState.baseRemoteTime)

		for _, event in ipairs(batch.Events) do
			local eventPlaybackTime = batchPlaybackTime + (event.TimestampOffset / 1000)
			local delay = math.max(0, eventPlaybackTime - now)

			task.delay(delay, function()
				if event.NoteId == 0 then
					local wasActive = remoteState.sustainActive
					remoteState.sustainActive = event.IsPressed
					if wasActive and not remoteState.sustainActive then
						for midi in pairs(remoteState.sustainedNotes) do
							VoiceProvider.stop(midi, userId, 0.5)
						end
						table.clear(remoteState.sustainedNotes)
					end
				elseif event.IsPressed then
					local assetId = getAssetForNote(event.NoteId, batch.SoundfontId)
					if assetId then
						VoiceProvider.play(event.NoteId, event.Velocity, assetId, userId, batch.Piano)
					end
				else
					if remoteState.sustainActive then
						remoteState.sustainedNotes[event.NoteId] = true
					else
						VoiceProvider.stop(event.NoteId, userId, 0.5)
					end
				end
			end)
		end
	end)
end

return PianoNetworking
