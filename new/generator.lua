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
	for _, v in pairs(xmlstream.byid) do if v.xarg.fullname then
		local o = t[v.xarg.fullname] or {}
		table.insert(o, v)
		t[v.xarg.fullname] = o
	end end
	get_from_fullname = function(n)
		local ret = t[n]
		assert(ret, 'unknown identifier: '..n)
		return ret
	end
	get_unique_fullname = function(n)
		n = tostring(n)
		local ret = t[n]
		assert(ret, 'unknown identifier: '..n)
		assert(type(ret)=='table' and #ret==1, 'ambiguous identifier: '..n)
		return ret[1]
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
		local identifier = get_unique_fullname(typename)
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
		return fullname .. '* arg' .. tostring(i) .. ' = static_cast< ' ..
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
local get_constref = function(fullname)
	return function(i,j)
		j = j or -i
		return fullname .. ' const& arg' .. tostring(i) .. ' = *static_cast< ' ..
			fullname .. ' *>(LqtGetClassType(L, '..tostring(j)..', "' .. fullname .. '*"));'
	end
end
local get_ref = function(fullname)
	return function(i,j)
		j = j or -i
		return fullname .. '& arg' .. tostring(i) .. ' = *static_cast< ' ..
			fullname .. ' *>(LqtGetClassType(L, '..tostring(j)..', "' .. fullname .. '*"));'
	end
end

type_properties = function(t)
	local typename = type(t)=='string' and t or t.xarg.type_name

	if rawget(base_types, typename) then
		local ret = rawget(base_types, typename)
		return ret.on_stack, ret.get, ret.push
	end

	-- not a base type
	if type(t)=='string' or t.xarg.type_base==typename then
		local identifier = get_unique_fullname(typename)
		if identifier.label=='Enum' then
			return 'string;', get_enum(identifier.xarg.fullname)
		elseif identifier.label=='Class' then
			return typename..'*;', get_class(identifier.xarg.fullname)
		else
			error('unknown identifier type: '..identifier.label)
		end
	elseif t.xarg.array then
		error'I cannot manipulate arrays'
	elseif string.match(typename, '%(%*%)') then
		-- function pointer type
		-- FIXME: the XML description does not contain this info
		error'I cannot manipulate function pointers'
	elseif t.xarg.indirections then
		if t.xarg.indirections=='1' then
			local b = get_unique_fullname(t.xarg.type_base)
			if b.label=='Class' then
				-- TODO: check if other modifiers are in place?
				return t.xarg.type_base..'*;', get_pointer(t.xarg.type_base)
			else
				error('I cannot manipulate pointers to '..t.xarg.type_base)
			end
		end
		error'I cannot manipulate double pointers'
	else
		-- this is any combination of constant, volatile and reference
		local ret_get = nil
		if typename==(t.xarg.type_base..' const&') then
			ret_get = get_constref(t.xarg.type_base)
		elseif typename==(t.xarg.type_base..'&') then
			ret_get = get_ref(t.xarg.type_base)
		end
		assert(ret_get, 'cannot get non-base type '..typename..' from stack')
		return type_properties(t.xarg.type_base), ret_get
	end
end

entities.return_type = function(f)
	assert_function(f)
	if entities.is_destructor(f) then
		return nil
	elseif entities.is_constructor(f) then
		-- FIXME: hack follows!
		assert(f.xarg.type_name==f.xarg.type_base, 'return type of constructor is strange')
		f.xarg.type_name = f.xarg.type_base..'*'
		f.xarg.indirections='1'
		return f
	elseif f.xarg.type_name=='' or f.xarg.type_name=='void' then
		return nil
	else
		return f
	end
end


local arguments_on_stack = function(f)
	assert_function(f)
	local args_on_stack = ''
	--print('=====', f.xarg.fullname) 
	for _,a in ipairs(f) do
		--local st, err = pcall(type_on_stack, a)
		--if not st then table.foreach(a, print) end
		--assert(st, err)
		local err = type_properties(a)
		args_on_stack = args_on_stack .. err
	end
	if entities.takes_this_pointer(f) then
		args_on_stack = f.xarg.member_of .. '*;' .. args_on_stack
	end
	return args_on_stack
end

function_description = function(f)
	assert_function(f)
	local args_on_stack = arguments_on_stack(f)
	return f.xarg.type_name .. ' ' .. f.xarg.fullname .. ' (' .. args_on_stack .. ')'..
	(f.xarg.static=='1' and ' [static]' or '')..
	(f.xarg.virtual=='1' and ' [virtual]' or '')..
	(entities.is_constructor(f) and ' [constructor]' or '')..
	(entities.is_destructor(f) and ' [destructor]' or '')..
	' [in ' .. tostring(f.xarg.member_of) .. ']'
end

-- TODO: must wait for a way to specify pushing base types
local calling_code = function(f)
	assert_function(f)
	local ret, indent = '', '  '
	local n = 0
	for _,a in ipairs(f) do if a.label=='Argument' then
		n = n + 1
		local d, g, p = type_properties(a)
		ret = ret .. indent .. g(n) .. '(void) arg'..tostring(n)..';\n'
	end end
	if entities.is_constructor(f) then
	elseif entities.is_constructor(f) then
	elseif entities.takes_this_pointer(f) then
	else
		local args = ''
		for i = 1,n do
			args = args .. (i > 1 and ', arg' or 'arg') .. tostring(i)
		end
		args = '('..args..')';
		local ret_type = entities.return_type(f)
		ret_type = ret_type and ret_type.xarg.type_name or nil
		local call_line = (ret_type and (ret_type..' ret = ') or '')
		call_line = call_line .. f.xarg.fullname .. args
		ret = ret .. indent .. call_line .. ';\n'
		ret = ret .. (ret_type and (indent..'(void)ret;\n') or '')
	end
	return ret
end


io.write[[
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <QtGui>

typedef lua_Integer LqtBaseType_integer;
typedef double LqtBaseType_number;
typedef bool LqtBaseType_bool;
typedef const char * LqtBaseType_string;

#define LqtGetBaseType_integer lua_tointeger
#define LqtGetBaseType_number lua_tonumber
#define LqtGetBaseType_bool lua_toboolean

void * LqtGetClassType (lua_State *L, int i, const char *t) {
	return NULL;
}
quint32 LqtGetEnumType (lua_State *L, int i, const char *t) {
	return 0;
}
const char * LqtGetBaseType_string (lua_State *L, int i) {
	return NULL;
}

]]

local FILTERS = {
	function(f) return f.xarg.name:match'^[_%w]*'=='operator' end,
	function(f) return f.xarg.fullname:match'%b<>' end,
	function(f) return f.xarg.name=='qobject_cast' end,
	function(f) return f.xarg.access~='public' end,
}
local filter_out = function(f)
	local ret, msg, F = nil, next(FILTERS, nil)
	while (not ret) and F do
		ret = F(f) and msg
		msg, F = next(FILTERS, msg)
	end
	return ret
end

for _, v in pairs(xmlstream.byid) do
	if string.find(v.label, 'Function')==1 and (not filter_out(v)) then
		local status, err = pcall(function_description, v)
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
		if status then
			local s, e = pcall(calling_code, v)
			--io[s and 'stdout' or 'stderr']:write((s and ''
			--or ('error calling '..v.xarg.fullname..': '))..e..(s and '' or '\n'))
			if s then
				io.stdout:write('extern "C" int bound_function'..v.xarg.id..' (lua_State *L) {\n(void)L;\n')
				io.stdout:write(e)
				io.stdout:write('}\n')
			end
		end
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	end
end
--table.foreach(name_list, print)


