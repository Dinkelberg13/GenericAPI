local tStrs = {["\r"]="\\r",["\t"]="\\t",["\a"]="\\a",["\f"]="\\f",--[=[["\z"]="\\z",]=]["\v"]="\\v",["\b"]="\\b",["\n"]="\\n",["\\"]="\\\\",["\""]="\\\"",["\'"]="\\\'"}
local Bytes = {["@"] = true, ["\32"] = true, [","] = true, ["."] = true, ["["] = true, ["]"] = true, ["|"] = true, ["{"] = true, ["}"] = true, [";"] = true, [":"] = true, ["_"] = true, ["<"] = true, [">"] = true, ["!"] = true, ["?"] = true, ["("] = true, [")"] = true, ["="] = true, ["~"] = true, ["^"] = true, ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true, ["$"] = true, ["&"] = true, ["#"] = true}
for i = 0, 9, 1 do
    Bytes[("%.99g"):format(i)] = true
end

for i = ("a"):byte(), ("z"):byte(), 1 do
    Bytes[("%c"):format(i)] = true
end

for i = ("A"):byte(), ("Z"):byte(), 1 do
    Bytes[("%c"):format(i)] = true
end

local function verifyByte(str)
    return Bytes[str]
end

for i = 0, 0xff, 1 do
    if not verifyByte(("%c"):format(i)) and not tStrs[("%c"):format(i)] then
        tStrs[("%c"):format(i)] = "\\" .. i
    end
end

local Table, mtTable = {}, {["__index"] = {}}
local seen = setmetatable({}, mtTable)

local types = {
    ["function"] = true,    ["table"]    =  true,
    ["number"]   = true,    ["string"]   =  true,
    ["thread"]   = true,    ["userdata"] = false,
}

local function tohexcode(val0)
    if not val0 then return "(null)" end
    if not types[type(val0)] then
        val0 = getrawmetatable(val0) or (tostring(val0):gsub("(.+:) ", ""))
    end
    local val1 = (tostring(val0):gsub("(.+:) ", ""))
    return ("0x%x"):format(val1)
end

local function preloadCHECK(t, grade)
    grade = type(grade) == "number" and grade or tonumber(grade) or grade == nil and 1 or assert(false, ("bad argument #2 to 'preloadCHECK' (number or nil expected, got %s)"):format(type(grade)))
    assert(type(t) == "table", ("bad argument #1 to 'preloadCHECK' (table expected, got %s)"):format(type(t)))
    local s = "{\n"
    local empy = true
    local xGrade = ("\t"):rep(grade)
    for k, v in next, t do
        empy = false
        s = (s .. xGrade .. "[%s] = %s,\n"):format((function()
            if type(k) == "number" then
                return ("%.99g"):format(k)
            elseif type(k) == "userdata" then
                return ("userdata at %s"):format(tohexcode(k))
            else
                return ("\"%s\""):format(k)
            end
        end)(), (function()
            if type(v) == "string" then
                v = v:gsub(".", tStrs)
                return ("\"%s\""):format(v)
            elseif type(v) == "number" then
                print(v)
                return ("%.99g"):format(type(v) == "number" and v or tonumber(v) or tonumber("nan"))
            elseif type(v) == "boolean" then
                return tostring(v)
            elseif type(v) == "table" and not seen[v] then
                seen[v] = v
                for _k, _v in next, v do
                    if type(_v) == "table" and _v[_k] == _v then
                        local sAux = ("'[circular table at %s]'"):format(tohexcode(seen[v]))
                        seen[v] = nil
                        return sAux
                    end
                end
                return preloadCHECK(v, grade + 1)
            elseif type(v) == "table" and seen[v] then
                for _k, _v in next, v do
                    if type(_v) == "table" and not _v[_k] then
                        return preloadCHECK(_v, grade + 1)
                    end
                end
                seen[v] = v
                return ("'[circular table at %s]'"):format(tohexcode(seen[v]))
            -- elseif type(v) == "userdata" and not seen[v] and getrawmetatable(v) then
            --  seen[v] = getrawmetatable(v)
            --  for _k, _v in next, getrawmetatable(v) do
            --      if type(_v) == type(v) and _v[_k] == _v then
            --          local sAux = ("'[circular table at %s]'"):format(tohexcode(seen[v]))
            --          seen[v] = nil
            --          return sAux
            --      end
            --  end
            --  return preloadCHECK(v, grade + 1)
            else
                return ("'%s at %s'"):format(type(v), tohexcode(v))
            end
        end)())
    end
    if not empy then
        s = s:sub(1, s:len() - 2)
        s = s .. "\n" .. xGrade:sub(xGrade:len() - (xGrade:len() - 2)) .. "}"
    else
        s = "{}"
    end
    s = s:gsub("\t","\32\32\32\32")
    return s
end

function mtTable.__index:forEach(cback)
    for k, v in next, self do
        local packed = {cback(k, v)}
        if rawlen(packed) > 0 then
            return table.unpack(packed)
        end
    end
end

function mtTable.__index:forEachI(cback)
    for k, v in ipairs(self) do
        local packed = {cback(k, v)}
        if rawlen(packed) > 0 then
            return table.unpack(packed)
        end
    end
end

function mtTable.__index:Insert(key, value)
    return rawset(self, key, value)
end

function mtTable.__index:Unpack()
    return table.unpack(self)
end

function mtTable.__index.Clone(tbl, apply)
    if apply == true then
        local newTable = Table.New()
        Table.forEach(tbl, function(key, value)
            Table.Insert(newTable, key, value)
        end)
        return newTable
    else
        local newTable = {}
        Table.forEach(tbl, function(key, value)
            Table.Insert(newTable, key, value)
        end)
        return newTable
    end
end

function mtTable.__index:Find(value)
    return self:forEach(function(key, val)
        if value == val then
            return key, val
        end
    end)
end

function mtTable.__index:SetMetatable(mtVal)
    if type(mtVal) == "table" then
        mtTable.forEach(mtVal, function(...)
            mtTable.Insert(self, ...)
        end)
        return debug.setmetatable()
    end
end

function mtTable:__tostring()
    local result = preloadCHECK(self, 1)
    seen:forEach(function(key)
        seen:Insert(key, nil)
    end)
    return result
end

local frozenMT = setmetatable({
    ["__metatable"] = freezeFNC
}, {
    ["__eq"] = function(self, val0)
        if type(val0) == "table" and (rawget(val0, "__metatable") == self.__metatable) then
            return true
        else
            return false
        end
    end,
    ["__index"] = mtTable.__index,
    ["__tostring"] = mtTable.__tostring
})

function Table.New(...)
    return setmetatable({...}, mtTable)
end

local tempassert = debug.traceback
local function freezeFNC(self, key0)
    rawset(self, key0, nil)
    return tempassert("cannot modify a frozen table.")
end

mtTable.__index = setmetatable(mtTable.__index, {
    ["__tostring"] = function(self)
        local result = preloadCHECK(self, 1)
        seen:forEach(function(key)
            seen:Insert(key, nil)
        end)
        return result
    end,
    ["__index"] = {
        ["Methods"] = (function()
            local selfMethods = Table.New()
            mtTable.__index:forEach(function(key2, val2)
                selfMethods:Insert(key2, val2)
            end)
            return selfMethods
        end)()
    }
})

function Table.Apply(tb)
    if tb == (_ENV or _G) then
        Table.Apply(getmetatable(""))
        Table.Apply(getmetatable(io.stdin))
        
        local mtClone = mtTable:Clone()
        function mtClone:__newindex(key1, val1)
            if type(key1) == "table" and not getmetatable(key1) then
                setmetatable(key1, mtClone)
            end
            if type(val1) == "table" and not getmetatable(val1) then
                setmetatable(val1, mtClone)
                return rawset(self, key1, val1)
            end
        end

        setmetatable(tb, mtClone):forEach(function(_, val0)
            if type(val0) == "table" and not getmetatable(val0) then
                Table.Apply(val0)
            end
        end)
    else
        setmetatable(tb, mtTable):forEach(function(_, val0)
            if type(val0) == "table" and not getmetatable(val0) then
                Table.Apply(val0)
            end
        end)
    end
    return tb
end

function Table.Freeze(t)
    if debug.getmetatable(t) then
        local clonedFrozenMT = frozenMT:Clone()
        debug.getmetatable(t):forEach(function(key3, val3)
            clonedFrozenMT:Insert(key3, val3)
        end)
        return debug.setmetatable(t, clonedFrozenMT)
    else
        return debug.setmetatable(t, frozenMT)
    end
end

function Table.IsFrozen(t)
    local ok, msg = pcall(function()
        return frozenMT == debug.getmetatable(t)
    end)
    if ok and msg == true then
        return msg
    end
    return false
end

mtTable = setmetatable(mtTable, mtTable)

--print(msg.Clone(debug.getmetatable(Enum) or {"nothing"}, true))

return setmetatable(Table, mtTable)
