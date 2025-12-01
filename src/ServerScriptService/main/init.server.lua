local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(ReplicatedStorage.Core)
Core
	:curate(script.Providers)
	:run()