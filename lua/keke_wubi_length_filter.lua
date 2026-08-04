-- keke_wubi_length_filter.lua，设置在第几码时，“候选框”开始编码提示的脚本
local str_find = string.find

local function filter(input, env)
    local ctx = env.engine.context
    local input_str = ctx.input
    -- 提前判断含z直接放行，不进入循环内分支
    if str_find(input_str, "z") then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    -- 配置读取一次
    local cfg = env.engine.schema.config
    local min_length = cfg:get_int("speller/min_code_length_for_completion") or 3
    local code_len = #input_str
    local cand_type

    for cand in input:iter() do
        if code_len >= min_length then
            yield(cand)
        else
            cand_type = nil
            pcall(function() cand_type = cand.type end)
            if cand_type ~= "completion" then
                yield(cand)
            end
        end
    end
end
return filter