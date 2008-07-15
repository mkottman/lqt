#!/usr/bin/lua

require'qtgui'

local add_method = function(qobj, qname, signature, func)
	local stringdata = qobj['Lqt MetaStringData']
	local data = qobj['Lqt MetaData']
	local slots = qobj['Lqt Slots']
	local sigs = qobj['Lqt Signatures']
	if stringdata==nil then
		--print'adding a slot!'
		--initialize
		stringdata = qname..'\0'
		data = setmetatable({}, {__index=table})
		data:insert(1) -- revision
		data:insert(0) -- class name
		data:insert(0) -- class info (1)
		data:insert(0) -- class info (2)
		data:insert(0) -- number of methods
		data:insert(10) -- beginning of methods
		data:insert(0) -- number of properties
		data:insert(0) -- beginning of properties
		data:insert(0) -- number of enums/sets
		data:insert(0) -- beginning of enums/sets
		slots = setmetatable({}, {__index=table})
		sigs = setmetatable({}, {__index=table})
	end
	local name, args = string.match(signature, '^(.*)(%b())$')
	local arg_list = ''
	if args=='()' then
		arg_list=''
	else
		local argnum = select(2, string.gsub(args, '.+,', ','))+1
		for i = 1, argnum do
			if i>1 then arg_list=arg_list..', ' end
			arg_list = arg_list .. 'arg' .. i
		end
	end
	--print(arg_list, signature)
	local sig, params = #stringdata + #arg_list + 1, #stringdata -- , ty, tag, flags
	stringdata = stringdata .. arg_list .. '\0' .. signature .. '\0'
	data:insert(sig) -- print(sig, string.byte(stringdata, sig, sig+4), string.char(string.byte(stringdata, sig+1, sig+6)))
	data:insert(params) -- print(params, string.char(string.byte(stringdata, params+1, params+10)))
	data:insert(#stringdata-1) -- print(#stringdata-1, (string.byte(stringdata, #stringdata)))
	data:insert(#stringdata-1) -- print(#stringdata-1, (string.byte(stringdata, #stringdata)))
	if func then
		data:insert(0x0a)
		slots:insert(func)
		sigs:insert('__slot'..signature:match'%b()')
	else
		data:insert(0x05)
		slots:insert(false)
		sigs:insert(false)
	end
	data[5] = data[5] + 1
	qobj['Lqt MetaStringData'] = stringdata
	qobj['Lqt MetaData'] = data
	qobj['Lqt Slots'] = slots
	qobj['Lqt Signatures'] = sigs
end

local LCD_Range = function(...)
	local this = QWidget.new(...)
	--print(this:metaObject():className(), this:metaObject():methodCount())
	--print(this:metaObject():className(), this:metaObject():methodCount())

	local lcd = QLCDNumber.new()
	lcd:setSegmentStyle'Filled'

	local slider = QSlider.new'Horizontal'
	slider:setRange(0, 99)
	slider:setValue(0)

	this:__addmethod("LuaLCD", 'valueChanged(int)')
	this:__addmethod("LuaLCD", 'setValue(int)', function(_, val) slider:setValue(val) end)
	QObject.connect(slider, '2valueChanged(int)', lcd, '1display(int)')
	QObject.connect(slider, '2valueChanged(int)', this, '2valueChanged(int)')

	local layout = QVBoxLayout.new()
	layout:addWidget(lcd)
	layout:addWidget(slider)
	this:setLayout(layout)
	return this
end

local new_MyWidget = function(...)
	local this = QWidget.new(...)

	local quit = QPushButton.new(QString.new'Quit')
	quit:setFont(QFont.new(QString.new'Times', 18, 75))

	QObject.connect(quit, '2clicked()', this, '1close()')

	local grid = QGridLayout.new()
	local previousRange = nil
	for row = 1, 3 do
		for column = 1, 3 do
			local lcdrange = LCD_Range()
			grid:addWidget(lcdrange, row, column)
			if previousRange then
				QObject.connect(lcdrange, '2valueChanged(int)',
					previousRange, '1setValue(int)')
			end
			previousRange = lcdrange
		end
	end

	local layout = QVBoxLayout.new()
	layout:addWidget(quit)
	layout:addLayout(grid)
	this:setLayout(layout)
	return this
end

app = QApplication.new(1 + select('#', ...), {arg[0], ...})
app.__gc = app.delete -- take ownership of object

widget = new_MyWidget()
widget:show()

app.exec()


