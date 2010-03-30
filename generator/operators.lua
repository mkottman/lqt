module('operators', package.seeall)

local operatorTrans = {
	['<<'] = 'IN',
	['>>'] = 'OUT',
	['+='] = 'ADD',
	['-='] = 'SUB',
	['*='] = 'MUL',
	['/='] = 'DIV',
	['++'] = 'INC',
	['--'] = 'DEC',
	['+'] = '__add',
	['-'] = '__sub',
	['*'] = '__mul',
	['/'] = '__div',
}

function fix_operators(index)
	for f in pairs(index) do
		if f.label == "Function" then
			if f.xarg.name:match("^operator") and f.xarg.friend and #f.arguments == 2 then
				if f[1].xarg.type_base == f.xarg.member_of then
					-- friend operator for class defined outside of class - has 2 arguments,
					-- although in reality only the second one is used; the first is 'this',
					-- so we need to remove it
					table.remove(f, 1)
					table.remove(f.arguments, 1)
				end
			end
		end
	end
end

function get_operator(name)
	return name:match('^operator(.+)$')
end

function is_operator(name)
	return name:match('^operator.') and operatorTrans[get_operator(name)]
end

function rename_operator(name)
	local trans = operatorTrans[get_operator(name)]
	if is_operator(name) and trans then
		return trans
	end
	return name
end
