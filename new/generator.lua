#!/usr/bin/lua

local my = {
				readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end
}


local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local xmlstream = dofile(path..'xml.lua')(my.readfile(filename))
local code = xmlstream[1]

local decompound = function(n)
				-- test function pointer
				local r, a = string.match(n, '(.-) %(%*%) (%b())')
				if r and a then
								-- only single arguments are supported
								return 'function', r, string.match(a, '%(([^,]*)%))')
				end
				return nil
end


local base_types = dofile'types.lua'

-- this only works on resolved types (no typedefs) and no compound types
local types_desc = setmetatable({}, {
				__index = function(t, k)
								-- exclude base types
								if rawget(base_types, k) then
												t[k] = rawget(base_types, k)
												return rawget(base_types, k)
								end
								-- exclude templates
								if string.match(k, '<') then
												return nil -- explicitly won't support templates yet
								end

								-- traverse namespace tree
								local space = code
								local iter = string.gmatch(k, '[^:]+')
								for n in iter do if space.byname and space.byname[n] then
												space = space.byname[n]
												if type(space)=='table' and space.label=='TypeAlias' then
																error'you should resolve aliases before calling this function'
												end -- is an alias?
								else
												return nil
								end	end

								-- make use of final result
								if type(space)~='table' then
												return nil
								else
												t[k] = space
								end
								return t[k]
				end,
})

local types_name = setmetatable({}, {
				__index = function(t, k)
								-- exclude base types
								if rawget(base_types, k) then
												t[k] = k
												return k
								end
								-- exclude templates
								if string.match(k, '<') then
												return nil -- explicitly won't support templates yet
								end

								-- traverse namespace tree
								local space = code
								local iter = string.gmatch(k, '[^:]+')
								for n in iter do if space.byname and space.byname[n] then
												space = space.byname[n]
												if type(space)=='table' and space.label=='TypeAlias' then
																print('^^^^^^^^', k)
																local alias = space.xarg.type_name
																if space.xarg.type_base~=alias then
																				-- if it is not a pure object name, it should not have members
																				if iter() then
																								error'compound type shouldn\'t have members'
																				else
																								local sub = t[space.xarg.type_base]
																								local ret = sub and string.gsub(alias, space.xarg.type_base, sub) or nil
																								print('++++', ret)
																								t[k] = ret
																								return ret
																				end
																else -- alias to compound type?
																				for i in iter do alias = alias..'::'..i end -- reconstruct full name
																				--print ('----', k, 'is alias for', n)
																				local ret = t[alias]
																				if ret then t[k] = ret end
																				print ('----', k, 'is alias for', alias, 'and is', ret)
																				return ret
																end -- alias to compound type?
												end -- is an alias?
								else
												t[k] = nil
												return nil
								end	end

								-- make use of final result
								if type(space)~='table' then
												t[k] = nil
								else
												t[k] = space.xarg.fullname
								end
								return t[k]
				end,
})


local cache = {}
for _, v in pairs(xmlstream.byid) do
				if v.label~='TypeAlias' then
								local __ = types_name[v.xarg.type_base or 'none']
				end
				--if v.xarg.scope~=v.xarg.context..'::' then print(v.label, v.xarg.id, v.xarg.type_name, v.xarg.scope, v.xarg.context) end
				--cache[v.xarg.context] = true
				--print(pushtype(v)(v.xarg.name), ' // '.._..': '..v.label..' : '..(v.xarg.type_name or ''))
				--assert(type_name(v.xarg.type_base, v.xarg.type_constant, v.xarg.type_volatile, v.xarg.type_reference, v.xarg.indirections or 0)==v.xarg.type_name)
end
--table.foreach(cache, print)
do
				local t = {}
				table.foreach(types_name, function(i, j) t[j] = true end)
				table.foreach(types_name, print)
end




