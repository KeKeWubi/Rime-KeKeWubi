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
                
                local is_radical = (code >= 0x2E80 and code <= 0x2EFF) or (code >= 0x2F00 and code <= 0x2FD5)
                
                if not is_radical and (code < 0x4E00 or (code >= 0x4E00 and code <= 0x9FA5)) then
                    yield(entry)
                end
            end
        end
    end
end

return keke_wubi_charset_filter