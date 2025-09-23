-- Utility functions for scrub
-- String and value conversion utilities

local function remove_trailing_zeros(str)
	local s = str:find("%.0+$")
	if s then return str:sub(1,s-1) end
	return str
end

---@param str string
---@return any
local function string_to_value(str)
	assert(type(str) == "string","Expected string, got "..type(str))

	local whitespaceless = str:gsub("%s+","")
	local value

	local number = tonumber(whitespaceless)
	if number then return number end
	if whitespaceless == "nil" or value == "" then return nil end
	if whitespaceless == "true" then return true end
	if whitespaceless == "false" then return false end

	do
		local delimiter_contents = whitespaceless:match("^%((.+)%)$")
		if not delimiter_contents then goto skip_vector end

		local components = {}
		local i = 1
		local sep = false
		while i <= #delimiter_contents do
			local s,e
			if sep then
				s,e = delimiter_contents:find(",",i)
			else
				s,e = delimiter_contents:find("[+-]?%d+%.%d+",i)
				if not s or s ~= i then
					s,e = delimiter_contents:find("[+-]?%d+",i)
				end

				local num = tonumber(delimiter_contents:sub(s,e))
				if not num then goto skip_vector end
				add(components,num)
			end
			if not s or s ~= i then goto skip_vector end
			i = e+1
			sep = not sep
		end
		
		return vec(unpack(components))
	end
	::skip_vector::

	return str
end

--- @param value any
--- @return string
local function value_to_string(value)
	local value_type = type(value)

	if value_type ~= "userdata" then
		return tostr(value)
	end

	local str = "("
	for i = 0,#value-1 do
		str = str..remove_trailing_zeros(tostr(value[i]))
		if i < #value-1 then str = str.."," end
	end
	str = str..")"
	return str
end

local function iterate_selection(timeline_selection)
	local sel_first,sel_last = timeline_selection.first,timeline_selection.last
	if sel_first > sel_last then
		sel_first,sel_last = sel_last,sel_first
	end

	local i = sel_first
	return function()
		if i > sel_last then return nil end
		local frame = i
		i = i + 1
		return frame
	end
end

---@param basis string
---@param fetch fun(str:string):any
local function next_name(basis,fetch)
	local i = 1
	local name = basis.."_1"
	while fetch(name) do
		i = i + 1
		name = basis.."_"..i
	end
	return name
end

return {
	remove_trailing_zeros = remove_trailing_zeros,
	string_to_value = string_to_value,
	value_to_string = value_to_string,
	iterate_selection = iterate_selection,
	next_name = next_name,
}