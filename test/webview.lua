#!/usr/bin/lua

print(package.cpath )

require'qtcore'
require'qtgui'
require'qtwebkit'

app = QApplication.new(1 + select('#', ...), {arg[0], ...})
app.__gc = app.delete -- take ownership of object

lua = QUrl.new(QString.new('http://www.lua.org'))

webView = QWebView.new(window)
webView:setUrl(lua)
webView:show()

app.exec()



