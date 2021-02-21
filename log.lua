TGLog = {}
TGLog.__index = TGLog

function TGLog:new(...)
    local log = {}
    setmetatable(log, self)
    log:TGLog(...)
    return log
end

function TGLog:TGLog(level)
    self.lines = {}
    self.level = level
    self.echo  = false
end

function TGLog:clear()
    self.lines = {}
end

function TGLog:log(level, ...)
    if self.level > level then
        return
    end

    local args = {n = select("#", ...), ...}
    local msg = ""
    for i=1, args.n do
        msg = msg..tostring(args[i])
    end
    table.insert(self.lines, msg)

    if self.echo then
        print(msg)
    end
end

function TGLog:dump()
    for _, msg in ipairs(self.lines) do
        print(msg)
    end
end
