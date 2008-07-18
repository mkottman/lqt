
=== Build Instructions ===

The lqt bindings have currently no simple build method.
They could be used to bind many different libraries and
toolkits, but you will have to modify the following commands
according to your needs.

Here there is a simple and quick method for obtaining the
bindings to the QtGui module of (auspicably) any Qt release
of the Qt4 series.

The generator has been tested only with
 * gcc 4.3.1
 * lua 5.1.3
 * qt 4.3.3-5 and 4.4.0

== Unpack the tarball and enter the directory ==

tar xzf lqt*.tar.gz
cd lqt

== Build the C++ parser ==

cd cpptoxml
qmake
make
cd ..

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
lua generator/generator.lua src/qtgui.xml -i '<QtGui>' -n qtgui -t generator/types.lua -t generator/qtypes.lua -f generator/qt_internal.lua

on windows use the command:
lua generator\generator.lua src\qtgui.xml -i '<QtGui>' -n qtgui -t generator\types.lua -t generator\qtypes.lua -f generator\qt_internal.lua


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

cp common/lqt_common.?pp qtgui_src/
cd qtgui_src/
qmake -project -template lib -o qtgui.pro
qmake
make

Then wait. If everything works, you will likely have a
working lua module named libqtgui.so.1.0.0 . Rename or
link as qtcore.so, and place where require can find it.

You may have to tell qmake where to find Lua headers.

