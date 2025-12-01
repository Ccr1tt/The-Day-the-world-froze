local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.lib.Signal)
local Promise = require(ReplicatedStorage.lib.Promise)
local SharedTypes = require(ReplicatedStorage.Types)
local Types = require(ServerStorage.Types)
local ProfileStore = require(ServerStorage.data.ProfileStore)
local DataTemplate = require(ServerStorage.data.DataTemplate)

local PLAYER_STORE = ProfileStore.New("mock-player-data", DataTemplate)
local SESSION = {} :: {[player]: Types.Profile}

local PROFILE_LOADED = Signal()
local PROFILE_RELEASED = Signal()

local DataService = {}
DataService._session = SESSION
DataService.ProfileLoaded = PROFILE_LOADED

local function getProfileKey(player: Player)
	return `{player.UserId}`
end

function DataService:init()
	local function wrappedLoad(player: Player)
		self:Load(player)
	end
	for _, player: Player in Players:GetPlayers() do
		wrappedLoad(player)
	end
	Players.PlayerAdded:Connect(wrappedLoad)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = SESSION[player]
		if profile ~= nil then
			profile:EndSession()
		end
	end)
end

function DataService:start()
end

function DataService:Load(player: Player)
	local profile: Types.Profile = PLAYER_STORE:StartSessionAsync(getProfileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end
	})
	
	if profile == nil then
		player:Kick("ROBLOX has failed to load your data - please rejoin or wait until the outage is over")
		return warn("Data loading failure")
	end
	
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	
	profile.OnSessionEnd:Connect(function()
		PROFILE_RELEASED:Fire(player)
		SESSION[player] = nil
	end)
	
	if player.Parent == Players then
		SESSION[player] = profile
		PROFILE_LOADED:Fire(profile)
	else
		profile:EndSession()
	end
end

function DataService:Get(player: Player): SharedTypes.Promise
	local profile = SESSION[player]
	if profile then
		return Promise.resolve(profile)
	end
	
	local profileLoaded = Promise.fromEvent(PROFILE_LOADED, function(target: Player)
		return target == player
	end)
	
	local profileReleased = Promise.fromEvent(PROFILE_RELEASED, function(target: Player)
		return target == player
	end)	
	
	local playerLeaving = Promise.fromEvent(Players.PlayerRemoving, function(profile: Types.Profile)
		return profile.Key == tostring(player.UserId)
	end)
	
	return Promise.race {
		profileLoaded,
		profileReleased,
		playerLeaving,
	}
end

function DataService:getQuick(player: Player)
	return SESSION[player]
end

return DataService