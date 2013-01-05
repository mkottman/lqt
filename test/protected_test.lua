require "qtcore"
require "qtgui"

A = QApplication(1, {'Protected test'})

-- We will implement our custom model
M = QAbstractListModel()

-- stored in the environment table of the userdata
M.luaData = {'Hello', 'World'}

-- these are implemented virtual methods
function M:rowCount()
	return #self.luaData
end

local empty = QVariant()
function M:data(index, role)
	if role == Qt.ItemDataRole.DisplayRole then
		local row = index:row()
		return QVariant(self.luaData[row + 1])
	end
	return empty
end

-- this is a custom helper function
function M:addAnotherString(str)
	table.insert(self.luaData, str)
	local row = #self.luaData - 1
	local index = self:createIndex(row, 0, 0)
	self:dataChanged(index, index)
end

-- some simple layout - list and a button
MW = QWidget()

W = QListView()
W:setModel(M)

B = QPushButton('Add Lua data')
local counter = 1
B:connect('2clicked()', function()
	M:addAnotherString('Added text ' .. counter)
	counter = counter + 1
end)

L = QVBoxLayout()
L:addWidget(W)
L:addWidget(B)
MW:setLayout(L)

MW:show()
A.exec()
