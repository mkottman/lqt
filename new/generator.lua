#!/usr/bin/lua


local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local code = dofile(path..'xml.lua')(my.readfile(filename))[1]

table.foreach(code.byname.hello[1].xarg, print)



