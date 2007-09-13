#!/usr/bin/lua

MyWidget = {
	event = function (b,e,...)
		local mt, env = getmetatable(e), debug.getfenv(e)
		print(mt, env)
		table.foreach(env, print)
		print(b.__qtype,e.__qtype,e:type(),...)
	end,
	__base = { QPushButton=QPushButton },
	__index = function(t, k) return QPushButton.__index(t, k) end,
	__newindex = QPushButton.__newindex,
}

MyWidget.new = function(...)
	local ret = QPushButton.new(...)
	debug.setmetatable(ret, MyWidget)
	print(ret, getmetatable(ret), MyWidget )
	return ret
end

b = MyWidget.new()

print(b, b.__index, '->', type(b.__index(b, "show")))
b:show()

return true, tostring(getmetatable(b)), tostring(MyWidget)


