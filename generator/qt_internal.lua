
local classes, enums = ...
local ret1, ret2 = {}, {}

-- don't bind this Qt internals/unsupported classes
-- if there are linker errors, or errors when laoding the .so 
-- add the class here 

for c in pairs(classes) do
	local n = c.xarg.name
	if n~=string.lower(n) and not (string.match(n, '_')
			-- these are useless to bind, but compile
			or c.xarg.fullname=='QVariant::Private' -- well, it IS public
			or c.xarg.fullname=='QVariant::Private::Data' -- well, it IS public
			or c.xarg.fullname=='QVariant::PrivateShared' -- well, it IS public
			or c.xarg.fullname=='QObjectData'-- compiles
			or c.xarg.fullname=='QtConcurrent::internal::ExceptionStore' -- it compiles
			or c.xarg.fullname=='QtConcurrent::internal::ExceptionHolder' -- it compiles
			or c.xarg.fullname=='QtConcurrent::ResultIteratorBase' -- it compiles
			or c.xarg.fullname=='QtSharedPointer' -- compiles
			or c.xarg.fullname=='QtSharedPointer::InternalRefCountData' -- compiles
			or c.xarg.fullname=='QtSharedPointer::ExternalRefCountData' -- compiles
			or c.xarg.fullname=='QUpdateLaterEvent' -- compiles
			or c.xarg.fullname=='QTextStreamManipulator' -- compiles
			or c.xarg.fullname=='QtConcurrent::ThreadEngineSemaphore' -- compiles
			-- internals, no binding needed
			or c.xarg.fullname=='QDebug::Stream' -- private
			or c.xarg.fullname=='QByteArray::Data' -- private
			or c.xarg.fullname=='QRegion::QRegionData' -- private
			or c.xarg.fullname=='QString::Data' -- private
			or c.xarg.fullname=='QXmlAttributes::Attribute' -- private
			or c.xarg.fullname=='QGLColormap::QGLColormapData' -- private

			-- platform specific, TODO
			or c.xarg.fullname=='QWindowsCEStyle'
			or c.xarg.fullname=='QWindowsMobileStyle'
			or c.xarg.fullname=='QWindowsXPStyle'
			or c.xarg.fullname=='QWindowsVistaStyle'
			or c.xarg.fullname=='QMacStyle'

			-- binding bugs
			or c.xarg.fullname=='QThreadStorageData' -- binding error (function pointer)
			or c.xarg.fullname=='QForeachContainerBase' -- "was not declared in this scope"
			or c.xarg.fullname=='QtConcurrent::Exception'                 -- GCC throw() in destructor base declaration
			or c.xarg.fullname=='QtConcurrent::UnhandledException'        -- GCC throw() in destructor base declaration



			) then
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

