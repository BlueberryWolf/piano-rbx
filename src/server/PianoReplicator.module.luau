local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BlinkServer = require(ReplicatedStorage.Shared.PianoSchemaServer)

local PianoReplicator = {}

local playerVoices = {}
local MAX_POLYPHONY = 128
local MAX_TIMESTAMP_OFFSET = 255
local MIN_NOTE_ID = 21
local MAX_NOTE_ID = 108

local function sanitize(event)
	if event.NoteId ~= 0 and (event.NoteId < MIN_NOTE_ID or event.NoteId > MAX_NOTE_ID) then
		return false
	end
	if event.TimestampOffset > MAX_TIMESTAMP_OFFSET then
		return false
	end
	return true
end

function PianoReplicator.init()
	BlinkServer.SendNoteBatch.On(function(player, batch)
		local userId = player.UserId
		playerVoices[userId] = playerVoices[userId] or { count = 0, active = {} }
		local voiceData = playerVoices[userId]

		local sanitized = {}

		for _, event in ipairs(batch.Events) do
			if not sanitize(event) then
				continue
			end

			if event.NoteId ~= 0 then
				if event.IsPressed then
					if voiceData.count >= MAX_POLYPHONY then
						continue
					end
					if not voiceData.active[event.NoteId] then
						voiceData.count += 1
						voiceData.active[event.NoteId] = true
					end
				else
					if voiceData.active[event.NoteId] then
						voiceData.count -= 1
						voiceData.active[event.NoteId] = nil
					end
				end
			end

			table.insert(sanitized, event)
		end

		if #sanitized > 0 then
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer == player then
					continue
				end
				BlinkServer.RecvNoteBatch.Fire(otherPlayer, {
					UserId = userId,
					Batch = {
						FrameNumber = batch.FrameNumber,
						Events = sanitized,
						SoundfontId = batch.SoundfontId,
						Piano = batch.Piano,
					},
				})
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	playerVoices[player.UserId] = nil
end)

return PianoReplicator
