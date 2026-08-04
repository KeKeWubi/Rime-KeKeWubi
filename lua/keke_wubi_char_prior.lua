--- 单字在前脚本
local utf8_len = utf8.len

local function keke_wubi_char_prior(input)
    local phrase_buf = {}
    local entry_text
    for entry in input:iter() do
        entry_text = entry.text
        if utf8_len(entry_text) == 1 then
            yield(entry)
        else
            table.insert(phrase_buf, entry)
        end
    end
    for _, entry in ipairs(phrase_buf) do
        yield(entry)
    end
end
return keke_wubi_char_prior