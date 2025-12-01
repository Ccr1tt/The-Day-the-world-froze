--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MatchService = {}

type MatchInfo = {
	active: boolean,
	time: number?,

	creator: Player?,
	players: {[Player]: boolean},
	metadata: {any} & {
		maxPlayers: number?
	}
}

local function getPlayerFromHit(hit: BasePart): Player?
	return hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
end

local function canMakeMatch(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return true
end

local function newZone(): MatchInfo
	return {
		active = false,
		time = nil,
		creator = nil,
		players = {},
		metadata = {}
	}
end

function MatchService:init()
	local function onPlayerAdded(player: Player)
		player.CharacterRemoving:Connect(function()
			if player:GetAttribute("Matchmaking") then
				self:RemovePlayerFromMatch(player)
			end
		end)
		player:SetAttribute("Matchmaking", false)
	end
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute("Matchmaking") then
			self:RemovePlayerFromMatch(player)
		end
	end)
end

function MatchService:start()
	self.zones = {}
	self:Track()
end

function MatchService:Track()
	for index, zone: BasePart in CollectionService:GetTagged("MatchPad") do
		zone.Touched:Connect(function(hit: BasePart)
			local player = getPlayerFromHit(hit)
			if player and not player:GetAttribute("Matchmaking") and canMakeMatch(player) then
				self:AddPlayer(player, zone)
			end
		end)
		zone.TouchEnded:Connect(function(hit: BasePart)
			local player = getPlayerFromHit(hit)
			if player and player:GetAttribute("Matchmaking") and canMakeMatch(player) then
				self:RemovePlayer(player, zone)
			end
		end)
		self.zones[zone] = newZone()
	end
end

function MatchService:RemovePlayerFromMatch(player: Player)
	return self:RemovePlayer(player, self:GetPlayerZone(player))
end

function MatchService:GetPlayerZone(player: Player): BasePart?
	if not player:GetAttribute("Matchmaking") then
		return
	end
	
	for zone: BasePart, info: MatchInfo in self.zones do
		if info.players[player] then
			return zone
		end
	end
	return nil
end

function MatchService:AddPlayer(player: Player, zone: BasePart)
	local zoneInfo: MatchInfo = self.zones[zone]
	player:SetAttribute("Matchmaking", true)
	
	if not zoneInfo.active then
		zoneInfo.active = true
		zoneInfo.creator = player
		zoneInfo.time = 20
	end
	zoneInfo.players[player] = true
end

function MatchService:RemovePlayer(player: Player, zone: BasePart)
	local zoneInfo: MatchInfo = self.zones[zone]
	player:SetAttribute("Matchmaking", false)
	
	zoneInfo.players[player] = nil
	if next(zoneInfo.players) == nil then
		self:CleanZone(zone)
	end
end

function MatchService:CleanZone(zone: BasePart)
	self.zones[zone] = newZone()
end

return MatchService