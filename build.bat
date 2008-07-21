
mkdir src
cpptoxml\debug\cpptoxml.exe QtGui -qt > src\qtgui.xml
lua generator\generator.lua src\qtgui.xml -n qtgui -t generator\types.lua -i QtGui -f generator\qt_internal.lua
cd qtgui_src
copy /Y ..\common\*.* .
::qmake -project -template lib -o qtgui.pro
::qmake -tp vc qtgui.pro
qmake -tp vc qtgui_merged_build.pro
cd ..

