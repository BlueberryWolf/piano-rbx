local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rootBlink = ReplicatedStorage:FindFirstChild("Blink")

if rootBlink then
	return require(rootBlink)
end

local Stub = {}
Stub.Buffer = {
	new = function()
		return {
			writeUInt32 = function() end,
			writeUInt8 = function() end,
			writeUInt16 = function() end,
			writeBool = function() end,
		}
	end,
	Reader = {
		new = function()
			return {
				readUInt32 = function()
					return 0
				end,
				readUInt8 = function()
					return 0
				end,
				readUInt16 = function()
					return 0
				end,
				readBool = function()
					return false
				end,
			}
		end,
	},
}

Stub.Network = {
	SendUnreliable = function() end,
}

Stub.Server = {
	BindUnreliable = function() end,
	SendUnreliable = function() end,
}

return Stub
