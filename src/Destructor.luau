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
-- make sure your wrapper signatures at minimum cover all of these taskItems:
type DestructorItemInput = DestructorItem | DestructorItemInputTable

type DestructorData = {
	-- for this Destructor's overarching "job", we have a collection of tasks:
	_job: { [DestructorItemInput]: DestructorFunction },
}

local function refineInputTable(inputTable: DestructorItemInputTable): DestructorFunction?
	return inputTable.destroy or inputTable.Destroy or inputTable.disconnect or inputTable.Disconnect or nil
end

local taskWrapperMapping = {
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
	local self = setmetatable({ _job = {} }, Destructor)

	if select("#", ...) ~= 0 then
		for _, taskItem in { ... } do
			self:add(taskItem)
		end
	end

	return self
end

function Destructor.add(self: Destructor, taskItem: DestructorItemInput)
	self._job[taskItem] = (taskWrapperMapping[typeof(taskItem)])(taskItem) :: DestructorFunction

	return function()
		self._job[taskItem] = nil
	end, taskItem
end

function Destructor.remove(self: Destructor, taskItem: DestructorItemInput)
	local removedItem = self._job[taskItem]
	self._job[taskItem] = nil

	return removedItem or nil
end

function Destructor.destruct(self: Destructor)
	local job = self._job

	local i, itemTask = next(job)
	while itemTask ~= nil do
		job[i :: DestructorItemInput] = nil
		itemTask()

		i, itemTask = next(job)
	end
end

Destructor.Destroy = Destructor.destruct
Destructor.DoCleaning = Destructor.destruct

return Destructor
