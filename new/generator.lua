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
			--space.on_stack = 'userdata;' -- more precise info is needed
		end
		return t[k]
	end,
})

local cache = {}
--[[
for _, v in pairs(xmlstream.byid) do
	if v.xarg.type_base then
		if not string.match(v.xarg.context, '[<,]%s*'..v.xarg.type_base..'%s*[>,]') then
			local __ = types_desc[v.xarg.type_base]
		else
		end
	end
end
--]]

do
	--local t = {}
	--table.foreach(types_desc, function(i, j) t[j] = true end)
	--table.foreach(types_desc, function(n,d) print(n, d.label, d.on_stack) end)
end

do
	local t = {}
	for _, v in pairs(xmlstream.byid) do
		local o = t[v.xarg.fullname] or {}
		table.insert(o, v)
		t[v.xarg.fullname] = o
	end
	get_from_fullname = function(n)
		return t[n]
	end
	--name_list = t
end


type_on_stack = function(t)
	local typename = type(t)=='string' and t or t.xarg.type_name
	if rawget(base_types, typename) then
		local ret = rawget(base_types, typename).on_stack
		return ret
	end
	if type(t)=='string' or t.xarg.type_base==typename then
		local identifier = get_from_fullname(typename)
		assert(identifier and #identifier==1, 'cannot resolve base type: '..typename)
		identifier = identifier[1]
		if identifier.label=='Enum' then
			return 'string;'
		elseif identifier.label=='Class' then
			return typename..'*;'
		else
			error('unknown identifier type: '..identifier.label)
		end
	else
		if t.xarg.array then
			error'I cannot manipulate arrays'
		elseif string.match(typename, '%(%*%)') then
			-- function pointer type
			-- FIXME: the XML description does not contain this info
			error'I cannot manipulate function pointers'
		elseif t.xarg.indirections then
			if t.xarg.indirections=='1' then
				local b = assert(get_from_fullname(t.xarg.type_base), 'unknown type base')[1]
				if b.label=='Class' then
					return t.xarg.type_base..'*;'
				else
					error('I cannot manipulate pointers to '..t.xarg.type_base)
				end
			end
			error'I cannot manipulate double pointers'
		else
			-- this is any combination of constant, volatile and reference
			-- we ignore this info and treat this as normal value
			return type_on_stack(t.xarg.type_base)
		end
	end
end

assert_function = function(f)
	if type(f)~='table' or string.find(f.label, 'Function')~=1 then
		error('this is NOT a function')
	end
end
function_is_constructor = function(f)
	assert_function(f)
	return (f.xarg.member_of and f.xarg.member_of~=''
	and f.xarg.fullname==(f.xarg.member_of..'::'..f.xarg.name) -- this should be always true
	and string.match(f.xarg.member_of, f.xarg.name..'$')) and '[constructor]'
end
function_is_destructor = function(f)
	assert_function(f)
	return f.xarg.name:sub(1,1)=='~' and '[destructor]'
end
function_takes_this_pointer = function(f)
	assert_function(f)
	if f.xarg.member_of and not (f.xarg.static=='1') and f.xarg.member_of~=''
		and not function_is_constructor(f) then
		return f.xarg.member_of .. '*;'
	end
	return false
end
return_type = function(f)
	assert_function(f)
	if function_is_destructor(f) then
		return nil
	elseif function_is_constructor(f) then
		-- FIXME: hack follows!
		assert(f.xarg.type_name==f.xarg.type_base, 'return type of constructor is strange')
		f.xarg.type_name = f.xarg.type_base..'*'
		f.xarg.indirections='1'
		return f
	else
		return f
	end
end
function_arguments_on_stack = function(f)
	assert_function(f)
	local args_on_stack = ''
	--print('=====', f.xarg.fullname) 
	for _,a in ipairs(f) do
		--local st, err = pcall(type_on_stack, a)
		--if not st then table.foreach(a, print) end
		--assert(st, err)
		local err = type_on_stack(a)
		args_on_stack = args_on_stack .. err
	end
	if function_takes_this_pointer(f) then
		args_on_stack = f.xarg.member_of .. '*;' .. args_on_stack
	end
	return args_on_stack
end
function_description = function(f)
	assert_function(f)
	local args_on_stack = function_arguments_on_stack(f)
	return f.xarg.type_name .. ' ' .. f.xarg.fullname .. ' (' .. args_on_stack .. ')'..
	(f.xarg.static=='1' and ' [static]' or '')..
	(f.xarg.virtual=='1' and ' [virtual]' or '')..
	(function_is_constructor(f) and ' [constructor]' or '')..
	(function_is_destructor(f) and ' [destructor]' or '')..
	' [in ' .. tostring(f.xarg.member_of) .. ']'
end
for _, v in pairs(xmlstream.byid) do
	if string.find(v.label, 'Function')==1 then
		local status, err = pcall(function_description, v)
		io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	end
end
--table.foreach(name_list, print)


