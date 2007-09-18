#ifndef __LQT_HPP
#define __LQT_HPP

#include <QObject>
#include <QVariant>
#include <QPointer>


extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
};

class LuaConnectDummy: public QObject {
Q_OBJECT
public:
  LuaConnectDummy(lua_State *l):L(l) {}
  virtual ~LuaConnectDummy() {}
  
public slots:
   void slot1() {}
   void slot2(double, float) {}
private:
  lua_State *L;
protected:
};

#define QOBJECT_METATABLE QMetaType::typeName(QMetaType::QObjectStar)
// #define QOBJECT_HANDLER "lqt_handler"

#define luaL_checkqobject(L, index) (*(QPointer<QObject>*)luaL_checkudata(L, index, QOBJECT_METATABLE))

#ifdef QOBJECT_HANDLER
class QLuaHandler: public QObject {
Q_OBJECT
public:
  QLuaHandler(lua_State *l):L(l) {}
  virtual ~QLuaHandler() {}
public slots:
  void destroyed ( QObject * obj = 0 );
private:
  lua_State *L;
protected:
};
#endif // QOBJECT_HANDLER

int lua_pushqobject(lua_State *L, QObject *Q);
QObject *lua_toqobject (lua_State *L, int index);
int lua_isqobject (lua_State *L, int index);

int lua_pushqvariant (lua_State *L, QVariant *V);
QVariant lua_toqvariant (lua_State *L, int index);

int lqt_connect (lua_State *L);
int lqt_disconnect (lua_State *L);

int methods_of (lua_State *L);


#endif // __LQT_HPP
