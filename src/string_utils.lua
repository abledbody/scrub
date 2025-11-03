---Converts a parseable string into a value.
---@param str string
---@return boolean|string|userdata|number|nil
local function string_to_value(str)
	assert(type(str) == "string", "Expected string, got " .. type(str))
	
	local whitespaceless = str:gsub("%s+", "")
	local value
	
	local number = tonumber(whitespaceless)
	if number then return number end
	if whitespaceless == "nil" or value == "" then return nil end
	if whitespaceless == "true" then return true end
	if whitespaceless == "false" then return false end
	
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
		
		return vec(unpack(components))
	end
	::skip_vector::
	
	return str
end

---Converts a value of a parseable type into a string.
---@param value boolean|string|userdata|number|nil
---@return string
local function value_to_string(value)
	local value_type = type(value)
	
	if value_type ~= "userdata" then
		return tostr(value)
	end
	
	return string.format("(" .. string.rep("%.15g", #value, ",") .. ")", value:get())
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

return {
	string_to_value = string_to_value,
	value_to_string = value_to_string,
	next_name = next_name,
}