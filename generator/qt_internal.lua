
local classes, enums = ...
local ret1, ret2 = {}, {}

for c in pairs(classes) do
	local n = c.xarg.name
	if n~=string.lower(n) and not (string.match(n, '_')
			or c.xarg.fullname=='QDebug::Stream'
			or c.xarg.fullname=='QForeachContainerBase'
			or c.xarg.fullname=='QByteArray::Data'
			or c.xarg.fullname=='QVariant::Private::Data'
			or c.xarg.fullname=='QRegion::QRegionData'
			or c.xarg.fullname=='QTextStreamManipulator'
			or c.xarg.fullname=='QString::Data'
			or c.xarg.fullname=='QUpdateLaterEvent'
			or c.xarg.fullname=='QWindowsXPStyle'
			or c.xarg.fullname=='QWindowsVistaStyle'
			or c.xarg.fullname=='QMacStyle'
			or c.xarg.fullname=='QThreadStorageData') then
		ret1[c] = true
	end
end

for e in pairs(enums) do
	local n = e.xarg.name
	if n~=string.lower(n) and not string.match(n, '_') then
		ret2[e] = true
	end
end

return ret1, ret2

