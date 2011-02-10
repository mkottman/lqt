Overview of lqt
===============

This document explains how to use lqt in Lua, how to load the libraries, how to use them, create instances and use advanced features.

Loading the library
-------------------

The libraries are distributed as separate modules, that can be loaded by the `require` function. They are named by lowercasing the module name, i.e. `qtcore`, `qtgui`, `qtxml`, etc.:

    require 'qtcore'

Classes and creating instances
------------------------------

Classes are named the same as in Qt (i.e. `QPushButton`), and are registered in the global table. To create an instance, you can either "call" the class, or call the `new()` function. You can pass the arguments as parameters. The `new()` function is preferred, because you explicitly state the memory management type (more later), and the Class() type may change later.

    a = QPushButton.new("Button A")
    b = QPushButton("Button B") -- equivalent to previous

Calling methods
---------------

Calling methods follows the Lua idioms - you pass the object as the first parameter, so you can use the colon:`btn:setVisible(true)`. For static methods, you can use the dot: `QApplication.exec()`.

Mapping of types
----------------

Primitive C++ types, like `int`, `bool`, `double`, `const char *` are converted to corresponding Lua types. Every other class and struct is represented by userdata. One exception is QByteArray - it is mapped into Lua string, and you can pass Lua string anywhere QByteArray is accepted. You lose ability to call methods of the QByteArray, but you can do them in Lua anyway.

Why can you pass Lua string where QString is expected? lqt uses the same principle as C++ - implicit constructors. Becase QString can be constructed from a QByteArray (which is Lua string), you can pass a Lua string wherever a QString is expected. This also means that you can pass number/boolean/string as QVariant parameter.

Memory management
-----------------

Memory management with Lua and C++ is a complicated issue. For every bound class, lqt provides the `new(...)` and `delete(o)` methods. `new(...)` creates a new instance -  userdata containing a boxed pointer to the instance, and `delete(o)` frees the memory and sets the boxed pointer to NULL.

Mix in Lua garbage collector (GC). By default, lqt does not let the Lua GC free the created objects. However, you can do this:

    local o = QObject.new()
    o.__gc = o.delete -- take ownership of object

This way, when Lua collects the userdata, it will also free the allocated object. lqt provides a shortcut for this - the `new_local()` function:

    local o = QObject.new_local()

Now, when `o` goes out of scope (and there is no other reference to it), the object will be freed. You have to be careful however - if Qt keeps a reference to an object, and there is no reference to it in Lua (even a simple `t[obj]=true`, the GC may collect it and free the memory, and then cause a segmentation fault when Qt accesses it.

The Qt framework provides an alternative way - the parent/child mechanism. Every class derived from QObject has a constructor that takes an argument named `parent` (check the Qt documentation). The object then becomes a child of `parent`, and is freed whenever the parent gets freed. When using the parent/child system, you cannot use the Lua GC (because the object will be freed twice).

Essentially you have 3 choices:
* forget about memory management and use `new(...)` everywhere (not good for long-running apps)
* use `new_local(...)` and keep references to objects while they are used in Qt
* create a widget/parent object and make other objects it's children using `new(..., parent)`

Additional Lua fields
-----------------

The userdata objects can also serve as traditional Lua tables (these are stored in the userdata's environment table):

    local obj = QObject.new()
    obj.message = "Hello from Lua!"

lqt keeps references to objects keyed by their pointer (in a weak table).When you have a userdata and you keep a reference to it, and a method returns the same pointer as return value, or it is passed to your callback function, you get back the same userdata (along with it's Lua fields).

Virtual methods
---------------

You can override a virtual method and implement abstract methods in Lua. To do that, you need to save them as an object field. Easier to show on code:

    wnd = QMainWindow.new()
    function wnd:resizeEvent(e)
        print("I'm being resized!")
    end
    wnd:show()

Signal/slot mechanism
---------------------

To see the signals and slots an object responds to, you can retrieve a list of them by using the `__methods()` method. It returns a table of strings, representing the signatures and types of Qt "methods" (= signals and slots) it supports.

To connect signals and slots, use the standard `connect()` method, you just have to prepend '2' to the signal signature, and '1' to the slot signature. If you really want, you can use the following functions:

    function SIGNAL(sig) return '2'..sig end
    function SLOT(sig) return '1'..sig end

To implement custom slots, you need to use the `__addmethod(obj, sig, func)` method to add a custom slot. You can implement it on any object you want, but it usually makes sense to implement it directly on the provider of the signal. It is used as follows:

    local btn = QCheckButton.new("Press me!")
    btn:__addmethod("mySlot(bool)", function(self, state)
        print("My state is", state)
    end)
    btn:connect('2toggled(bool)', btn, '1mySlot(bool)')

You have to be careful about the signature (Qt is picky, you have to be precise). Always check `__methods()` to see the correct signature: `table.foreachi(obj:__methods(), print)`. Also, lqt can only implement slots of known signature - they are compiled from the list of all signals, therefore you can create a slot for any signal signature present in Qt, but you cannot create new slots/signals (use pure Lua for that).

The Qt API
------------

For reference on available classes and their methods, please refer to the [Qt documentation](http://doc.qt.nokia.com/). lqt provides essentially the same API, except that you do not need differentiate between pointers, references and values.
