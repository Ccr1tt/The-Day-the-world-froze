if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(ReplicatedStorage:WaitForChild("Core"))
Core
	:curate(script:WaitForChild("Controllers"))
	:run()