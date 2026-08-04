--- “仅输出单字”脚本
local utf8_len = utf8.len

local function keke_wubi_char_only(input)
    for entry in input:iter() do
        if utf8_len(entry.text) == 1 then
            yield(entry)
        end
    end
end
return keke_wubi_char_only