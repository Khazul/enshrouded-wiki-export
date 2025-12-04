local jsonEnc = {}

-- JSON encoder with:
--  * __type = "object"   → force table to be an object. Most useful for empty tables
--  * skip fields beginning with "__"
--  * indentation + pretty output

local function escape_json_string(s)
    return s
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function is_array(tbl)
    -- Arrays NEVER have __type = "object"
    if tbl.__type == "object" then
        return false
    end

    -- Sequential integer keys? (1..n)
    local count = 0
    for k in pairs(tbl) do
        if type(k) == "number" and k > 0 and math.floor(k) == k then
            count = count + 1
        else
            return false
        end
    end

    -- Must have all indexes 1..count
    for i = 1, count do
        if tbl[i] == nil then return false end
    end

    return true
end

local function encode_value(v, indent, level, hidePrefix)
    local t = type(v)

    if t == "string" then
        return '"' .. escape_json_string(v) .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "nil" then
        return "null"
    elseif t == "table" then
        return encode_table(v, indent, level, hidePrefix)
    else
        error("Unsupported JSON type: " .. t)
    end
end

-- Forward declaration
function encode_table(tbl, indent, level, hidePrefix)

    indent = indent or "  "
    level = level or 0

    local pad = string.rep(indent, level)
    local pad_inner = string.rep(indent, level + 1)

    -- JSON ARRAY
    if is_array(tbl) then
        local parts = {}
        for i = 1, #tbl do
            table.insert(parts, pad_inner .. encode_value(tbl[i], indent, level + 1, hidePrefix))
        end

        if #parts == 0 then
            return "[]"
        end

        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    end

    -- JSON OBJECT
    local keys = {}
    for k, _ in pairs(tbl) do
        if type(k) == "string" and k:sub(1, #hidePrefix) == hidePrefix then
            -- skip private/internal fields
        else
            table.insert(keys, k)
        end
    end

    table.sort(keys)

    local parts = {}
    for _, k in ipairs(keys) do
        local v = tbl[k]
        table.insert(
            parts,
            pad_inner .. '"' .. escape_json_string(k) .. '": ' .. encode_value(v, indent, level + 1, hidePrefix)
        )
    end

    if #parts == 0 then
        return "{}"
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

function jsonEnc.encode(tbl, indent, hide_)
    local hidePrefix = "__"
    if hide_ == true then 
        hidePrefix = "_" 
    end
    return encode_table(tbl, indent or "  ", 0, hidePrefix)
end

return jsonEnc
