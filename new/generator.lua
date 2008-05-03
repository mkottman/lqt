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


local base_types = {}
assert(loadfile'types.lua')(base_types)

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


local push_enum = function(fullname)
	return function(j)
		return 'lqtL_pushenum(L, '..tostring(j)..', "'..fullname..'");'
	end
end
local push_pointer = function(fullname)
	return function(j)
		return 'lqtL_pushudata(L, '..tostring(j)..', "' .. fullname .. '*");'
	end
end
local push_class = function(fullname)
	return function(j)
		return 'lqtL_passudata(L, new '..fullname..'('..tostring(j)..'), "' .. fullname .. '*");'
	end
end
local push_constref = function(fullname) -- FIXME: is it correct?
	return function(j)
		return 'lqtL_passudata(L, new '..fullname..'('..tostring(j)..'), "' .. fullname .. '*");'
	end
end
local push_ref = function(fullname)
	return function(j)
		return 'lqtL_passudata(L, &'..tostring(j)..', "' .. fullname .. '*");'
	end
end

local get_enum = function(fullname)
	return function(i)
		return 'static_cast< ' ..
			fullname .. ' >(lqtL_toenum(L, '..tostring(i)..', "' .. fullname .. '"));'
	end
end
local get_pointer = function(fullname)
	return function(i)
		return 'static_cast< ' ..
			fullname .. ' *>(lqtL_toudata(L, '..tostring(i)..', "' .. fullname .. '*"));'
	end
end
local get_class = function(fullname)
	return function(i)
		return '*static_cast< ' ..
			fullname .. ' *>(lqtL_toudata(L, '..tostring(i)..', "' .. fullname .. '*"));'
	end
end
local get_constref = function(fullname)
	return function(i)
		return '*static_cast< ' ..
			fullname .. ' *>(lqtL_toudata(L, '..tostring(i)..', "' .. fullname .. '*"));'
	end
end
local get_ref = function(fullname)
	return function(i)
		return '*static_cast< ' ..
			fullname .. ' *>(lqtL_toudata(L, '..tostring(i)..', "' .. fullname .. '*"));'
	end
end

type_properties = function(t)
	local typename = type(t)=='string' and t or t.xarg.type_name

	if base_types[typename] then
		local ret = base_types[typename]
		return ret.desc, ret.get, ret.push, ret.num
	end

	-- not a base type
	if type(t)=='string' or t.xarg.type_base==typename then
		local identifier = get_unique_fullname(typename)
		local fn = identifier.xarg.fullname
		if identifier.label=='Enum' then
			return 'string;', get_enum(fn), push_enum(fn), 1
		elseif identifier.label=='Class' then
			return typename..'*;', get_class(fn), push_class(fn), 1
		else
			error('unknown identifier type: '..identifier.label)
		end
	elseif t.xarg.array or t.xarg.type_name:match'%b[]' then -- FIXME: another hack
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
				return t.xarg.type_base..'*;',
					get_pointer(t.xarg.type_base),
					push_pointer(t.xarg.type_base), 1
			else
				error('I cannot manipulate pointers to '..t.xarg.type_base)
			end
		end
		error'I cannot manipulate double pointers'
	else
		-- this is any combination of constant, volatile and reference
		local ret_get, ret_push = nil, nil
		if typename==(t.xarg.type_base..' const&') then
			local bt = get_unique_fullname(t.xarg.type_base)
			--assert(entities.class_is_copy_constructible(bt))
			ret_get = get_constref(t.xarg.type_base)
			ret_push = push_constref(t.xarg.type_base)
		elseif typename==(t.xarg.type_base..'&') then
			ret_get = get_ref(t.xarg.type_base)
			ret_push = push_ref(t.xarg.type_base)
		end
		assert(ret_get, 'cannot get non-base type '..typename..' from stack')
		return type_properties(t.xarg.type_base), ret_get, ret_push, 1
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

function_description = function(f)
	assert_function(f)
	local args_on_stack = '' -- arguments_on_stack(f) -- FIXME: use another method
	return f.xarg.type_name .. ' ' .. f.xarg.fullname .. ' (' .. args_on_stack .. ')'..
	(f.xarg.static=='1' and ' [static]' or '')..
	(f.xarg.virtual=='1' and ' [virtual]' or '')..
	(entities.is_constructor(f) and ' [constructor]' or '')..
	(entities.is_destructor(f) and ' [destructor]' or '')..
	' [in ' .. tostring(f.xarg.member_of) .. ']'
end

local argument_number = function(f)
	assert_function(f)
	local narg = #f
	if entities.is_destructor(f) then
		narg = 1
	elseif entities.is_constructor(f) then
	elseif entities.takes_this_pointer then
		narg = narg + 1
	end
	return narg
end

local argument_assert = function(f)
	assert_function(f)
	local narg = argument_number(f)
	return 'luaL_checkany(L, '..tostring(narg)..')'
end

local argument = function(n)
	return 'arg'..tostring(n)
end

local get_args = function(f, indent)
	assert_function(f)
	indent = indent or '  '
	local ret, argi = '', 0
	if entities.takes_this_pointer(f) then
		argi = argi + 1
		ret = ret .. indent .. f.xarg.member_of_class .. '* self = '
		ret = ret .. get_pointer(f.xarg.member_of_class)(argi) .. ';(void)self;\n'
	end
	for _,a in ipairs(f) do if a.label=='Argument' then
		argi = argi + 1
		local _d, g, _p, _n = type_properties(a)
		ret = ret .. indent .. a.xarg.type_name .. ' arg' .. tostring(argi) .. ' = '
		ret = ret .. g(argi) .. '(void) arg'..tostring(argi)..';\n'
	else error'element in function is not argument'
	end end
	return ret
end

-- TODO: constructors wait for deciding if base class is needed
local calling_code = function(f)
	assert_function(f)
	local ret, indent = '', '  '
	local argi = 0

	ret = ret..indent..argument_assert(f)..';'

	ret = ret..get_args(f, indent)

	if entities.is_constructor(f) then
	elseif entities.is_destructor(f) then
	else
		local args = ''
		for i = 1,n do
			args = args .. (i > 1 and ', arg' or 'arg') .. tostring(i)
		end
		args = '('..args..')';
		local call_line = f.xarg.fullname .. args .. ';\n'
		local ret_type = entities.return_type(f)
		if ret_type then
			call_line = ret_type.xarg.type_name .. ' ret = ' .. call_line
			local _d, _g, p, n = type_properties(ret_type)
			call_line = call_line .. indent .. p'ret' .. '\n'
			call_line = call_line .. indent .. 'return ' .. tostring(n) .. ';\n'
		end
		ret = ret .. indent .. call_line .. '\n'
	end
	return ret
end


io.write[[
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include "lqt_common.hpp"
#include <QtGui>

#define lqtL_getinteger lua_tointeger
#define lqtL_getstring lua_tostring
#define lqtL_getnumber lua_tonumber

]]

local FILTERS = {
	function(f) return f.xarg.name:match'^[_%w]*'=='operator' end,
	function(f) return f.xarg.fullname:match'%b<>' end,
	function(f) return f.xarg.name:match'_cast' end,
	function(f) return f.xarg.fullname:match'QInternal' end,
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
				io.stdout:write('return 0;}\n') -- FIXME
			end
		else
			print(err)
		end
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	end
end
--table.foreach(name_list, print)


