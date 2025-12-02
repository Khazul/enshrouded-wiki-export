local jsonEnc = {}

-- JSON encoder with:
--  * __type = "object"   → force table to be an object. Most useful for empty tables
--  * skip fields beginning with "__"
--  * indentation + pretty output

local function escape_json_string(s)
    s = s:gsub("\\", "\\\\")
         :gsub("\"", "\\\"")
         :gsub("\n", "\\n")
         :gsub("\r", "\\r")
         :gsub("\t", "\\t")

    -- Escape control characters (0x00–0x1F)
    s = s:gsub("[%z\1-\31]", function(c)
        return string.format("\\u%04x", string.byte(c))
    end)

    return "\"" .. s .. "\""
end

local function encode_value(v, indent, level, hidePrefix)
    local t = type(v)

    if t == "string" then
        return escape_json_string(v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        return encode_table(v, indent, level, hidePrefix)
    elseif t == "nil" then
        return "null"
    else
        error("Unsupported type in JSON: " .. t)
    end
end

-- Forward declaration
function encode_table(tbl, indent, level, hidePrefix)
    local isObject = (tbl.__type == "object")

    -- Remove "__type" and any "__something"
    local items = {}
    for k, v in pairs(tbl) do
        if type(k) == "string" and k:sub(1, #hidePrefix) == hidePrefix then
            -- skip private/internal fields
        else
            items[#items + 1] = { key = k, value = v }
        end
    end

    -- Empty table case
    if #items == 0 then
        return isObject and "{}" or "[]"
    end

    local nextLevel = level + 1
    local prefix = string.rep(indent, nextLevel)
    local sep = ",\n"

    if isObject then
        -- JSON object
        local out = "{\n"
        for i, kv in ipairs(items) do
            local k = tostring(kv.key)
            local v = encode_value(kv.value, indent, nextLevel, hidePrefix)
            out = out .. prefix .. string.format("%q: %s", k, v)
            if i < #items then out = out .. sep end
        end
        return out .. "\n" .. string.rep(indent, level) .. "}"
    else
        -- JSON array
        local out = "[\n"
        for i, kv in ipairs(items) do
            local v = encode_value(kv.value, indent, nextLevel, hidePrefix)
            out = out .. prefix .. v
            if i < #items then out = out .. sep end
        end
        return out .. "\n" .. string.rep(indent, level) .. "]"
    end
end

function jsonEnc.encode(tbl, inden, hide_)
    local hidePrefix = "__"
    if hide_ == true then 
        hidePrefix = "_" 
    end
    return encode_table(tbl, indent or "  ", 0, hidePrefix)
end

return jsonEnc
