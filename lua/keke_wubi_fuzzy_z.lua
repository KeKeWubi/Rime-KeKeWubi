-- keke_wubi_fuzzy_z.lua
local str_sub = string.sub
local str_find = string.find
local str_match = string.match
local str_rep = string.rep
local str_char = string.char
local str_gsub = string.gsub
local utf8_len = utf8.len
local io_open = io.open
local ipairs = ipairs
local tonumber = tonumber
local table_insert = table.insert

local static_global_dict = nil
local dict_already_loaded = false

local M = {}
local function is_single_char(str)
    if utf8 and utf8_len then
        return utf8_len(str) == 1
    end
    local count = 0
    for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > 1 then return false end
    end
    return count == 1
end

local function open_dict_file(dict_name)
    local user_dir = rime_api and rime_api.get_user_data_dir and rime_api.get_user_data_dir() or ""
    local shared_dir = rime_api and rime_api.get_shared_data_dir and rime_api.get_shared_data_dir() or ""
    local sep = package.config:sub(1,1)
    local paths = {
        user_dir .. sep .. dict_name .. ".dict.yaml",
        shared_dir .. sep .. dict_name .. ".dict.yaml",
        dict_name .. ".dict.yaml"
    }
    
    for _, p in ipairs(paths) do
        if p ~= "" then
            local f = io_open(p, "r")
            if f then return f end
        end
    end
    return nil
end

local function load_single_dict(dict_name, tier, dict_map)
    local f = open_dict_file(dict_name)
    if not f then return end
    local in_header = true
    local line, word, code
    for line in f:lines() do
        if in_header then
            if str_sub(line, 1, 3) == "..." then
                in_header = false
            end
        else
            if not str_find(line, "^%s*#") and not str_find(line, "^%s*$") then
                word, code = str_match(line, "^([^\t]+)\t([a-z]+)")
                if word and code and is_single_char(word) then
                    local list = dict_map[code]
                    if not list then
                        list = {}
                        dict_map[code] = list
                    end
                    
                    local exists = false
                    for i = 1, #list, 2 do
                        if list[i] == word then
                            exists = true
                            break
                        end
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

local function unload_dict(env)
    if env.loaded then
        env.dict_map = nil
        env.loaded = false
        collectgarbage("step", 80)
    end
end

local function ensure_dict_loaded(env)
    if dict_already_loaded then
        env.dict_map = static_global_dict
        env.loaded = true
        return
    end
    if env.loaded then return end
    
    local config = env.engine.schema.config
    local main_dict = config:get_string("translator/dictionary") or "keke_wubi_86_common"
    local prefix = str_gsub(str_gsub(str_gsub(main_dict, "_common$", ""), "_system$", ""), "_rare$", "")
    
    local dict_map = {}
    load_single_dict(prefix .. "_common", 1, dict_map)
    load_single_dict(prefix .. "_system", 2, dict_map)
    load_single_dict(prefix .. "_rare",   3, dict_map)
    
    static_global_dict = dict_map
    dict_already_loaded = true
    env.dict_map = dict_map
    env.loaded = true
    collectgarbage("step", 120)
end

local function expand_z(pos_list, index, current_code, results)
    if #results > 300 then return end
    if index > #pos_list then
        table_insert(results, current_code)
        return
    end
    local pos = pos_list[index]
    local prefix = str_sub(current_code, 1, pos - 1)
    local suffix = str_sub(current_code, pos + 1)
    for ascii = 97, 121 do -- a-y
        expand_z(pos_list, index + 1, prefix .. str_char(ascii) .. suffix, results)
        if #results > 300 then break end
    end
end

local function get_expanded_codes(code_str)
    local pos_list = {}
    for i = 1, #code_str do
        if str_sub(code_str, i, i) == "z" then
            table_insert(pos_list, i)
        end
    end
    if #pos_list > 3 then return {} end
    local results = {}
    expand_z(pos_list, 1, code_str, results)
    return results
end

function M.init(env)
    env.loaded = false
    env.dict_map = nil
end

function M.func(input, seg, env)
    local context = env.engine.context
    if not context:get_option("fuzzy_z") then
        unload_dict(env)
        return
    end
    if not str_find(input, "z") then
        unload_dict(env)
        return
    end
    ensure_dict_loaded(env)
    if not env.dict_map then return end
    local input_len = #input
    if input_len > 4 then return end
    local matches = {}
    local seen = {}
    local max_len = (input == "z") and 3 or 4
    local padded_input, codes, list, word, code, tier, key, item
    for len = input_len, max_len do
        padded_input = input .. str_rep("z", len - input_len)
        codes = get_expanded_codes(padded_input)
        for _, code in ipairs(codes) do
            list = env.dict_map[code]
            if list then
                for i = 1, #list, 2 do
                    word = list[i]
                    tier = list[i+1]
                    key = word .. "_" .. code
                    if not seen[key] then
                        seen[key] = true
                        table_insert(matches, {
                            word = word,
                            code = code,
                            tier = tier,
                            is_exact = (#code == input_len),
                            len = #code
                        })
                    end
                end
            end
        end
    end
    table.sort(matches, function(a, b)
        if a.is_exact ~= b.is_exact then
            return a.is_exact
        end
        if a.tier ~= b.tier then
            return a.tier < b.tier
        end
        if a.len ~= b.len then
            return a.len < b.len
        end
        return a.code < b.code
    end)
    for _, item in ipairs(matches) do
        yield(Candidate("table", seg.start, seg._end, item.word, "[" .. item.code .. "]"))
    end
    collectgarbage("step", 60)
end
return M
