#!/usr/bin/lua

require'qtgui'

app = QApplication.new(select('#', ...), {...})
app.__gc = app.delete -- take ownership of object

hello = QPushButton.new(QString.new("Hello World!"))
hello:resize(100, 30)

hello:show()

app.exec()


