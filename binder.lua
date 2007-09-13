#!/usr/bin/lua

local binder = {}
local B = nil

-- a string devised to not compile. should not make into code. never.
binder.ERRORSTRING = '<<>>'
binder.WRAPCALL = '__LuaWrapCall__'
binder.debug_type = function(el) return (type(el)=='table'and (el.tag .. ' ' .. el.attr.id) or el) end

function binder:init(filename)
  --require 'lxp'
  --require 'lxp.lom'
  
  if not self.tree then
    local xmlf = io.open(filename, 'r')
    local xmls = xmlf:read('*a')
    xmlf:close()
    --self.tree = lxp.lom.parse(xmls)
		self.tree = xml:collect(xmls)
  end
  
  self.type_names = {}
  self.types_to_stack = {
    ['const char *'] = function(i) return 'lua_pushstring(L, ' .. tostring(i) .. ')' end,
    ['short int'] =              function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['unsigned short int'] =     function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['int'] =                    function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['unsigned int'] =           function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['long int'] =               function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['unsigned long int'] =      function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['long unsigned int'] =      function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['long long int'] =          function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['unsigned long long int'] = function(i) return 'lua_pushinteger(L, ' .. tostring(i) .. ')' end,
    ['float'] =  function(i) return 'lua_pushnumber(L, ' .. tostring(i) .. ')' end,
    ['double'] = function(i) return 'lua_pushnumber(L, ' .. tostring(i) .. ')' end,
    ['bool'] = function(i) return 'lua_pushboolean(L, ' .. tostring(i) .. ')' end,
    ['void *'] =   function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
    ['void * *'] = function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
  }
  self.types_from_stack = {
    ['const char *'] = function(i) return 'lua_tostring(L, ' .. tostring(i) .. ')' end,
    ['short int'] =              function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['unsigned short int'] =     function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['int'] =                    function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['unsigned int'] =           function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['long int'] =               function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['unsigned long int'] =      function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['long unsigned int'] =      function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['long long int'] =          function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['unsigned long long int'] = function(i) return 'lua_tointeger(L, ' .. tostring(i) .. ')' end,
    ['float'] =  function(i) return 'lua_tonumber(L, ' .. tostring(i) .. ')' end,
    ['double'] = function(i) return 'lua_tonumber(L, ' .. tostring(i) .. ')' end,
    ['bool'] = function(i) return '(bool)lua_toboolean(L, ' .. tostring(i) .. ')' end,
    ['void *'] =   function(i) return 'lua_touserdata(L, ' .. tostring(i) .. ')' end,
    ['void * *'] = function(i) return 'static_cast<void **>(lua_touserdata(L, ' .. tostring(i) .. '))' end,
  }
  self.types_test = {
    ['const char *'] = function(i) return '(lua_type(L, ' .. tostring(i) .. ')==LUA_TSTRING)' end,
    ['short int'] =              function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['unsigned short int'] =     function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['int'] =                    function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['unsigned int'] =           function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['long int'] =               function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['unsigned long int'] =      function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['long unsigned int'] =      function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['long long int'] =          function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['unsigned long long int'] = function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['float'] =  function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['double'] = function(i) return 'lua_isnumber(L, ' .. tostring(i) .. ')' end,
    ['bool'] = function(i) return 'lua_isboolean(L, ' .. tostring(i) .. ')' end,
    ['void *'] =   function(i) return 'lua_isuserdata(L, ' .. tostring(i) .. ')' end,
    ['void * *'] = function(i) return 'lua_isuserdata(L, ' .. tostring(i) .. ')' end,
  }
--   self.conditions = {}
  
  return self.tree
end

function binder.wrapclass(n)
  return 'LuaBinder< '..n..' >'
end

function binder.lua_proto(s)
  return 'int '..s..' (lua_State *L)'
end

function binder.fake_pointer (id)
  return { tag='PointerType', attr={ type=id } }
end

function binder:find(f, t)
  t = t or self.tree
  if type(t)~='table' then return nil end;
  if f(t) then return t end
  local ret = nil
  for k,v in pairs(t) do
    ret = ret or self:find(f, v)
    if ret then break end
  end;
  return ret;
end

function binder.name_search (n)
  return function (t)
      return (type(t)=='table') and (type(t.attr)=='table') and (t.attr.name==n)
    end
end

function binder.id_search (i)
  return function (t)
      return (type(t)=='table') and (type(t.attr)=='table') and (t.attr.id==i) -- or ((type(i)=='table') and i[t.attr.id])
    end
end

function binder.tag_search (n)
  return function (t)
      return (type(t)=='table') and (t.tag==n) -- or ((type(i)==table) and i[t.attr.id])
    end
end

function binder.pointer_search(id)
  return function (t)
    return (type(t)=='table') and (t.tag=='PointerType') and (type(t.attr)=='table') and (t.attr.type==id)
  end
end

function binder:find_name (n)
  if not self.names then self.names = {} end
  if not self.names[n] then
    self.names[n] = self:find(self.name_search(n))
  end
  return self.names[n]
end

function binder:find_id (n)
  if not self.ids then self.ids = {} end
  if not self.ids[n] then
    self.ids[n] = self:find(self.id_search(n))
  end
  return self.ids[n]
end

function binder:find_pointer (n)
  if not self.pointers then self.pointers = {} end
  if not self.pointers[n] then
    self.pointers[n] = self:find(self.pointer_search(n.attr.id))
  end
  return self.pointers[n]
end

function binder:context_name(el)
    if type(el.attr)~='table' then return '' end
    if type(el.attr.context)~='string' then return '' end
    
    local context_el = self:find_id(el.attr.context)
    
    if not context_el then return '' end
    
    local context = (context_el.attr.name=='::') and '' or (context_el.attr.name..'::')
    return context
end

function binder:type_name(el)
--     print('getting name of', el, el.tag)
    
  self.type_names = self.type_names or {}
  local t = self.type_names
  
  if t[el] then return t[el] end
  
      if el.tag == 'FundamentalType' then
    t[el] = el.attr.name
  elseif (el.tag == 'Class') or (el.tag == 'Struct') or (el.tag=='Union') then
    t[el] = self:context_name(el) .. el.attr.name
  elseif el.tag == 'Typedef' then
    t[el] = self:type_name(self:find_id(el.attr.type))
  elseif el.tag == 'PointerType' then
    t[el] = self:type_name(self:find_id(el.attr.type)) .. ' *'
  elseif el.tag == 'ReferenceType' then
    t[el] = self:type_name(self:find_id(el.attr.type)) .. '&'
  elseif el.tag == 'CvQualifiedType' then
    t[el] = ( (el.attr.volatile=='1') and 'volatile ' or '' )
         .. ( (el.attr.const=='1') and 'const ' or '' )
         .. self:type_name(self:find_id(el.attr.type))
  elseif el.tag == 'Enumeration' then
    t[el] = self:context_name(el) .. el.attr.name
  else
    error('cannot determine type name: ' .. self.debug_type(el))
  end
  return t[el]
end

function binder.wrapcall(m, overload, n)
  if m.tag=='Method' then
    return binder.WRAPCALL..m.attr.name..(overload and '__OverloadedVersion'..tostring(n) or '')
  elseif m.tag=='Constructor' then
    return binder.WRAPCALL..m.attr.name..'__new'..(overload and '__OverloadedVersion'..tostring(n) or '')
  elseif m.tag=='Destructor' then
    -- cannot be overloaded, true?
    return binder.WRAPCALL..m.attr.name..'__delete'..(overload and '__OverloadedVersion'..tostring(n) or '')
  end
  return false
end

function binder.arguments_of(f)
  local ret = {}
  for argi = 1, table.maxn(f) do
    if (type(f[argi])=='table') and (f[argi].tag=='Argument') then
      table.insert(ret, f[argi])
    end
  end
  return ret
end


function binder:base_type(el)
  local ret = self:find_id(el.attr.type)
  while (ret.tag=='Typedef') or (ret.tag=='CvQualifiedType') do
    ret = self:find_id(ret.attr.type)
  end
  return ret
end

function binder:type_from_stack(el)
  local t = self.types_from_stack
  if t[el] then return t[el] end
  
  local name = self:type_name(el)
  if t[name] then
    t[el] = t[name]
    return t[el]
  end

  if (el.tag=='Class') or (el.tag=='Struct') or (el.tag=='Union') then
    t[el] = function(i) return '**static_cast<'..name..'**>(lqtL_checkudata(L, '..tostring(i)..', "' ..name.. '*"))' end
  elseif (el.tag=='CvQualifiedType') then
    t[el] = self:type_from_stack(self:find_id(el.attr.type))
  elseif (el.tag=='ReferenceType') then
    t[el] = self:type_from_stack(self:find_id(el.attr.type))
  elseif (el.tag=='Typedef') then
    t[el] = self:type_from_stack(self:find_id(el.attr.type))
  elseif (el.tag=='Enumeration') then
    t[el] = function (i) return 'static_cast<'..name..'>(lqtL_toenum(L, '..tostring(i)..', "'..name..'"))' end
  elseif (el.tag=='PointerType') then
    local b = self:base_type(el)
    local base_t = self:type_from_stack(b)
    t[el] = (type(base_t)=='function') and function (i)
              local base = base_t(i)
              local c = string.sub(base, 1, 1)
              if (c=='*') then
                return string.sub(base, 2)
              else
                return 'static_cast<'..name..'>(lua_touserdata(L, '..tostring(i)..'))'
              end
            end or function (i) return '0' end
  elseif (el.tag=='FunctionType') then -- FIXME
  end
  
  if t[el]==nil then
    error('cannot deternime how to retrieve type: '.. ((type(el)=='table') and (el.tag..' '..el.attr.id) or el))
  end
  return t[el]
end


function binder:type_to_stack(el)
  local t = self.types_to_stack
  
  if t[el] then return t[el] end
  
  local name = self:type_name(el)
--   print (el.tag, '|'..name..'|', rawget(t,el) or '<>')
  
  if t[name] then
    t[el] = t[name]
    return t[el]
  end

  if (el.tag=='Class') or (el.tag=='Struct') or (el.tag=='Union') then
    -- FIXME: force deep copy if possible
    t[el] = function(i) return 'lqtL_passudata(L, new '..name..'('..tostring(i)..'), "'..name..'*")' end
  elseif (el.tag=='CvQualifiedType') then -- FIXED? FIXME: this is just a mess
    local base_t = self:base_type(el)
    local non_cv = self:type_to_stack(base_t)
    --if (base_t.tag=='Class') or (base_t.tag=='Struct') or (base_t.tag=='Union') then else end
    t[el] = non_cv
  elseif (el.tag=='ReferenceType') then
    local base_t = self:base_type(el)
		if (base_t.tag=='Class') or (base_t.tag=='Struct') or (base_t.tag=='Union') then
			t[el] = function(i) return 'lqtL_pushudata(L, &('..tostring(i)..'), "'..self:type_name(base_t)..'*")' end
		else
			t[el] = self:type_to_stack(self:find_id(el.attr.type))
		end
  elseif (el.tag=='Typedef') then
    t[el] = self:type_to_stack(self:find_id(el.attr.type))
  elseif (el.tag=='Enumeration') then
    t[el] = function (i) return 'lqtL_pushenum(L, '..tostring(i)..', "'..name..'")' end
  elseif (el.tag=='PointerType') then
    local base_t = self:base_type(el)
    t[el] = function(i) return 'lqtL_pushudata(L, '..tostring(i)..', "'..self:type_name(base_t)..'*")' end
  end
  
--   print (el.tag, el, rawget(t,el) or '<>')
  if t[el]==nil then
    error('cannot deternime how to push on stack type: '.. self.debug_type(el))
  end
  return t[el]
end



function binder:type_test(el)
  local t = self.types_test
  
  if t[el] then return t[el] end
  
  local name = self:type_name(el)
  
  if t[name] then
    t[el] = t[name]
    return t[el]
  end

  if (el.tag=='Class') or (el.tag=='Struct') or (el.tag=='Union') then
    t[el] = function(i) return 'lqtL_testudata(L, ' .. tostring(i) .. ', "' .. name .. '*")' end
  elseif (el.tag=='CvQualifiedType') then
    t[el] = self:type_test(self:find_id(el.attr.type))
  elseif (el.tag=='ReferenceType') then
    t[el] = self:type_test(self:find_id(el.attr.type))
  elseif (el.tag=='Typedef') then
    t[el] = self:type_test(self:find_id(el.attr.type))
  elseif (el.tag=='Enumeration') then
    t[el] = function (i) return 'lqtL_isenum(L, '..tostring(i)..', "'..name..'")' end
  elseif (el.tag=='PointerType') then
    t[el] = self:type_test(self:find_id(el.attr.type)) or function() return '(true)' end
  elseif (el.tag=='FunctionType') then -- FIXME
  end
  
--   print (el.tag, el, rawget(t,el) or '<>')
  if t[el]==nil then
    error('cannot deternime how to test type: '.. self.debug_type(el))
  end
  return t[el]
end


function binder:function_body(f)
  if f.attr.pure_virtual=='1' then error'cannot call pure vitual functions' end

  local body = '{\n'
  local has_this = 0
  --local base_class = nil
  local args = self.arguments_of(f)
  local funcname = self:context_name(f) .. f.attr.name
  local ret_type = nil
  local pointer_to_class = self.fake_pointer(f.attr.context)
  
  --if f.attr.context then base_class = self:find_id(f.attr.context) end
  --if base_class and ((base_class.tag=='Class') or (base_class.tag=='Struct')) then
    --pointer_base = self:find(self.pointer_search(f.attr.context)) 
  --end
  
  -- NEEDS THIS POINTER?
  if ( (f.tag=='Method') and (f.attr.static~='1') ) or (f.tag == 'Destructor') then
    local pointer_base = pointer_to_class
    body = body .. '  ' .. self:type_name(pointer_base) .. '& __lua__obj = '
                .. self:type_from_stack(pointer_base)(1) .. ';\n';
---[==[
    body = body .. [[
	if (__lua__obj==0) {
		lua_pushstring(L, "trying to reference deleted pointer");
		lua_error(L);
		return 0;
	}
]]
--]==]
    has_this = 1
  end
  
  -- GETTING ARGUMENTS
  for argi = 1, table.maxn(args) do
    local arg = args[argi]
    local argname = 'arg' .. tostring(argi)
    
    local argt = self:find_id(arg.attr.type)
    local argtype = self:type_name(argt)
    local def = arg.attr.default
    
    if def and string.match(string.sub(def, 1, 1), '[%l%u]') then
      def = self:context_name(argt)..def
    elseif def then
      def = 'static_cast< ' .. argtype .. ' >(' .. def .. ')'
    end
    
    --print ('getting arg type', argtype, arg.attr.type)
    
    body = body .. '  ' .. argtype .. ' ' .. argname .. ' = '
                .. (def and (self:type_test(argt)(argi+has_this) .. '?') or '')
                .. self:type_from_stack(argt)(argi+has_this)
    body = body .. (def and (':' .. tostring(def)) or '') .. ';\n' --  '// default = '..tostring(def)..'\n'
  end
  body = body .. '  '
  
  if f.tag=='Constructor' then
		--[[
		local my_class = self:find_id(f.attr.context)
		if my_class.attr.abstract='1' then error'cannot construct abstract class' end
		--]]
    ret_type = pointer_to_class
    funcname = 'new ' .. self.wrapclass(f.attr.name)
    
--     ret_type = self:find_id(f.attr.context) -- wrong?
--     body = body .. self:type_name(ret_type) .. ' * ret = new '
--     print (self:type_name(ret_type))
  elseif f.tag=='Destructor' then
    -- TREATED AS SPECIAL CASE
    body = body .. 'delete __lua__obj;\n'
    body = body .. '  __lua__obj = 0;\n';
    body = body .. '  return 0;\n}\n'
    return body
  else
    ret_type = self:find_id(f.attr.returns)
  end

  -- GET RETURN TYPE
  if ret_type.attr.name=='void' then
    ret_type = nil
  else
    body = body .. self:type_name(ret_type) .. ' ret = '
  end

  -- CALL FUNCTION    
  if has_this==1 then
    body = body .. '__lua__obj->' .. funcname .. '('
  else
    body = body .. funcname .. '('
  end
  
  -- IF OVERRIDING CONSTRUCTOR ADD STATE POINTER
  if f.tag=='Constructor' then
    body = body .. 'L' .. ((table.maxn(args) > 0) and ', ' or '')
  end
  
  -- ADD ARGS TO FUNCTION CALL
  if table.maxn(args) > 0 then body = body .. 'arg1' end
  for argi = 2, table.maxn(args) do
    body = body .. ', arg' .. tostring(argi)
  end
  
  body = body .. ');\n'

  -- HANDLE RETURN VALUE
  if ret_type then
    -- print('pushing', binder:type_name(ret_type))
    local ret_to_stack = self:type_to_stack(ret_type)'ret'
    body = body .. '  ' .. ret_to_stack .. ';\n'
    body = body .. '  return 1;\n}\n'
  else
    body = body .. '  return 0;\n}\n'
  end
  
  return body
end

function binder:function_test(p, score)
  local ret = ''
  local isstatic = 0
  
  ret = ret .. '  ' .. score .. ' = 0;\n'
  
  if p.attr.static~='1' and p.tag=='Method' then
    ret = ret .. '  ' .. score .. ' += ' .. self:type_test( self.fake_pointer(p.attr.context) )(1)
              .. '?premium:-premium*premium;\n' 
    isstatic = 1
  end
  
  local args = self.arguments_of(p)
  
  for argi = 1, table.maxn(args) do
    local arg = args[argi]
    --print ( 'ARGUMENT TEST', argi)
    local argname = 'arg' .. tostring(argi)
    if (type(arg)=='table') and (arg.tag=='Argument') then
      ret = ret .. '  if (' .. self:type_test( self:find_id(arg.attr.type) )(argi+isstatic)  .. ') {\n'
      ret = ret .. '    ' .. score .. ' += premium;\n'
      ret = ret .. '  } else if (' .. tostring(arg.attr.default and true or false) .. ') {\n'
      ret = ret .. '    ' .. score .. ' += premium-1; // '..tostring(arg, arg.attr.default)..';\n'
      ret = ret .. '  } else {\n'
      ret = ret .. '    ' .. score .. ' -= premium*premium;\n'
      ret = ret .. '  }\n'
      
--       ret = ret .. '  ' .. score .. ' += ' .. type_on_stack_test( find_id(arg.attr.type) , argi+isstatic )
--                 .. '?' .. tostring(premium) .. ':-' .. tostring(premium) .. '*' .. tostring(premium) .. ';\n' 
    end
  end
  
  return ret
end

function binder:get_members (c)
  if not self.members then self.members = {} end
  if not self.members[c] then
    local ret = { functions={}, enumerations={}, classes={}, methods={}, constructors={}, virtuals={} }
    for s in string.gmatch(c.attr.members, '(_%d+) ') do
      local m = self:find_id(s)
      local n = m.attr.name
      print("member of", c.attr.name , "found:", s, "name:", n)

			local filtered, motive = false, ''
			if self.filter then
				filtered, motive = self.filter(m)
			end

			if filtered then
				print('Filtered member: '..n..' for '..(motive or 'no apparent reason.'))
			elseif m.tag=='Enumeration' then
        table.insert(ret.enumerations, m)
      elseif m.tag=='Function' then
        ret.functions[n] = ret.functions[n] or {}
        table.insert(ret.functions[n], m)
      elseif m.tag=='Method' and (m.attr.access=='public') then
        ret.methods[n] = ret.methods[n] or {}
        table.insert(ret.methods[n], m)
      elseif m.tag=='Constructor' and (m.attr.access=='public') then
        table.insert(ret.constructors, m)
      elseif m.tag=='Destructor' then
        ret.destructor = m
      elseif m.tag=='Class' or m.tag=='Struct' then
        table.insert(ret.classes, m)
      end

      if (m.attr.virtual=='1') and (m.tag~='Constructor') and (m.tag~='Destructor') and not filtered then
        table.insert(ret.virtuals, m)
      end
      --[[
      local n = n..' < < of type > > '.. m.tag ..' < < with access > > ' .. m.attr.access
      ret.cache[n] = ret.cache[n] or {}
      table.insert(ret.cache[n], m)
      ]]
    end
    self.members[c] = ret
  end
  return self.members[c]
end

function binder:code_function (f)
  local body, test = {}, {}

  for i, m in ipairs(f) do
    local fname = self.wrapcall(m, overloaded, j)
    
    if not fname then error'this shout *NOT* happen!' end
    local st, err
    
    st, err = pcall(self.function_body, self, m)
    if st then
      body[i] = err
    else
      print(err)
      body[i] = nil
    end
    
    st, err = pcall(self.function_test, self, m, 'score['..i..']')
    if st then
      test[i] = err
    else
      print(err)
      test[i] = nil
    end

    --body[i] = self:function_body(m)
    --test[i] = self:function_test(m, 'score['..i..']')
  end
  
  return body, test
end

function binder:begin_dispatch(n, m)
    return self.lua_proto(n) .. ' {\n  int score[' .. m
                     ..'];\n  const int premium = 11+lua_gettop(L);\n'
end

function binder:choose_dispatch(m)
  return [[
  int best = 1;
  for (int i=1;i<=]]..m..[[;i++) {
    if (score[best] < score[i]) { best = i; }
  }
  switch (best) {
]]
end

function binder:solve_overload (f, n, c)
  local proto, def = '', ''
  local body, test = self:code_function(f)

  local number = 0
  for i = 1,table.maxn(f) do if (type(body[i])=='string') and (type(test[i])=='string') then number = number + 1 end end
  
  if number>1 then
    local fulltest = self:begin_dispatch(c..n, table.maxn(f))

    for i = 1,table.maxn(f) do
      local fullname = n..'__OverloadedVersion__'..i
      if (type(body[i])=='string') and (type(test[i])=='string') then
        proto = proto .. '  static '..self.lua_proto(fullname)..';\n'
        def = def .. self.lua_proto(c..fullname)..' '..body[i]
        fulltest = fulltest .. test[i]
      end
    end

    fulltest = fulltest .. self:choose_dispatch(table.maxn(f))

    for i = 1,table.maxn(f) do
      if (type(body[i])=='string') and (type(test[i])=='string') then
        local fullname = n..'__OverloadedVersion__'..i
        fulltest = fulltest .. '    case ' .. i .. ': return ' .. fullname ..'(L); break;\n'
      end
    end

    -- TODO: move to a function?
    fulltest = fulltest .. '  }\n  return -1;\n}\n'

    proto = proto .. '  static '..self.lua_proto(n)..';\n'
    def = def .. fulltest
  elseif number==1 then
    proto, def = nil, nil
    for i, v in ipairs(body) do
      proto = '  static '..self.lua_proto(n)..';\n'
      def = self.lua_proto(c..n)..' '..v
    end
  else
    proto, def = nil, nil
  end
  
  return proto, def
end

return binder

