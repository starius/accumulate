local accumulator = require "resty.batch.accumulator"
local f = accumulator.new(3, 10.0, function(tasks)
    print("Start calculations")
    ngx.sleep(3.0)
    local result = {}
    for i = 1, #tasks do
        result[i] = i
    end
    print("Stop calculations")
    return result
end)

return function()
    ngx.say(f("input"))
end
