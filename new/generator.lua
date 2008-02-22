#!/usr/bin/lua

local my = { readfile = function(fn) local f = assert(io.open(fn)) local s = f:read'*a' f:close() return s end }


local filename = ...
local path = string.match(arg[0], '(.*/)[^%/]+') or ''
local code = dofile(path..'xml.lua')(my.readfile(filename))[1]

table.foreach(code.byname.hello[1].xarg, print)



