--- 单字在前脚本
local function keke_wubi_char_prior(input)
    local phrase_buf = {}
    for entry in input:iter() do
        if (utf8.len(entry.text) == 1) then
            yield(entry)
        else
            table.insert(phrase_buf, entry)
        end
    end
    for idx, entry in ipairs(phrase_buf) do
        yield(entry)
    end
end

return keke_wubi_char_prior