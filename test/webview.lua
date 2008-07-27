#!/usr/bin/lua

require'qtcore'
require'qtgui'
require'qtwebkit'

app = QApplication.new(1 + select('#', ...), {arg[0], ...})
app.__gc = app.delete -- take ownership of object

local address = tostring(arg[01])

if address == '' then
	address = QUrl.new(QString.new('http://www.lua.org'))
end

url = QUrl.new(QString.new(address))

print('Loading site  '..address..' ...')

webView = QWebView.new(window)
webView:setUrl(url)
webView:show()

app.exec()



