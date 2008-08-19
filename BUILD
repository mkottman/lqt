======================
  Build Instructions
======================


Qt 4.4 or 4.3

Compilers:
GCC 4.2, 4.3
MSVC 8,9



1. CMake


Create an out-of-source directory, 
for instance relative to the lqt sources the directory ../build, 
then with qmake in your PATH variable call in ../build

build> cmake ..\lqt
build> make

Thats all. 

Example lua files are in lqt/test
(under Linux LUA_CPATH is needed):

build> export LUA_CPATH=$PWD/lib/lib?.so
build> ./bin/lua ../lqt/test/webview.lua


Without any option it also builds Lua which could
be suppressed by -DSYSTEM_LUA
(TODO is FindLua broken?)




2. qmake, step by step ==


== Build the C++ parser ==

cd cpptoxml
qmake
make
cd ..

Checkouts from KDE svn needs to build cpptoxml seperately
svn.kde.org/home/kde/trunk/kdesupport/cpptoxml


== Create a cpp file including the module ==

mkdir ./src
echo '#include <QtGui>' > ./src/qtgui.cpp

== Create the XML description of the file ==

./cpptoxml/cpptoxml -C cpptoxml/parser/rpp/pp-qt-configuration ./src/qtgui.cpp > src/qtgui.xml

Rememebr that you have to set the QT_INCLUDE env variable such that
$QT_INCLUDE contains the QtCore, QtGui, etc... directories

The same command could be issued directly on the header file
e.g.
/usr/include/QtGui/QtGui
instead of
./src/qtgui.cpp

== Create destination directory and generate bindings ==

mkdir qtgui_src
lua generator/generator.lua src/qtgui.xml -i QtGui -i lqt_qt.hpp -n qtgui -t generator/types.lua -t generator/qtypes.lua -f generator/qt_internal.lua

On windows use the command:
lua generator\generator.lua src\qtgui.xml -i QtGui -i lqt_qt.hpp -n qtgui -t generator\types.lua -t generator\qtypes.lua -f generator\qt_internal.lua



The options tell the generator which is the name of the
module (-n), which type definitions to use (-t), which files
must be included in the final binding (-i), how to filter out
some classes (-f)

Every time you issue this command you will likely end up with
different binding file and also a different number of files,
even if src/qtgui.xml has not changed. It is probably better
to always begin with an empty directory each time, so that
there are no leftover files from previous runs.

== Copy static files and compile binding ==

cp common/lqt_*.?pp qtgui_src/
cd qtgui_src/
qmake -project -template lib -o qtgui.pro
qmake
make

Then wait. If everything works, you will likely have a
working lua module named libqtgui.so.1.0.0 . Rename or
link as qtcore.so, and place where require can find it.

You may have to tell qmake where to find Lua headers.

