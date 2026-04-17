--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local PianoState = require(ReplicatedStorage.Shared.PianoState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Icon")
local Icon = require(IconFolder)

local scope = Fusion.scoped(Fusion)

local icon = Icon.new()
	:setLabel("Piano Lock")
	:setCaption("Toggle Chat / Key Lock")
	:setLeft()

local function updateIconVisuals()
	local isLocked = Fusion.peek(PianoState.chatLocked)
	if isLocked then
		icon:setImage("rbxassetid://6031082533") -- lock
		icon:setLabel("Locked")
		if not icon.isSelected then
			icon:select()
		end
	else
		icon:setImage("rbxassetid://6026568220") -- unlock
		icon:setLabel("Unlocked")
		if icon.isSelected then
			icon:deselect()
		end
	end
end

icon.selected:Connect(function()
	PianoState.chatLocked:set(true)
end)

icon.deselected:Connect(function()
	PianoState.chatLocked:set(false)
end)


scope:Observer(PianoState.chatLocked):onChange(function()
	local isLocked = Fusion.peek(PianoState.chatLocked)
	
	updateIconVisuals()

	task.spawn(function()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not isLocked)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, not isLocked)
		end)
	end)
end)

scope:Observer(PianoState.activePiano):onChange(function()
	local isSeated = Fusion.peek(PianoState.activePiano) ~= nil
	if isSeated then
		PianoState.chatLocked:set(true)
		icon:setEnabled(true)
	else
		PianoState.chatLocked:set(false)
		icon:setEnabled(false)
	end
end)

updateIconVisuals()
icon:setEnabled(Fusion.peek(PianoState.activePiano) ~= nil)
if Fusion.peek(PianoState.activePiano) then
	PianoState.chatLocked:set(true)
end
