-- keke_wubi_length_filter.lua，设置在第几码时，“候选框”开始编码提示的脚本
local function filter(input, env)
    local context = env and env.engine and env.engine.context
    local input_str = (context and context.input) or ""

    if string.find(input_str, "z") or string.find(input_str, "Z") then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local min_length = 3
    if env and env.engine and env.engine.schema and env.engine.schema.config then
        min_length = env.engine.schema.config:get_int("speller/min_code_length_for_completion") or 3
    end

    local code_len = #input_str

    for cand in input:iter() do
        local ctype = ""
        pcall(function() ctype = cand.type end)

        if code_len >= min_length then
            yield(cand)
        else
            if ctype ~= "completion" then
                yield(cand)
            end
        end
    end
end

return filter