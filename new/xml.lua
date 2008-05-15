#!/usr/bin/lua

local parseargs, collect, strip_escapes

strip_escapes = function (s)
	s = string.gsub(s, '&gt;', '>')
	s = string.gsub(s, '&lt;', '<')
	return s
end


function parseargs(s)
	local arg = {}
	string.gsub(s, "([%w_]+)=([\"'])(.-)%2", function (w, _, a)
		arg[strip_escapes(w)] = strip_escapes(a)
	end)
	return arg
end

function collect(s)
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
		if empty == "/" then  -- empty element tag
			table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
		elseif c == "" then   -- start tag
			top = {label=label, xarg=parseargs(xarg)}
			table.insert(stack, top)   -- new level
		else  -- end tag
		local toclose = table.remove(stack)  -- remove top
		top = stack[#stack]
		if #stack < 1 then
			error("nothing to close with "..label)
		end
		if toclose.label ~= label then
			error("trying to close "..toclose.label.." with "..label)
		end
		table.insert(top, toclose)
		toclose.parent = top
		if toclose.xarg.name then
			--[[
			local print = toclose.xarg.id=='_4334' and function(...)
				io.stderr:write(...)
				io.stderr:write'\n'
			end or function()end
			--]]
			top.byname = top.byname or {}
			local overload = top.byname[toclose.xarg.name]
			if overload then
				-- FIXME: most probably a case of overload: check
				if overload.label~='Overloaded' then
					--print('created overload '..toclose.xarg.name)
					top.byname[toclose.xarg.name] = {
						label='Overloaded',
						xarg={ name=toclose.xarg.name },
						overload
					}
				end
				table.insert(top.byname[toclose.xarg.name], toclose)
				--print('used overload '..toclose.xarg.name)
			else
				top.byname[toclose.xarg.name] = toclose
				--print('not overloaded')
			end
		end
		if toclose.xarg.id then
			stack[1].byid = stack[1].byid or {}
			stack[1].byid[toclose.xarg.id] = toclose
		end
	end
	i = j+1
end
local text = string.sub(s, i)
if not string.find(text, "^%s*$") then
	table.insert(stack[#stack], text)
end
if #stack > 1 then
	error("unclosed "..stack[stack.n].label)
end
return stack[1]
end

return collect
