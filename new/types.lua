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

base_types['char const*'] = BaseType'string'
base_types['char'] = BaseType'integer'
base_types['unsigned char'] = BaseType'integer'
base_types['int'] = BaseType'integer'
base_types['unsigned int'] = BaseType'integer'
base_types['short'] = BaseType'integer'
base_types['short int'] = BaseType'integer'
base_types['unsigned short'] = BaseType'integer'
base_types['unsigned short int'] = BaseType'integer'
base_types['short unsigned int'] = BaseType'integer'
base_types['long'] = BaseType'integer'
base_types['unsigned long'] = BaseType'integer'
base_types['long int'] = BaseType'integer'
base_types['unsigned long int'] = BaseType'integer'
base_types['long unsigned int'] = BaseType'integer'
base_types['long long'] = BaseType'integer'
base_types['unsigned long long'] = BaseType'integer'
base_types['long long int'] = BaseType'integer'
base_types['unsigned long long int'] = BaseType'integer'
base_types['float'] = BaseType'number'
base_types['double'] = BaseType'number'
base_types['bool'] = BaseType'boolean'
base_types['QSizeF'] = {
	get = function(i) return 'QSizeF(lua_tonumber(L, '..i..'), lua_tonumber(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushnumber(L, '..i..'.width()), lua_pushnumber(L, '..i..'.height()))', 2 end,
}
base_types['QSizeF const&'] = base_types['QSizeF']
base_types['QSize'] = {
	get = function(i) return 'QSize(lua_tointeger(L, '..i..'), lua_tointeger(L, '..i..'+1))', 2 end,
	push = function(i) return 'lua_pushinteger(L, '..i..'.width()), lua_pushinteger(L, '..i..'.height())', 2 end,
}
base_types['QSize const&'] = base_types['QSize']

return base_types
