-- 可可五笔 英文提示模式翻译器
-- keke_wubi_english_hint.lua  （lua_translator）
--
-- 仅当"英文提示模式"（选项 keke_en_hint，由右Shift切换）开启时工作：
-- 用共享词典模块 keke_en_dict 做前缀匹配，把结果作为英文候选送给候选窗。
--
-- == 为什么一次输出"整份候选"而不是只输出当前页 ==
--   英文提示模式必须开 ascii_mode（小狼毫托盘只认它来显示"英"），
--   而 librime 源码里 key_binder 的 has_menu / paging 条件在 ascii_mode 下被
--   硬编码禁用（key_binder.cc：`HasMenu() && !get_option("ascii_mode")`），
--   所以 - / = 匹配不到翻页绑定，只能由处理器自己接管翻页键。
--
--   v6 的做法是"翻译器只给当前页、处理器改页码后重建组字"。缺点很明显：
--   引擎的候选菜单永远只有一页（page_no=0、is_last_page=true），
--   候选窗右侧的翻页箭头永远是灰的，和普通输入法的观感不一致。
--
--   v7 改成：翻译器一次性把头 CAP 个候选全部交给引擎，让引擎自己分页；
--   处理器拦到 - / = 时直接把 Segment 的 selected_index 挪到目标页
--   （实测 librime-lua 允许写这个字段，Menu 的 page_no 随之变），
--   于是 page_no / is_last_page 都是真实值，候选窗左右翻页箭头该亮就亮，
--   点击箭头（前端会发 Page_Up/Page_Down）也能用同一套逻辑翻页。
--
-- 重要：yield 绝不能包在 pcall 里（librime-lua 的候选产出在协程中，
-- Lua 5.3 及以下 pcall 内 yield 会抛错，导致候选全部丢失）。
-- 本文件所有 pcall 只做"读取/加载"，yield 都在 pcall 之外。

local OPT_ENHINT = "keke_en_hint"
local DEFAULT_CAP = 200      -- 与 keke_en_dict.CAP 保持一致

-- 载入共享词典模块（require 失败时按绝对路径 loadfile 兜底）
local function load_dict_module()
  local cached = rawget(_G, "keke_en_dict_module")
  if type(cached) == "table" then return cached end
  local ok, mod = pcall(require, "keke_en_dict")
  if ok and type(mod) == "table" then
    _G.keke_en_dict_module = mod
    return mod
  end
  local dir
  pcall(function()
    if rime_api and rime_api.get_user_data_dir then dir = rime_api:get_user_data_dir() end
  end)
  if dir then
    local chunk = loadfile(dir .. "/lua/keke_en_dict.lua")
    if chunk then
      local ok2, mod2 = pcall(chunk)
      if ok2 and type(mod2) == "table" then
        _G.keke_en_dict_module = mod2
        return mod2
      end
    end
  end
  return nil
end

local dict = nil

-- 供处理器在"进入提示模式"时预热，避免第一次按键才读词典
function _G.keke_en_preload()
  if not dict then dict = load_dict_module() end
  if dict then pcall(dict.load) end
end

local function translator(input, seg, env)
  if not seg or not env or not env.engine then return end

  local ok, on = pcall(function()
    return env.engine.context:get_option(OPT_ENHINT)
  end)
  if not ok or not on then return end
  if type(input) ~= "string" or not input:match("^[%a'%-]+$") then return end

  if not dict then dict = load_dict_module() end
  if not dict then return end
  local ok2, words = pcall(dict.words, input)
  if not ok2 or type(words) ~= "table" or #words == 0 then return end

  local cap = dict.CAP or DEFAULT_CAP
  local n = #words
  if n > cap then n = cap end

  local from, to = 1, n

  -- 兼容不同 librime-lua 版本的 Segment 字段名
  local start_pos = seg._start or seg.start_pos or 0
  local end_pos = seg._end or seg.end_pos or (start_pos + #input)

  -- 第 6 个参数 comment 不能省（librime-lua 会校验成 string），
  -- 留空字符串：候选窗不再显示多余的"英文"标记
  for i = from, to do
    yield(Candidate("keke_en", start_pos, end_pos, words[i], ""))
  end
end

return translator
