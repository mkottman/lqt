#!/usr/bin/lua

local xml_parser = {

strip_escapes = function (self, s)
	s = string.gsub(s, '&gt;', '>')
	s = string.gsub(s, '&lt;', '<')
	return s
end,

parseargs = function (self, s)
	local arg = {}
	string.gsub(s, "([%w_]+)=([\"'])(.-)%2", function (w, _, a)
		arg[self:strip_escapes(w)] = self:strip_escapes(a)
	end)
	return arg
end,

collect = function (self, s)
	local stack = {}
	local top = {}
	table.insert(stack, top)
	local ni,c,label,xarg, empty
	local i, j = 1, 1
	while true do
		ni,j,c,label,xarg, empty = string.find(s, "<(%/?)(%w+)(.-)(%/?)>", j)
		if not ni then break end
		local text = string.sub(s, i, ni-1)
		if not string.find(text, "^%s*$") then
			table.insert(top, text)
		end
		local inserted = nil
		if empty == "/" then  -- empty element tag
			inserted = {tag=label, attr=self:parseargs(xarg), empty=1}
			table.insert(top, inserted)
		elseif c == "" then   -- start tag
			top = {tag=label, attr=self:parseargs(xarg)}
			inserted = top
			table.insert(stack, top)   -- new level
		else  -- end tag
	    local toclose = table.remove(stack)  -- remove top
			top = stack[#stack]
			if #stack < 1 then
				error("nothing to close with "..label)
			end
			if toclose.tag ~= label then
				error("trying to close "..toclose.label.." with "..label)
			end
			table.insert(top, toclose)
		end
		if inserted then
			for a, v in pairs(inserted.attr) do
				if type(self[a])=='table' then
					self[a][v] = inserted
				end
			end
		end
		i = j+1
	end
	local text = string.sub(s, i)
	if not string.find(text, "^%s*$") then
		table.insert(stack[stack.n], text)
	end
	if #stack > 1 then
		error("unclosed "..stack[stack.n].label)
	end
	return stack[1]
end,
}

return xml_parser
