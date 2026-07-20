-- 日期时间命令翻译器 标准Rime接口
local function translator(input, seg)
    local cmds = {
        ["date"] = function() return os.date("%Y-%m-%d") end,
        ["CMDdate"] = function() return os.date("%Y年%m月%d日") end,
        ["日期"] = function() return os.date("%Y年%m月%d日") end,
        ["time"] = function() return os.date("%H:%M:%S") end,
        ["CMDtime"] = function() return os.date("%H时%M分%S") end,
        ["时间"] = function() return os.date("%H:%M") end
    }
    if cmds[input] then
        yield(Candidate("cmd", seg.start, seg._end, cmds[input], "[命令]"))
    end
end
return translator