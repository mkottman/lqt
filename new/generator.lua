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

next_scope = function(path, i)
				local ns, te, j = string.match(path, "([^:<>]+)(%b<>)()", i)
				if not ns then ns, te, j = string.match(path, "([^:<>]+)(%z?)()", i) end
				return ns, te, j
end

find_element = function(t, path, err)
				local ns, te, i = next_scope(path)
				while ns and ns~='' do
								print ('===>', ns, '`'..te..'\'', i, path)
								if te=='' then
												if not t.byname[ns] then
																print(path..' broken at '..ns..' -- '..err)
																break
												else
																t = t.byname[ns]
												end
								else
												local ot = t
												for k, v in pairs(t.byname) do
																if string.find(k, ns..'<')==1 then
																				t = v
																				break
																end
												end
												if t==ot then print('broken template ' ..ns..te) end
								end
								ns, te, i = next_scope(path, i)
				end
				return t
end

is = {
				function_pointer = function(t)
								return string.match(t.xarg.type_name, '%(%*%)')
				end,
				array = function(t)
								return string.match(t.xarg.type_name, '%[%d+%]$')
				end,
				pointer = function(t)
								return string.match(t.xarg.type_name, '%*$')
				end,
				reference = function(t)
								return string.match(t.xarg.type_name, '%&$')
				end,
}
push = {
				function_pointer = function(t)
								return function(x)
												return 'lqt_pushpointer(L, '..tostring(x)..', "'..tostring(t.xarg.type_name)..'")'
								end
				end,
				array = function(t)
								return function(x) return '(array type) '..tostring(x) end
				end,
				pointer = function(t)
								return function(x)
												return 'lqt_pushpointer(L, &'..tostring(x)..', "'
												..t.xarg.type_name:gsub(' const',''):gsub(' volatile','')..'")'
								end
				end,
				reference = function(t)
								return function(x)
												return 'lqt_pushpointer(L, &'..tostring(x)..', "'
												..t.xarg.type_name:gsub(' const',''):gsub(' volatile',''):gsub('%&$', '*')..'")'
								end
				end,
}

pushtype = function(t)
				if type(t)~='table' or type(t.xarg)~='table' or type(t.xarg.type_name)~='string' then
								-- TODO: throw error
								return function(x) return '(not type) '..tostring(x) end
				end
				print('===>', find_element(code, t.xarg.type_base, t.xarg.id).label)
				if pushtype_table[t.xarg.type_name] then return pushtype_table[t.xarg.type_name] end
				-- TODO throw error
				for i, p in pairs(is) do
								if p(t) then return push[i](t) end
				end
				return function(x) return '=== UNKNOWN TYPE === '..(t.xarg.type_name)..' '..tostring(x) end
end


for _, v in pairs(xmlstream.byid) do
				--if v.xarg.scope~=v.xarg.context..'::' then print(v.label, v.xarg.id, v.xarg.type_name) end
				print(pushtype(v)(v.xarg.name), ' // '.._..': '..v.label..' : '..(v.xarg.type_name or ''))
				--assert(type_name(v.xarg.type_base, v.xarg.type_constant, v.xarg.type_volatile, v.xarg.type_reference, v.xarg.indirections or 0)==v.xarg.type_name)
end




