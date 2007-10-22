#!/usr/bin/lua

require'ex'

local cpptoxml = '../../cpptoxml/cpptoxml'

local runtest = function ()
	local xmlfile = assert(io.open('test.xml', 'w'))
	local exit, status = ex.wait(ex.spawn{ cpptoxml, 'test.cpp', stdout=xmlfile })
  xmlfile:close()
  assert((exit==1) and (status==0), 'cpptoxml died unexpectedly')

	local genfile = assert(io.open('test.out', 'w'))
  exit, status = ex.wait(ex.spawn{ 'lua', '../../generator.lua', './test.xml', stdout=genfile })
	genfile:close()
  assert((exit==1) and (status==0), 'generator died unexpectedly')
end


local exit, status = ex.wait(ex.spawn{'make', '-C', './cpptoxml'})
assert((exit==1) and (status==0), 'cannot build cpptoxml: aborting...')
assert(ex.chdir'./test')

local d = assert(ex.opendir'.')

for t in ex.readdir, d do
	if t~='.' and t~='..' and ex.chdir(t) then
		io.write('running test '..t..' ... ')
		local ret, err = pcall(runtest, t)
		if ret then
			print'OK'
		else
			print(err)
		end
		ex.chdir'..'
	end
end

ex.closedir(d)


