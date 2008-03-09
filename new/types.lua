
return {
				--['void'] =   function(i) return '(void)(L, ' .. tostring(i) .. ')' end,
				--['void*'] =   function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
				--['void**'] = function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
				--['void const*'] =   function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,
				--['void const**'] = function(i) return 'lua_pushlightuserdata(L, ' .. tostring(i) .. ')' end,

				['char*'] = 'string;',
				--['char**'] = function(i) return 'lqtL_pusharguments(L, ' .. tostring(i) .. ')' end,
				['char const*'] = 'string;',
				--['char const**'] = function(i) return 'lqtL_pusharguments(L, ' .. tostring(i) .. ')' end,

				['int'] =                    'integer;',
				['unsigned int'] =           'integer;',

				['short'] =                  'integer;',
				['short int'] =              'integer;',
				['unsigned short'] =         'integer;',
				['unsigned short int'] =     'integer;',
				['short unsigned int'] =     'integer;',

				['long'] =                   'integer;',
				['unsigned long'] =          'integer;',
				['long int'] =               'integer;',
				['unsigned long int'] =      'integer;',
				['long unsigned int'] =      'integer;',

				['long long'] =              'integer;',
				['unsigned long long'] =     'integer;',
				['long long int'] =          'integer;',
				['unsigned long long int'] = 'integer;',

				['float'] =  'number;',
				['double'] = 'number;',

				['bool'] = 'bool;',
}

