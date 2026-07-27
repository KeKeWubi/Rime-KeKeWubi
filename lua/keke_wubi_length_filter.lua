-- lua/keke_wubi_length_filter.lua
local function filter(input, env)
    -- 获取配置的最小提示码长，默认值为 3
    local min_length = env.engine.schema.config:get_int("speller/min_code_length_for_completion") or 3
    local context = env.engine.context
    local code_len = string.len(context.input)

    for cand in input:iter() do
        -- 1. 达到设定码长（如 >=3 码），放行所有候选（包括补全提示）
        if code_len >= min_length then
            yield(cand)
        -- 2. 未达到设定码长（如 1、2 码），只保留精确匹配项，拦截长词提示，防止卡死
        else
            if cand.type ~= "completion" then
                yield(cand)
            end
        end
    end
end

return filter