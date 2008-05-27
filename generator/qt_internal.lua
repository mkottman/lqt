
local classes, enums = ...
local ret1, ret2 = {}, {}

for c in pairs(classes) do
	local n = c.xarg.name
	if n~=string.lower(n) and not string.match(n, '_') then
		ret1[c] = true
	end
end

for e in pairs(enums) do
	local n = e.xarg.name
	if n~=string.lower(n) and not string.match(n, '_') then
		ret2[e] = true
	end
end

return ret1, ret2

