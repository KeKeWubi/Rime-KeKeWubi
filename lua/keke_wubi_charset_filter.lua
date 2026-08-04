-- 可可五笔 keke_wubi_charset_filter.lua 常用字可输出8105规范汉字
local function keke_wubi_charset_filter(input, env)
    local is_extended = env.engine.context:get_option("extended_charset")

    for entry in input:iter() do
        if is_extended then
            yield(entry)
        else
            local text = entry.text
            if utf8.len(text) > 1 then
                yield(entry)
            else
                local code = utf8.codepoint(text)
                
                -- 偏旁/部首区间（过滤）
                local is_radical = (code >= 0x2E80 and code <= 0x2EFF) or (code >= 0x2F00 and code <= 0x2FD5)
                
                -- ASCII 与基础标点 (包含句号 。 顿号 、 等，编码 < 0x4E00)
                local is_basic_punct = (code < 0x4E00)
                
                -- 全角标点符号区间 (包含逗号 ， 分号 ； 冒号 ： 感叹号 ！ 等)
                local is_fullwidth_punct = (code >= 0xFF00 and code <= 0xFFEF)
                
                -- 常用 CJK 规范汉字基本区 (0x4E00 - 0x9FA5)
                local is_common_hanzi = (code >= 0x4E00 and code <= 0x9FA5)
                
                if not is_radical and (is_basic_punct or is_fullwidth_punct or is_common_hanzi) then
                    yield(entry)
                end
            end
        end
    end
end

return keke_wubi_charset_filter
