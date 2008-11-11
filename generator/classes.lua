#!/usr/bin/lua

lqt = lqt or {}
lqt.classes = lqt.classes or {}

lqt.classes.insert = function(cname, types) --, cancopy)
	local pointer_t = function(fn)
		return {
			-- the argument is a pointer to class
			push = function(n)
				return 'lqtL_passudata(L, '..n..', "'..fn..'*")', 1
			end,
			get = function(n)
				return 'static_cast<'..fn..'*>'
				..'(lqtL_toudata(L, '..n..', "'..fn..'*"))', 1
			end,
			test = function(n)
				return 'lqtL_isudata(L, '..n..', "'..fn..'*")', 1
			end,
		}
	end
	local pointer_const_t = function(fn)
		return {
			-- the argument is a pointer to constant class instance
			push = function(n)
				return 'lqtL_passudata(L, '..n..', "'..fn..'*")', 1
			end,
			get = function(n)
				return 'static_cast<'..fn..'*>'
				..'(lqtL_toudata(L, '..n..', "'..fn..'*"))', 1
			end,
			test = function(n)
				return 'lqtL_isudata(L, '..n..', "'..fn..'*")', 1
			end,
		}
	end
	local ref_t = function(fn)
		return {
			-- the argument is a reference to class
			push = function(n)
				return 'lqtL_passudata(L, &'..n..', "'..fn..'*")', 1
			end,
			get = function(n)
				return '*static_cast<'..fn..'*>'
				..'(lqtL_toudata(L, '..n..', "'..fn..'*"))', 1
			end,
			test = function(n)
				return 'lqtL_isudata(L, '..n..', "'..fn..'*")', 1
			end,
		}
	end
	local instance_t = function(fn)
		return {
			-- the argument is the class itself
			push = function(n)
				return 'lqtL_copyudata(L, &'..n..', "'..fn..'*")', 1
			end,
			get = function(n)
				return '*static_cast<'..fn..'*>'
				..'(lqtL_toudata(L, '..n..', "'..fn..'*"))', 1
			end,
			test = function(n)
				return 'lqtL_isudata(L, '..n..', "'..fn..'*")', 1
			end,
		}
	end
	local const_ref_t = function(fn)
		return {
			-- the argument is a pointer to class
			push = function(n)
				return 'lqtL_copyudata(L, &'..n..', "'..fn..'*")', 1, string.gsub(fn, ' const&$', '')
			end,
			get = function(n)
				return '*static_cast<'..fn..'*>'
				..'(lqtL_toudata(L, '..n..', "'..fn..'*"))', 1
			end,
			test = function(n)
				return 'lqtL_isudata(L, '..n..', "'..fn..'*")', 1
			end,
		}
	end
	if types[cname]==nil then
		types[cname..'*'] = pointer_t(cname)
		types[cname..' const*'] =  pointer_const_t(cname)
		types[cname..'&'] = ref_t(cname)
		--if cancopy then
			types[cname] = instance_t(cname)
			types[cname..' const&'] = const_ref_t(cname)
		--end
		return true
	else
		return false
	end
end



