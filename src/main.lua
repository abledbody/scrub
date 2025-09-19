--[[pod_format="raw",created="2025-04-08 23:03:23",modified="2025-04-08 23:03:23",revision=0]]
include"src/require.lua"

-- Constants
DT = 1/60

-- Dependencies
local Animation = require"src/animation"
local Gui = require"src/gui"

-- Editor state
ScreenSize = nil --- @type userdata
Lightest = 7
Darkest = 0

local animator --- @type Animator
local animations --- @type table<string,Animation>
local current_anim_key --- @type string
local gui_data
local gfx_cache --- @type table<number, [{bmp:userdata}]>
local palette --- @type userdata
local playing --- @type boolean
local timeline_selection --- @type {first:integer,last:integer}
local lock_selection_to_frame --- @type boolean

local on_animations_changed --- @type function
local on_frames_changed --- @type function
local on_frame_change --- @type function
local on_properties_changed --- @type function
local on_selection_changed --- @type function
local on_events_changed --- @type function

--- @return Animation
local function save_working_file()
	return animations
end

--- @param item_1 table<string,Animation>?
local function load_working_file(item_1)
	if item_1 and type(item_1) ~= "table" then
		notify("Failed to load working file.")
		item_1 = nil
	end
	animations = item_1 or {animation_1 = {sprite = {0}, duration = {0.1}}}
end

--- Sets the palette for the given range of scanlines.
--- @param palette_i 0|1|2|3 The palette index to set.
--- @param first_y integer The first scanline to set the palette for.
--- @param last_y integer The last scanline to set the palette for.
function set_scanline_palette(palette_i,first_y,last_y)
	assert(palette_i >= 0 and palette_i < 4,"Palette index must be between 0 and 3.")
	if first_y > last_y then
		first_y,last_y = last_y,first_y
	end
	first_y = mid(0,first_y,269)
	last_y = mid(0,last_y,269)
	
	local first_byte_i = first_y//4
	local last_byte_i = ceil(last_y/4)
	local scanline_bytes = userdata("u8",last_byte_i-first_byte_i+1)

	for y = first_y,last_y do
		local i = y//4-first_byte_i
		local j = y%4*2
		assert(scanline_bytes[i])
		scanline_bytes[i] = (scanline_bytes[i]&(~(3<<j)))|(palette_i<<j)
	end

	poke(0x5400+first_byte_i,scanline_bytes:get())
end

local function find_binary_cols()
	local lightest_mag = 0
	local darkest_mag = 1000
	for i = 0,63 do
		local colnum = palette:get(i)
		local col = vec(colnum&0xFF,(colnum>>8)&0xFF,(colnum>>16)&0xFF)
		local mag = col:magnitude()
		if mag > lightest_mag then
			Lightest = i
			lightest_mag = mag
		elseif mag < darkest_mag then
			Darkest = i
			darkest_mag = mag
		end
	end
end

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

local function iterate_selection()
	local sel_first,sel_last = timeline_selection.first,timeline_selection.last
	if sel_first > sel_last then
		sel_first,sel_last = sel_last,sel_first
	end

	local i = sel_first
	return function()
		if i > sel_last then return nil end
		local frame = i
		i += 1
		return frame
	end
end

---@param basis string
---@param fetch fun(str:string):any
local function next_name(basis,fetch)
	local i = 1
	local name = basis.."_1"
	while fetch(name) do
		i += 1
		name = basis.."_"..i
	end
	return name
end

local function initialize_events()
	local animation = animations[current_anim_key]
	if animation.events then return end

	local events = {}
	for i = 1,#animation.duration do
		events[i] = {}
	end
	animation.events = events
end

local function clean_events()
	local animation = animations[current_anim_key]
	local events = animation.events
	if not events then return end

	local event_found = false
	for i = 1,#animation.duration do
		if events[i] and next(events[i]) then event_found = true break end
	end

	if event_found then
		for i = 1,#animation.duration do
			if not events[i] then
				events[i] = {}
			end
		end
	else
		animation.events = nil
	end
end

-- Accessors

local function set_timeline_selection(first,last)
	local length = #animations[current_anim_key].duration
	first = mid(1,first,length)
	last = mid(1,last,length)

	if first == timeline_selection.first
		and last == timeline_selection.last
	then return end

	timeline_selection = {first = first,last = last}
	on_selection_changed()
end

local function set_frame(frame_i)
	animator:reset(mid(1,frame_i,#animations[current_anim_key].duration))
	on_frame_change()
end

local function select_frame(frame_i)
	if not playing then
		set_frame(frame_i)
	end
	
	if key("shift") then
		local sel_first = timeline_selection.first
		set_timeline_selection(sel_first,frame_i)
	else
		set_timeline_selection(frame_i,frame_i)
	end
	lock_selection_to_frame = false
end

local function insert_frame()
	if playing then return end
	local animation = animations[current_anim_key]

	local sel_last = timeline_selection.last

	for k,v in pairs(animation) do
		if k == "events" then
			add(v,{},sel_last+1)
		else
			add(v,v[sel_last],sel_last+1)
		end
	end

	select_frame(sel_last+1)
	on_frames_changed()
end

local function remove_frame()
	if playing then return end
	local animation = animations[current_anim_key]
	
	local sel_first,sel_last = timeline_selection.first,timeline_selection.last
	if sel_first > sel_last then
		sel_first,sel_last = sel_last,sel_first
	end

	for _,v in pairs(animation) do
		for i = sel_last,sel_first,-1 do
			if #v == 1 then break end
			deli(v,i)
		end
	end

	clean_events()
	playing = false

	select_frame(sel_first)
	-- Have to trigger this manually, because technically the selection is still
	-- pointing to the same indices.
	on_selection_changed()

	on_frames_changed()
end

--- Sets the current animation to the one with the given key.
--- @param key string The key of the animation to switch to.
local function set_animation(key)
	animator.anim = animations[key]
	current_anim_key = key
	set_timeline_selection(1,1)
	on_selection_changed()
	set_frame(1)
	on_frames_changed()
end

--- Renames the current animation to the given name.
--- @param name string The new name for the current animation.
local function rename_animation(name)
	if animations[name] then return end
	animations[name],animations[current_anim_key] = animations[current_anim_key],nil
	current_anim_key = name

	on_animations_changed()
end

--- Creates a new animation with a unique name and sets it as the current animation.
--- @return string anim_name The name of the newly created animation.
local function create_animation()
	local anim_name = next_name("new",function(key) return animations[key] end)

	animations[anim_name] = {sprite = {0}, duration = {0.1}}
	set_animation(anim_name)

	on_animations_changed()
	return anim_name
end

--- Removes the animation with the given key.
--- @param key string The key of the animation to remove.
local function remove_animation(key)
	if not animations[key] then return end

	if key == current_anim_key then
		local next_key = next(animations,key) or next(animations)
		animations[key] = nil
		if next_key and next_key ~= current_anim_key then
			set_animation(next_key)
		else
			set_animation(create_animation())
		end
	else
		animations[key] = nil
	end

	on_animations_changed()
end

local function get_property_strings()
	local properties = {}
	local source_frame = timeline_selection.first
	for k,v in pairs(animations[current_anim_key]) do
		if k ~= "events" then
			add(properties,{key = k,value = value_to_string(v[source_frame])})
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

--- @param key string
--- @param str string
local function set_property_by_string(key,str)
	local value = string_to_value(str)
	if key == "duration" and (type(value) ~= "number" or value <= 0) then
		notify("Duration must be a positive number.")
		return
	end

	local animation = animations[current_anim_key]
	for i in iterate_selection() do
		animation[key][i] = value
	end

	on_properties_changed()
end

local function create_property()
	local animation = animations[current_anim_key]

	local key = next_name("new",function(key) return animation[key] end)

	animation[key] = {}

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

local function get_event_strings()
	local events = animations[current_anim_key].events
	if not events then return {} end

	local event_strings = {}
	local frame_events = events[timeline_selection.first]
	if not frame_events then return {} end

	for k,v in pairs(frame_events) do
		add(event_strings,{key = k,value = value_to_string(v)})
	end
	return event_strings
end

local function create_event()
	local animation = animations[current_anim_key]
	if not animation.events then initialize_events() end
	local events = animation.events

	local key = next_name("new",function(key)
		for i in iterate_selection() do
			local frame_events = events[i]
			if frame_events and frame_events[key] then return true end
		end
	end)

	for i in iterate_selection() do
		if not events[i] then events[i] = {} end
		local frame_events = events[i]
		frame_events[key] = true
	end

	on_events_changed()
	return key
end

--- @param key string
local function remove_event(key)
	local events = animations[current_anim_key].events
	if not events then return end

	for i in iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[key] = nil
		end
	end

	clean_events()

	on_events_changed()
end

--- @param key string
--- @param new_key string
local function rename_event(key,new_key)
	local events = animations[current_anim_key].events
	if not events then return end

	-- Double loop to prevent mutation if the rename fails.
	for i in iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] and frame_events[new_key] then
			notify("The "..new_key.." event already exists somewhere in the selection.")
			return
		end
	end

	for i in iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[new_key] = frame_events[key]
			frame_events[key] = nil
		end
	end

	on_events_changed()
end

--- @param key string
--- @param str string
local function set_event_by_string(key,str)
	local events = animations[current_anim_key].events
	if not events then return end

	local value = string_to_value(str)
	if value == nil then return end

	for i in iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] then
			frame_events[key] = value
		end
	end

	on_events_changed()
end

local function set_playing(value)
	if value then lock_selection_to_frame = true end
	playing = value
end

--- Loads a gfx file into the cache if not already loaded.
--- @param gfx_file_index number The gfx file index (0 for 0.gfx, 1 for 1.gfx, etc.)
--- @return [{bmp:userdata}]? gfx_data The loaded gfx data or nil if failed.
local function load_gfx_file(gfx_file_index)
	if gfx_cache[gfx_file_index] then
		return gfx_cache[gfx_file_index]
	end
	
	local gfx_data = fetch("/ram/cart/gfx/" .. gfx_file_index .. ".gfx")
	if gfx_data then
		gfx_cache[gfx_file_index] = gfx_data
	end
	return gfx_data
end

--- Fetches a sprite bitmap by index, automatically loading the correct .gfx file.
--- Sprites 0-255 are in 0.gfx, 256-511 are in 1.gfx, etc.
--- @param anim_spr integer The sprite index to fetch.
--- @return userdata? sprite_data The sprite bitmap data.
local function get_sprite(anim_spr)
	if type(anim_spr) ~= "number" then return nil end
	
	-- Calculate which .gfx file and local index within that file
	local gfx_file_index = anim_spr // 256
	local local_sprite_index = anim_spr % 256
	
	local gfx_data = load_gfx_file(gfx_file_index)
	if not gfx_data then return nil end
	
	local sprite = gfx_data[local_sprite_index]
	return sprite and sprite.bmp
end

-- Picotron hooks
function _init()
	window{
		tabbed = true,
		icon = --[[pod_type="gfx"]]unpod("b64:bHo0ACkAAAAsAAAA8AJweHUAQyAICASABwAHAAcgFwYAYQA3AAcARwoAARAAcCAHAAcAB4A=")
	}

	local sw,sh = get_display():attribs()
	ScreenSize = vec(sw,sh)

	mkdir("/ram/cart/anm")

	wrangle_working_file(
		save_working_file,
		load_working_file,
		"/ram/cart/anm/0.anm"
	)

	current_anim_key = next(animations) or "new_1"
	animator = Animation.new_animator(animations[current_anim_key])
	playing = false
	timeline_selection = {first = 1,last = 1}
	clean_events()

	palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100,palette:get())
		find_binary_cols()
	end
	poke4(0x5000,fetch(DATP.."pal/0.pal"):get())

	gfx_cache = {}
	
	-- Load the default 0.gfx file
	load_gfx_file(0)
	
	local accessors = {
		set_frame = set_frame,
		insert_frame = insert_frame,
		remove_frame = remove_frame,

		get_animation_key = function() return current_anim_key end,
		set_animation_key = rename_animation,
		get_animation_keys = function()
			local keys = {}
			for k in pairs(animations) do
				add(keys,k)
			end
			return keys
		end,
		
		set_animation = set_animation,
		get_animation = function() return animations[current_anim_key] end,
		create_animation = create_animation,
		remove_animation = remove_animation,

		get_property_strings = get_property_strings,
		rename_property = rename_property,
		set_property_by_string = set_property_by_string,
		create_property = create_property,
		remove_property = remove_property,

		get_event_strings = get_event_strings,
		rename_event = rename_event,
		set_event_by_string = set_event_by_string,
		create_event = create_event,
		remove_event = remove_event,

		get_playing = function() return playing end,
		set_playing = set_playing,
		get_timeline_selection = function() return timeline_selection end,
		set_timeline_selection = set_timeline_selection,
		select_frame = select_frame,

		get_sprite = get_sprite,

		animator = animator,
	}

	gui_data = Gui.initialize(
		accessors
	)

	on_animations_changed = gui_data.on_animations_changed
	on_frames_changed = function()
		set_timeline_selection(timeline_selection.first,timeline_selection.last)
		gui_data.on_frames_changed()
	end
	on_frame_change = gui_data.on_frame_change
	on_properties_changed = gui_data.on_properties_changed
	on_selection_changed = gui_data.on_selection_changed
	on_events_changed = gui_data.on_events_changed
end

function _update()
	gui_data.gui:update_all()
	if playing then
		local last_frame = animator.frame_i
		animator:advance(DT)
		if animator.frame_i ~= last_frame then
			on_frame_change()
		end
	end

	if not gui_data.gui:get_keyboard_focus_element() then
		local duration_count = #animations[current_anim_key].duration
		if keyp("left") then
			set_playing(false)
			select_frame((animator.frame_i-2)%duration_count+1)
		end
		if keyp("right") then
			set_playing(false)
			select_frame((animator.frame_i%duration_count)+1)
		end
		if keyp("space") then
			set_playing(not playing)
		end
		if keyp("insert") then
			insert_frame()
		end
		if keyp("delete") then
			remove_frame()
		end
	end
	
	if lock_selection_to_frame then
		set_timeline_selection(animator.frame_i,animator.frame_i)
	end
end

function _draw()
	cls()
	gui_data.gui:draw_all()
end

include"src/error_explorer.lua"