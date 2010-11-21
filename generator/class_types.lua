#!/usr/bin/lua

lqt = lqt or {}
lqt.classes = lqt.classes or {}


local pointer_t = function(fn)
	local cn = string.gsub(fn, '::', '.')
	return {
		-- the argument is a pointer to class
		push = function(n)
			return 'lqtL_passudata(L, '..n..', "'..cn..'*")', 1
		end,
		get = function(n)
			return 'static_cast<'..fn..'*>'
			..'(lqtL_toudata(L, '..n..', "'..cn..'*"))', 1
		end,
		test = function(n)
			return 'lqtL_isudata(L, '..n..', "'..cn..'*")', 1
		end,
		onstack = cn..'*,',
	}
end
local pointer_const_t = function(fn)
	local cn = string.gsub(fn, '::', '.')
	return {
		-- the argument is a pointer to constant class instance
		push = function(n)
			return 'lqtL_passudata(L, '..n..', "'..cn..'*")', 1
		end,
		get = function(n)
			return 'static_cast<'..fn..'*>'
			..'(lqtL_toudata(L, '..n..', "'..cn..'*"))', 1
		end,
		test = function(n)
			return 'lqtL_isudata(L, '..n..', "'..cn..'*")', 1
		end,
		onstack = cn..'*,',
	}
end
local ref_t = function(fn)
	local cn = string.gsub(fn, '::', '.')
	return {
		-- the argument is a reference to class
		push = function(n)
			return 'lqtL_pushudata(L, &'..n..', "'..cn..'*")', 1
		end,
		get = function(n)
			return '*static_cast<'..fn..'*>'
			..'(lqtL_toudata(L, '..n..', "'..cn..'*"))', 1
		end,
		test = function(n)
			return 'lqtL_isudata(L, '..n..', "'..cn..'*")', 1
		end,
		onstack = cn..'*,',
	}
end
local instance_t = function(fn)
	local cn = string.gsub(fn, '::', '.')
	return {
		-- the argument is the class itself
		push = function(n)
			return 'lqtL_copyudata(L, &'..n..', "'..cn..'*")', 1
		end,
		get = function(n)
			return '*static_cast<'..fn..'*>'
			..'(lqtL_toudata(L, '..n..', "'..cn..'*"))', 1
		end,
		test = function(n)
			return 'lqtL_isudata(L, '..n..', "'..cn..'*")', 1
		end,
		onstack = cn..'*,',
	}
end
local const_ref_t = function(fn)
	local cn = string.gsub(fn, '::', '.')
	return {
		-- the argument is a pointer to class
		push = function(n)
			return 'lqtL_copyudata(L, &'..n..', "'..cn..'*")', 1, string.gsub(fn, ' const&$', '')
		end,
		get = function(n)
			return '*static_cast<'..fn..'*>'
			..'(lqtL_toudata(L, '..n..', "'..cn..'*"))', 1
		end,
		test = function(n)
			return 'lqtL_isudata(L, '..n..', "'..cn..'*")', 1
		end,
		onstack = cn..'*,',
	}
end

local const_ptr_ref_t = pointer_const_t

lqt.classes.insert = function(cname)
	if typesystem[cname]==nil then
		typesystem[cname..'*'] = pointer_t(cname)
		typesystem[cname..' const*'] =  pointer_const_t(cname)
		typesystem[cname..'&'] = ref_t(cname)

		typesystem[cname] = instance_t(cname)
		typesystem[cname..' const'] = instance_t(cname)
		typesystem[cname..' const&'] = const_ref_t(cname)
		typesystem[cname..'* const&'] = const_ptr_ref_t(cname)

		return true
	else
		return nil
	end
end



