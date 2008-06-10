#!/usr/bin/lua

require'qtgui'

app = QApplication.new(1 + select('#', ...), {arg[0], ...})

window = QWidget.new()
window:resize(200, 120)

quit = QPushButton.new(QString.new("Quit"), window)
quit:setFont(QFont.new(QString.new'Times', 18, 75))
quit:setGeometry(10, 40, 180, 40)

QObject.connect(quit, '2clicked()', app, '1quit()')

window:show()

app.exec()


