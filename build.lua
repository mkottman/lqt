#!/usr/bin/lua

local debug = print

cpptoxml = {
	command = './cpptoxml/cpptoxml',
	config = './cpptoxml/parser/rpp/pp-qt-configuration',
}

generator = {
	file = './generator/generator.lua',
	directory = 'build',
	default = {
		types = { 'generator/types.lua' },
		filters = {  },
		includes = {  },
	},
}

modules = {
	qtcore = {
		includes = { '<QtCore>' },
		types = { 'generator/qtypes.lua' },
		filters = { 'generator/qt_internal.lua' },
		depends = {},
	},
	basegui = {
		includes = { '<QWidget>' },
		types = { },
		filters = { },
		depends = { 'qtcore' },
	},
}

Module = function(name)
	local m = modules[name]
	local ret = { name = name, hppfiles={}, }
	local deps = {}
	for _, d in ipairs(m.depends) do
		table.insert(deps, Module(d))
		table.insert(ret.hppfiles, d..'_head.hpp')
		table.insert(m.types, d..'_src/'..d..'_type.lua')
	end
	for k, t in pairs(generator.default) do
		local set = {}
		ret[k] = {}
		for _, v in ipairs(t) do
			if not set[v] then table.insert(ret[k], v) set[v]=true end
		end
		for _, d in ipairs(deps) do
			for _, v in ipairs(d[k]) do
				if not set[v] then table.insert(ret[k], v) set[v]=true end
			end
		end
		for _, v in ipairs(m[k] or {}) do
			if not set[v] then table.insert(ret[k], v) set[v]=true end
		end
	end
	return ret
end

qmake_project = function(n, ...)
	return string.gsub([[
TEMPLATE = lib
TARGET = LQT_MODULE
DEPENDPATH += .
INCLUDEPATH += . ]]..table.concat({...}, ' ')..[[

# Input
HEADERS += LQT_MODULE_head.hpp
SOURCES += LQT_MODULE_enum.cpp LQT_MODULE_meta.cpp LQT_MODULE_virt.cpp
]], 'LQT_MODULE', n)
end

compile = function(name)
	local m = Module(name)
	-- create stub file
	debug('creating stub in', generator.directory..'/'..m.name..'.tmp')
	local f_stub = assert(io.open(generator.directory..'/'..m.name..'.tmp', 'w'))
	for _, i in ipairs(m.includes) do
		f_stub:write('#include '..i..'\n')
	end
	f_stub:close()
	-- generate xml file
	debug('getting output of', cpptoxml.command..' -C '..cpptoxml.config..' '..generator.directory..'/'..m.name..'.tmp')
	local xml_file = io.popen(cpptoxml.command..' -C '..cpptoxml.config..' '..generator.directory..'/'..m.name..'.tmp', 'r')
	local xml = xml_file:read'*a'
	xml_file:close()
	-- save xml on a file
	debug('creating xml file in', generator.directory..'/'..m.name..'.xml')
	local xml_out = io.open(generator.directory..'/'..m.name..'.xml', 'w')
	xml_out:write(xml)
	xml_out:close()
	xml = nil -- free memory
	-- run generator
	local cmd = 'lua ' .. generator.file .. ' '
	for _, t in ipairs(m.types) do
		cmd = cmd .. '-t ' .. t .. ' '
	end
	for _, i in ipairs(m.includes) do
		cmd = cmd .. '-i \'' .. i .. '\' '
	end
	for _, h in ipairs(m.hppfiles) do
		cmd = cmd .. '-i \'<' .. h .. '>\' '
	end
	for _, f in ipairs(m.filters) do
		cmd = cmd .. '-f \'' .. f .. '\' '
	end
	cmd = cmd .. '-n ' .. m.name .. ' ' .. generator.directory..'/'..m.name..'.xml'
	debug('executing', cmd)
	os.execute(cmd)
	debug('writing project file')
	local qmake = qmake_project(name)
	local f = io.open(name..'_src/'..name..'.pro', 'w')
	f:write(qmake)
	f:close()
end


compile(tostring(... or 'qtcore'))

