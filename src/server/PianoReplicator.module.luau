local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BlinkServer = require(ReplicatedStorage.Shared.PianoSchemaServer)

local PianoReplicator = {}

local playerVoices = {}
local MAX_POLYPHONY = 128
local FRAME_DURATION = 1 / 60
local SERVER_START = workspace:GetServerTimeNow()

local ENABLE_JITTER_BUFFER = true

local MIN_NOTE_ID = 21
local MAX_NOTE_ID = 108
local MAX_TIMESTAMP_OFFSET = 1000

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

		task.desynchronize()

		local eventsToPlay = {}
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

			local playTime = SERVER_START + (batch.FrameNumber * FRAME_DURATION) + (event.TimestampOffset / 1000)

			table.insert(eventsToPlay, {
				Time = playTime,
				Data = event,
			})
		end

		task.synchronize()

		for _, packet in ipairs(eventsToPlay) do
			local delayTime = 0
			if ENABLE_JITTER_BUFFER then
				delayTime = packet.Time - workspace:GetServerTimeNow()
				if delayTime < 0 then
					delayTime = 0
				end
				if delayTime > 0.5 then
					continue
				end
			end

			local function fire()
				for _, otherPlayer in ipairs(Players:GetPlayers()) do
					if otherPlayer ~= player then
						BlinkServer.RecvNoteBatch.Fire(otherPlayer, {
							UserId = player.UserId,
							Batch = {
								FrameNumber = batch.FrameNumber,
								Events = { packet.Data },
								SoundfontId = batch.SoundfontId,
								Piano = batch.Piano,
							},
						})
					end
				end
			end

			if delayTime > 0 then
				task.delay(delayTime, fire)
			else
				fire()
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	playerVoices[player.UserId] = nil
end)

return PianoReplicator
