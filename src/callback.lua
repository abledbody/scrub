---@class Callback<T>
local m_callback = {}
m_callback.__index = m_callback

---@generic T
---@param self Callback<`T`>
---@param func fun(args: T)
function m_callback:sub(func)
	self[func] = true
end

---@generic T
---@param self Callback<`T`>
---@param func fun(args: T)
function m_callback:unsub(func)
	self[func] = nil
end

---@generic T
---@param self Callback<`T`>
---@param args T
function m_callback:__call(args)
	for func in pairs(self) do
		func(args)
	end
end

---@generic T
---@return Callback<T>
local function new()
	return setmetatable({}, m_callback)
end

return new