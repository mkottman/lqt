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
}

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
