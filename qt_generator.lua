#!/usr/bin/lua

xml = dofile'xml.lua'
B = dofile'binder.lua'

function NOINSTANCE(b, name)
  b.types_from_stack[name] = function(i) error('cannot copy '..name) end
  b.types_test[name] = function(i) error('cannot copy '..name) end
  b.types_to_stack[name] = function(i) error('cannot copy '..name) end

  b.types_from_stack[(name..' *')] = function(i) return '*static_cast<'..name..'**>(lqtL_toudata(L, '..tostring(i)..', "'..name..'"))' end
  b.types_test[(name..' *')] = function(i) return 'lqtL_testudata(L, '..tostring(i)..', "'..name..'*")' end
  b.types_to_stack[(name..' *')] = function(i) return 'lqtL_pushudata(L, '..tostring(i)..', "'..name..'*")' end
end

function cp_file(src, dst)
  src = (type(src)=='string') and io.open(src, 'r') or src
  dst = (type(dst)=='string') and io.open(dst, 'w') or dst
	local content = src:read('*a')
	dst:write(content)
	src:close()
	dst:close()
end

function BINDQT(n)
  n = tostring(n)
  local h, c = B:make_namespace(n, n)
  print(n..': writing definition file')
  f = io.open('src/lqt_bind_'..n..'.cpp', 'w')
  f:write(c)
  f:close()

  print(n..': writing prototypes file')
  f = io.open('src/lqt_bind_'..n..'.hpp', 'w')
  f:write(h)
  f:close()
end

function init_qt(B)
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


	NOINSTANCE(B, 'QCoreApplication')


	B.types_from_stack['QString'] = function(i) return 'QString::fromAscii(lua_tostring(L, '..tostring(i)..'), lua_objlen(L, '..tostring(i)..'))' end
	B.types_test['QString'] = function(i) return '(lua_type(L, ' .. tostring(i) .. ')==LUA_TSTRING)' end
	B.types_to_stack['QString'] = function(i) return 'lua_pushlstring(L, '..tostring(i)..'.toAscii().data(), '..tostring(i)..'.toAscii().size())' end

	B.types_from_stack['QByteArray'] = function(i) return 'QByteArray(lua_tostring(L, '..tostring(i)..'), lua_objlen(L, '..tostring(i)..'))' end
	B.types_test['QByteArray'] = function(i) return '(lua_type(L, ' .. tostring(i) .. ')==LUA_TSTRING)' end
	B.types_to_stack['QByteArray'] = function(i) return 'lua_pushlstring(L, '..tostring(i)..'.data(), '..tostring(i)..'.size())' end
end

function make_tree (cl, tf)
	f = io.open(tf..'.cpp', 'w')
	for n in pairs(cl) do
		f:write('#include <'..n..'>\n')
	end
	f:write'\nmain() {\n'
	for n in pairs(cl) do
		f:write('  '..n..' *'..string.lower(n)..';\n')
	end
	f:write'}\n'
	f:close()
	os.execute('gccxml `pkg-config QtGui QtCore --cflags` -fxml='..tf..'.xml '..tf..'.cpp')
	--os.execute'gccxml -g -Wall -W -D_REENTRANT -DQT_GUI_LIB -DQT_CORE_LIB -DQT_SHARED -I/usr/share/qt4/mkspecs/linux-g++ -I. -I/usr/include/qt4/QtCore -I/usr/include/qt4/QtCore -I/usr/include/qt4/QtGui -I/usr/include/qt4/QtGui -I/usr/include/qt4 -I. -I. -I. -fxml=auto.xml auto.cpp'
	os.remove(tf..'.cpp')
end

function make_standard_qt(B, classlist)
  cp_file('lqt_common.hpp', 'src/lqt_common.hpp')
  cp_file('lqt_common.cpp', 'src/lqt_common.cpp')

	do
		local clist = {}
		for s in string.gmatch(classlist, '([%u%l%d]+)') do
			clist[s] = true
		end
		classlist = clist
	end

  local tmpfile='tmp/auto'

	make_tree(classlist, tmpfile)

	B:init(tmpfile..'.xml')
	init_qt(B)

	do
		local clist = {}
		for n in pairs(classlist) do
			local c = B:find_name(n)
			clist = B.set_union(clist, B:tree_of_bases(c))
		end
		classlist = B.set_union(classlist, clist)
	end

	for n in pairs(classlist) do
		BINDQT(n)
	end
end

function make_single_qt(B, class)
	local classlist = { class }

  local tmpfile='tmp/auto'

	make_tree(classlist, tmpfile)
	B:init(tmpfile..'.xml')
	init_qt(B)

	BINDQT(class)
end

make_standard_qt(B, [[
QLineEdit
]])
