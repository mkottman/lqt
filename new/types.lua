local base_types = (...) or {}

local BaseType = function(s)
	s = tostring(s)
	return {
		get = function(j)
			return 'lua_to'..s..'(L, '..tostring(j)..')', 1
		end,
		push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
			return 'lua_push'..s..'(L, '..tostring(j)..')', 1
		end,
	}
end
local integer_type = {
	get = function(j)
		return 'lua_tointeger(L, '..tostring(j)..')', 1
	end,
	push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lua_pushinteger(L, '..tostring(j)..')', 1
	end,
	test = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lqtL_isinteger(L, '..tostring(j)..')', 1
	end,
}
local number_type = {
	get = function(j)
		return 'lua_tonumber(L, '..tostring(j)..')', 1
	end,
	push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lua_pushnumber(L, '..tostring(j)..')', 1
	end,
	test = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lqtL_isnumber(L, '..tostring(j)..')', 1
	end,
}
local integer_type = {
	get = function(j)
		return 'lua_tointeger(L, '..tostring(j)..')', 1
	end,
	push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lua_pushinteger(L, '..tostring(j)..')', 1
	end,
	test = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lqtL_isinteger(L, '..tostring(j)..')', 1
	end,
}
local bool_type = {
	get = function(j)
		return 'lua_toboolean(L, '..tostring(j)..')', 1
	end,
	push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lua_pushboolean(L, '..tostring(j)..')', 1
	end,
	test = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lqtL_isboolean(L, '..tostring(j)..')', 1
	end,
}

base_types['char const*'] = {
	get = function(j)
		return 'lua_tostring(L, '..tostring(j)..')', 1
	end,
	push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
		return 'lua_pushstring(L, '..tostring(j)..')', 1
	end,
	test = function(j)
		return 'lqtL_isstring(L, '..tostring(j)..')', 1
	end,
}
base_types['char'] = integer_type
base_types['unsigned char'] = integer_type
base_types['int'] = integer_type
base_types['unsigned int'] = integer_type
base_types['short'] = integer_type
base_types['short int'] = integer_type
base_types['unsigned short'] = integer_type
base_types['unsigned short int'] = integer_type
base_types['short unsigned int'] = integer_type
base_types['long'] = integer_type
base_types['unsigned long'] = integer_type
base_types['long int'] = integer_type
base_types['unsigned long int'] = integer_type
base_types['long unsigned int'] = integer_type
base_types['long long'] = integer_type
base_types['unsigned long long'] = integer_type
base_types['long long int'] = integer_type
base_types['unsigned long long int'] = integer_type
base_types['float'] = number_type
base_types['double'] = number_type
base_types['bool'] = bool_type

base_types['QSizeF'] = {
	get = function(i) return 'QSizeF(lua_tonumber(L, '..i..'), lua_tonumber(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushnumber(L, '..i..'.width()), lua_pushnumber(L, '..i..'.height())', 2 end,
	test = function(i) return '(lqtL_isnumber(L, '..i..') && lqtL_isnumber(L, '..i..'+1))', 2 end,
}
base_types['QSizeF const&'] = base_types['QSizeF']

base_types['QSize'] = {
	get = function(i) return 'QSize(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.width()), lua_pushinteger(L, '..i..'.height())', 2 end,
	test = function(i) return '(lqtL_isinteger(L, '..i..') && lqtL_isinteger(L, '..i..'+1))', 2 end,
}
base_types['QSize const&'] = base_types['QSize']

base_types['QPoint'] = {
	get = function(i) return 'QPoint(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.x()), lua_pushinteger(L, '..i..'.y())', 2 end,
	test = function(i) return '(lqtL_isinteger(L, '..i..') && lqtL_isinteger(L, '..i..'+1))', 2 end,
}
base_types['QPoint const&'] = base_types['QPoint']

base_types['QPointF'] = {
	get = function(i) return 'QPointF(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.x()), lua_pushinteger(L, '..i..'.y())', 2 end,
	test = function(i) return '(lqtL_isinteger(L, '..i..') && lqtL_isinteger(L, '..i..'+1))', 2 end,
}
base_types['QPointF const&'] = base_types['QPointF']

base_types['QRect'] = {
	get = function(i) return 'QRect(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1), lua_tointeger(L, '..i..'+2), lua_tointeger(L, '..i..'+3))', 4 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.x()), lua_pushinteger(L, '..i..'.y()), lua_pushinteger(L, '..i..'.width()), lua_pushinteger(L, '..i..'.height())', 4 end,
	test = function(i) return '(lqtL_isinteger(L, '..i..') && lqtL_isinteger(L, '..i..'+1) && lqtL_isinteger(L, '..i..'+2) && lqtL_isinteger(L, '..i..'+3))', 4 end,
}
base_types['QRect const&'] = base_types['QRect']

base_types['QRectF'] = {
	get = function(i) return 'QRectF(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1), lua_tointeger(L, '..i..'+2), lua_tointeger(L, '..i..'+3))', 4 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.x()), lua_pushinteger(L, '..i..'.y()), lua_pushinteger(L, '..i..'.width()), lua_pushinteger(L, '..i..'.height())', 4 end,
	test = function(i) return '(lqtL_isinteger(L, '..i..') && lqtL_isinteger(L, '..i..'+1) && lqtL_isinteger(L, '..i..'+2) && lqtL_isinteger(L, '..i..'+3))', 4 end,
}
base_types['QRectF const&'] = base_types['QRectF']

return base_types
