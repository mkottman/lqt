#!/usr/bin/lua

local my = {
	readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end
}

local entities = dofile'entities.lua'
assert_function = function(f)
	assert(entities.is_function(f), 'argument is not a function')
end

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

local get_enum = function(fullname)
	return function(i,j)
		j = j or -i
		return fullname .. ' arg' .. tostring(i) .. ' = static_cast< ' ..
			fullname .. ' >(LqtGetEnumType(L, '..tostring(j)..', "' .. fullname .. '"));'
	end
end
local get_pointer = function(fullname)
	return function(i,j)
		j = j or -i
		return fullname .. ' arg' .. tostring(i) .. '* = static_cast< ' ..
			fullname .. ' *>(LqtGetClassType(L, '..tostring(j)..', "' .. fullname .. '*"));'
	end
end
local get_class = function(fullname)
	return function(i,j)
		j = j or -i
		return fullname .. ' arg' .. tostring(i) .. ' = *static_cast< ' ..
			fullname .. ' *>(LqtGetClassType(L, '..tostring(j)..', "' .. fullname .. '*"));'
	end
end

type_properties = function(t)
	local typename = type(t)=='string' and t or t.xarg.type_name
	if rawget(base_types, typename) then
		local ret = rawget(base_types, typename)
		return ret.on_stack, ret.get
	end
	if type(t)=='string' or t.xarg.type_base==typename then
		local identifier = get_from_fullname(typename)
		assert(identifier and #identifier==1, 'cannot resolve base type: '..typename)
		identifier = identifier[1]
		if identifier.label=='Enum' then
			return 'string;', get_enum(identifier.xarg.fullname)
		elseif identifier.label=='Class' then
			return typename..'*;', get_class(identifier.xarg.fullname)
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

return_type = function(f)
	assert_function(f)
	if entities.is_destructor(f) then
		return nil
	elseif entities.is_constructor(f) then
		-- FIXME: hack follows!
		assert(f.xarg.type_name==f.xarg.type_base, 'return type of constructor is strange')
		f.xarg.type_name = f.xarg.type_base..'*'
		f.xarg.indirections='1'
		return f
	else
		return f
	end
end

function_description = function(f)
	assert_function(f)
	local args_on_stack = entities.arguments_on_stack(f)
	return f.xarg.type_name .. ' ' .. f.xarg.fullname .. ' (' .. args_on_stack .. ')'..
	(f.xarg.static=='1' and ' [static]' or '')..
	(f.xarg.virtual=='1' and ' [virtual]' or '')..
	(entities.is_constructor(f) and ' [constructor]' or '')..
	(entities.is_destructor(f) and ' [destructor]' or '')..
	' [in ' .. tostring(f.xarg.member_of) .. ']'
end

for _, v in pairs(xmlstream.byid) do
	if string.find(v.label, 'Function')==1 then
		local status, err = pcall(function_description, v)
		io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	end
end
--table.foreach(name_list, print)


