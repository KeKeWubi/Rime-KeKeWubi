-- 可可五笔 英文提示模式候选过滤器
-- keke_wubi_en_mode_filter.lua  （lua_filter，需放在 filters 最前面）
--
-- 当"英文提示模式"（keke_en_hint，右Shift切换）开启时：
-- 只保留纯 ASCII（英文）候选，把中文候选隐藏。模式关闭时完全直通。
--
-- 重要：yield 绝不能包在 pcall 里！librime-lua 的候选产出运行在协程中，
-- Lua 5.3 及以下环境里 pcall 内 yield 会抛错，导致候选全部丢失。
-- 因此 pcall 只用于"读取"（选项、候选文本），所有 yield 都在 pcall 之外。

local function filter(input, env)
  local ok, on = pcall(function()
    return env.engine.context:get_option("keke_en_hint")
  end)
  if not ok or not on then
    -- 模式关闭（或读取失败）：原样放行
    for cand in input:iter() do
      yield(cand)
    end
    return
  end
  -- 英文提示模式：只放行纯 ASCII 候选
  for cand in input:iter() do
    local ok2, text = pcall(function() return cand.text end)
    if ok2 and text ~= nil and text:match("^[\32-\126]+$") then
      yield(cand)
    end
  end
end

return filter
