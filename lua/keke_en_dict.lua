-- 可可五笔 英文词典共享模块  （v2：紧凑存储版）
-- keke_en_dict.lua   （被 lua_translator 与 lua_processor 共同 require）
--
-- 为什么单独成一个模块：
--   英文提示模式的"上屏"（空格/数字选词/标点）需要【当下】就知道候选是什么。
--   如果靠回读引擎的候选菜单（ctx:select / get_selected_candidate），会遇到
--   三个坑：① 翻译器产出候选是延迟的，第一个按键时菜单还没就绪，读回来是 nil；
--   ② librime-lua 的 ctx:select(n) 不是"高亮第 n 个"，而是【立即提交】并清空组字；
--   ③ 选词一旦失败，处理器只能返回 kNoop，按键就漏给引擎的 ascii 直通逻辑，
--      于是"BA"上屏的同时"2"也进了应用 → "BA2"，残留输入还让下一键变"bb"。
--   本模块让翻译器和处理器用同一份词典、同一套匹配规则，
--   处理器不再依赖引擎时序，结果完全确定。
--
-- v2 为什么改存储结构：
--   旧的 buckets[letter] = { low = {...}, orig = {...} } 会为 5.8 万个词各建两个
--   Lua 字符串对象，实测常驻 5.4MB（进一次英文模式，进程就从 7.9MB 涨到 13.8MB，
--   而且不退出就永不释放）。
--   现在把"全部小写词"和"全部原词"各拼成【一个大字符串】，词与词之间用 \n 分隔，
--   每个首字母桶只存"词首偏移"的整数数组。同样 5.8 万词只需 1.5MB，省 3.9MB。
--   加载也是分块拼接，避免建表期间出现 5MB 级瞬时峰值。
--
-- 词典位置（按顺序查找，取第一个存在的）：
--   1) <用户目录>/keke_wubi_dict/english_words.txt  ← 推荐，与其它被导入词库放一起
--   2) <用户目录>/global/english_words.txt          ← 兼容旧位置
--   3) <用户目录>/english_words.txt                 ← 兼容旧位置
--   4) <用户目录>/lua/english_words.txt             ← 兼容旧位置
--   5) <共享目录>/keke_wubi_dict/english_words.txt
--   6) <共享目录>/english_words.txt
--
-- 词典格式：每行一个单词，行的先后决定候选先后。支持小写词、首字母大写词、
--   全大写词（USA）、连字符词（e-mail）、撇号词（don't）；含空格的词组忽略。
--
-- 匹配规则（与主流输入法一致）：
--   匹配永远不区分大小写（小写输入也能找到 Mr/USA）；
--   输出形态跟随输入形态：hel→原样、Hel→首字母大写、HEL→全大写。

local M = {}

local DICT_NAME = "english_words.txt"
local CAP = 200            -- 单次最多返回的候选数（够翻很多页，也避免长列表卡顿）
local CHUNK = 8192         -- 加载时每多少行合并一次，控制内存峰值

local dict = nil           -- { blob = 小写串, raw = 原词串, buckets = { [字母] = {偏移...} } }

local str_find = string.find
local str_sub  = string.sub

local function search_dirs()
  local dirs = {}
  local ok, api = pcall(function() return rime_api end)
  if ok and api then
    pcall(function()
      if api.get_user_data_dir then dirs[#dirs + 1] = api:get_user_data_dir() end
    end)
    pcall(function()
      if api.get_shared_data_dir then dirs[#dirs + 1] = api:get_shared_data_dir() end
    end)
  end
  return dirs
end

local function read_dict(d, path)
  local fh = io.open(path, "r")
  if not fh then return false end

  local raw_parts, low_parts = {}, {}
  local raw_chunks, low_chunks = {}, {}
  local pending = 0
  local buckets = {}
  local off = 0
  local first = true

  for line in fh:lines() do
    local word = line:match("^%s*(.-)%s*$")          -- 去首尾空白
    if first then
      first = false
      word = word:gsub("^\239\187\191", "")          -- 去掉 UTF-8 BOM
    end
    if word ~= "" and word:match("^[%a'%-]+$") then
      local low = word:lower()
      local k = str_sub(low, 1, 1)
      local list = buckets[k]
      if not list then list = {}; buckets[k] = list end
      list[#list + 1] = off + 1     -- 记 1 基位置，直接喂给 string.find/sub

      raw_parts[#raw_parts + 1] = word
      raw_parts[#raw_parts + 1] = "\n"
      low_parts[#low_parts + 1] = low
      low_parts[#low_parts + 1] = "\n"

      off = off + #word + 1
      pending = pending + 1
      if pending >= CHUNK then
        raw_chunks[#raw_chunks + 1] = table.concat(raw_parts)
        low_chunks[#low_chunks + 1] = table.concat(low_parts)
        raw_parts, low_parts = {}, {}
        pending = 0
      end
    end
  end
  fh:close()

  if pending > 0 then
    raw_chunks[#raw_chunks + 1] = table.concat(raw_parts)
    low_chunks[#low_chunks + 1] = table.concat(low_parts)
  end

  d.raw = table.concat(raw_chunks)
  d.blob = table.concat(low_chunks)
  d.buckets = buckets
  -- 分块拼接期间会产生几百 KB 临时串，这里收一次，让 Lua 把空闲页还给系统，
  -- 否则进程 RSS 会一直停在峰值上（用户看到的"进过英文模式就降不回去"）
  collectgarbage("collect")
  return true
end

-- 加载词典（只读一次，之后走缓存）
function M.load()
  if dict then return dict end
  local d = {}
  dict = d                     -- 先占位，避免加载失败时反复重试
  for _, dir in ipairs(search_dirs()) do
    if read_dict(d, dir .. "/keke_wubi_dict/" .. DICT_NAME) then return d end
    if read_dict(d, dir .. "/global/" .. DICT_NAME) then return d end
    if read_dict(d, dir .. "/" .. DICT_NAME) then return d end
    if read_dict(d, dir .. "/lua/" .. DICT_NAME) then return d end
  end
  return d
end

-- 处理器/翻译器共用同一个上限，保证"候选窗里有几个"和"能翻几页"完全一致
M.CAP = CAP

-- 释放词典（内存紧张时调用；下次 words() 会自动重新加载）
function M.unload()
  dict = nil
end

-- 查询候选：返回数组（可能为空表）。精确命中排最前，其后是前缀匹配。
function M.words(input)
  if type(input) ~= "string" or input == "" then return {} end
  if not input:match("^[%a'%-]+$") then return {} end

  local d = M.load()
  local blob, raw = d.blob, d.raw
  local buckets = d.buckets
  if not blob or not buckets then return {} end

  local li = input:lower()
  local offs = buckets[str_sub(li, 1, 1)]
  if not offs then return {} end

  local all_lower = (input == li)
  local all_upper = (input == input:upper())
  local li_len = #li

  local res, seen = {}, {}
  local n = 0
  local same, ci, pre = {}, {}, {}      -- 三轮：形态一致 / 其它精确 / 前缀

  for i = 1, #offs do
    local off = offs[i]
    local e = str_find(blob, "\n", off, true)
    local low = str_sub(blob, off, e - 1)
    if low == li then
      local orig = str_sub(raw, off, e - 1)
      if orig == input then same[#same + 1] = orig else ci[#ci + 1] = orig end
    elseif str_sub(low, 1, li_len) == li then
      pre[#pre + 1] = str_sub(raw, off, e - 1)
    end
  end

  local function push(word)
    local text
    if all_lower then text = word
    elseif all_upper then text = word:upper()
    else text = str_sub(word, 1, 1):upper() .. str_sub(word, 2) end
    if seen[text] then return true end
    seen[text] = true
    n = n + 1
    res[n] = text
    return n < CAP
  end

  for _, w in ipairs(same) do if not push(w) then return res end end
  for _, w in ipairs(ci)   do if not push(w) then return res end end
  for _, w in ipairs(pre)  do if not push(w) then return res end end
  return res
end

return M
