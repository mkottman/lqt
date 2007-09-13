#!/usr/bin/lua

xml = dofile'xml.lua'

tmpfile='tmp/auto'

classlist = [[
QEvent
]]

do
local clist = {}
for s in string.gmatch(classlist, '([%u%l%d]+)') do
  clist[s] = true
end
classlist = clist
end

f = io.open(tmpfile..'.cpp', 'w')
for n in pairs(classlist) do
  f:write('#include <'..n..'>\n')
end
f:write'\nmain() {\n'
for n in pairs(classlist) do
  f:write('  '..n..' *'..string.lower(n)..';\n')
end
f:write'}\n'
f:close()

--os.execute'gccxml -g -Wall -W -D_REENTRANT -DQT_GUI_LIB -DQT_CORE_LIB -DQT_SHARED -I/usr/share/qt4/mkspecs/linux-g++ -I. -I/usr/include/qt4/QtCore -I/usr/include/qt4/QtCore -I/usr/include/qt4/QtGui -I/usr/include/qt4/QtGui -I/usr/include/qt4 -I. -I. -I. -fxml=auto.xml auto.cpp'
os.execute('gccxml `pkg-config QtGui QtCore --cflags` -fxml='..tmpfile..'.xml '..tmpfile..'.cpp')

--os.remove'auto.cpp'


B = dofile'binder.lua'
B:init(tmpfile..'.xml')
B.filter = function (m)
	local n = type(m)=='table' and type(m.attr)=='table' and m.attr.name
	if n and string.match(n, "[_%w]*[xX]11[_%w]*$") then
		return true, 'it is X11 specific'
	end
	if n and string.match(n, "[_%w]*_[_%w]*$") then
		return true, 'it is meant to be internal'
	end
	return false
end


function NOINSTANCE(b, name)
  b.types_from_stack[name] = function(i) error('cannot copy '..name) end
  b.types_test[name] = function(i) error('cannot copy '..name) end
  b.types_to_stack[name] = function(i) error('cannot copy '..name) end

  b.types_from_stack[(name..' *')] = function(i) return '*static_cast<'..name..'**>(lqtL_toudata(L, '..tostring(i)..', "'..name..'"))' end
  b.types_test[(name..' *')] = function(i) return 'lqtL_testudata(L, '..tostring(i)..', "'..name..'*")' end
  b.types_to_stack[(name..' *')] = function(i) return 'lqtL_pushudata(L, '..tostring(i)..', "'..name..'*")' end
end

NOINSTANCE(B, 'QCoreApplication')


B.types_from_stack['QString'] = function(i) return 'QString::fromAscii(lua_tostring(L, '..tostring(i)..'), lua_objlen(L, '..tostring(i)..'))' end
B.types_test['QString'] = function(i) return '(lua_type(L, ' .. tostring(i) .. ')==LUA_TSTRING)' end
B.types_to_stack['QString'] = function(i) return 'lua_pushlstring(L, '..tostring(i)..'.toAscii().data(), '..tostring(i)..'.toAscii().size())' end

B.types_from_stack['QByteArray'] = function(i) return 'QByteArray(lua_tostring(L, '..tostring(i)..'), lua_objlen(L, '..tostring(i)..'))' end
B.types_test['QByteArray'] = function(i) return '(lua_type(L, ' .. tostring(i) .. ')==LUA_TSTRING)' end
B.types_to_stack['QByteArray'] = function(i) return 'lua_pushlstring(L, '..tostring(i)..'.data(), '..tostring(i)..'.size())' end

function B:enum_push_body(id, c)
	local enum = (type(id)=='string') and self:find_id(id) or id
	local e_context = self:context_name(enum)
	local e_name = 'lqt_pushenum_' .. enum.attr.name
	local e_proto, e_def = '', ''

	e_proto = e_proto .. '  static ' .. self.lua_proto(e_name) .. ';\n'
	e_def = e_def .. self.lua_proto(c .. e_name) .. ' '
	e_def = e_def .. '{\n'
	e_def = e_def .. '  int enum_table = 0;\n'
	e_def = e_def .. '  lua_getfield(L, LUA_REGISTRYINDEX, LQT_ENUMS);\n'
	e_def = e_def .. '  if (!lua_istable(L, -1)) {\n'
	e_def = e_def .. '    lua_pop(L, 1);\n'
	e_def = e_def .. '    lua_newtable(L);\n'
	e_def = e_def .. '    lua_pushvalue(L, -1);\n'
	e_def = e_def .. '    lua_setfield(L, LUA_REGISTRYINDEX, LQT_ENUMS);\n'
	e_def = e_def .. '  }\n'

	e_def = e_def .. '  lua_newtable(L);\n'
	e_def = e_def .. '  enum_table = lua_gettop(L);\n'
	for i, e in ipairs(enum) do
		if (type(e)=='table') and (e.tag=='EnumValue') then
			e_def = e_def .. '  lua_pushstring(L, "' .. e.attr.name .. '");\n'
			e_def = e_def .. '  lua_rawseti(L, enum_table, ' .. e.attr.init .. ');\n'
			e_def = e_def .. '  lua_pushinteger(L, ' .. e.attr.init .. ');\n'
			e_def = e_def .. '  lua_setfield(L, enum_table, "' .. e.attr.name .. '");\n'
		end
	end
	e_def = e_def .. '  lua_pushvalue(L, -1);\n'
	e_def = e_def .. '  lua_setfield(L, -3, "' .. e_context .. enum.attr.name .. '");\n'
	e_def = e_def .. '  lua_remove(L, -2);\n'
	e_def = e_def .. '  return 1;\n'
	e_def = e_def .. '}\n'
	--print (e_def)
	return e_proto, e_def, e_name
end
	

--[=====[
my_typename = 'QWidget'
my_class = B:find_name(my_typename)
my_context = B.wrapclass(my_typename)..'::'
my_pointer = B:find(B.pointer_search(my_class.attr.id))
my_enums = my_enums or {}
--]=====]

--lua_proto = B.lua_proto

--[[
hpp = {
  includes = {  },
  public = { 'public:\n' },
  private = { 'private:\n', '  lua_State *L;\n' },
  protected = { 'protected:\n' },
}

my_file = B:find_id(my_class.attr.file)
table.insert(hpp.includes, '#include "lqt_common.hpp"\n')
table.insert(hpp.includes, '#include "'..my_file.attr.name..'"\n')

cpp = { 
  includes = {},
  util = {},
  pusher = {},
  wrappers = {},
  register = {},
}
--]]

--my_virtual_destructor = false
--my_virtual = {}

function B:mangled (f)
  local args = B:arguments_of(f)
  local k = f.attr.name..'('
  for i = 1, table.maxn(args) do
    k = k..', '..self:type_name(args.attr.type)
  end
  k = k..')'
  return k
end


function B:get_virtuals (c)
  local c_v = self:get_members(c).virtuals
  local mang_virtuals = {}

  for n, f in pairs(c_v) do
    if f.attr.virtual=='1' then
      local k = self:mangled(f)
      mang_virtuals[k] = mang_virtuals[k] or f
    end
  end


  for s in string.gmatch(c.attr.bases or '', '(_%d+) ') do
    local my_base = self:find_id(s)
    local my_virtual = self:get_virtuals(my_base)
    for k, f in pairs(my_virtual) do
      mang_virtuals[k] = mang_virtuals[k] or f
    end
  end

  return mang_virtuals
  --[==[


  -- FIXME: deep inheritance tree

  local bvirtuals = {}
  for i = 1,table.maxn(classes) do
    local base = classes[i]
    local bm = B:get_members(base)
    for n, l in pairs(bm.methods) do
      for i, f in pairs(l) do
        if f.attr.virtual=='1' then table.insert(bvirtuals, f) end
      end
    end
    for i, f in pairs(bm.pure_virtuals) do
      if f.attr.virtual=='1' then table.insert(bvirtuals, f) end
    end
  end
  for i, v in ipairs(bvirtuals) do
    local args = B:arguments_of(v)
    local k = self:mange(v)
    mang_bvirtuals[k] = mang_bvirtuals[k] or v
  end

  return mang_bvirtuals
--]==]
end

function proto_preamble (n, i)
  -- FIXME: this is only Qt (the inclusion by name of class)
  -- FIXED?
  i = i or n
  return [[
#include "lqt_common.hpp"
#include <]]..i..[[>

template <> class ]] .. B.wrapclass(n) .. [[ : public ]]  .. n .. [[ {
  private:
  lua_State *L;
  public:
]]
end

function proto_ending (n)
 return [[
};

]]
end


function B:copy_constructor(c)
      local constr = '  '
      local args = self.arguments_of(c)
      constr = constr .. self.wrapclass(c.attr.name) .. ' (lua_State *l'
      for argi = 1, table.maxn(args) do
        local argt = self:find_id(args[argi].attr.type)
        local argtype = self:type_name(argt)
        constr = constr .. ', ' .. argtype .. ' arg'..tostring(argi)
      end
      constr = constr .. '):'..c.attr.name..'('
      for argi = 1, table.maxn(args) do
        constr = constr .. ((argi>1) and ', ' or '') .. 'arg'..tostring(argi)
      end
      constr = constr .. '), L(l) {}\n'
      return constr, nil
end


function meta_constr_proto (n) return 'int luaopen_'..n..' (lua_State *L);\n' end
function meta_constr_preamble (n)
  return [[
int luaopen_]]..n..[[ (lua_State *L) {
  if (luaL_newmetatable(L, "]]..n..[[*")) {
]]
end
function meta_constr_method (n, c)
  c = c or ''
  return '    lua_pushcfunction(L, '..c..n..');\n    lua_setfield(L, -2, "'..n..'");\n'
end
function meta_constr_ending (n)
  return [[
    lua_pushcfunction(L, lqtL_newindex);
    lua_setfield(L, -2, "__newindex");
    lua_pushcfunction(L, lqtL_index);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, lqtL_gc);
    lua_setfield(L, -2, "__gc");
    lua_pushstring(L, "]]..n..[[");
    lua_setfield(L, -2, "__qtype");
  }
  lua_pop(L, 1);
  return 0;
}
]]
end


function B:virtual_overload (f, c, id)
	--if f.attr.access~='public' then error'only public virtual function are exported' end
	if f.attr.access=='private' then error'private virtual function are not exported' end

  c = c or ''
  local args = self.arguments_of(f)
  local ret_t = f.attr.returns and self:find_id(f.attr.returns)
  local ret_n = ret_t and self:type_name(ret_t) or 'void'
  local fh, fb = '  ', ''
  fh = fh .. ret_n .. ' ' .. f.attr.name .. ' ('
  fb = fb .. ret_n .. ' ' .. c .. f.attr.name .. ' ('
  
  -- GETTING ARGUMENTS
  for argi = 1, table.maxn(args) do
    local arg = args[argi]
    local argname = 'arg' .. tostring(argi)
    
    local argt = self:find_id(arg.attr.type)
    local argtype = self:type_name(argt)
    local def = arg.attr.default or nil
    
    def = def and (self:context_name(argt)..def)
    
    --print ('signing arg type', argtype)
    
    if argi>1 then fh = fh .. ', ' fb = fb .. ', ' end
    fh = fh .. argtype .. ' ' .. argname .. (def and (' = '..def) or '')
    fb = fb .. argtype .. ' ' .. argname
  end
  
  fh = fh .. ')' .. (f.attr.const and ' const' or '') .. ';\n'

  if f.attr.access~='public' then
    fh = f.attr.access .. ':\n' .. fh .. 'public:\n'
  end

  fb = fb .. ')' .. (f.attr.const and ' const' or '') .. ' {\n'
  fb = fb .. '  bool absorbed = false;\n  int oldtop = lua_gettop(L);\n'
  
  local context = self:context_name(f)
  local pointer_to_class = self.fake_pointer ( id or f.attr.context )
  local push_this = self:type_to_stack(pointer_to_class)'this'
  --fb = fb .. '  ' .. push_this .. ';\n'
  --fb = fb .. '  lua_getfield(L, -1, "'..(f.attr.name)..'");\n  lua_insert(L, -2);\n' 
---[=[
  fb = fb .. '  ' .. push_this .. [[;
	if (lua_getmetatable(L, -1)) {
		lua_getfield(L, -1, "]]..(f.attr.name)..[[");
		lua_remove(L, -2);
	} else {
		lua_pushnil(L);
	}
	lua_insert(L, -2);
]]
--]=]


  for argi = 1, table.maxn(args) do
    local arg = args[argi]
    local argname = 'arg' .. tostring(argi)
    
    local argt = self:find_id(arg.attr.type)
    local argtype = self:type_name(argt)
    local def = arg.attr.default
    
    def = def and (self:context_name(argt)..def)
    
    local to_stack = self:type_to_stack(argt)(argname)
    --to_stack = (type(to_stack)=='string') and to_stack or table.concat(to_stack, '\n  ')
    fb = fb .. '  ' .. to_stack .. ';\n'
  end
  
  local sig = '(' .. (args[1] and 'arg1' or '')
  for argi = 2, table.maxn(args) do
    sig = sig .. ', arg' .. argi
  end
  sig = sig .. ')'

  fb = fb .. [[
  if (lua_isfunction(L, -]]..table.maxn(args)..[[-2)) {
    lua_pcall(L, ]] .. table.maxn(args) .. [[+1, 2, 0);
		absorbed = (bool)lua_toboolean(L, -1) || (bool)lua_toboolean(L, -2);
		lua_pop(L, 1);
  }
  if (!absorbed) {
    lua_settop(L, oldtop);
    ]] .. (f.attr.pure_virtual~='1' and (((ret_n~='void') and 'return ' or '')..'this->'..context..f.attr.name..sig..';\n') or '') .. [[
  }
]]
--   fb = fb .. '  if (!lua_isnil)' -- TODO: check?
  if ret_n~='void' then
    fb = fb .. '  ' .. ret_n .. ' ret = ' .. self:type_from_stack(ret_t)(-1) .. ';\n'
    fb = fb .. '  lua_settop(L, oldtop);\n'
    fb = fb .. '  return ret;\n'
  else
    fb = fb .. '  lua_settop(L, oldtop);\n'
  end
  fb = fb .. '}\n'
  
  return fh, fb
end


function B:virtual_destructor (f, c)
  c = c or ''
  local lname = self.wrapclass(f.attr.name)
  local pclass = self.fake_pointer(f.attr.context)
  local push_this = self:type_to_stack(pclass)'this'
  return [[
  ~]]..lname..[[ ();
]], 
c .. [[
  ~]]..lname..[[ () {
  int oldtop = lua_gettop(L);
  ]] .. push_this .. [[;
  lua_getfield(L, -1, "~]]..f.attr.name..[[");

  if (lua_isfunction(L, -1)) {
    lua_insert(L, -2);
    lua_pcall(L, 1, 1, 0);
  } else {
  }
  lua_settop(L, oldtop);
}
]]

end

----------------------------------

function B:make_namespace(tname, include_file)
  local bind_file = 'lqt_bind_'..include_file..'.hpp'
  if string.match(include_file, '(%.[hH]([pP]?)%2)$') then
    bind_file = 'lqt_bind_'..include_file
  end

  local my_class = B:find_name(tname)
  local my_context = B.wrapclass(tname)..'::'

  local my = B:get_members(my_class)

  local my_enums = nil
  my.virtuals = B:get_virtuals(my_class)

  print 'writing preambles'

  local fullproto = proto_preamble(tname, include_file)
  local fulldef = '#include "'..bind_file..'"\n\n'
  local metatable_constructor = meta_constr_preamble(tname)

  print 'binding each member'

  local my_members = {}
  table.foreach(my.methods, function(k, v) my_members[k] = v end)
  my_members.new = my.constructors
  my_members.delete = { my.destructor }
  for n, l in pairs(my_members) do
    local fname = B.WRAPCALL..n
    local proto, def = B:solve_overload(l, fname, my_context)
    if (proto and def) then
      fullproto = fullproto .. proto
      fulldef = fulldef .. def
      metatable_constructor = metatable_constructor .. meta_constr_method (n, my_context..B.WRAPCALL)
    end
  end

  print'binding virtual methods'

  for s, f in pairs(my.virtuals) do
    print ('virtual', s)
    local ret, h, c = pcall(B.virtual_overload, B, f, my_context, my_class.attr.id)
		if ret then
			fullproto, fulldef = fullproto..h, fulldef..c
		else
			print(h)
		end
  end

  print'overriding virtual destructor'
  if my.destructor.attr.virtual == '1' then
    local h, c = B:virtual_destructor(my.destructor, my_context)
    fullproto, fulldef = fullproto..h, fulldef..c
  end

	print'creating enum translation tables'
	for k, e in pairs(my.enumerations) do
		local e_p, e_d, e_n = self:enum_push_body(e, my_context)
		fulldef = fulldef .. e_d
		fullproto = fullproto .. e_p
		metatable_constructor = metatable_constructor .. '    ' .. my_context .. e_n .. '(L);\n    lua_pop(L, 1);\n'
	end

  print'copying constructors'
  for i, v in ipairs(my.constructors) do
    fullproto = fullproto..B:copy_constructor(v)
  end
  fullproto = fullproto .. proto_ending(tname) .. meta_constr_proto (tname)

  print'specifying bases'
  metatable_constructor = metatable_constructor .. '    lua_newtable(L);\n'
  for s in string.gmatch(my_class.attr.bases or '', '(_%d+) ') do
    local base = self:find_id(s)
    local bname = self:type_name(base)
    metatable_constructor = metatable_constructor .. [[
    lua_pushboolean(L, 0);
    lua_setfield(L, -2, "]]..bname..[[*");
]]
  end
  metatable_constructor = metatable_constructor .. '    lua_setfield(L, -2, "__base");\n'


  print'finalizing code'
  metatable_constructor = metatable_constructor .. meta_constr_ending (tname)
  fulldef = fulldef .. metatable_constructor

  return fullproto, fulldef
end


----------------------------
----------------------------
----------------------------
----------------------------

if false then

--[[
if not my_members then
  m = B:get_members(my_class)
  m.virtuals = B:get_virtuals(my_class)

  my_enums = m.enumerations
  my_members = {}
  local t = my_members
  table.foreach(m.methods, function(k, v) t[k] = v end)
  my_members.new = m.constructors
  my_members.delete = { m.destructor }
end

print 'writing preambles'

fullproto = proto_preamble(my_typename)
fulldef = '#include "bind.hpp"\n\n'
local metatable_constructor = meta_constr_preamble(my_typename)

print 'binding each member'

for n, l in pairs(my_members) do
  local fname = B.WRAPCALL..n
  local proto, def = B:solve_overload(l, fname, my_context)
  fullproto = fullproto .. proto
  fulldef = fulldef .. def
  metatable_constructor = metatable_constructor .. meta_constr_method (n, my_context..B.WRAPCALL)
end

print'binding virtual methods'

local virtual_methods = m.virtuals
for s, f in pairs(virtual_methods) do
  print ('virtual', s)
  local h, c = B:virtual_overload(f, my_context)
  fullproto, fulldef = fullproto..h, fulldef..c
end

print'overriding virtual destructor'
if m.destructor.attr.virtual == '1' then
  local h, c = B:virtual_destructor(m.destructor, my_context)
  fullproto, fulldef = fullproto..h, fulldef..c
end

print'copying constructors'
for i, v in ipairs(m.constructors) do
  fullproto = fullproto..B:copy_constructor(v)
end
fullproto = fullproto .. proto_ending(my_typename) .. meta_constr_proto (my_typename)

print'finalizing code'
metatable_constructor = metatable_constructor .. meta_constr_ending (my_typename)
fulldef = fulldef .. metatable_constructor

print'writing definition file'
f = io.open('bind.cpp', 'w')
f:write(fulldef)
f:close()

print'writing prototypes file'
f = io.open('bind.hpp', 'w')
f:write(fullproto)
f:close()

--]]


else

local h, c


function BINDQT(n)
  n = tostring(n)
  local h, c = B:make_namespace(n, n)
  print(n..': writing definition file')
  f = io.open('lqt_bind_'..n..'.cpp', 'w')
  f:write(c)
  f:close()

  print(n..': writing prototypes file')
  f = io.open('lqt_bind_'..n..'.hpp', 'w')
  f:write(h)
  f:close()
end

function set_union(...)
  local ret = {}
  for _, s in ipairs{...} do
    for v, t in pairs(s) do
      if t==true then ret[v] = true end
    end
  end
  return ret
end

function B:tree_of_bases(c)
  local ret = {}
  for s in string.gmatch(c.attr.bases or '', '(_%d+) ') do
    local b = self:find_id(s)
    ret[b.attr.name] = true
    local bb = self:tree_of_bases(b)
    ret = set_union(ret, bb)
  end
  return ret
end

do
local clist = {}
for n in pairs(classlist) do
  local c = B:find_name(n)
  clist = set_union(clist, B:tree_of_bases(c))
end
classlist = set_union(classlist, clist)
end

for n in pairs(classlist) do
  BINDQT(n)
end
--BINDQT'QObject'
--BINDQT'QWidget'
--BINDQT'QAbstractButton'
--BINDQT'QFont'
--BINDQT'QLabel'
--BINDQT'QApplication'

--[[
h, c = B:make_namespace('QWidget', 'QWidget')
print'writing definition file'
f = io.open('lqt_bind_QWidget.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QWidget.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QObject', 'QObject')
print'writing definition file'
f = io.open('lqt_bind_QObject.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QObject.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QAbstractButton', 'QAbstractButton')
print'writing definition file'
f = io.open('lqt_bind_QAbstractButton.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QAbstractButton.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QApplication', 'QApplication')
print'writing definition file'
f = io.open('lqt_bind_QApplication.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QApplication.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QPushButton', 'QPushButton')
print'writing definition file'
f = io.open('lqt_bind_QPushButton.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QPushButton.hpp', 'w')
f:write(h)
f:close()

h, c = b:make_namespace('qabstractbutton', 'qabstractbutton')
print'writing definition file'
f = io.open('lqt_bind_qabstractbutton.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_qabstractbutton.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QCoreApplication', 'QCoreApplication')
print'writing definition file'
f = io.open('lqt_bind_QCoreApplication.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QCoreApplication.hpp', 'w')
f:write(h)
f:close()

h, c = B:make_namespace('QFont', 'QFont')
print'writing definition file'
f = io.open('lqt_bind_QFont.cpp', 'w')
f:write(c)
f:close()

print'writing prototypes file'
f = io.open('lqt_bind_QFont.hpp', 'w')
f:write(h)
f:close()
--]]



end
