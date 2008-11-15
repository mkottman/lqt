#!/usr/bin/lua

require'qtcore'

slot = newslot()

slot.slot = function() print'called slot' end

for i = 1, 1e4 do
	local qo = QObject.new()
	qo:connect("2destroyed()", slot, "1slot()")
	qo:delete()
end

slot["slot()"] = function() print'called slot()' end

for i = 1, 1e4 do
	local qo = QObject.new()
	qo:connect("2destroyed()", slot, "1slot()")
	qo:delete()
end


