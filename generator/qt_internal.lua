
local classes, enums = ...
local ret1, ret2 = {}, {}

for c in pairs(classes) do
	local n = c.xarg.name
	if n~=string.lower(n) and not (string.match(n, '_')
			or c.xarg.fullname=='QAtomic'
			or c.xarg.fullname=='QAtomicInt'
			or c.xarg.fullname=='QBasicAtomic'
			or c.xarg.fullname=='QBasicAtomicInt'
			or c.xarg.fullname=='QDebug::Stream'
			or c.xarg.fullname=='QForeachContainerBase'
			or c.xarg.fullname=='QByteArray::Data'
			or c.xarg.fullname=='QVariant::Private::Data'
			or c.xarg.fullname=='QRegion::QRegionData'
			or c.xarg.fullname=='QTextStreamManipulator'
			or c.xarg.fullname=='QString::Data'
			or c.xarg.fullname=='QUpdateLaterEvent'
			or c.xarg.fullname=='QWindowsCEStyle'
			or c.xarg.fullname=='QWindowsMobileStyle'
			or c.xarg.fullname=='QWindowsXPStyle'
			or c.xarg.fullname=='QWindowsVistaStyle'
			or c.xarg.fullname=='QMacStyle'
			or c.xarg.fullname=='QtConcurrent::internal::ExceptionStore'
			or c.xarg.fullname=='QtConcurrent::BlockSizeManager'
			or c.xarg.fullname=='QtConcurrent::ResultItem'
			or c.xarg.fullname=='QtConcurrent::ResultIteratorBase'
			or c.xarg.fullname=='QtConcurrent::ResultStoreBase'
			or c.xarg.fullname=='QtConcurrent::ThreadEngineBase'
			or c.xarg.fullname=='QtConcurrent::ThreadEngineSemaphore'
			or c.xarg.fullname=='QtConcurrent::Exception'          -- generator bug
			or c.xarg.fullname=='QtConcurrent::UnhandledException' -- generator bug
			or c.xarg.fullname=='QtConcurrent::ExceptionHolder'    -- generator bug
			or c.xarg.fullname=='QtConcurrent::internal::ExceptionHolder' -- generator bug
			or c.xarg.fullname=='QtConcurrent::Future'          -- cpptoxml template bug
			or c.xarg.fullname=='QtConcurrent::FutureWatcher'   -- cpptoxml template bug
			or c.xarg.fullname=='QtConcurrent::FutureInterface' -- cpptoxml template bug
			or c.xarg.fullname=='QObjectData'
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

