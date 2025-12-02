--- Khazul-SkillTweaks mod
--- @Author Khazul
--- @Github https://github.com/Khazul/enshrouded-skill-tweaks
--- @description Table utilities

--- Creates a shallow copy of the given table.
-- Only the top-level keys and values are copied; nested tables are referenced.
-- @param t table The table to copy.
-- @return table A new table with the same key-value pairs as the input table.
-- TODO: move to own src
function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

--- Counts the number of key-value pairs in a table.
-- @param t table The table to count elements in.
-- @return number The number of elements in the table.
-- TODO: move to own src
function table.count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function table.is_array(t)
    if type(t) ~= "table" then
        return false
    end

    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
    end

    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end

    return true
end

function table.is_table(t)
    return type(t) == "table"
end
