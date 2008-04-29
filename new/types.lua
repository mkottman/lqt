local base_types = (...)

local BaseType = function(s)
	s = tostring(s)
	return {
		--label = "BaseType",
		--xargs = {  },
		desc = s..';',
		get = function(i, j)
			j = j or -i
			return 'lua_to'..s..'(L, '..tostring(j)..');'
		end,
		push = function(j) -- must handle arguments (e.g. in virtual callbacks) and return values
			return 'lua_push'..s..'(L, '..tostring(j)..');'
		end,
		test = function(i, j)
			error'not implemented' -- TODO
			j = j or -i
			return 'LqtTestBaseType_'..s..'(L, '..tostring(j)..')'
		end,
	}
end

base_types['char const*'] = BaseType'string'
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

