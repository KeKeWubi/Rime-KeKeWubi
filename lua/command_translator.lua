-- 可可五笔 命令翻译器
local function translator(input, seg)

    local function num_to_rmb(num_str)
        local digit = {'零','壹','贰','叁','肆','伍','陆','柒','捌','玖'}
        local inner_unit = {"", "拾", "佰", "仟"}
        local unit_dec = {'角','分'}
        
        local dot = num_str:find("%.")
        local integer_part, decimal_part
        if dot then
            integer_part = num_str:sub(1, dot-1)
            decimal_part = num_str:sub(dot+1):sub(1,2)
            if #decimal_part == 1 then
                decimal_part = decimal_part .. "0"
            end
        else
            integer_part = num_str
            decimal_part = "00"
        end
        integer_part = integer_part:gsub("^0+","")
        if integer_part == "" then integer_part = "0" end

        local jiao_num = tonumber(decimal_part:sub(1,1))
        local fen_num = tonumber(decimal_part:sub(2,2))

        local int_rev = integer_part:reverse()
        local group_list = {}
        for i = 1, #int_rev, 4 do
            local block = int_rev:sub(i, i+3):reverse()
            table.insert(group_list, block)
        end

        local rmb_int = ""
        local last_was_zero = false

        for g_idx = #group_list, 1, -1 do
            local block = group_list[g_idx]
            local block_buf = ""
            local block_has_num = false
            local blen = #block

            for d_idx = 1, blen do
                local n = tonumber(block:sub(d_idx, d_idx))
                local iu = inner_unit[blen - d_idx + 1]
                if n > 0 then
                    block_buf = block_buf .. digit[n+1] .. iu
                    block_has_num = true
                    last_was_zero = false
                else
                    if block_buf ~= "" and block_buf:sub(-1) ~= "零" then
                        block_buf = block_buf .. "零"
                    end
                end
            end
            block_buf = block_buf:gsub("零+$", "")

            local suffix = ""
            local level = g_idx - 1
            local yi_count = math.floor(level / 2)
            if level % 2 == 1 then
                suffix = "万"
            end
            suffix = suffix .. string.rep("亿", yi_count)

            if block_has_num then
                rmb_int = rmb_int .. block_buf .. suffix
                last_was_zero = false
            else
                if rmb_int ~= "" and not last_was_zero then
                    rmb_int = rmb_int .. "零"
                    last_was_zero = true
                end
            end
        end

        if rmb_int == "" then
            rmb_int = "零"
        end
        local rmb = rmb_int .. "元"

        if jiao_num > 0 then
            rmb = rmb .. digit[jiao_num+1] .. unit_dec[1]
        end
        if fen_num > 0 then
            if jiao_num == 0 then
                rmb = rmb .. "零"
            end
            rmb = rmb .. digit[fen_num+1] .. unit_dec[2]
        end

        if decimal_part == "00" then
            rmb = rmb .. "整"
        end

        return rmb
    end

    if input == "help" then
        yield(Candidate("cmd", seg._end, seg.start, "请前往可可五笔官网：keke.kim", os.date("")))
    end

    if input == "conf" or input == "conv" then
        yield(Candidate("cmd", seg._end, seg.start, "请按 Ctrl+0（数字零）", os.date("")))
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
        local dot_cnt = select(2, num_part:gsub("%.", ""))
        if dot_cnt > 1 then return end
        
        local rmb_str = num_to_rmb(num_part)
        yield(Candidate("cmd", seg.start, seg._end, rmb_str, "人民币大写"))
    end
    
end

return translator
