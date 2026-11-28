-- 可可五笔 Shift 英文双模式 v7（对应可可五笔官网"第七招 Shift切换英文"）
-- keke_wubi_shift_modes.lua  （lua_processor，需放在 processors 最顶部）
--
-- == 按键行为 ==
--   左Shift 单击：进入"单字母上屏模式"（原生英文直通，托盘显示"英"）
--   右Shift 单击：进入"英文提示模式"（英文单词候选，托盘同样显示"英"）
--   已进入任一模式时，再按【左右任意一个】Shift → 退出，回到中文模式
--   Esc：退出英文提示模式
--
-- == 英文提示模式下的按键 ==
--   字母（含大写）、' 、-  → 续打单词，实时出候选
--   空格   → 上屏首选候选 + 空格
--   数字1-9 → 上屏当前页对应候选
--   标点   → 上屏"候选词+标点"（单词自然收尾）
--   - / =  → 上一页 / 下一页（首页的 - 仍作连字符，可打 e-mail）
--   回车   → 原样上屏（词典没有的词、变量名、大写都适用）
--   退格   → 删除最后输入的字母
--
-- == 版本演进（每一版都是真机引擎实测出来的）==
--   v4 靠回读引擎候选菜单（ctx:select / get_selected_candidate）选词：
--      · 翻译器产出候选是延迟的，第一个按键时菜单还没就绪，读回来是 nil；
--      · ctx:select(n) 其实是【立即提交第 n 个候选】并清空组字，不是"高亮"；
--      于是数字选词失败后返回 kNoop，按键漏给引擎的直通逻辑，
--      候选被提交的同时"2"也进了应用 → "BA2"；残留 input 又让下一键变"bb"。
--   v5 改为不回读引擎：候选由共享模块 keke_en_dict 当场算，自己 commit，
--      凡是自己处理过的按键一律 kAccepted，双写与残留彻底消失。
--   v6 补上翻页：当时让翻译器只输出当前页、处理器改页码后重建组字。
--      代价是引擎的候选菜单永远只有一页，翻页箭头永远是灰的。
--   v7（本版）：
--      · 翻译器一次输出整份候选（前 CAP 个），由引擎自己分页，
--        page_no / is_last_page 都是真实值 → 翻页箭头会按页状态变色；
--      · 处理器拦到 - / = 时向引擎注入 Page_Up / Page_Down，引擎照常翻页，
--        页码同时记在 env 上，供"空格/数字选词"判断当前页；
--      · Ctrl 组合键（Ctrl+A 全选这类）直接 kRejected 中断处理链交给应用，
--        修掉 ascii 模式下被当普通字符吃进编码串的问题。
--
-- == 返回值约定（librime 源码 processor.h 的枚举，实测验证） ==
--   kRejected=0（中断处理链、按键交给应用）  ← 只有 Ctrl 组合键才用
--   kAccepted=1（消费按键）   kNoop=2（交给下一个处理器）
--   注意：普通按键绝不能返回 0，否则中文输入会全部失效。
--
-- == 安全保证 ==
--   本脚本不产出候选（无 yield）；全部逻辑包 pcall，任何错误只会让本脚本
--   静默失效放行按键，绝不影响中文输入。
--
-- 排错开关：改为 true 后 Rime 日志里搜 keke_shift 可看到模式切换轨迹。
local DEBUG = false

local kRejected = 0   -- 中断处理链，按键交给应用（仅用于 Ctrl/Alt/Super 组合键）
local kAccepted = 1   -- 消费按键
local kNoop     = 2   -- 交给下一个处理器

local XK_Shift_L   = 0xffe1
local XK_Shift_R   = 0xffe2
local XK_Page_Up   = 0xff55
local XK_Page_Down = 0xff56
local XK_BackSpace = 0xff08
local XK_Return    = 0xff0d
local XK_Escape    = 0xff1b

-- 少数前端/RimeProcessKey 会把功能键按 ASCII 码传进来，这里一并认下
local is_escape    = function(c) return c == XK_Escape or c == 0x1b end
local is_return    = function(c) return c == XK_Return or c == 0x0d end
local is_backspace = function(c) return c == XK_BackSpace or c == 0x08 end

local OPT_LETTER = "keke_letter_mode"   -- 单字母上屏模式标记
local OPT_ENHINT = "keke_en_hint"       -- 英文提示模式标记

local DEFAULT_PAGE_SIZE = 6             -- 读不到 menu/page_size 时的兜底

local page_size_cache = nil
local dict = nil
local inited = false                    -- 本次进程是否已做过启动清理

-- ---------- 共享词典模块 ----------
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

local function get_dict()
  if not dict then dict = load_dict_module() end
  return dict
end

-- 查候选（失败时返回空表，绝不让异常外泄）
local function words_of(input)
  local d = get_dict()
  if not d then return {} end
  local ok, list = pcall(d.words, input)
  if ok and type(list) == "table" then return list end
  return {}
end

-- 候选总条数（与翻译器实际输出的条数一致，决定能翻几页）
local function total_of(input)
  local n = #words_of(input)
  local d = get_dict()
  local cap = d and d.CAP or 200
  if n > cap then n = cap end
  return n
end

-- ---------- 小工具 ----------
local function dbg(msg)
  if not DEBUG then return end
  if type(log) == "table" and type(log.info) == "function" then
    log.info("keke_shift: " .. msg)
  end
end

-- 单词续打字符：字母、撇号、连字符（支持 don't / e-mail）
local function is_word_char(ch)
  return ch:match("^[%a'%-]") ~= nil
end

-- 带变化检测的选项设置（修复"每打一个字母抖一下"）：
--   librime 的 set_option 每次调用都会触发通知（哪怕值没变），小狼毫默认会
--   据此刷新提示气泡。此辅助函数只在值真正变化时才调用 set_option。
local function set_opt(ctx, name, value)
  local ok, cur = pcall(function() return ctx:get_option(name) end)
  if ok and cur == value then return end
  pcall(function() ctx:set_option(name, value) end)
end

-- 读当前组字串（引擎真源，比自己在 Lua 里记账可靠）
local function get_input(ctx)
  local s = ""
  pcall(function() s = ctx.input end)
  if type(s) ~= "string" then s = "" end
  return s
end

-- 加一个字符到组字（走引擎正规接口 push_input，选项与分段状态才正确）
local function push_char(ctx, ch)
  local ok = pcall(function() ctx:push_input(ch) end)
  if not ok then
    local ok2 = pcall(function() ctx.input = get_input(ctx) .. ch end)
    if not ok2 then pcall(function() ctx:set_input(get_input(ctx) .. ch) end) end
  end
end

local function pop_char(ctx)
  local ok = pcall(function() ctx:pop_input(1) end)
  if not ok then
    local s = get_input(ctx)
    pcall(function() ctx.input = s:sub(1, -2) end)
  end
end

local function clear_composition(ctx)
  local ok = pcall(function() ctx:clear() end)
  if not ok then pcall(function() ctx.input = "" end) end
end

local function commit_text(env, text)
  local ok = pcall(function() env.engine:commit_text(text) end)
  dbg("提交: [" .. tostring(text) .. "] " .. (ok and "成功" or "失败!"))
  return ok
end

-- ---------- 页码（仅供空格/数字选词判断，翻页本身由引擎完成） ----------
local function set_page(env, page)
  if type(page) ~= "number" or page < 0 then page = 0 end
  env.page = page
end

local function get_page(env)
  local p = env.page
  if type(p) ~= "number" or p < 0 then p = 0 end
  return p
end

-- 候选窗每页几个（读 schema 的 menu/page_size，读不到用 6）
local function page_size(env)
  if not page_size_cache then
    local n = DEFAULT_PAGE_SIZE
    pcall(function()
      local schema = env.engine.schema
      local cfg = schema and schema.config
      if cfg and cfg.get_int then
        local v = cfg:get_int("menu/page_size")
        if type(v) == "number" and v > 1 then n = v end
      end
    end)
    page_size_cache = n
  end
  return page_size_cache
end

-- 把候选窗挪到第 page 页。
-- ascii 模式下输入被打上 raw 标签，Selector 见到 raw 一律不处理翻页键
-- （注入 Page_Down 会被引擎原样退回），所以翻页只能自己来。
-- 实测 librime-lua 可以写 Segment.selected_index，而 Menu 的 page_no 就是
-- selected_index / page_size —— 改它等于让引擎自己翻到那一页，
-- 于是 page_no / is_last_page 都是真实值，候选窗左右箭头该亮就亮。
local function goto_page(env, page)
  set_page(env, page)
  local ctx = env.engine.context
  local size = page_size(env)
  local ok, seg = pcall(function() return ctx.composition:back() end)
  if ok and seg then
    pcall(function() seg.selected_index = page * size end)
  end
  dbg("翻页 -> 第 " .. (page + 1) .. " 页")
end

-- 退出英文提示模式时释放词典：v2 紧凑词典常驻约 1.5MB，
-- 不 unload 的话进程内存会一直停在英文模式的峰值上。
local function release_en_memory()
  local d = get_dict()
  if d and type(d.unload) == "function" then
    pcall(d.unload)
  else
    pcall(collectgarbage, "collect")
  end
end

-- 退出一切英文模式，回到中文
local function exit_all(ctx, env)
  local was_hint = false
  pcall(function() was_hint = ctx:get_option(OPT_ENHINT) end)
  set_opt(ctx, OPT_ENHINT, false)
  set_opt(ctx, OPT_LETTER, false)
  set_opt(ctx, "ascii_mode", false)
  clear_composition(ctx)
  set_page(env, 0)
  if was_hint then release_en_memory() end
end

-- 当前页的首选候选（翻页后用户看到的第 1 个；词典没有该词时原样返回输入）
local function top_word(env, input)
  local list = words_of(input)
  local idx = get_page(env) * page_size(env) + 1
  return list[idx] or list[1] or input
end

-- 上屏并清场
local function commit_and_reset(ctx, env, text)
  commit_text(env, text)
  clear_composition(ctx)
  set_page(env, 0)
end

-- 启动清理：switches 里已经不再声明这两个选项，引擎不会自动 reset，
-- 这里补一次（只在整个进程第一次按键时判断，且仅当真有残留才写选项，不抖动）
local function startup_reset(ctx, env)
  if inited then return end
  inited = true
  if ctx:get_option(OPT_ENHINT) or ctx:get_option(OPT_LETTER) then
    local was_hint = ctx:get_option(OPT_ENHINT)
    set_opt(ctx, OPT_ENHINT, false)
    set_opt(ctx, OPT_LETTER, false)
    set_opt(ctx, "ascii_mode", false)
    clear_composition(ctx)
    set_page(env, 0)
    if was_hint then release_en_memory() end
    dbg("启动清理：残留的英文模式状态已归零")
  end
end

-- ---------- 主逻辑 ----------
local function processor_impl(key, env)
  local ctx = env.engine.context
  local code = key.keycode

  -- 老版本 librime-lua 缺少按键方法时，本脚本自动退化为纯放行
  if type(key.release) ~= "function" then
    return kNoop
  end

  -- Ctrl/Alt/Super 组合键：不参与任何模式逻辑
  -- Ctrl+A 全选、Ctrl+C 复制这类必须原样交给应用。ascii 模式下引擎链上
  -- 会把它当普通字符塞进编码串（实测 preedit 变成 "hea"），所以这里不能
  -- 只 return kNoop，要 kRejected 直接中断处理链。
  local combo = false
  pcall(function() combo = key.ctrl() or key.alt() or key.super() end)
  if not combo then
    -- 兜底：少数版本 key:ctrl() 取不到，直接看 modifier 位
    --   Control = 1<<2，Alt = 1<<3
    local m = 0
    pcall(function() m = key.modifier or 0 end)
    if type(m) == "number" then
      if m % 8 >= 4 then combo = true end                        -- Ctrl
      if math.floor(m / 8) % 2 == 1 then combo = true end        -- Alt
    end
  end
  if combo then
    env.armed = nil
    -- 只有 Ctrl+字母 直接放行（全选/复制/粘贴/撤销这类）；
    -- Ctrl+grave、Ctrl+period、Ctrl+0 这些输入法自身的热键保持原样，
    -- 数字类组合键也不拦，继续往后交给引擎处理
    local is_alpha = (code >= 0x41 and code <= 0x5a)
      or (code >= 0x61 and code <= 0x7a)
    if is_alpha then return kRejected end
    return kNoop
  end

  startup_reset(ctx, env)

  -- ===== Shift 键：单击切换 =====
  if code == XK_Shift_L or code == XK_Shift_R then
    local side = (code == XK_Shift_L) and "L" or "R"
    if not key:release() then
      env.armed = side            -- 按下：武装
      return kNoop
    end
    if env.armed ~= side then     -- 松开时不是单击（组合键）：放行
      env.armed = nil
      return kNoop
    end
    env.armed = nil
    -- ★ 任何英文模式激活中（含原生英文直通），按左右任一 Shift 都回中文
    local ascii = ctx:get_option("ascii_mode")
    if ascii or ctx:get_option(OPT_ENHINT) or ctx:get_option(OPT_LETTER) then
      exit_all(ctx, env)
      dbg("Shift单击 -> 回到中文模式")
      return kAccepted
    end
    clear_composition(ctx)                       -- 清残留组字
    set_page(env, 0)
    page_size(env)                               -- 初始化页大小
    if code == XK_Shift_R then
      set_opt(ctx, OPT_LETTER, false)            -- 两模式互斥（值不变时不发通知）
      set_opt(ctx, OPT_ENHINT, true)
      set_opt(ctx, "ascii_mode", true)           -- 托盘显示"英"
      if type(_G.keke_en_preload) == "function" then pcall(_G.keke_en_preload) end
      dbg("右Shift单击 -> 英文提示模式=开（托盘英）")
    else
      set_opt(ctx, OPT_ENHINT, false)
      set_opt(ctx, OPT_LETTER, true)
      set_opt(ctx, "ascii_mode", true)
      dbg("左Shift单击 -> 单字母上屏模式=开（托盘英）")
    end
    return kAccepted
  end

  -- 其它按键解除武装（Shift 组合键打大写等不会误触发）
  env.armed = nil

  -- ===== 非提示模式 =====
  if not ctx:get_option(OPT_ENHINT) then
    -- 单字母模式标记与实际直通状态自愈（Caps 等外部切换后保持一致）
    if ctx:get_option(OPT_LETTER) and not ctx:get_option("ascii_mode") then
      set_opt(ctx, OPT_LETTER, false)
    end
    return kNoop    -- 全部放行：字母直通交给系统原生机制（=单字母上屏模式）
  end

  -- ===== 英文提示模式 =====
  -- 状态自愈：提示模式开着但英文直通没开（如从 F4 菜单进入），补开
  if not ctx:get_option("ascii_mode") then
    set_opt(ctx, "ascii_mode", true)
  end
  set_opt(ctx, OPT_LETTER, false)          -- 两模式互斥（仅值变化时才设置）
  page_size(env)

  if key:release() then return kAccepted end   -- 释放事件一律吞掉，避免漏到直通

  local composing = ctx:is_composing()
  local input = composing and get_input(ctx) or ""
  if input == "" then set_page(env, 0) end     -- 组字结束/为空：页码归零

  if is_backspace(code) then
    if input == "" then return kNoop end         -- 没在组字：交给应用删字
    pop_char(ctx)
    goto_page(env, 0)                            -- 删字符后回到第 1 页
    return kAccepted
  end

  if is_escape(code) then
    exit_all(ctx, env)
    dbg("Esc -> 退出英文提示模式")
    return kAccepted
  end

  if is_return(code) then
    if input == "" then return kNoop end
    commit_and_reset(ctx, env, input)            -- 原样上屏
    return kAccepted
  end

  if code == 0x20 then                           -- 空格：首选候选 + 空格
    if input == "" then return kNoop end
    commit_and_reset(ctx, env, top_word(env, input) .. " ")
    return kAccepted
  end

  -- '-' 或 Page_Up（候选窗左侧箭头）：上一页
  -- 首页的 '-' 仍当连字符（e-mail 这类词），首页的 Page_Up 直接吞掉
  if code == 0x2d or code == XK_Page_Up then
    if input == "" then return kNoop end
    local page = get_page(env)
    if page > 0 then
      goto_page(env, page - 1)
      return kAccepted
    end
    if code == XK_Page_Up then return kAccepted end
    push_char(ctx, "-")
    set_page(env, 0)
    return kAccepted
  end

  -- '=' 或 Page_Down（候选窗右侧箭头）：下一页
  if code == 0x3d or code == XK_Page_Down then
    if input == "" then return kNoop end
    local size = page_size(env)
    local page = get_page(env)
    if (page + 1) * size < total_of(input) then
      goto_page(env, page + 1)
    end
    return kAccepted                             -- 已是最后一页：吞掉，不污染输入
  end

  if code >= 0x31 and code <= 0x39 then          -- 数字 1-9：选当前页第 n 个候选
    if input == "" then return kNoop end         -- 没在组字：数字直通给应用
    local list = words_of(input)
    local idx = get_page(env) * page_size(env) + (code - 0x30)
    local word = list[idx]
    if word then
      commit_and_reset(ctx, env, word)           -- 词典与候选窗同源，必然一致
    else
      set_page(env, 0)
    end
    return kAccepted                             -- 无论成功与否都吞掉，绝不再漏出去
  end

  if code >= 0x21 and code <= 0x7e then          -- 可打印字符
    local ch = string.char(code)
    local word_char = is_word_char(ch)
    -- 撇号/连字符只有在单词中才算单词字符（开头直接打视为标点）
    if word_char and (ch == "'" or ch == "-") and input == "" then
      word_char = false
    end
    if word_char then
      -- Shift+字母 = 大写（保持输入的大小写，供词典生成对应形态的候选）
      local shifted = false
      pcall(function() shifted = key:shift() end)
      if shifted then ch = ch:upper() end
      push_char(ctx, ch)                         -- 组字重建，候选从第 1 页开始
      goto_page(env, 0)
      return kAccepted
    end
    -- 标点：单词自然收尾（词+标点一起上屏）
    if input ~= "" then
      commit_and_reset(ctx, env, top_word(env, input) .. ch)
    else
      commit_and_reset(ctx, env, ch)             -- 无单词时标点原样输出（保证英文标点）
    end
    return kAccepted
  end

  return kNoop                                   -- 方向键等其余按键放行
end

local function processor(key, env)
  local ok, result = pcall(processor_impl, key, env)
  if ok and result ~= nil then
    return result
  end
  return kNoop   -- 出错或无返回：交给下一个处理器，绝不中断处理链
end

return processor
