#!/usr/bin/lua

local my = { readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end }


local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local xmlstream = dofile(path..'xml.lua')(my.readfile(filename))
local code = xmlstream[1]

--[[
table.foreach(code.byname.hello.xarg, print)
table.foreach(code.byname.hello[1].xarg, print)

table.foreach(code.byname.world.xarg, print)
table.foreach(code.byname.world[1].xarg, print)

table.foreach(code.byname.string_type.xarg, print)
table.foreach(code.byname.string_type[1].xarg, print)
--]]


pushtype_table = {
['void'] =   function(i) return '(void)(L, ' .. tostring(i) .. ')' end,
['void*'] =   function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
['void**'] = function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
['void const*'] =   function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
['void const**'] = function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,

['char*'] = function(i) return 'lua_pushstring(L, ' .. tostring(i) .. ')' end,
['char**'] = function(i) return 'lqtL_pusharguments(L, ' .. tostring(i) .. ')' end,
['char const*'] = function(i) return 'lua_pushstring(L, ' .. tostring(i) .. ')' end,
['char const**'] = function(i) return 'lqtL_pusharguments(L, ' .. tostring(i) .. ')' end,

['int'] =                    function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['unsigned int'] =           function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,

['short int'] =              function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['unsigned short int'] =     function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['short unsigned int'] =     function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,

['long int'] =               function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['unsigned long int'] =      function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['long unsigned int'] =      function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,

['long long int'] =          function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
['unsigned long long int'] = function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,

['float'] =  function(i) return 'lua_pushnumber(L, ' .. tostring(i) .. ')' end,
['double'] = function(i) return 'lua_pushnumber(L, ' .. tostring(i) .. ')' end,

['bool'] = function(i) return 'lua_pushboolean(L, ' .. tostring(i) .. ')' end,
}

--[[
type_name = function(base, constant, volatile, reference, indirections)
				print(base, constant, volatile, reference, indirections)
				local ret = base
				if not ret then return nil end
				ret = ret .. (constant and ' const' or '')
				ret = ret .. (volatile and ' volatile' or '')
				ret = ret .. string.rep('*', indirections)
				ret = ret .. (reference and '&' or '')
				return ret
end
--]]

assimplepointer = function(n)
								return function(x)
												return 'lqt_pushpointer(L, '..tostring(x)..', "'..tostring(n)..'")'
								end
end

printtype = function(n)
				return function(x) return '('..tostring(n)..' type) '..tostring(x) end
end

issimplepointer = function(t)
				if string.match(t.xarg.type_name, '%(%*%)') then
								return assimplepointer(t.xarg.type_name)
				elseif string.match(t.xarg.type_name, '%[%d+%]$') then
								-- TODO: error'Don\'t know what to do with arrays'
								return printtype'array'
				elseif string.match(t.xarg.type_name, '%*$') then
								return assimplepointer(t.xarg.type_name:gsub(' const', ''):gsub(' volatile',''))
				end
end

isreference = function(t)
end

isinstance = function(t)
end

pushtype = function(t)
				if type(t)~='table' or type(t.xarg)~='table' or type(t.xarg.type_name)~='string' then
								-- TODO: throw error
								return printtype'not'
				end
				if pushtype_table[t.xarg.type_name] then return pushtype_table[t.xarg.type_name] end
				-- TODO throw error
				return issimplepointer(t)
				or function(x) return '=== UNKNOWN TYPE === '..(t.xarg.type_name)..' '..tostring(x) end
end

for _, v in pairs(xmlstream.byid) do
				print(pushtype(v)(v.xarg.name), ' // '.._..': '..v.label..' : '..(v.xarg.type_name or ''))
				--assert(type_name(v.xarg.type_base, v.xarg.type_constant, v.xarg.type_volatile, v.xarg.type_reference, v.xarg.indirections or 0)==v.xarg.type_name)
end




