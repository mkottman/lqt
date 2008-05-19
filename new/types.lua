local base_types = (...) or {}

local BaseType = function(s)
	s = tostring(s)
	return {
		--label = "BaseType",
		--xargs = {  },
		desc = s..';',
		get = function(j)
			return 'lua_to'..s..'(L, '..tostring(j)..');', 1
		end,
		push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
			return 'lua_push'..s..'(L, '..tostring(j)..');', 1
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

return base_types
