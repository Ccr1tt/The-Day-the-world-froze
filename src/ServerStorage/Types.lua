local ProfileStore = require(script.Parent.data.ProfileStore)

local Types = {}
export type ProfileStore = typeof(ProfileStore.New())
export type Profile = typeof(ProfileStore.New():StartSessionAsync())
return Types