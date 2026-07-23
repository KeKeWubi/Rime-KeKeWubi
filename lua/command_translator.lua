-- 可可五笔 命令翻译器
local function translator(input, seg)
    
    if input == "help" then
        yield(Candidate("cmd", seg._end, seg.start, "请前往可可五笔官网：keke.kim", os.date("")))
    end

    if input == "conf" or input == "conv" then
        yield(Candidate("cmd", seg._end, seg.start, "请按Ctrl+0", os.date("")))
    end
	
    if input == "date" then
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y%m%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y-%m-%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y.%m.%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y/%m/%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%m-%d-%Y"), ""))
    end

    if input == "time" then
        yield(Candidate("cmd", seg.start, seg._end, os.date("%H:%M"), ""))
		yield(Candidate("cmd", seg.start, seg._end, os.date("%H时%M分"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%H:%M:%S"), ""))
		yield(Candidate("cmd", seg.start, seg._end, os.date("%H时%M分%S秒"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y%m%d%H%M%S"), "时间戳"))
    end

    local weekday = {'日', '一', '二', '三', '四', '五', '六'}
    if input == "week" then
        local w = tonumber(os.date("%w")) + 1
        yield(Candidate("cmd", seg.start, seg._end, "星期"..weekday[w], ""))
		yield(Candidate("cmd", seg.start, seg._end, "周"..weekday[w], ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%A"), "英文全称"))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%a"), "英文缩写"))
        yield(Candidate("cmd", seg.start, seg._end, os.date("第%W周"), "当年周数"))
    end
    
end

return translator
