-- Property management for scrub
local Utils = require"src/utils"

local function create_property_manager(state)
	local animations = state.animations
	local current_anim_key = state.current_anim_key
	local timeline_selection = state.timeline_selection
	local on_properties_changed = state.on_properties_changed

	local function get_property_strings()
		local properties = {}
		local source_frame = timeline_selection.first
		for k,v in pairs(animations[current_anim_key]) do
			if k ~= "events" then
				add(properties,{key = k,value = Utils.value_to_string(v[source_frame])})
			end
		end
		return properties
	end

	local function rename_property(key,new_key)
		local animation = animations[current_anim_key]
		if not animation[key] or key == "events" then return end
		if key == "duration" then notify("You cannot rename the duration property.") return end
		if new_key == "events" then notify("'events' is a reserved property name.") return end
		if animation[new_key] then notify("The "..new_key.." property already exists.") return end
		
		animation[new_key] = animation[key]
		animation[key] = nil

		on_properties_changed()
	end

	local function set_property_by_string(key,str)
		local value = Utils.string_to_value(str)
		if key == "duration" and (type(value) ~= "number" or value <= 0) then
			notify("Duration must be a positive number.")
			return
		end

		local animation = animations[current_anim_key]
		for i in Utils.iterate_selection(timeline_selection) do
			animation[key][i] = value
		end

		on_properties_changed()
	end

	local function create_property()
		local animation = animations[current_anim_key]
		local key = Utils.next_name("new",function(key) return animation[key] end)

		animation[key] = {}
		for i = 1,#animation.duration do
			animation[key][i] = ""
		end

		on_properties_changed()
		return key
	end

	local function remove_property(key)
		if key == "duration" or key == "events" then return end

		local animation = animations[current_anim_key]
		if not animation[key] then return end
		animation[key] = nil

		on_properties_changed()
	end

	return {
		get_property_strings = get_property_strings,
		rename_property = rename_property,
		set_property_by_string = set_property_by_string,
		create_property = create_property,
		remove_property = remove_property,
	}
end

return {
	create_property_manager = create_property_manager,
}