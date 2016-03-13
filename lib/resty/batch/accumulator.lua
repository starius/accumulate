local accumulator = {}

local LARGE_TIMEOUT = 1000.0

function accumulator.new(max_size, timeout, func)

    local ngx = require "ngx"
    local semaphore = require "ngx.semaphore"

    local function makeState()
        return {
            tasks = {},
            sema = semaphore.new(),
        }
    end

    local state0 = makeState()

    local function applyFunc(_, state)
        if not state.applied then
            state.applied = true
            state0 = makeState()
            local ok, second = pcall(func, state.tasks)
            if ok and second then
                state.results = second
            else
                state.error_msg = second
            end
            state.sema:post(#state.tasks)
        end
    end

    local function wrapper(task)
        assert(task ~= nil)
        local state = state0
        table.insert(state.tasks, task)
        local index = #state.tasks
        if #state.tasks == max_size then
            ngx.timer.at(0.0, applyFunc, state)
        elseif #state.tasks == 1 then
            ngx.timer.at(timeout, applyFunc, state)
        end
        repeat until state.sema:wait(LARGE_TIMEOUT)
        if state.results then
            return state.results[index]
        else
            return nil, state.error_msg
        end
    end

    return wrapper
end

return accumulator
