-->> Services
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

-->> Constants
local MatchesRunning = MemoryStoreService:GetSortedMap("Matches")
local Signal = require(ReplicatedStorage.lib.Signal)
local Gamemodes = require(ReplicatedStorage.store.gamemodes)
local TestingEnviorment = game["Run Service"]:IsStudio()


-->> Events
local PlayerEntered = Signal()
local PlayerLeft = Signal()

local MatchService = {}
MatchService.playerEntered = PlayerEntered
MatchService.playerLeft = PlayerLeft
MatchService.pads = {}

type PadData = {
	inPad: {Player},
	creator: number,
	maxPlayers: number,
	currentPlayers: number,
	gamemode: keyof<Gamemodes>,
}

local function serializeData(data: PadData)
	
end

local function entered(player: Player, data: {any})
	PlayerEntered:Fire(data)
	ReplicatedStorage.relay.match.entered:FireClient(player, data.creator == player.UserId, data)
end

local function exited(player: Player)
	PlayerLeft:Fire()
	ReplicatedStorage.relay.match.exited:FireClient(player)
end

function MatchService:start()
	self.pads = {}
	self:_SetupEvents()
	self:SetupPads()
end

function MatchService:InPad(Player:Player, Pad:Model)
	local padData: PadData = self.pads[Pad]
	if not padData then 
		return false
	end
	return table.find(padData.inPad, Player.UserId)
end

function MatchService:SetupPads()
	self.pads = {}
	for _, padModel in CollectionService:GetTagged("Pad") do 
		self.pads[padModel] = {
			inPad = {}, 
			creator = 0, 
			maxPlayers = 0,
			currentPlayers = 0,
			time = 0,
			gamemode = Gamemodes.Normal, 
			padObject = padModel, 
			Blacklist = {}
		} :: PadData
		self.pads[padModel].padObject = padModel
		task.defer(function()
			print(padModel)
			self:_queryPad(padModel, self.pads[padModel])
		end)
	end
end
function MatchService:_SetupEvents()
	ReplicatedStorage.relay.match.update.OnServerEvent:Connect(function(Player, Pad, Diff)
		if self:InPad(Player, Pad) then 
			self:UpdatePad(Pad,Diff, Player)
			self:_BegincountDown(Pad)
		end
	end)
end

function MatchService:UpdatePad(pad:Model, Diff: {any}?, Player:Player?)
	local padData: PadData = self.pads[pad] 
	if not padData then 
		return
	end
	if Player and padData.Locked or Player and Player.UserId ~= padData.creator then 
		return
	end
	for k, v in Diff do
		padData[k] = v
	end
	
	local Status = pad.StatusBox.Contents.Holder
	local Gamemode = padData.gamemode
	local PlayerCount = padData.currentPlayers
	local MaxPlayers = padData.maxPlayers
	Status.Gamemode.Text = Gamemode.Display
	Status.Players.Text = `PLAYERS: {PlayerCount}/{MaxPlayers}`

	for _, id in padData.Blacklist do 
		local Player = Players:GetPlayerByUserId(id)
		if not Player then 
			continue
		end
		self:_removePlayer(Player, pad)
	end
end


-->> PRIVATE

function MatchService:_BegincountDown(pad:Model)
	local padData: PadData = self.pads[pad]
	if not padData or padData.Countdown then 
		return
	end
	padData.Countdown = true 
	local Count = 15
	while padData.Countdown and Count > 0 do 
		Count -= 1
		pad.StatusBox.Contents.Holder.Count.Text = `{Count}s`
		task.wait(1)
	end
	pad.StatusBox.Contents.Holder.Count.Text = ""
	if not padData.Countdown then 
		return
	end
	--local Newserver = TeleportService:ReserveServer(padData.gamemode.ID)
	--for _, id in padData.inPad do 
	--	task.defer(function()
	--		TeleportService:TeleportToPrivateServer(
	--			padData.gamemode.ID, 
	--			Newserver, 
	--			{Players:GetPlayerByUserId(id)}
	--		)
	--	end)
	--end
	self:_CleanPad(pad)
end

function MatchService:_CleanPad(pad)
	local padData:PadData = self.pads[pad]
	if not padData then 
		warn(`Invalid padData for: `, pad)
		return
	end
	padData.Countdown = false
	for _, id in padData.inPad do 
		local Player = Players:GetPlayerByUserId(id)
		if Player then 
			self:_removePlayer(Player, pad)
		end
	end
	padData.Blacklist = {}
	padData.inPad = {}
	padData.maxPlayers = 1
	padData.currentPlayers = 0
	padData.gamemode = Gamemodes.Normal
	padData.creator = 0 
	self:UpdatePad(pad, padData)
end

function MatchService:_insertPlayer(player: Player, pad: Model)
	local padData: PadData = self.pads[pad]
	
	if padData.currentPlayers + 1 > padData.maxPlayers and padData.creator ~= 0 then
		player.Character.HumanoidRootPart.CFrame = pad.Rejected.CFrame
		return
	end
	if table.find(padData.Blacklist, player.UserId) then 
		return
	end
	
	if padData.creator == 0 then 
		padData.creator = player.UserId
		padData.creatorInstance = player
		padData.maxPlayers = 1
	end
	table.insert(padData.inPad, player.UserId)
	padData.currentPlayers += 1
	player:SetAttribute("InPad", true)
	self:UpdatePad(pad, padData)
	entered(player, padData)
	task.defer(function()
		while not player.Parent do 
			self:_removePlayer(player, pad)
			return
		end
	end)
	if player.UserId ~= padData.creator then 
		ReplicatedStorage.relay.match.update:FireClient(
			padData.creatorInstance, 
			true, 
			padData
		)
	end
end



function MatchService:_removePlayer(player: Player, pad: Model)
	
	local padData: PadData = self.pads[pad]
	if not table.find(padData.inPad, player.UserId) then 
		return
	end
	player:SetAttribute("InPad", false)
	table.remove(
		padData.inPad, 
		table.find(padData.inPad, player.UserId)
	)
	padData.currentPlayers -= 1
	player.Character.HumanoidRootPart.CFrame = pad.Rejected.CFrame
	self:UpdatePad(pad, padData)
	exited(player)
	if padData.currentPlayers <= 0 then 
		self:_CleanPad(pad)
	end
end

function MatchService:_queryPad(pad: Model, padData:PadData)
	while true do 
		local hitbox: BasePart = pad.Hitbox
		local Touchingparts = workspace:GetPartsInPart(hitbox)
		local TouchingCharacters = {}
		for _, part in Touchingparts do
			local Player = Players:GetPlayerFromCharacter(part.Parent) 
			if not Player then 
				continue
			end
			table.insert(TouchingCharacters, part.Parent)

			if (not Player:GetAttribute("InPad") and not table.find(padData.inPad, Player.UserId)) then 
				self:_insertPlayer(Player, pad)
			end
		end 
		for _, userId in padData.inPad do 
			local Player = Players:GetPlayerByUserId(userId) 
			if not Player then 
				continue
			end
			if not table.find(TouchingCharacters, Player.Character) and table.find(padData.inPad, Player.UserId)  then 
				warn(padData.inPad)
				self:_removePlayer(Player, pad)
				warn(`Left:`, pad)
			end
		end
		task.wait()
	end
end

return MatchService
