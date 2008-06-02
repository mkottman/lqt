#!/usr/bin/lua

require'qtgui'

app = QApplication.new(select('#', ...), {...})

quit = QPushButton.new(QString.new("Quit"))
quit:resize(75, 30)
quit:setFont(QFont.new(QString.new'Times', 18, 75))

QObject.connect(quit, '2clicked()', app, '1quit()')

quit:show()

app.exec()


