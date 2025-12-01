local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ItemInfo = require(ReplicatedStorage.store.items)
local Types = require(ReplicatedStorage.Types)

local ItemService = {
	_cache = {} :: {[ItemModel]: ItemData}
}

type ItemData = Types.ItemData
type ItemModel = BasePart | Model

local function getItemData(model: ItemModel): ItemData
	local itemInfo: ItemInfo.Data = ItemInfo[model.Name]
	return (itemInfo and itemInfo._data) or {
		load = 1
	}
end

local function setNetwork(model: ItemModel, ended: boolean?)
	return function(player: Player)
		if model.ClassName == 'Model' then
			if ended then
				model.PrimaryPart:SetNetworkOwnershipAuto()
			else
				model.PrimaryPart:SetNetworkOwner(player)
			end
		else
			if ended then
				model:SetNetworkOwnershipAuto()
			else
				model:SetNetworkOwner(player)
			end
		end
	end
end

function ItemService:start()
	for _, model: ItemModel in CollectionService:GetTagged("Item") do
		self:Create(model)
	end
	CollectionService:GetInstanceAddedSignal("Item"):Connect(function(model: ItemModel)
		self:Create(model)	
		model:Destroy()
	end)
	CollectionService:GetInstanceRemovedSignal("Item"):Connect(function(model: ItemModel)
		self:Destroy(model)
	end)
end

function ItemService:GetData(model: ItemModel)
	return self._cache[model]
end

function ItemService:Create(model: ItemModel)
	local dragger = script.Dragger:Clone()
	self._cache[model] = getItemData(model)
	
	dragger.DragStart:Connect(setNetwork(model))
	dragger.DragEnd:Connect(setNetwork(model, true))
	
	dragger.Parent = model
	return self._cache[model]
end

function ItemService:Make(templ: ItemModel)
	local model = templ:Clone()
	self:Create(model)
	return model
end

function ItemService:Destroy(model: ItemModel)
	self._cache[model] = nil
end

return ItemService