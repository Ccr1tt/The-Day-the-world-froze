local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.lib.Promise)

local Types = {}
export type Promise = Promise.Promise
export type ItemData = {
	load: number
}
return Types