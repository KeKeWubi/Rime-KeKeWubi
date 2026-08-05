-- 可可五笔 keke_wubi_charset_filter.lua 常用字可输出8105规范汉字
local utf8_len = utf8.len
local utf8_codepoint = utf8.codepoint

local RADICAL_S = 0x2E80
local RADICAL_E1 = 0x2EFF
local RADICAL_S2 = 0x2F00
local RADICAL_E2 = 0x2FD5
local CJK_MIN = 0x4E00
local CJK_MAX = 0x9FA5
local FW_PUNC_S = 0xFF00
local FW_PUNC_E = 0xFFEF

local function keke_wubi_charset_filter(input, env)
    local ctx = env.engine.context
    local is_extended = ctx:get_option("extended_charset")
    local text, code, is_radical, is_basic_punct, is_fullwidth_punct, is_common_hanzi

    for entry in input:iter() do
        if is_extended then
            yield(entry)
            goto continue
        end

        text = entry.text
        if utf8_len(text) > 1 then
            yield(entry)
            goto continue
        end

        code = utf8_codepoint(text)
        is_radical = (code >= RADICAL_S and code <= RADICAL_E1)
            or (code >= RADICAL_S2 and code <= RADICAL_E2)
        is_basic_punct = code < CJK_MIN
        is_fullwidth_punct = (code >= FW_PUNC_S and code <= FW_PUNC_E)
        is_common_hanzi = (code >= CJK_MIN and code <= CJK_MAX)

        if not is_radical and (is_basic_punct or is_fullwidth_punct or is_common_hanzi) then
            yield(entry)
        end

        ::continue::
    end
end
return keke_wubi_charset_filter
