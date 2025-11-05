local fmt = string.format

---@class IndexMap
---@field indices table<string, integer>
---@field keys [string]
local m_index_map = {}
m_index_map.__index = m_index_map

---@param self IndexMap
---@param key string
function m_index_map:remove(key)
	local last_index = #self.keys
	
	local index = self.indices[key]
	if not index then return false end
	
	self.indices[key] = nil
	
	for i = index, last_index - 1 do
		local key_to_move = self.keys[i + 1]
		self.keys[i] = key_to_move
		self.indices[key_to_move] = i
	end
	
	self.keys[last_index] = nil
	
	return true
end

---@param self IndexMap
---@param key string
---@param index integer?
function m_index_map:insert(key, index)
	if self.indices[key] then error(fmt("Attempted to insert duplicate key '%s'", key)) end
	
	local last_index = #self.keys
	
	if index then
		if index < 1 or index > last_index + 1 then
			error(fmt("Attempted to insert key '%s' to index %i, which is not in the range [1,%i]", key, index, last_index + 1))
		end
		
		for i = index, last_index do
			self.indices[self.keys[i]] += 1
		end
	end
	
	add(self.keys, key, index)
	self.indices[key] = index or #self.keys
end

---@param self IndexMap
---@param old_key string
---@param new_key string
function m_index_map:replace_key(old_key, new_key)
	if self.indices[new_key] then error(fmt("Attempted to replace existing key '%s' with '%s'", old_key, new_key)) end
	
	local index = self.indices[old_key]
	
	self.keys[index] = new_key
	self.indices[old_key] = nil
	self.indices[new_key] = index
	
	return true
end

---@param keys [string]?
local function new_index_map(keys)
	local index_map = {
		indices = {},
		keys = keys or {},
	}
	
	for i, v in ipairs(index_map.keys) do
		index_map.indices[v] = i
	end
	
	return setmetatable(index_map, m_index_map)
end

return new_index_map