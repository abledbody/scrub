-- File operations for scrub
-- Handles working file save/load operations

--- @return Animation
local function save_working_file(animations)
	return animations
end

--- @param item_1 table<string,Animation>?
local function load_working_file(item_1)
	if item_1 and type(item_1) ~= "table" then
		notify("Failed to load working file.")
		item_1 = nil
	end
	return item_1 or {animation_1 = {sprite = {0}, duration = {0.1}}}
end

return {
	save_working_file = save_working_file,
	load_working_file = load_working_file,
}