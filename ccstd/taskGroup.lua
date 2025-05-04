---A class to manage and execute groups of asynchronous tasks using coroutines.
---Tasks can yield and will resume on the next event,allowing for event-driven
---multitasking.
---
---You can start taskGroups inside other task groups.
---Example:
---```lua
---local taskGroup1 = TaskGroup.new()
---
---taskGroup1:addTask(function()
---  local taskGroup2 = TaskGroup.new()
---  taskGroup2:addTask(someFunc, arg1, arg2)
---  taskGroup2:startTasks()
---end)
---
---
---taskGroup1:startTasks()
---```
---
---Warning functions like below will block execution of entire program anyway:
---```lua
---local function func()
---  while true do
---    someAction()
---  end
---end
---```
---To prevent blocking use yielding functions such as `sleep()`, `os.pullEvent()`
---or `coroutine.yield()`
---@class TaskGroup
---@field private _runningTasks table Stores currently running tasks (coroutines).
---@field private _startingTasks table Tasks that are ready to start execution.
---@field private _isRunning boolean Is task group currently running.
local TaskGroup = {}
TaskGroup.__index = TaskGroup

---Create new TaskGroup
---@return TaskGroup
function TaskGroup.new()
  local self = {}
  self._startingTasks = {}
  self._runningTasks = {}
  self._isRunning = false
  return setmetatable(self, TaskGroup)
end


---Add task to task group.
---Works even if task group is running.
---@param func function Function to add
---@param ... any Arguments for function
function TaskGroup:addTask(func, ...)
  local newTask = {
    task = coroutine.create(func),
    args = {...,},
  }

  table.insert(self._startingTasks, newTask)
end


---Cycle just started tasks
---@private
function TaskGroup:_cycleStartingTasks()
  local oldStartingTasks = self._startingTasks
  self._startingTasks = {}
  for _, newTask in ipairs(oldStartingTasks) do
    local task = newTask.task
    local args = newTask.args
    local ok, output = coroutine.resume(task, table.unpack(args))
    if not ok then
      error(output, 3)
    end
    if coroutine.status(task) ~= 'dead' then
      local runningTask = {
        task = task,
        eventFilter = output,
      }
      table.insert(self._runningTasks, runningTask)
    end
  end
end


---Cycle running tasks
---@private
---@param event string[] return of {os.pullEvent()}
function TaskGroup:_cycleRunningTasks(event)
  -- Cycle backwards to safely remove dead tasks in-place
  for i = #self._runningTasks, 1, -1 do
    local runningTask = self._runningTasks[i]
    local task = runningTask.task
    local eventFilter = runningTask.eventFilter
    if not eventFilter or eventFilter == event[1] then
      local ok, output = coroutine.resume(task, table.unpack(event))
      if ok then
        runningTask.eventFilter = output
      end
      if not ok then
        error(output, 3)
      end
      if coroutine.status(task) == 'dead' then
        table.remove(self._runningTasks, i)
      end
    end
  end
end


---Starts running task group. Can't start if already started.
---
---Rises error if error inside a task raised.
---
---@async
---@return boolean `false` if the task group is already running, `true` otherwise.
function TaskGroup:runTasks()
  if self._isRunning then
    return false
  end
  self._isRunning = true
  while self._isRunning and
    (#self._runningTasks > 0 or #self._startingTasks > 0)
  do
    self:_cycleStartingTasks()
    local event = {os.pullEventRaw(),}
    self:_cycleRunningTasks(event)
    if event[1] == 'terminate' then
      print()
      error('terminated', 3)
    end
  end
  return true
end


---Stop task group
---@return boolean `true` if the task group was running and is now stopped, `false` if it was not running.
function TaskGroup:stopTasks()
  if self._isRunning then
    self._isRunning = false
    return true
  end
  return false
end


return TaskGroup
