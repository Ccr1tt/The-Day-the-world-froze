--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local IndoorService = {}

type ZoneInfo = {
	zone: BasePart,
	players: {[Player]: boolean}
}

local function getPlayerFromHit(hit: BasePart): Player?
	return hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
end

function IndoorService:init()
	local function onPlayerAdded(player: Player)
		player.CharacterRemoving:Connect(function()
			if self:IsIndoors(player) then
				self:RemoveFromZones(player)
			end
		end)
		player:SetAttribute("IndoorCount", 0)
	end
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:RemoveFromZones(player)
	end)
end

function IndoorService:start()
	self.zones = {}
	self:Track()
	
	while true do
		task.wait(10)
		self:Clean()
	end
end

function IndoorService:Set(player: Player, index: number, state: boolean)
	local wasTracked = self:IsInZone(player, index)
	local current = player:GetAttribute("IndoorCount") or 0
	
	if state and not wasTracked then
		player:SetAttribute("IndoorCount", current + 1)
		self.zones[index].players[player] = true	
	elseif not state and wasTracked then
		player:SetAttribute("IndoorCount", math.max(0, current - 1))
		self.zones[index].players[player] = nil
	end
end

function IndoorService:IsInZone(player: Player, index: number): boolean
	return self.zones[index].players[player] == true
end

function IndoorService:_isTouchingZone(player: Player, index: number): boolean
	local character = player.Character
	if not character then
		return false
	end
	
	local zone = self.zones[index].zone
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params:AddToFilter(character)
	
	local curated = workspace:GetPartsInPart(zone, params)
	return #curated > 0
end

function IndoorService:IsIndoors(player: Player): boolean
	return (player:GetAttribute("IndoorCount") or 0) > 0
end

function IndoorService:Track()
	for index, zone in CollectionService:GetTagged("Indoors") :: {BasePart} do
		zone.Touched:Connect(function(hit: BasePart)
			local player = getPlayerFromHit(hit)
			if player and not self:IsInZone(player, index) then
				self:Set(player, index, true)
			end
		end)
		zone.TouchEnded:Connect(function(hit: BasePart)
			local player = getPlayerFromHit(hit)
			if player and self:IsInZone(player, index) then
				self:Set(player, index, false)
			end
		end)
		
		zone.Name = tostring(index)
		table.insert(self.zones, {zone = zone, players = {}})
	end
end

function IndoorService:RemoveFromZones(player: Player)
	local self = self :: typeof(IndoorService) & {zones: {any}}
	
	for index: number in self.zones do
		if self:IsInZone(player, index) then
			self:Set(player, index, false)
		end
	end
end

function IndoorService:Clean()
	local self = self :: typeof(IndoorService) & {zones: {ZoneInfo}}
	
	local playersToCheck = {}
	for index: number, info: ZoneInfo in self.zones do
		for player: Player in info.players do
			table.insert(playersToCheck, {player = player, index = index})
		end
	end
	
	for _, info in playersToCheck do
		local player, index = info.player, info.index
		if player.Parent == Players and self:_isTouchingZone(player, index) then
			continue
		end
		self:Set(player, index, false)
	end
end

return IndoorService