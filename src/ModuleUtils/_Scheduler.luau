--!strict
--@title: SchedulerType
--@author: crusherfire
--@date: 4/2/24
--[[@description:
	Allows to place 'tasks' in queue. A task can be anything (function, table, etc). These 'tasks' will be passed to
	the bound callback function responsible for handling the tasks. A new incoming task won't be available to
	the handler callback until :DoneHandlingTask() is called.
	
	Change the policy on the fly using :SetPolicy(). (FIFO is default)
	Add a predicate to filter out undesireable tasks in the queue!
	Return false from your predicate if you wish for the task to be removed from the queue.
	
	DOCUMENTATION:
	
	.new(policy: Policies?): SchedulerType
	Returns a Scheduler object with an optional policy parameter. The default policy is "FIFO" if none is provided.
	
	:ChangePolicy(policy: Policies)
	Changes the policy of the scheduler. This can be changed even while the scheduler is handling tasks 
	and will be reflected when the next task is going to be chosen.
	
	:BindCallback(callback: (nextTask: any) -> ())
	Binds the callback to handle tasks given from the scheduler. This MUST be called before adding tasks to the scheduler.
	
	:UnbindCallback()
	Removes the callback that handles tasks given from the queue. This will stop the scheduler and clears 
	all tasks currently in queue. Before adding a new task, a new callback must be bound.
	
	:ConnectToQueueEmptySignal(callback: () -> ()): Signal.SignalConnection
	Returns a connection to the queue empty signal. This signal fires when there are no more tasks in the queue.
	
	:AddPredicate(predicate: (nextTask: any) -> (boolean))
	Adds an optional predicate to filter out undesirable tasks from the queue.
	
	:RemovePredicate()
	Removes the predicate.
	
	:DoneHandlingTask()
	This function notifies the scheduler that the callback is ready to receive the next task in the queue. 
	If you do not call this function, the scheduler will wait forever.
	
	:AddTask(newTask: any)
	Adds a new task to the queue. You must have a callback bound. If the scheduler is not active, this will start the scheduler.
	
	:GetNumberOfTasks()
	Returns the number of tasks currently in queue.
	
	:Destroy()
	Halts the scheduler & clears all values.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signal = require(script.Parent._Signal)
local Trove = require(script.Parent._Trove)

-----------------------------
-- TYPES --
-----------------------------
type Policies = "LIFO" | "FIFO"
type Predicate = (nextTask: any) -> (boolean)
type Callback = (nextTask: any) -> ()
type self = {
	_trove: Trove.TroveType,
	TasksInQueue: {any},
	QueueEmptySignal: Signal.SignalType<() -> (), ()>,
	_callback: Callback?,
	_policy: Policies,
	_predicates: { [string]: Predicate },
	_activeThread: thread?
}

-----------------------------
-- VARIABLES --
-----------------------------
local Scheduler = {}
local MT = {}
MT.__index = MT

export type SchedulerType = typeof(setmetatable({} :: self, MT))

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function startTaskLoop(self: SchedulerType)
	while self._callback do
		local index = if self._policy == "FIFO" then 1 else #self.TasksInQueue
		local currentTask = self.TasksInQueue[index]
		if not currentTask then
			break
		end
		
		local removed = false
		for _, predicate in pairs(self._predicates) do
			if not predicate(currentTask) then
				table.remove(self.TasksInQueue, index)
				removed = true
				break
			end
		end
		if removed then
			continue
		end
		
		local success, err = pcall(function()
			self._callback(currentTask)
		end)
		if err then
			warn("Encountered error while handling task:\n", err)
		end
		table.remove(self.TasksInQueue, index)
	end
	self._activeThread = nil
	table.clear(self.TasksInQueue)
	self.QueueEmptySignal:Fire()
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new Scheduler.
function Scheduler.new(policy: Policies?): SchedulerType
	local self = {} :: self

	self._trove = Trove.new()
	self.TasksInQueue = {}
	self.QueueEmptySignal = self._trove:Construct(Signal)
	self._predicates = {}
	self._policy = policy or "FIFO"

	return setmetatable(self, MT)
end

function MT.ChangePolicy(self: SchedulerType, policy: Policies)
	assert(policy == "LIFO" or policy == "FIFO", "Unexpected value passed to policy parameter!")

	self._policy = policy
end

function MT.GetNumberOfTasks(self: SchedulerType)
	return #self.TasksInQueue
end

function MT.BindCallback(self: SchedulerType, callback: (nextTask: any) -> ())
	if self._callback then
		warn("Callback is already bound to scheduler!")
		return
	end
	assert(typeof(callback) == "function", "Callback must be a function!")

	self._callback = callback
end

function MT.ConnectToQueueEmptySignal(self: SchedulerType, callback: () -> ()): Signal.SignalConnection
	assert(typeof(callback) == "function", "Expected function for callback!")
	
	return self.QueueEmptySignal:Connect(callback)
end

-- Unbinding the callback will halt the scheduler and clears all values in the queue.
function MT.UnbindCallback(self: SchedulerType)
	self._callback = nil
end

function MT.AddPredicate(self: SchedulerType, identifier: string, allowNextTask: (nextTask: any) -> (boolean))
	assert(typeof(identifier) == "string", "Identifier must be a string!")
	assert(typeof(allowNextTask) == "function", "Predicate must be a function!")
	
	self._predicates[identifier] = allowNextTask
end

function MT.RemovePredicate(self: SchedulerType, identifier: string)
	self._predicates[identifier] = nil
end

-- Callback MUST be bound before adding a task to the scheduler!
function MT.AddTask(self: SchedulerType, ...: any)
	assert(self._callback, "No callback has been bound to the Scheduler!")

	local tasks = {...}
	for _, t in tasks do
		table.insert(self.TasksInQueue, t)
	end

	if not self._activeThread then
		self._activeThread = task.spawn(startTaskLoop, self)
	end
end

function MT:Destroy()
	task.cancel(self._activeThread)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return Scheduler