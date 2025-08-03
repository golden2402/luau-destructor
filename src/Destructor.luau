--!strict
-- https://github.com/Fraktality/Destructor/blob/main/Destructor.lua

type DestructorFunction = () -> ()

type DestructorItem = thread | RBXScriptConnection | Instance | DestructorFunction

type TableDestructorFunction<T> = (self: T) -> ()
type TableDestructorItem<T> = {
	destroy: TableDestructorFunction<T>,
} | {
	Destroy: TableDestructorFunction<T>,
} | {
	disconnect: TableDestructorFunction<T>,
} | {
	Disconnect: TableDestructorFunction<T>,
}

-- defines the list of types that are applicable for destructor extraction; see
-- taskRefinementMap below
type DestructorDataKey = DestructorItem | TableDestructorItem<any>

type DestructorData = {
	-- for this Destructor's overarching "job", we have a collection of tasks:
	_job: { [DestructorDataKey]: DestructorFunction },
}

local function getFirstDestructorFunction<T>(_inputTable: TableDestructorItem<T>): TableDestructorFunction<T>
	-- as long as the parameter's OK, we should be safe to bypass all checks:
	local inputTable: any = _inputTable

	return assert(
		inputTable.destroy or inputTable.Destroy or inputTable.disconnect or inputTable.Disconnect,
		"attempted to refine table without destructor function"
	) :: TableDestructorFunction<T>
end

local taskRefinementMap = {
	["table"] = function<T>(inputTable: TableDestructorItem<T>)
		local destructor = getFirstDestructorFunction(inputTable)

		return function()
			destructor(inputTable)
		end
	end,
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

function Destructor.new(...: DestructorDataKey)
	local self = setmetatable({ _job = {} }, Destructor)

	if select("#", ...) ~= 0 then
		for _, taskItem in { ... } do
			self:add(taskItem)
		end
	end

	return self
end

function Destructor.add(self: Destructor, taskItem: DestructorDataKey)
	self._job[taskItem] = (taskRefinementMap[typeof(taskItem)])(taskItem) :: DestructorFunction

	return function()
		self._job[taskItem] = nil
	end, taskItem
end

function Destructor.remove(self: Destructor, taskItem: DestructorDataKey)
	local removedItem = self._job[taskItem]
	self._job[taskItem] = nil

	return removedItem or nil
end

function Destructor.destruct(self: Destructor)
	local job = self._job

	local i, itemTask = next(job)
	while itemTask ~= nil do
		job[i :: DestructorDataKey] = nil
		itemTask()

		i, itemTask = next(job)
	end
end

Destructor.Destroy = Destructor.destruct
Destructor.DoCleaning = Destructor.destruct

return Destructor
