#!/usr/bin/lua

local my = {
	readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end
}

local elements = dofile'entities.lua'
assert_function = function(f)
	assert(entities.is_function(f), 'argument is not a function')
end

local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local xmlstream, idindex = dofile(path..'xml.lua')(my.readfile(filename))
--local code = xmlstream[1]

local debug = function(...)
	for i = 1, select('#',...) do
		io.stderr:write((i==1) and '' or '\t', tostring(select(i,...)))
	end
	io.stderr:write'\n'
end

----------------------------------------------------------------------------------

local copy_functions = function(index)
	local ret, copied = {}, 0
	for e in pairs(index) do
		if e.label:match'^Function' then
			--[[and not (e.xarg.name:match'^[%a]*'=='operator'
			or e.xarg.fullname:match'%b<>'
			or e.xarg.name:match'_'
			or e.xarg.name:match'[xX]11'
			or e.xarg.fullname:match'QInternal'
			or e.xarg.access=='private'
			or e.xarg.access=='protected' -- FIXME
			or e.xarg.fullname=='QVariant::canConvert') then --]]
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

local fix_functions = function(index, all)
	local fullnames = {}
	for e in pairs(all or {}) do
		if e.xarg.fullname then fullnames[e.xarg.fullname] = true end
	end
	for f in pairs(index) do
		local args = {}
		for i, a in ipairs(f) do
			-- avoid bogus 'void' arguments
			if a.xarg.type_name=='void' and i==1 and f[2]==nil then break end
			if a.label=='Argument' then
				table.insert(args, a)
				if a.xarg.default=='1' and string.match(a.xarg.defaultvalue, '%D') then
					local dv = a.xarg.defaultvalue
					if not fullnames[dv] then
						dv = a.xarg.context..'::'..dv
					end
					if fullnames[dv] then
						a.xarg.defaultvalue = dv
					else
						a.xarg.default = nil
						a.xarg.defaultvalue = nil
					end
				end
			end
		end
		f.arguments = args
		if elements.is_constructor(f) then
			f.xarg.fullname = '*new '..f.xarg.fullname
			f.return_type = f.xarg.type_base..'&'
			f.xarg.static = '1'
		elseif elements.is_destructor(f) or f.xarg.type_name=='void' then
			f.return_type = nil
		else
			if false and f.xarg.access=='protected' then
				local shellname = 'lqt_shell_'..string.gsub(f.parent.xarg.fullname, '::', '_LQT_')
				f.xarg.fullname = shellname..'::'..f.xarg.name
				if f.xarg.static~='1' then
					f.xarg.static='1'
					local newarg = { label='Argument', xarg = {
						type_name = f.xarg.member_of_class..'*',
					}, }
					table.insert(args, newarg, 1)
				end
			end
			f.return_type = f.xarg.type_name
		end
	end
	return index
end

local copy_enums = function(index)
	local ret = {}
	for e in pairs(index) do
		if e.label=='Enum'
			and not string.match(e.xarg.fullname, '%b<>')
			and e.xarg.access~='private' then
			ret[e] = true
		end
	end
	return ret
end

local fix_enums = function(index)
	for e in pairs(index) do
		local values = {}
		for _, v in ipairs(e) do
			if v.label=='Enumerator' then
				table.insert(values, v)
			end
		end
		e.values = values
	end
	return index
end

local copy_classes = function(index)
	local ret = {}
	for e in pairs(index) do
		if e.label=='Class'
			and e.xarg.access~='private'
			and not (e.xarg.fullname:match'%b<>' 
			or e.xarg.fullname=='QDebug::Stream'
			or e.xarg.fullname=='QForeachContainerBase'
			or e.xarg.fullname=='QByteArray::Data'
			or e.xarg.fullname=='QVariant::Private::Data'
			or e.xarg.fullname=='QRegion::QRegionData'
			or e.xarg.fullname=='QTextStreamManipulator'
			or e.xarg.fullname=='QString::Data'
			or e.xarg.fullname=='QThreadStorageData'
			) then
			ret[e] = true
		end
	end
	return ret
end

local fill_virtuals = function(index)
	local classes = {}
	for c in pairs(index) do
		classes[c.xarg.fullname] = c
	end
	local get_virtuals
	get_virtuals = function(c)
		local ret = {}
		for _, f in ipairs(c) do
			if f.label=='Function' and f.xarg.virtual=='1' then
				local n = string.match(f.xarg.name, '~') or f.xarg.name
				if n~='~' then ret[n] = f end
			end
		end
		for b in string.gmatch(c.xarg.bases or '', '([^;]+);') do
			local base = classes[b]
			if type(base)=='table' then
				local bv = get_virtuals(base)
				for n, f in pairs(bv) do
					if not ret[n] then ret[n] = f end
				end
			end
		end
		for _, f in ipairs(c) do
			if f.label=='Function'
				and f.xarg.access~='private'
				and (ret[string.match(f.xarg.name, '~') or f.xarg.name]) then
				f.xarg.virtual = '1'
				local n = string.match(f.xarg.name, '~')or f.xarg.name
				ret[n] = f
			end
		end
		return ret
	end
	for c in pairs(index) do
		c.virtuals = get_virtuals(c)
		for _, f in pairs(c.virtuals) do
			if f.xarg.abstract=='1' then c.abstract=true break end
		end
	end
	return index
end

local fill_special_methods = function(index)
	for c in pairs(index) do
		local construct, destruct, normal = {}, nil, {}
		local n = c.xarg.name
		local auto, copy = true, nil
		for _, f in ipairs(c) do
			if n==f.xarg.name then
				auto = false
				if #(f.arguments or {})==1 and
					f.arguments[1].xarg.type_name==(c.xarg.fullname..' const&') then
					copy = f.xarg.access or 'PUBLIC?'
				end
			end
			if n==f.xarg.name then
				table.insert(construct, f)
			elseif f.xarg.name:match'~' then
				destruct = f
			else
				if (not string.match(f.xarg.name, '^operator%W'))
					and (not f.xarg.member_template_parameters) then
					table.insert(normal, f)
				end
			end
		end
		construct.auto = auto
		construct.copy = (copy==nil and 'auto' or copy) -- FIXME: must try
		c.constructors = construct
		c.destructor = destruct and (destruct.xarg.access or 'PUBLIC?') or 'auto'
		c.methods = normal
	end
	return index
end

local fill_copy_constructor = function(index)
	local classes = {}
	for c in pairs(index) do
		classes[c.xarg.name] = c
	end
	local destr
	destr = function(c)
		if c.destructor=='auto' then
			local ret = nil
			for b in string.gmatch(c.xarg.bases or '', '([^;]+);') do
				local base = classes[b]
				if base and destr(base)=='private' then
					c.destructor = 'private'
					return 'private'
				end
			end
		end
		return c.destructor
	end
	local copy_constr
	copy_constr = function(c)
		if c.constructors.copy=='auto' then
			local ret = nil
			for b in string.gmatch(c.xarg.bases or '', '([^;]+);') do
				local base = classes[b]
				if base and copy_constr(base)=='private' then
					c.constructors.copy = 'private'
					return 'private'
				end
			end
		end
		return c.constructors.copy
	end
	for c in pairs(index) do
		c.constructors.copy = copy_constr(c)
		c.destructor = destr(c)
		--io.stderr:write(c.xarg.fullname, '\t', c.constructors.copy, '\n')
		--io.stderr:write(c.xarg.fullname, '\t', c.destructor, '\n')
	end
	return index
end

local fill_typesystem_with_enums = function(enums, types)
	local ret = {}
	for e in pairs(enums) do
		if not types[e.xarg.fullname] then
			ret[e] = true
			types[e.xarg.fullname] = {
				push = function(n)
					return 'lqtL_pushenum(L, '..n..', "'..e.xarg.fullname..'")', 1
				end,
				get = function(n)
					return 'static_cast<'..e.xarg.fullname..'>'
					..'(lqtL_toenum(L, '..n..', "'..e.xarg.fullname..'"))', 1
				end,
				test = function(n)
					return 'lqtL_isenum(L, '..n..', "'..e.xarg.fullname..'")', 1
				end,
			}
		else
			--io.stderr:write(e.xarg.fullname, ': already present\n')
		end
	end
	return ret
end

local fill_typesystem_with_classes = function(classes, types)
	local ret = {}
	for c in pairs(classes) do
		if not types[c.xarg.fullname] then
			ret[c] = true
			types[c.xarg.fullname..'*'] = {
				-- the argument is a pointer to class
				push = function(n)
					return 'lqtL_passudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
				end,
				get = function(n)
					return 'static_cast<'..c.xarg.fullname..'*>'
					..'(lqtL_toudata(L, '..n..', "'..c.xarg.fullname..'*"))', 1
				end,
				test = function(n)
					return 'lqtL_isudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
				end,
			}
			types[c.xarg.fullname..' const*'] = {
				-- the argument is a pointer to constant class instance
				push = function(n)
					return 'lqtL_passudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
				end,
				get = function(n)
					return 'static_cast<'..c.xarg.fullname..'*>'
					..'(lqtL_toudata(L, '..n..', "'..c.xarg.fullname..'*"))', 1
				end,
				test = function(n)
					return 'lqtL_isudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
				end,
			}
			types[c.xarg.fullname..'&'] = {
				-- the argument is a reference to class
				push = function(n)
					return 'lqtL_passudata(L, &'..n..', "'..c.xarg.fullname..'*")', 1
				end,
				get = function(n)
					return '*static_cast<'..c.xarg.fullname..'*>'
					..'(lqtL_toudata(L, '..n..', "'..c.xarg.fullname..'*"))', 1
				end,
				test = function(n)
					return 'lqtL_isudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
				end,
			}
			if c.constructors.copy~='private' then -- and c.destructor~='private' then
				local shellname = 'lqt_shell_'..string.gsub(c.xarg.fullname, '::', '_LQT_')
				types[c.xarg.fullname] = {
					-- the argument is the class itself
					push = function(n)
						return 'lqtL_passudata(L, new '..shellname
						..'(L, '..n..'), "'..c.xarg.fullname..'*")', 1
					end,
					get = function(n)
						return '*static_cast<'..c.xarg.fullname..'*>'
						..'(lqtL_toudata(L, '..n..', "'..c.xarg.fullname..'*"))', 1
					end,
					test = function(n)
						return 'lqtL_isudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
					end,
				}
				types[c.xarg.fullname..' const&'] = {
					-- the argument is a pointer to class
					push = function(n)
						return 'lqtL_passudata(L, new '..shellname
						..'(L, '..n..'), "'..c.xarg.fullname..'*")', 1
					end,
					get = function(n)
						return '*static_cast<'..c.xarg.fullname..'*>'
						..'(lqtL_toudata(L, '..n..', "'..c.xarg.fullname..'*"))', 1
					end,
					test = function(n)
						return 'lqtL_isudata(L, '..n..', "'..c.xarg.fullname..'*")', 1
					end,
				}
			else
				--io.stderr:write(c.xarg.fullname, ': no copy constructor\n')
			end
		else
			--io.stderr:write(c.xarg.fullname, ': already present\n')
		end
	end
	return ret
end

local fill_wrapper_code = function(f, types, debug)
	debug = debug or function()end
	local stackn, argn = 1, 1
	local wrap, line = '', ''
	if f.xarg.member_of_class and f.xarg.static~='1' then
		if not types[f.xarg.member_of_class..'*'] then return nil end -- print(f.xarg.member_of_class) return nil end
		local sget, sn = types[f.xarg.member_of_class..'*'].get(stackn)
		wrap = wrap .. '  ' .. f.xarg.member_of_class .. '* self = ' .. sget .. ';\n'
		stackn = stackn + sn
		wrap = wrap .. [[
  if (NULL==self) {
    lua_pushstring(L, "this pointer is NULL");
    lua_error(L);
  }
]]
		--print(sget, sn)
		line = 'self->'..f.xarg.fullname..'('
	else
		line = f.xarg.fullname..'('
	end
	for i, a in ipairs(f.arguments) do
		if not types[a.xarg.type_name] then debug(a.xarg.type_name) return nil end -- print(a.xarg.type_name) return nil end
		local aget, an = types[a.xarg.type_name].get(stackn)
		wrap = wrap .. '  ' .. a.xarg.type_name .. ' arg' .. tostring(argn) .. ' = '
		if a.xarg.default=='1' and an>0 then
			wrap = wrap .. 'lua_isnoneornil(L, '..stackn..')'
			for j = stackn+1,stackn+an-1 do
				wrap = wrap .. ' && lua_isnoneornil(L, '..j..')'
			end
			local dv = a.xarg.defaultvalue
			wrap = wrap .. ' ? ' .. dv .. ' : '
		end
		wrap = wrap .. aget .. ';\n'
		line = line .. (argn==1 and 'arg' or ', arg') .. argn
		stackn = stackn + an
		argn = argn + 1
	end
	line = line .. ')'
	-- FIXME: hack follows for constructors
	if f.calling_line then line = f.calling_line end
	if f.return_type then line = f.return_type .. ' ret = ' .. line end
	wrap = wrap .. '  ' .. line .. ';\n  lua_settop(L, 0);\n' -- lua_pop(L, '..stackn..');\n'
	if f.return_type then
		if not types[f.return_type] then return nil end
		local rput, rn = types[f.return_type].push'ret'
		wrap = wrap .. '  luaL_checkstack(L, '..rn..', "cannot grow stack for return value");\n'
		wrap = wrap .. '  '..rput..';\n  return '..rn..';\n'
	else
		wrap = wrap .. '  return 0;\n'
	end
	f.wrapper_code = wrap
	return f
end

local fill_test_code = function(f, types)
	local stackn = 1
	local test = ''
	if f.xarg.member_of_class and f.xarg.static~='1' then
		if not types[f.xarg.member_of_class..'*'] then return nil end -- print(f.xarg.member_of_class) return nil end
		local stest, sn = types[f.xarg.member_of_class..'*'].test(stackn)
		test = test .. ' && ' .. stest
		stackn = stackn + sn
	end
	for i, a in ipairs(f.arguments) do
		if not types[a.xarg.type_name] then return nil end -- print(a.xarg.type_name) return nil end
		local atest, an = types[a.xarg.type_name].test(stackn)
		if a.xarg.default=='1' and an>0 then
			test = test .. ' && (lqtL_missarg(L, ' .. stackn .. ', ' .. an .. ') || '
			test = test .. atest .. ')'
		else
			test = test .. ' && ' .. atest
		end
		stackn = stackn + an
	end
	-- can't make use of default values if I fix number of args
	test = '(lua_gettop(L)<' .. stackn .. ')' .. test
	f.test_code = test
	return f
end

local fill_wrappers = function(functions, types)
	local ret = {}
	for f in pairs(functions) do
		f = fill_wrapper_code(f, types)
		if f then
			f = assert(fill_test_code(f, types), f.xarg.fullname) -- MUST pass
			ret[f] = true
			local out = 'extern "C" int lqt_bind'..f.xarg.id..' (lua_State *L) {\n'
			.. f.wrapper_code .. '}\n'
			--print(out)
		end
	end
	return ret
end

local argument_name = function(tn, an)
	local ret
	if string.match(tn, '%(%*%)') then
		ret = string.gsub(tn, '%(%*%)', '(*'..an..')', 1)
	elseif string.match(tn, '%[.*%]') then
		ret = string.gsub(tn, '(%[.*%])', an..'%1')
	else
		ret = tn .. ' ' .. an
	end
	return ret
end

local virtual_overload = function(v, types)
	local ret = ''
	if v.virtual_overload then return v end
	-- make return type
	if v.return_type and not types[v.return_type] then return nil end
	local rget, rn = '', 0
	if v.return_type then rget, rn = types[v.return_type].get'oldtop+1' end
	local retget = (v.return_type and argument_name(v.return_type, 'ret')
	.. ' = ' .. rget .. ';' or '') .. 'lua_settop(L, oldtop);return'
	.. (v.return_type and ' ret' or '')
	-- make argument push
	local pushlines, stack = '', 0
	for i, a in ipairs(v.arguments) do
		if not types[a.xarg.type_name] then return nil end
		local apush, an = types[a.xarg.type_name].push('arg'..i)
		pushlines = pushlines .. '    ' .. apush .. ';\n'
		stack = stack + an
	end
	-- make lua call
	local luacall = 'lua_pcall(L, '..stack..', '..rn..', 0)'
	-- make prototype and fallback
	local proto = (v.return_type or 'void')..' ;;'..v.xarg.name..' ('
	local fallback = ''
	for i, a in ipairs(v.arguments) do
		proto = proto .. (i>1 and ', ' or '')
		.. argument_name(a.xarg.type_name, 'arg'..i)
		fallback = fallback .. (i>1 and ', arg' or 'arg') .. i
	end
	proto = proto .. ')' .. (v.xarg.constant=='1' and ' const' or '')
	fallback = (v.return_type and 'return this->' or 'this->')
	.. v.xarg.fullname .. '(' .. fallback .. ');\n}\n'
	ret = proto .. [[ {
  int oldtop = lua_gettop(L);
  lqtL_pushudata(L, this, "]]..v.xarg.member_of_class..[[*");
  lua_getfield(L, -1, "]]..v.xarg.name..[[");
  if (lua_isfunction(L, -1)) {
    lua_insert(L, -2);
]] .. pushlines .. [[
    if (]]..luacall..[[) {
      ]]..retget..[[;
    }
  }
  lua_settop(L, oldtop);
  ]] .. fallback
	v.virtual_overload = ret
	v.virtual_proto = string.gsub(proto, ';;', '', 1)
	return v
end

local fill_shell_class = function(c, types)
	local shellname = 'lqt_shell_'..string.gsub(c.xarg.fullname, '::', '_LQT_')
	local shell = 'class ' .. shellname .. ' : public ' .. c.xarg.fullname .. ' {\npublic:\n'
	shell = shell .. '  lua_State *L;\n'
	for _, constr in ipairs(c.constructors) do
		if constr.xarg.access~='private' then
			local cline = '  '..shellname..' (lua_State *l'
			local argline = ''
			for i, a in ipairs(constr.arguments) do
				cline = cline .. ', ' .. argument_name(a.xarg.type_name, 'arg'..i)
				argline = argline .. (i>1 and ', arg' or 'arg') .. i
			end
			cline = cline .. ') : ' .. c.xarg.fullname
				.. '(' .. argline .. '), L(l) '
				.. '{ lqtL_register(L, this); }\n'
			shell = shell .. cline
		end
	end
	if c.constructors.copy=='auto' then
		local cline = '  '..shellname..' (lua_State *l, '..c.xarg.fullname..' const& arg1)'
		cline = cline .. ' : ' .. c.xarg.fullname .. '(arg1), L(l) {}\n'
		shell = shell .. cline
	end
	for i, v in pairs(c.virtuals) do
		if v.xarg.access~='private' then
			local vret = virtual_overload(v, types)
			if v.virtual_proto then shell = shell .. '  virtual ' .. v.virtual_proto .. ';\n' end
		end
	end
	shell = shell .. '  ~'..shellname..'() { lqtL_unregister(L, this); }\n'
	shell = shell .. '};\n'
	c.shell_class = shell
	return c
end

local fill_shell_classes = function(classes, types)
	local ret = {}
	for c in pairs(classes) do
		if c.shell then
			c = fill_shell_class(c, types)
			if c then ret [c] = true print(c.shell_class)
			else
				io.stderr:write(c.fullname, '\n')
			end
		end
	end
	return ret
end

local print_virtual_overloads = function(classes, types)
	for c in pairs(classes) do
		local shellname = 'lqt_shell_'..string.gsub(c.xarg.fullname, '::', '_LQT_')
		for _,v in pairs(c.virtuals) do
			if v.virtual_overload then
				print((string.gsub(v.virtual_overload, ';;', shellname..'::', 1)))
			end
		end
	end
	return classes
end

local print_wrappers = function(index)
	for c in pairs(index) do
		local meta = {}
		for _, f in ipairs(c.methods) do
			if f.wrapper_code then
				local out = 'extern "C" int lqt_bind'..f.xarg.id
				..' (lua_State *L) {\n'.. f.wrapper_code .. '}\n'
				if f.xarg.access=='public' then
					print(out)
					meta[f] = f.xarg.name
				end
			end
		end
		if c.shell then
			for _, f in ipairs(c.constructors) do
				if f.wrapper_code then
					local out = 'extern "C" int lqt_bind'..f.xarg.id
					    ..' (lua_State *L) {\n'.. f.wrapper_code .. '}\n'
					if f.xarg.access=='public' then
						print(out)
						meta[f] = 'new'
					end
				end
			end
			--local shellname = 'lqt_shell_'..string.gsub(c.xarg.fullname, '::', '_LQT_')
			local out = 'extern "C" int lqt_delete'..c.xarg.id..' (lua_State *L) {\n'
			out = out ..'  '..c.xarg.fullname..' *p = static_cast<'
				..c.xarg.fullname..'*>(lqtL_toudata(L, 1, "'..c.xarg.fullname..'*"));\n'
			out = out .. '  if (p) delete p;\n  return 0;}\n'
			print(out)
		end
		c.meta = meta
	end
	return index
end

local print_metatable = function(c)
	local methods = {}
	for m, n in pairs(c.meta) do
		methods[n] = methods[n] or {}
		table.insert(methods[n], m)
	end
	for n, l in pairs(methods) do
		local disp = 'extern "C" int lqt_dispatcher_'..n..c.xarg.id..' (lua_State *L) {\n'
		for _, f in ipairs(l) do
			disp = disp..'  if ('..f.test_code..') return lqt_bind'..f.xarg.id..'(L);\n'
		end
		disp = disp .. '  lua_settop(L, 0);\n'
		disp = disp .. '  lua_pushstring(L, "incorrect or extra arguments");\n'
		disp = disp .. '  return lua_error(L);\n}\n' 
		print(disp)
	end
	local metatable = 'static luaL_Reg lqt_metatable'..c.xarg.id..'[] = {\n'
	for n, l in pairs(methods) do
		metatable = metatable .. '  { "'..n..'", lqt_dispatcher_'..n..c.xarg.id..' },\n'
	end
	if c.shell then
		metatable = metatable .. '  { "delete", lqt_delete'..c.xarg.id..' },\n'
	end
	metatable = metatable .. '  { 0, 0 },\n};\n'
	print(metatable)
	local bases = ''
	for b in string.gmatch(c.xarg.bases or '', '([^;]*);') do
		bases = bases .. '{"' .. b .. '*"}, '
	end
	bases = 'static lqt_Base lqt_base'..c.xarg.id..'[] = { '..bases..'{NULL} };\n'
	print(bases)
	return c
end

local print_metatables = function(classes)
	for c in pairs(classes) do
		print_metatable(c)
	end
	return classes
end

local print_class_list = function(classes)
	local list = 'static lqt_Class lqt_class_list[] = {\n'
	for c in pairs(classes) do
		class = '{ lqt_metatable'..c.xarg.id..', lqt_base'..c.xarg.id..', "'..c.xarg.fullname..'*" },\n'
		list = list .. '  ' .. class
	end
	list = list .. '  { 0, 0, 0 },\n};\n'
	print(list)
	return classes
end

local fix_methods_wrappers = function(classes)
	for c in pairs(classes) do
		-- if class seems abstract but has a shell class
		-- FIXME: destructor should not matter?
		if c.abstract and c.destructor~='private' then
			-- is it really abstract?
			local a = false
			for _, f in pairs(c.virtuals) do
				-- if it is abstract but we cannot overload
				if f.xarg.abstract=='1' and not f.virtual_overload then a = true break end
			end
			c.abstract = a
		end
		-- FIXME: destructor should not matter?
		c.shell = (not c.abstract) and (c.destructor~='private')
		for _, constr in ipairs(c.constructors) do
			local shellname = 'lqt_shell_'..string.gsub(c.xarg.fullname, '::', '_LQT_')
			constr.calling_line = '*new '..shellname..'(L'
			for i=1,#(constr.arguments) do
				constr.calling_line = constr.calling_line .. ', arg' .. i
			end
			constr.calling_line = constr.calling_line .. ')'
		end
	end
	return classes
end

local print_enum_tables = function(enums)
	for e in pairs(enums) do
		local table = 'static lqt_Enum lqt_enum'..e.xarg.id..'[] = {\n'
		--io.stderr:write(e.xarg.fullname, '\t', #e.values, '\n')
		for _,v in pairs(e.values) do
			table = table .. '  { "' .. v.xarg.name
				.. '", static_cast<int>('..v.xarg.fullname..') },\n'
		end
		table = table .. '  { 0, 0 }\n'
		table = table .. '};\n'
		e.enum_table = table
		print(table)
	end
	return enums
end
local print_enum_creator = function(enums)
	local out = 'static lqt_Enumlist lqt_enum_list[] = {\n'
	for e in pairs(enums) do
		out = out..'  { lqt_enum'..e.xarg.id..', "'..e.xarg.fullname..'" },\n'
	end
	out = out..'  { 0, 0 },\n};\n'
	out = out .. 'extern "C" int lqt_create_enums (lua_State *L) {\n'
	out = out .. '  lqtL_createenumlist(L, lqt_enum_list);  return 0;\n}\n'
	print(out)
	return enums
end

local print_openmodule = function(n)
	print([[

extern "C" int luaopen_]]..n..[[ (lua_State *L) {
  lqt_create_enums(L);
  lqtL_createclasses(L, lqt_class_list);
  return 0;
}
]])
end

local functions = copy_functions(idindex)
local functions = fix_functions(functions, idindex)

local enums = copy_enums(idindex)
local enums = fix_enums(enums)

local classes = copy_classes(idindex)
local classes = fill_virtuals(classes)
local classes = fill_special_methods(classes)
local classes = fill_copy_constructor(classes)
local classes = fix_methods_wrappers(classes)

local ntable = function(t) local ret=0 for _ in pairs(t) do ret=ret+1 end return ret end


local typesystem = {}
do
	local ts = dofile(path..'types.lua')
	setmetatable(typesystem, {
		__newindex = function(t, k, v)
			--debug('added type', k)
			ts[k] = v
		end,
		__index = function(t, k)
			local ret = ts[k]
			--if not ret then debug("unknown type:", tostring(k), ret) end
			return ret
		end,
	})
end

--debug('funcs', ntable(functions))
--debug('enums', ntable(enums))
--debug('class', ntable(classes))
local enums = fill_typesystem_with_enums(enums, typesystem)
local classes = fill_typesystem_with_classes(classes, typesystem)
local functions = fill_wrappers(functions, typesystem)
local classes = fill_shell_classes(classes, typesystem)
local classes = print_virtual_overloads(classes, typesystem)
local classes = print_wrappers(classes)
local enums = print_enum_tables(enums)
local enums = print_enum_creator(enums)
local classes = print_metatables(classes)
local classes = print_class_list(classes)
--debug('funcs', ntable(functions))
--debug('enums', ntable(enums))
--debug('class', ntable(classes))
print_openmodule'src'

local print_virtuals = function(index)
	for c in pairs(index) do
		debug(c.xarg.name)
		for n, f in pairs(c.virtuals) do debug('  '..n, f.xarg.fullname) end
	end
end


for f in pairs(idindex) do
	if f.label=='Function' and f.xarg.name=='connect' then
		--debug(f.xarg.fullname, f.xarg.wrapper_code and 'true' or 'false')
		local w = fill_wrapper_code(f, typesystem, debug)
		--debug(w)
		--print(k, v.get'INDEX')
	elseif f.label=='Function' and f.xarg.name=='QObject' then
		--debug('==>', #f.arguments, f.wrapper_code and 'wrapped' or 'gone')
	end
end

--print_virtuals(classes)

--print(copy_functions(idindex))

