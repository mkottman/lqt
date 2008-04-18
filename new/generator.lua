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
		if string.match(k, '[<>]') then
			return nil -- explicitly won't support templates yet
		end

		-- traverse namespace tree
		local space = code
		local iter = string.gmatch(k, '[^:]+')
		for n in iter do if space.byname and space.byname[n] then
			space = space.byname[n]
			if type(space)=='table' and space.label=='TypeAlias' then
				print(space.xarg.fullname, k)
				error'you should resolve aliases before calling this function'
			end -- is an alias?
		else -- this name is not in this space
			-- this is probably a template argument (at least in Qt) so we do not care for now
			do return nil end
			error(tostring(k)..' '..tostring(space.fullname)..' '..tostring(n) )
		end end

		-- make use of final result
		if type(space)~='table' then
			return nil
		else
			t[k] = space
		end
		return t[k]
	end,
})

local cache = {}
for _, v in pairs(xmlstream.byid) do
	if v.xarg.type_base then
		if not string.match(v.xarg.context, '[<,]%s*'..v.xarg.type_base..'%s*[>,]') then
			local __ = types_desc[v.xarg.type_base]
		else
		end
	end
end

do
	local t = {}
	--table.foreach(types_desc, function(i, j) t[j] = true end)
	table.foreach(types_desc, print)
end




