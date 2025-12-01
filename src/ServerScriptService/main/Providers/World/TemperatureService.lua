local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DEFAULT_TEMPERATURE = 36.6

local TemperatureService = {}

function TemperatureService:_onCharacterAdded(character: Model)
	character:SetAttribute("Temperature", DEFAULT_TEMPERATURE)
end

function TemperatureService:init()
	Players.PlayerAdded:Connect(function(player: Player)
		if player.Character then
			self:_onCharacterAdded(player.Character)
		end
		player.CharacterAdded:Connect(function(character: Model)
			self:_onCharacterAdded(character)
		end)
	end)
end

function TemperatureService:start()
	
end

return TemperatureService