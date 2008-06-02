#!/usr/bin/lua

require'qtgui'

app = QApplication.new(select('#', ...), {...})

hello = QPushButton.new(QString.new("Hello World!"))
hello:resize(100, 30)

hello:show()

app.exec()


