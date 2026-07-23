-- 可可五笔 命令翻译器
local function translator(input, seg)

    local function num_to_rmb(num_str)
        local digit = {'零','壹','贰','叁','肆','伍','陆','柒','捌','玖'}
        local unit_int = {'','拾','佰','仟','万','拾','佰','仟','亿','拾','佰','仟'}
        local unit_dec = {'角','分'}
        local dot = num_str:find("%.")
        local integer_part, decimal_part
        if dot then
            integer_part = num_str:sub(1, dot-1)
            decimal_part = num_str:sub(dot+1):sub(1,2)
        else
            integer_part = num_str
            decimal_part = ""
        end
        integer_part = integer_part:gsub("^0+","")
        if integer_part == "" then integer_part = "0" end

        local rmb = ""
        local int_len = #integer_part
        for i=1,int_len do
            local n = tonumber(integer_part:sub(i,i))
            local pos = int_len - i + 1
            if n ~= 0 then
                rmb = rmb .. digit[n+1] .. unit_int[pos]
            else
                if rmb:sub(-1) ~= "零" and #rmb > 0 then
                    rmb = rmb .. "零"
                end
            end
        end
        rmb = rmb .. "元"

        if decimal_part ~= "" then
            local jiao = tonumber(decimal_part:sub(1,1))
            local fen = tonumber(decimal_part:sub(2,2) or "0")
            if jiao > 0 then
                rmb = rmb .. digit[jiao+1] .. unit_dec[1]
            end
            if fen > 0 then
                if jiao == 0 then rmb = rmb .. "零" end
                rmb = rmb .. digit[fen+1] .. unit_dec[2]
            end
        else
            rmb = rmb .. "整"
        end
        return rmb
    end

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
    
    local num_part = input:match("^rmb([0-9%.]+)$")
    if num_part then
        yield(Candidate("cmd", seg.start, seg._end, num_to_rmb(num_part), "人民币大写"))
    end
    
end

return translator
