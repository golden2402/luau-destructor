--!strict
-- https://github.com/Fraktality/Destructor/blob/main/Destructor.lua

type DestructorFunction = () -> ()
type DestructorItem = thread | RBXScriptConnection | Instance | DestructorFunction

type DestructorItemInputTable = {
	destroy: DestructorFunction?,
	Destroy: DestructorFunction?,
	disconnect: DestructorFunction?,
	Disconnect: DestructorFunction?,
}
-- make sure your wrapper signatures at minimum cover all of these items:
type DestructorItemInput = DestructorItem | DestructorItemInputTable

type DestructorData = {
	_items: { [DestructorItemInput]: DestructorFunction },
}

local function refineInputTable(inputTable: DestructorItemInputTable): DestructorFunction?
	return inputTable.destroy or inputTable.Destroy or inputTable.disconnect or inputTable.Disconnect or nil
end

local itemWrappers = {
	["thread"] = function(thread: thread)
		return function()
			task.cancel(thread)
		end
	end,
	["function"] = function(destructorFunction: DestructorFunction)
		return function()
			destructorFunction()
		end
	end,
	["table"] = function(tableToWrap: DestructorItemInputTable)
		local cleanup = refineInputTable(tableToWrap)

		if cleanup == nil then
			error("table wrapper received bad table")
		end

		return function()
			cleanup()
		end
	end,
	["Instance"] = function(instance: Instance)
		return function()
			instance:Destroy()
		end
	end,
	["RBXScriptConnection"] = function(connection: RBXScriptConnection)
		return function()
			connection:Disconnect()
		end
	end,
}

local Destructor = {}
Destructor.__index = Destructor

export type Destructor = typeof(setmetatable({} :: DestructorData, Destructor))

function Destructor.new(...: DestructorItemInput)
	local self = setmetatable({ _items = {} }, Destructor)

	if select("#", ...) ~= 0 then
		for _, item in { ... } do
			self:add(item)
		end
	end

	return self
end

function Destructor.add(self: Destructor, item: DestructorItemInput)
	self._items[item] = (itemWrappers[typeof(item)])(item) :: DestructorFunction

	return function()
		self._items[item] = nil
	end, item
end

function Destructor.remove(self: Destructor, item: DestructorItemInput)
	local removedItem = self._items[item]
	self._items[item] = nil

	return removedItem or nil
end

function Destructor.destroy(self: Destructor)
	for _, finalizer in self._items do
		finalizer()
	end

	table.clear(self._items)
end

return Destructor
