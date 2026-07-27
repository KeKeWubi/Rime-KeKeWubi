--- 单字脚本
local function keke_wubi_char_only(input)
    for entry in input:iter() do
        if (utf8.len(entry.text) == 1) then
            yield(entry)
        end
    end
end
return keke_wubi_char_only