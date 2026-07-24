-- keke_wubi_fuzzy_z.lua

local M = {}

local function is_single_char(str)
    if utf8 and utf8.len then
        return utf8.len(str) == 1
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
    
    local paths = {
        user_dir .. "/" .. dict_name .. ".dict.yaml",
        user_dir .. "\\" .. dict_name .. ".dict.yaml",
        shared_dir .. "/" .. dict_name .. ".dict.yaml",
        dict_name .. ".dict.yaml"
    }
    
    for _, p in ipairs(paths) do
        if p ~= "" then
            local f = io.open(p, "r")
            if f then return f end
        end
    end
    return nil
end

local function load_single_dict(dict_name, tier, dict_map)
    local f = open_dict_file(dict_name)
    if not f then return end

    local in_header = true
    for line in f:lines() do
        if in_header then
            if line:sub(1, 3) == "..." then
                in_header = false
            end
        else
            if not line:find("^%s*#") and not line:find("^%s*$") then
                local word, code = line:match("^([^\t]+)\t([a-z]+)")
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
                        table.insert(list, word)
                        table.insert(list, tier)
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
        collectgarbage("collect")
        collectgarbage("collect")
    end
end

local function ensure_dict_loaded(env)
    if env.loaded then return end
    
    local config = env.engine.schema.config
    local main_dict = config:get_string("translator/dictionary") or "keke_wubi_86_common"
    local prefix = main_dict:gsub("_common$", ""):gsub("_system$", ""):gsub("_rare$", "")
    
    local dict_map = {}
    load_single_dict(prefix .. "_common", 1, dict_map)
    load_single_dict(prefix .. "_system", 2, dict_map)
    load_single_dict(prefix .. "_rare",   3, dict_map)
    
    env.dict_map = dict_map
    env.loaded = true

    collectgarbage("collect")
end

function M.init(env)
    env.loaded = false
    env.dict_map = nil
end

local function expand_z(pos_list, index, current_code, results)
    if index > #pos_list then
        table.insert(results, current_code)
        return
    end
    local pos = pos_list[index]
    local prefix = current_code:sub(1, pos - 1)
    local suffix = current_code:sub(pos + 1)
    for ascii = 97, 121 do -- a-y
        expand_z(pos_list, index + 1, prefix .. string.char(ascii) .. suffix, results)
    end
end

local function get_expanded_codes(code_str)
    local pos_list = {}
    for i = 1, #code_str do
        if code_str:sub(i, i) == "z" then
            table.insert(pos_list, i)
        end
    end
    local results = {}
    expand_z(pos_list, 1, code_str, results)
    return results
end

function M.func(input, seg, env)
    local context = env.engine.context
    if not context:get_option("fuzzy_z") then
        unload_dict(env)
        return
    end

    if not input:find("z") then
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

    for len = input_len, max_len do
        local padded_input = input .. string.rep("z", len - input_len)
        local codes = get_expanded_codes(padded_input)

        for _, code in ipairs(codes) do
            local list = env.dict_map[code]
            if list then
                for i = 1, #list, 2 do
                    local word = list[i]
                    local tier = list[i+1]
                    local key = word .. "_" .. code
                    if not seen[key] then
                        seen[key] = true
                        table.insert(matches, {
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
end

return M