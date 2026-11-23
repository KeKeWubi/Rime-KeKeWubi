-- keke_wubi_fuzzy_z.lua  （v2：紧凑二进制索引版）
--
-- 功能不变：打开"万能Z"后，编码里打 z 可代任意字母，从这里把匹配到的单字吐出来。
--
-- 为什么重写：
--   旧版把三本词典的 10 万个单字全部塞进 Lua 表（dict_map[code] = {字, tier, 字, tier...}），
--   实测常驻 17.7MB —— 其中 6.6 万个"编码键"每个都要一个 Lua table 对象，
--   光这部分就占大头；而且 static_global_dict 是模块级变量，关掉万能Z 也永不释放，
--   所以内存"只涨不落"，Windows 上撞到 40MB+ 就开始卡。
--
-- 现在的做法：
--   把 (编码, 词, tier) 预打包成一个二进制索引文件 keke_fuzzy_z_<ver>.idx，
--   运行时只读成【一个大字符串】（1.4MB），靠二分查找定位，零 Lua 对象开销。
--   10 万条 → 1.4MB，省掉 16MB。
--
--   idx 缺失或与词典不匹配（用户改过词典）时，自动退回旧的全表扫描方式，
--   功能不受影响，只是内存回到老样子。

local str_sub   = string.sub
local str_find  = string.find
local str_match = string.match
local str_rep   = string.rep
local str_char  = string.char
local str_gsub  = string.gsub
local str_unpack = string.unpack
local utf8_len  = utf8.len
local io_open   = io.open
local ipairs    = ipairs
local floor     = math.floor
local table_insert = table.insert
local table_sort   = table.sort

local MAX_CODES   = 300    -- 单次最多展开多少个编码（沿用旧版上限）
local MAX_MATCHES = 800    -- 单次最多产出多少个候选（旧版无上限，是卡顿主因之一）

local M = {}

-- ────────────────────────── 词典定位 ──────────────────────────

local function user_dir()
  local ok, api = pcall(function() return rime_api end)
  if ok and api and api.get_user_data_dir then
    local ok2, d = pcall(function() return api:get_user_data_dir() end)
    if ok2 and d and d ~= "" then return d end
  end
  return ""
end

local function shared_dir()
  local ok, api = pcall(function() return rime_api end)
  if ok and api and api.get_shared_data_dir then
    local ok2, d = pcall(function() return api:get_shared_data_dir() end)
    if ok2 and d and d ~= "" then return d end
  end
  return ""
end

local function make_paths(name)
  local sep = package.config:sub(1, 1)
  local ud, sd = user_dir(), shared_dir()
  local p = {}
  if ud ~= "" then
    p[#p + 1] = ud .. sep .. name
    p[#p + 1] = ud .. sep .. "lua" .. sep .. name
  end
  if sd ~= "" then
    p[#p + 1] = sd .. sep .. name
    p[#p + 1] = sd .. sep .. "lua" .. sep .. name
  end
  p[#p + 1] = name
  return p
end

local function open_first(name, mode)
  for _, path in ipairs(make_paths(name)) do
    local f = io_open(path, mode or "r")
    if f then return f end
  end
  return nil
end

local function file_size(name)
  local f = open_first(name .. ".dict.yaml", "rb")
  if not f then return nil end
  local ok, sz = pcall(function() return f:seek("end") end)
  f:close()
  if ok then return sz end
  return nil
end

-- ────────────────────────── 后端 A：二进制索引 ──────────────────────────

-- 按方案缓存：86/98/nc 三套方案共用同一个 lua 模块实例，必须分开存
local idx_cache = {}       -- [ver] = { s = entries 串, data = 数据串, n = 条数 } 或 false（表示不可用）

-- 从 idx 里找 q 对应的 [first, last] 区间
local function find_range(s, n, q)
  local l, r = 1, n + 1
  while l < r do
    local mid = floor((l + r) / 2)
    if str_unpack("<I4", s, (mid - 1) * 8 + 1) < q then l = mid + 1 else r = mid end
  end
  local first = l
  if first > n then return first, first - 1 end
  l, r = first, n + 1
  while l < r do
    local mid = floor((l + r) / 2)
    if str_unpack("<I4", s, (mid - 1) * 8 + 1) <= q then l = mid + 1 else r = mid end
  end
  return first, l - 1
end

local function load_idx(prefix, names)
  local cached = idx_cache[prefix]
  if cached ~= nil then return cached or nil end
  if type(str_unpack) ~= "function" then     -- Lua 5.2 及更早没有 pack
    idx_cache[prefix] = false
    return nil
  end

  local f = open_first("keke_fuzzy_z_" .. prefix .. ".idx", "rb")
  if not f then idx_cache[prefix] = false; return nil end
  local ok, blob = pcall(function() return f:read("a") end)
  f:close()
  if not ok or not blob or #blob < 24 or str_sub(blob, 1, 4) ~= "KKEZ" then
    idx_cache[prefix] = false; return nil
  end

  local ver, n, sig, dlen = str_unpack("<BxxxIII", blob, 5)
  if ver ~= 1 or n < 1 then idx_cache[prefix] = false; return nil end

  -- 签名：三本词典的文件大小 + 条数，防止用户改了词典还用旧索引
  local s2 = 0
  local complete = true
  for _, name in ipairs(names) do
    local sz = file_size(name)
    if not sz then complete = false; break end
    s2 = (s2 * 131 + sz) & 0xFFFFFFFF
  end
  if not complete then idx_cache[prefix] = false; return nil end
  s2 = (s2 ~ n) & 0xFFFFFFFF
  if s2 ~= sig then idx_cache[prefix] = false; return nil end

  local entry_at = 25
  if #blob < entry_at - 1 + n * 8 + dlen then idx_cache[prefix] = false; return nil end

  local rec = {
    s = str_sub(blob, entry_at, entry_at + n * 8 - 1),
    data = str_sub(blob, entry_at + n * 8, entry_at + n * 8 + dlen - 1),
    n = n,
  }
  idx_cache[prefix] = rec
  return rec
end

-- ────────────────────────── 后端 B：旧的全表扫描（兜底） ──────────────────────────

local static_global_dict = nil
local dict_already_loaded = false

local function is_single_char(str)
  if utf8 and utf8_len then return utf8_len(str) == 1 end
  local count = 0
  for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
    if count > 1 then return false end
  end
  return count == 1
end

local function load_single_dict(dict_name, tier, dict_map)
  local f = open_first(dict_name .. ".dict.yaml", "r")
  if not f then return end
  local in_header = true
  local line, word, code
  for line in f:lines() do
    if in_header then
      if str_sub(line, 1, 3) == "..." then in_header = false end
    else
      if not str_find(line, "^%s*#") and not str_find(line, "^%s*$") then
        word, code = str_match(line, "^([^\t]+)\t([a-z]+)")
        if word and code and is_single_char(word) then
          local list = dict_map[code]
          if not list then list = {}; dict_map[code] = list end
          local exists = false
          for i = 1, #list, 2 do
            if list[i] == word then exists = true; break end
          end
          if not exists then
            table_insert(list, word)
            table_insert(list, tier)
          end
        end
      end
    end
  end
  f:close()
end

local function ensure_table_dict(env, prefix, names)
  if static_global_dict then
    env.dict_map = static_global_dict
    env.loaded = true
    return static_global_dict
  end
  if env.loaded and env.dict_map then return env.dict_map end

  local dict_map = {}
  for i, name in ipairs(names) do
    load_single_dict(name, i, dict_map)
  end
  static_global_dict = dict_map
  dict_already_loaded = true
  env.dict_map = dict_map
  env.loaded = true
  collectgarbage("step", 120)
  return dict_map
end

-- ────────────────────────── 编码展开（带缓存） ──────────────────────────

local function expand_z(pos_list, index, current_code, results)
  if #results >= MAX_CODES then return end
  if index > #pos_list then
    table_insert(results, current_code)
    return
  end
  local pos = pos_list[index]
  local prefix = str_sub(current_code, 1, pos - 1)
  local suffix = str_sub(current_code, pos + 1)
  for ascii = 97, 121 do -- a-y
    expand_z(pos_list, index + 1, prefix .. str_char(ascii) .. suffix, results)
    if #results >= MAX_CODES then break end
  end
end

local function get_expanded_codes(code_str)
  local pos_list = {}
  for i = 1, #code_str do
    if str_sub(code_str, i, i) == "z" then table_insert(pos_list, i) end
  end
  if #pos_list > 3 then return {} end
  local results = {}
  expand_z(pos_list, 1, code_str, results)
  return results
end

-- 编码 → 量化整数（与生成脚本完全一致：len * 2^20 + 26 进制值）
local function q_of(code)
  local len = #code
  if len < 1 or len > 4 then return nil end
  local v = 0
  for i = 1, len do
    local b = str_find(code, "[a-z]", i)
    if b ~= i then return nil end
    v = v * 26 + (code:byte(i) - 97)
  end
  return len * 1048576 + v
end

-- ────────────────────────── 主流程 ──────────────────────────

-- 读 schema 配置得到"当前是哪套方案"。注意必须在 func 里做：
-- init 阶段 env.engine.schema 可能还没准备好，在那里取会抛错、整个 translator 被禁用。
local function prepare(env)
  if env.dict_names then return end
  local prefix = "keke_wubi_86"
  pcall(function()
    local cfg = env.engine.schema.config
    local main_dict = cfg:get_string("translator/dictionary")
    if type(main_dict) == "string" and main_dict ~= "" then
      prefix = str_gsub(str_gsub(str_gsub(main_dict, "_common$", ""), "_system$", ""), "_rare$", "")
    end
  end)
  env.dict_prefix = prefix
  env.dict_ver = str_match(prefix, "keke_wubi_(%w+)$") or "86"
  -- 目录布局：入口词典 keke_wubi_XX_common 在 Rime 根目录，
  -- 其余词典（含 system / rare）统一放在 keke_wubi_dict/ 子目录
  -- （librime 不支持入口词典带子目录）。
  local sub = "keke_wubi_dict/" .. prefix .. "_"
  env.dict_names = {                 -- 层级序，与生成脚本算签名时一致
    prefix .. "_common",
    sub .. "system",
    sub .. "rare",
  }
  env.dict_tier_names = {            -- 词频层级序
    prefix .. "_common",
    sub .. "system",
    sub .. "rare",
  }
end

function M.init(env)
  env.loaded = false
  env.dict_map = nil
end

function M.func(input, seg, env)
  prepare(env)
  local context = env.engine.context
  if not context:get_option("fuzzy_z") then
    -- 关掉万能Z：把索引和兜底表都放掉（下次要用再读，1.4MB 读盘只要几毫秒）
    if next(idx_cache) ~= nil then idx_cache = {} end
    if env.loaded or static_global_dict then
      env.dict_map = nil
      env.loaded = false
      static_global_dict = nil
      dict_already_loaded = false
      collectgarbage("step", 200)
    end
    return
  end
  if not str_find(input, "z") then return end
  if #input > 4 then return end

  -- 后端选择：优先二进制索引
  local use_idx = load_idx(env.dict_ver or "86", env.dict_names)
  local dict_map = nil
  if not use_idx then
    dict_map = ensure_table_dict(env, env.dict_prefix, env.dict_tier_names)
    if not dict_map then return end
  end

  local input_len = #input
  local max_len = (input == "z") and 3 or 4

  -- 复用临时表：每次按键都新建 500 个 table 是卡顿的主要来源之一，
  -- 挂到 env 上跨按键复用，只清内容不重新分配。
  local scratch = env.scratch
  if not scratch then
    scratch = { seen = {}, order = {}, mw = {}, mc = {}, mt = {}, me = {}, ml = {} }
    env.scratch = scratch
  end
  local seen, order = scratch.seen, scratch.order
  local mw, mc, mt, me, ml = scratch.mw, scratch.mc, scratch.mt, scratch.me, scratch.ml
  for k in pairs(seen) do seen[k] = nil end
  local nm = 0

  local full = false
  for len = input_len, max_len do
    if full then break end
    local padded = input .. str_rep("z", len - input_len)
    local codes = get_expanded_codes(padded)
    for _, code in ipairs(codes) do
      local sw = seen[code]
      if not sw then sw = {}; seen[code] = sw end
      if use_idx then
        local q = q_of(code)
        if q then
          local first, last = find_range(use_idx.s, use_idx.n, q)
          for i = first, last do
            local _, off = str_unpack("<I4I4", use_idx.s, (i - 1) * 8 + 1)
            local wlen, tier = str_unpack("<BB", use_idx.data, off + 1)
            local word = str_sub(use_idx.data, off + 3, off + 2 + wlen)
            if not sw[word] then
              sw[word] = true
              nm = nm + 1
              mw[nm], mc[nm], mt[nm] = word, code, tier
              me[nm], ml[nm] = (len == input_len), len
              if nm >= MAX_MATCHES then full = true; break end
            end
          end
        end
      else
        local list = dict_map[code]
        if list then
          for i = 1, #list, 2 do
            local word, tier = list[i], list[i + 1]
            if not sw[word] then
              sw[word] = true
              nm = nm + 1
              mw[nm], mc[nm], mt[nm] = word, code, tier
              me[nm], ml[nm] = (len == input_len), len
              if nm >= MAX_MATCHES then full = true; break end
            end
          end
        end
      end
      if full then break end
    end
  end
  if nm == 0 then return end

  for i = nm + 1, #order do order[i] = nil end   -- 先截断，否则 sort 会排到上次的残留元素
  for i = 1, nm do order[i] = i end
  table_sort(order, function(a, b)
    if me[a] ~= me[b] then return me[a] end
    if mt[a] ~= mt[b] then return mt[a] < mt[b] end
    if ml[a] ~= ml[b] then return ml[a] < ml[b] end
    return mc[a] < mc[b]
  end)

  for i = 1, nm do
    local k = order[i]
    yield(Candidate("table", seg.start, seg._end, mw[k], "[" .. mc[k] .. "]"))
  end
  for i = nm + 1, #order do order[i] = nil end
  collectgarbage("step", 60)
end

return M
