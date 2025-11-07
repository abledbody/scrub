local fmt = string.format

---Converts a parseable string into a value.
---@param str string
---@return boolean|string|userdata|number|nil
---@return boolean success
local function string_to_value(str)
	assert(type(str) == "string", "Expected string, got " .. type(str))
	
	local whitespaceless = str:gsub("%s+", "")
	
	local number = tonumber(whitespaceless)
	if number then return number, true end
	if whitespaceless == "nil" or str == "" then return nil, true end
	if whitespaceless == "true" then return true, true end
	if whitespaceless == "false" then return false, true end
	
	do
		local delimiter_contents = whitespaceless:match("^%((.+)%)$")
		if not delimiter_contents then goto skip_vector end
		
		local csv = split(delimiter_contents, ",")
		local components = {}
		for _,v in ipairs(csv) do
			local component = tonumber(v)
			if not component then goto skip_vector end
			table.insert(components, component)
		end
		
		return vec(unpack(components)), true
	end
	::skip_vector::
	
	local string_contents = str:match("^\".*\"$")
	if string_contents then
		return str:sub(2, -2), true
	end
	
	return nil, false
end

---Converts a value of a parseable type into a string.
---@param value boolean|string|userdata|number|nil
---@return string
local function value_to_string(value)
	local value_type = type(value)
	
	if value_type == "string" then
		return fmt("\"%s\"", value)
	elseif value_type == "userdata" then
		return fmt("(" .. string.rep("%.15g", #value, ",") .. ")", value:get())
	end
	
	return tostr(value)
end

---@param basis string
---@param fetch fun(str:string):any
local function next_name(basis, fetch)
	local i = 1
	local name = basis .. "_1"
	while fetch(name) do
		i += 1
		name = basis .. "_" .. i
	end
	return name
end

---@param str string
---@param d_mouse_x userdata
---@return integer
local function get_char_position(str, d_mouse_x)
	local dummy = userdata("u8", 1, 1)
	local prev_cam = {camera()}
	local prev_draw_target = set_draw_target(dummy)
	
	local result = -1
	local range = {1, #str + 1}
	while true do
		local sample = (range[1] + range[2]) // 2
		local x = print(str:sub(1, sample), 0, 0) or 0
		
		if d_mouse_x == x then
			-- x is on right side of character, sample is on left.
			result = sample + 1
			break
		end
		
		if range[1] == range[2] then
			local left_x = print(str:sub(1, range[1] - 1), 0, 0) or 0
			result = d_mouse_x <= (left_x + x) * 0.5 and range[1] or range[1] + 1
			break
		end
		
		if d_mouse_x < x then
			range[2] = sample
		else
			range[1] = sample + 1
		end
	end
	
	set_draw_target(prev_draw_target)
	camera(unpack(prev_cam))
	return result
end

return {
	string_to_value = string_to_value,
	value_to_string = value_to_string,
	next_name = next_name,
	get_char_position = get_char_position,
}