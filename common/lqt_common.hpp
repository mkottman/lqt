/*
 * Copyright (c) 2007-2008 Mauro Iazzi
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#ifndef __LQT_COMMON_HPP
#define __LQT_COMMON_HPP

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

//#include <iostream>

//#define lqtL_register(L, p, n) ( (void)L, (void)p, (void)n )
//#define lqtL_unregister(L, p) ( (void)L, (void)p )

#define LQT_POINTERS "Registry Pointers"
#define LQT_REFS "Registry References"
#define LQT_ENUMS "Registry Enumerations"

extern void lqtL_register(lua_State *, const void *);
extern void lqtL_unregister(lua_State *, const void *);

//extern int& lqtL_tointref (lua_State *, int);

//extern void lqtL_pusharguments (lua_State *, char**);
//extern char** lqtL_toarguments (lua_State *, int);
//extern bool lqtL_testarguments (lua_State *, int);

//extern void lqtL_manageudata (lua_State *, int);
//extern void lqtL_unmanageudata (lua_State *, int);
extern void lqtL_pushudata (lua_State *, const void *, const char *);
extern void lqtL_passudata (lua_State *, const void *, const char *);
extern void lqtL_copyudata (lua_State *, const void *, const char *);
extern void * lqtL_toudata (lua_State *, int, const char *);
extern bool lqtL_testudata (lua_State *, int, const char *);
//#define lqtL_checkudata(a...) luaL_checkudata(a)
extern void * lqtL_checkudata (lua_State *, int, const char *);
#define lqtL_isudata lqtL_testudata

extern void lqtL_pushenum (lua_State *, int, const char *);
extern bool lqtL_isenum (lua_State *, int, const char *);
extern int lqtL_toenum (lua_State *, int, const char *);

extern bool lqtL_isinteger (lua_State *, int);
extern bool lqtL_isnumber (lua_State *, int);
extern bool lqtL_isstring (lua_State *, int);
extern bool lqtL_isboolean (lua_State *, int);

extern bool lqtL_missarg (lua_State *, int, int);
//extern int lqtL_baseindex (lua_State *, int, int);

//extern int lqtL_gc (lua_State *);
//extern int lqtL_index (lua_State *);
//extern int lqtL_newindex (lua_State *);

typedef struct {
	const char *name;
	int value;
} lqt_Enum;

typedef struct {
	lqt_Enum *enums;
	const char *name;
} lqt_Enumlist;

extern int lqtL_createenumlist (lua_State *, lqt_Enumlist[]);

typedef struct {
	const char *basename;
} lqt_Base;

typedef struct {
	luaL_Reg *mt;
	lqt_Base *bases;
	const char * name;
} lqt_Class;

extern int lqtL_createclasses (lua_State *, lqt_Class *);

/* functions to get/push special types */

extern void * lqtL_getref (lua_State *, size_t);
extern int * lqtL_tointref (lua_State *, int);
extern char ** lqtL_toarguments (lua_State *, int);
extern void lqtL_pusharguments (lua_State *, char **);

extern int lqtL_getflags (lua_State *, int, const char *);
extern void lqtL_pushflags (lua_State *, int, const char *);

extern "C" int luaopen_qtbase (lua_State *);


#endif // __LQT_COMMON_HPP

