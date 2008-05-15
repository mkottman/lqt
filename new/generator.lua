#!/usr/bin/lua

local my = {
	readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end
}

local entities = dofile'entities.lua'
local elements = entities
assert_function = function(f)
	assert(entities.is_function(f), 'argument is not a function')
end

local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local xmlstream, idindex = dofile(path..'xml.lua')(my.readfile(filename))
io.stderr:write'parsed XML\n'
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


local arg_iter = function(f)
	local i = 0
	local stackn = 1
	local onlyargs = 0
	return function()
		local a, retn = {}, 0
		while a and a.label~='Argument' do
			i = i + 1
			a = f[i]
		end
		retn = stackn
		onlyargs = onlyargs + 1
		if a then
			local d, g, p, n = type_properties(a)
			stackn = stackn + n
		end
		return (a and onlyargs), a, (a and retn), stackn-1
	end
end

local base_types = {}
assert(loadfile'types.lua')(base_types)

while false do
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
			return 'enum;', get_enum(fn), push_enum(fn), 1
		elseif identifier.label=='Class' then
			--assert(entities.class_is_copy_constructible(bt))
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
			ret_push = entities.class_is_copy_constructible(bt) and push_constref(t.xarg.type_base) or nil
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
		assert((f.xarg.type_name==f.xarg.type_base)
			or (f.xarg.type_name==f.xarg.type_base..'&'), 'return type of constructor is strange')
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
	local narg, sarg = 0, 0
	for i, a, s, r in arg_iter(f) do
		narg = i
		sarg = r
	end
	if entities.is_destructor(f) then
		narg, sarg = 1, 1
	elseif entities.is_constructor(f) then
	elseif entities.takes_this_pointer(f) then
		narg, sarg = narg + 1, sarg + 1
	end
	return narg, sarg
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
	local ret, shift = '', 0
	if entities.takes_this_pointer(f) then
		shift = 1
		ret = ret .. indent .. f.xarg.member_of_class .. '* self = '
		ret = ret .. get_pointer(f.xarg.member_of_class)(1) .. ';\n' -- (void)self;\n'
	end
	for argi, a, stacki in arg_iter(f) do
		local _d, g, _p, _n = type_properties(a)
		ret = ret .. indent .. a.xarg.type_name .. ' ' .. argument(argi) .. ' = '
		ret = ret .. g(stacki + shift) .. ';\n' -- .. '(void) '..argument(argi)..';\n'
	end
	return ret
end

local arg_list = function(f, pre)
	assert_function(f)
	if entities.is_destructor(f) then
		return '(self)'
	else
		local ret = ''
		for i in arg_iter(f) do
			ret = ret .. ((i>1 or pre) and ', ' or '') .. argument(i)
		end
		pre = pre or ''
		return '('..pre..ret..')'
	end
end

local function_static_call = function(f)
	assert_function(f)
	if entities.is_destructor(f) then
		return 'delete (self)'
	elseif entities.is_constructor(f) then
		return '*new lqt_shell_class' .. f.parent.xarg.id .. arg_list(f, 'L')
		-- f.xarg.fullname..arg_list(f)
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
		return '*new lqt_shell_class' .. f.parent.xarg.id .. arg_list(f)
		-- f.xarg.fullname..arg_list(f)
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


--[==[io.write[[
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
--]==]

local CLASS_FILTERS = {
	function(c) return c.xarg.fullname:match'%b<>' end,
	function(c) return c.xarg.name:match'_' end,
	--function(c) return c.xarg.fullname:match'Q.-Data' end,
	function(c) return c.xarg.class_type=='struct' end,
	function(c) return c.xarg.fullname=='QVariant::Private::Data' end,
	function(c) return c.xarg.fullname=='QTextStreamManipulator' end,
}
local FUNCTIONS_FILTERS = {
	function(f) return not pcall(calling_code, f) end,
	function(f) return f.xarg.name:match'^[_%w]*'=='operator' end,
	function(f) return f.xarg.fullname:match'%b<>' end,
	function(f) return f.xarg.name:match'_' end,
	function(f) return f.xarg.fullname:match'QInternal' end,
	function(f) return f.xarg.access~='public' end,
	function(f) return f.xarg.fullname=='QVariant::canConvert' end,
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
	for i, a in arg_iter(f) do
		if a.xarg.type_name=='void' then
			larg1, larg2 = '', ''
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
			impl[f.xarg.name] = #ret
		end
	end
	-- virtual functions in base classes are not included and
	-- reimplementation are not marked as virtuals
	for b in string.gmatch(c.xarg.bases or '', '([^;]+);') do
		local bvirt = get_virtuals(get_unique_fullname(b))
		for _, v in ipairs(bvirt) do
			if not impl[v.xarg.name] then
				table.insert(ret, v)
				impl[v.xarg.name] = #ret
			end
		end
	end
	-- [[
	-- this wants to return the top-most virtual implementation
	-- so that it knows to which version it should fallback
	for _, f in ipairs(c) do
		if impl[f.xarg.name] and f.xarg.access~='private' then
			ret[ impl[f.xarg.name] ] = f
		end
	end
	--]]
	return ret
end

local virtual_proto = function(f)
	assert_function(f)
	local ret = 'virtual '..f.xarg.type_name..' '..f.xarg.name..'('
	local larg1, larg2 = function_proto(f)
	ret = ret .. larg1 .. ')'
	return ret
end

local virtual_body = function(f, n)
	assert_function(f)
	local ret = f.xarg.type_name..' '..n..'::'..f.xarg.name..'('
	local larg1, larg2 = function_proto(f)
	ret = ret .. larg1 .. [[) {
	int oldtop = lua_gettop(L);
	lqtL_pushudata(L, this, "]]..f.parent.xarg.fullname..[[*");
	lua_getfield(L, -1, "]]..f.xarg.name..[[");
	lua_insert(L, -2);
	if (!lua_isnil(L, -2)) {
]]
	for i, a in arg_iter(f) do
		local _d, _g, p, _n = type_properties(a)
		ret = ret .. '		' .. p(argument(i)) .. ';\n'
	end
	ret = ret .. [[
		if (!lua_pcall(L, lua_gettop(L)-oldtop+1, LUA_MULTRET, 0)) {
			]]
	if f.xarg.type_name=='void' then
		ret = ret .. 'return;\n'
	else
		local _d, g, _p, _n = type_properties(f)
		ret = ret .. g('oldtop+1') .. ';\n'
	end
	ret = ret .. [[
		}
	}
	lua_settop(L, oldtop);
	]]
	if f.xarg.abstract then
		if f.xarg.type_name~='void' then
			local dc
			if f.xarg.type_name~=f.xarg.type_base then
				dc = entities.default_constructor(f)
			else
				local st, err = pcall(get_unique_fullname, f.xarg.type_base)
				dc = entities.default_constructor(st and err or f)
			end
			if not dc then return nil end
			ret = ret .. 'return ' .. dc .. ';\n'
		else
			ret = ret .. 'return;\n'
		end
	else
		if f.type_name~='void' then
			ret = ret .. 'return this->' .. f.xarg.fullname .. '(' .. larg2 .. ');\n'
		else
			ret = ret .. 'this->' .. f.xarg.fullname .. '(' .. larg2 .. ');\n'
		end
	end
	ret = ret .. '}\n'
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
			local st, larg1, larg2 = pcall(function_proto, f)
			--assert(larg1 and larg2, 'cannot reproduce prototype of function')
			if st then
				onlyprivate = false
				larg1 = (larg1=='') and '' or (', '..larg1)
				ret = ret .. cname .. '(lua_State *l'..larg1..'):'..c.xarg.fullname..'('
				ret = ret .. larg2 .. '), L(l) {} // '..f.xarg.id..'\n'
			end
		end
	end
	if #constr==0 then
		ret = ret .. cname .. '(lua_State *l):L(l) {} // automatic \n'
	elseif onlyprivate then
		error('cannot bind class: '..c.xarg.fullname..': it has only private constructors')
	end
	ret = ret .. 'virtual ~'..cname..'() { lqtL_unregister(L, this); }\n'

	local virtuals = get_virtuals(c)
	local ret2 = ''
	for _, f in ipairs(virtuals) do
		local st, bd = pcall(virtual_body, f, cname)
		if st then
			ret = ret .. virtual_proto(f) .. ';\n'
			ret2 = ret2 .. bd .. '\n'
		end
	end

	ret = ret .. '};\n' .. ret2
	return ret
end

--[==[ ]=]
for _, v in pairs(xmlstream.byid) do
	--if string.find(v.label, 'Function')==1 and v.xarg.virtual and v.xarg.abstract then io.stderr:write(v.xarg.fullname, '\n') end
	if string.find(v.label, 'Function')==1 and (not filter_out(v, FUNCTIONS_FILTERS)) then
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
			else
				io.stderr:write(e, '\n')
			end
		else
			print(err)
		end
		--io[status and 'stdout' or 'stderr']:write((status and '' or v.xarg.fullname..': ')..err..'\n')
	elseif false and v.label=='Class' and not filter_out(v, CLASS_FILTERS) then -- do not support templates yet
		local st, ret = pcall(examine_class, v)
		if st then print(ret) else io.stderr:write(ret, '\n') end
	end
end
--table.foreach(name_list, print)
--]==]

local make_function = function(f)
	local fret, s, e = '', pcall(calling_code, f)
	if s and not filter_out(f, FUNCTIONS_FILTERS) then
		fret = fret .. 'static int bound_function'..f.xarg.id..' (lua_State *L) {\n'
		fret = fret .. e
		fret = fret .. '}\n'
	end
	return fret
end

local do_class = function(fn)
	local c = get_unique_fullname(fn)
	local ret = ''
	ret = ret .. examine_class(c)

	--[[
	for _, o in pairs(c.byname) do
		if o.label=='Overloaded' then
			io.stderr:write('overload: ', o.xarg.name, ' ', #o, '\n')
			for __, f in pairs(o) do
				ret = ret .. make_function(f)
			end
		else
			ret = ret .. make_function(o)
		end
	end
	--]]
	
	local names = {}
	for _, f in ipairs(c) do
		if entities.is_function(f) and not filter_out(f, FUNCTIONS_FILTERS) then
			local _, argnum = argument_number(f) -- care about arguments on stack
			names[f.xarg.name] = names[f.xarg.name] or {}
			names[f.xarg.name][argnum] = names[f.xarg.name][argnum] or {}
			table.insert(names[f.xarg.name][argnum], f)
		end
	end

	--[[
	for n, t in pairs(names) do
		io.stderr:write(n, ' ', tostring(t), '\n')
		for a, f in pairs(t) do
			io.stderr:write('  ', tostring(a), '\n')
			for _, g in pairs(f) do
				io.stderr:write('    ', g.xarg.id, '\n')
			end
		end
	end
	--]]
	
	local fcomp = function(f, g)
		if pcall(calling_code, f) and not pcall(calling_code, g) then
		elseif entities.takes_this_pointer(g) and not entities.takes_this_pointer(f) then
			return true
		elseif argument_number(f) > argument_number(g) then
			return false
		elseif argument_number(f) < argument_number(g) then
			return true
		else
			local fa, ga = {}, {}
			for _, a in arg_iter(f) do
				table.insert(fa, a)
			end
			for _, a in arg_iter(g) do
				table.insert(ga, a)
			end
			for i = 1, #fa do
				if base_types[fa[i]] and not base_types[ga[i]] then
					return true
				elseif base_types[fa[i]] and base_types[ga[i]] then
					return false -- TODO: better handling
				end
			end
		end
		return false
	end

	io.write(ret)

	local metatable = {}
	for name, t in pairs(names) do
		local call_this_one = nil
		local fname = 'lqt_bind_'..(tostring(name):match'%~' and 'delete' or 'function')
		                .. '_' .. tostring(name):gsub('%~', '')
		for k, n in pairs(t) do
			table.sort(n, fcomp)
			t[k] = calling_code(n[1]):gsub('\n(.)', '\n  %1')
			call_this_one = call_this_one and (call_this_one .. '  } else ') or '  '
			call_this_one = call_this_one .. 'if (lua_gettop(L)=='..tostring(k)..') {\n'
			call_this_one = call_this_one .. t[k]
		end
		call_this_one = 'static int ' .. fname .. ' (lua_State *L) {\n'
		.. call_this_one
		.. '  }\n  return luaL_error(L, "wrong number of arguments");\n}\n'
		print(call_this_one)
		metatable[name] = fname
	end

	io.write('static const luaL_Reg metatable_'..c.xarg.name..'[] = {\n')
	for n, f in pairs(metatable) do
		io.write( '  { "', n, '", ', f, ' },\n')
	end
	io.write'};\n'
	io.write('\n\nextern "C" int lqtL_open_', c.xarg.name, ' (lua_State *L) {\n')
	io.write('  luaL_register(L, "QObject", metatable_', c.xarg.name, ');\n')
	io.write('  return 0;\n')
	io.write('}\n')

end

local copy_functions = function(index)
	local ret, copied = {}, 0
	for e in pairs(index) do
		if e.label:match'^Function'
			and (e.xarg.name:match'^[_%w]*'=='operator'
			or e.xarg.fullname:match'%b<>'
			or e.xarg.name:match'_'
			or e.xarg.name:match'[xX]11'
			or e.xarg.fullname:match'QInternal'
			or e.xarg.access=='private'
			or e.xarg.fullname=='QVariant::canConvert') then
			e.label = 'Function'
			ret[e] = true
			copied = copied + 1
		else
			--removed = removed + (e.label:match'^Function' and 1 or 0)
			--removed = removed + 1
		end
	end
	return ret, copied
end

local fix_functions = function(index)
	for f in pairs(index) do
		local args = {}
		for i, a in ipairs(f) do
			if a.label=='Argument' then
				table.insert(args, a)
			end
		end
		f.arguments = args
		if elements.is_constructor(f) then
			f.return_type = f.xarg.type_base..'&'
		elseif elements.is_destructor(f) then
			f.return_type = nil
		else
			f.return_type = f.xarg.type_name
		end
	end
	return index
end

local functions = copy_functions(idindex)

--print(copy_functions(idindex))

