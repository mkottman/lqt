#ifndef __LQT_QT_UTILS_HPP
#define __LQT_QT_UTILS_HPP

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}


extern "C" int luaopen_qt (lua_State*);



#endif // __LQT_QT_UTILS_HPP
