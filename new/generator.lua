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
		f.xarg.type_name = f.xarg.type_base..'&'
		f.xarg.reference='1'
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
	local ret, argi, shift = '', 0, 0
	if entities.takes_this_pointer(f) then
		shift = 1
		ret = ret .. indent .. f.xarg.member_of_class .. '* self = '
		ret = ret .. get_pointer(f.xarg.member_of_class)(1) .. ';\n' -- (void)self;\n'
	end
	for _,a in ipairs(f) do if a.label=='Argument' then
		argi = argi + 1
		local _d, g, _p, _n = type_properties(a)
		ret = ret .. indent .. a.xarg.type_name .. ' '..argument(argi) .. ' = '
		ret = ret .. g(argi + shift) .. ';\n' -- .. '(void) '..argument(argi)..';\n'
	else error'element in function is not argument'
	end end
	return ret
end

local arg_list = function(f)
	assert_function(f)
	if entities.is_destructor(f) then
		return '(self)'
	else
		local ret = ''
		for i = 1, #f do
			ret = ret .. (i>1 and ', ' and '') .. argument(i)
		end
		return '('..ret..')'
	end
end

local function_static_call = function(f)
	assert_function(f)
	if entities.is_destructor(f) then
		return 'delete (self)'
	elseif entities.is_constructor(f) then
		return '*new '..f.xarg.fullname..arg_list(f)
	elseif entities.takes_this_pointer(f) then
		return 'self->'..f.xarg.fullname..arg_list(f)
	else
		return f.xarg.fullname..arg_list(f)
	end
end

local function_shell_call = function(f)
	assert_function(f)
	assert(f.xarg.member_of_class, 'not a shell class member')
	if entities.is_destructor(f) then
		return 'delete (self)'
	elseif entities.is_constructor(f) then
		return '*new '..f.xarg.fullname..arg_list(f)
	elseif f.xarg.access=='public' then
		return function_static_call(f)
	elseif entities.takes_this_pointer(f) then
		return 'self->'..f.xarg.fullname..arg_list(f)
	else
		return f.xarg.fullname..arg_list(f)
	end
end

local collect_return = function(f)
	assert_function(f)
	local ret_t = entities.return_type(f)
	if not ret_t then
		return ''
	else
		return ret_t.xarg.type_name .. ' ret = '
	end
end

local give_back_return = function(f)
	assert_function(f)
	local ret_t = entities.return_type(f)
	if not ret_t then
		return ''
	else
		local _d, _g, p, _n = type_properties(ret_t)
		return p'ret'
	end
end

local return_statement = function(f)
	assert_function(f)
	local ret_t = entities.return_type(f)
	if not ret_t then
		return 'return 0'
	else
		local _d, _g, _p, n = type_properties(ret_t)
		return 'return '..tostring(n)
	end
end

-- TODO: constructors wait for deciding if shell class is needed
local calling_code = function(f)
	assert_function(f)
	local ret, indent = '', '  '
	local argi = 0

	ret = ret..indent..argument_assert(f)..';\n'

	ret = ret..get_args(f, indent)

	--if entities.is_constructor(f) then
	--elseif entities.is_destructor(f) then
	--else
	do
		--[[
		local args = ''
		for i = 1,#f do
			args = args .. (i > 1 and ', ' or '') .. argument(i)
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
		--]]
		local call_line = function_static_call(f)
		ret = ret .. indent .. collect_return(f) .. call_line .. ';\n'
		local treat_return = give_back_return(f)
		ret = treat_return and (ret..indent..treat_return..';\n') or ret
		ret = ret .. indent .. return_statement(f) .. ';\n'
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

local CLASS_FILTERS = {
	function(c) return c.xarg.fullname:match'%b<>' end,
	function(c) return c.xarg.name:match'_' end,
	--function(c) return c.xarg.fullname:match'Q.-Data' end,
	function(c) return c.xarg.class_type=='struct' end,
	function(c) return c.xarg.fullname=='QVariant::Private::Data' end,
	function(c) return c.xarg.fullname=='QTextStreamManipulator' end,
}
local FUNCTIONS_FILTERS = {
	function(f) return f.xarg.name:match'^[_%w]*'=='operator' end,
	function(f) return f.xarg.fullname:match'%b<>' end,
	function(f) return f.xarg.name:match'_' end,
	function(f) return f.xarg.fullname:match'QInternal' end,
	function(f) return f.xarg.access~='public' end,
}
local filter_out = function(f, t)
	local ret, msg, F = nil, next(t, nil)
	while (not ret) and F do
		ret = F(f) and msg
		msg, F = next(t, msg)
	end
	return ret
end

local choose_function = function(f1, f2)
	assert_function(f1)
	assert_function(f2)
	
end

local function_proto = function(f)
	assert_function(f)
	local larg1, larg2 = '', ''
	for i = 1, #f do
		local a = f[i]
		if a.label~='Argument' then error(a.label) end
		if a.xarg.type_name=='void' then
			larg1, larg2 = nil, nil
			break
		end
		larg1 = larg1 .. (i>1 and ', ' or '')
		if string.match(a.xarg.type_name, '%(%*%)') then
			larg1 = larg1 .. a.xarg.type_name:gsub('%(%*%)', '(*'..argument(i)..')')
		elseif string.match(a.xarg.type_name, '%[.*%]') then
			larg1 = larg1 .. a.xarg.type_name:gsub('(%[.*%])', argument(i)..'%1')
		else
			larg1 = larg1 .. a.xarg.type_name .. ' ' .. argument(i)
		end
		larg2 = larg2 .. (i>1 and ', ' or '') .. argument(i)
	end
	return larg1, larg2
end

local get_virtuals
get_virtuals = function(c)
	assert(entities.is_class(c), 'not a class')
	local ret, impl = {}, {}
	for _, f in ipairs(c) do
		if entities.is_function(f) and f.xarg.virtual=='1'
			and not string.match(f.xarg.name, '~') then
			table.insert(ret, f)
			impl[f.xarg.name] = true
		end
	end
	for b in string.gmatch(c.xarg.bases or '', '([^;]+);') do
		local bvirt = get_virtuals(get_unique_fullname(b))
		for _, v in ipairs(bvirt) do
			if not impl[v.xarg.name] then
				table.insert(ret, v)
				impl[v.xarg.name] = true
			end
		end
	end
	return ret
end

local virtual_proto = function(f)
	assert_function(f)
	local ret = 'virtual '..f.xarg.type_name..' '..f.xarg.name..'('
	local larg1, larg2 = function_proto(f)
	ret = ret .. larg1 .. ')'
	return ret
end

local virtual_body = function(f)
	local ret = ''
	return ret
end

local examine_class = function(c)
	assert(entities.is_class(c), 'not a class')
	local constr, destr = {}, nil
	for _, f in ipairs(c) do
		if entities.is_function(f) then
			if entities.is_constructor(f) then
				table.insert(constr, f)
			elseif entities.is_destructor(f) then
				assert(not destr, 'cannot have more than one destructor!')
				destr = f
			end
		end
	end
	--[[
	local public_f, protected_f, virtual_f, virt_prot_f, abstract_f = {}, {}, {}, {}, {}
	for _, f in ipairs(c) do
		if entities.is_function(f) then
			if f.xarg.abstract=='1' then
				table.insert(abstract_f, f)
			elseif f.xarg.virtual=='1' and f.xarg.access=='protected' then
				table.insert(virt_prot_f, f)
			elseif f.xarg.virtual=='1' and f.xarg.access=='public' then
				table.insert(virtual_f, f)
			elseif f.xarg.virtual~='1' and f.xarg.access=='protected' then
				table.insert(protected_f, f)
			elseif f.xarg.virtual~='1' and f.xarg.access=='public' then
				table.insert(public_f, f)
			end
		end
	end
	--]]
	local cname = 'lqt_shell_class'..c.xarg.id
	local ret = 'class '..cname..' : public '..c.xarg.fullname..' {\npublic:\n'
	ret = ret .. 'lua_State *L;\n'
	local onlyprivate = true
	for _, f in ipairs(constr) do
		if f.xarg.access~='private' then
			onlyprivate = false
			local larg1, larg2 = function_proto(f)
			assert(larg1 and larg2, 'cannot reproduce prototype of function')
			larg1 = (larg1=='') and '' or (', '..larg1)
			ret = ret .. cname .. '(lua_State *l'..larg1..'):'..c.xarg.fullname..'('
			ret = ret .. larg2 .. '), L(l) {} // '..f.xarg.id..'\n'
		end
	end
	if #constr==0 then
		ret = ret .. cname .. '(lua_State *l):L(l) {} // automatic \n'
	elseif onlyprivate then
		error('cannot bind class: '..c.xarg.fullname..': it has only private constructors')
	end
	ret = ret .. 'virtual ~'..cname..'() { lqtL_unregister(L, this); }\n'

	local virtuals = get_virtuals(c)
	for _, f in ipairs(virtuals) do
		ret = ret .. virtual_proto(f) .. ';\n'
	end

	ret = ret .. '};\n'
	return ret
end

for _, v in pairs(xmlstream.byid) do
	if false and string.find(v.label, 'Function')==1 and (not filter_out(v, FUNCTIONS_FILTERS)) then
		local status, err = pcall(function_description, v)
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
		if true or status then
			local s, e = pcall(calling_code, v)
			--io[s and 'stdout' or 'stderr']:write((s and ''
			--or ('error calling '..v.xarg.fullname..': '))..e..(s and '' or '\n'))
			if s then
				io.stdout:write('extern "C" int bound_function'..v.xarg.id..' (lua_State *L) {\n')
				io.stdout:write(e)
				io.stdout:write('}\n') -- FIXME
			end
		else
			print(err)
		end
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	elseif v.label=='Class' and not filter_out(v, CLASS_FILTERS) then -- do not support templates yet
		local st, ret = pcall(examine_class, v)
		if st then print(ret) else io.stderr:write(ret, '\n') end
	end
end
--table.foreach(name_list, print)


