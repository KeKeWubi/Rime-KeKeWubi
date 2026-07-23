-- 可可五笔 日期时间命令翻译器
local function translator(input, seg)
    local weekTab = {'日', '一', '二', '三', '四', '五', '六'}

    -- date 多种日期格式
    if input == "date" then
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y年%m月%d日"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y%m%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y-%m-%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y.%m.%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y/%m/%d"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%m-%d-%Y"), ""))
    end

    -- time 多种时间格式
    if input == "time" then
        yield(Candidate("cmd", seg.start, seg._end, os.date("%H:%M"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%H:%M:%S"), ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%Y%m%d%H%M%S"), "时间戳"))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%H%M%S"), ""))
    end

    -- week 星期
    if input == "week" then
        local w = tonumber(os.date("%w")) + 1
        yield(Candidate("cmd", seg.start, seg._end, "周"..weekTab[w], ""))
        yield(Candidate("cmd", seg.start, seg._end, "星期"..weekTab[w], ""))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%A"), "英文全称"))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%a"), "英文缩写"))
        yield(Candidate("cmd", seg.start, seg._end, os.date("%W"), "当年周数"))
    end


end

return translator