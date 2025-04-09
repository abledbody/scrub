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
local gfx --- @type [{bmp:userdata}]
local palette --- @type userdata
local playing --- @type boolean
local timeline_selection --- @type {first:integer,last:integer}
local lock_selection_to_frame --- @type boolean

local on_animations_changed --- @type function
local on_frames_changed --- @type function
local on_frame_change --- @type function
local on_properties_changed --- @type function
local on_selection_changed --- @type function

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
	
	local first_byte_i = first_y\4
	local last_byte_i = ceil(last_y/4)
	local scanline_bytes = userdata("u8",last_byte_i-first_byte_i+1)

	for y = first_y,last_y do
		local i = y\4-first_byte_i
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
	local animation = animations[current_anim_key]

	local sel_last = timeline_selection.last

	for _,v in pairs(animation) do
		add(v,v[sel_last],sel_last+1)
	end

	select_frame(sel_last+1)
	on_frames_changed()
end

local function remove_frame()
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

	on_frames_changed()
	set_frame(sel_first)
end

--- Sets the current animation to the one with the given key.
--- @param key string The key of the animation to switch to.
local function set_animation(key)
	animator.anim = animations[key]
	current_anim_key = key
	set_timeline_selection(1,1)
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
	local animation_count = 1
	local anim_name = "new_1"
	while animations[anim_name] do
		animation_count += 1
		anim_name = "new_"..animation_count
	end

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

local function remove_trailing_zeros(str)
	local s = str:find("%.0+$")
	if s then return str:sub(1,s-1) end
	return str
end

local function get_property_strings()
	local properties = {}
	local source_frame = timeline_selection.first
	for k,v in pairs(animations[current_anim_key]) do
		if type(k) ~= "string" then goto continue end
		
		local value = v[source_frame]
		local value_type = type(value)
		if value_type == "userdata" then
			local str = "("
			for i = 0,#value-1 do
				str = str..remove_trailing_zeros(tostr(value[i]))
				if i < #value-1 then str = str.."," end
			end
			str = str..")"
			add(properties,{key = k,value = str})
		else
			add(properties,{key = k,value = tostr(value)})
		end


		::continue::
	end
	return properties
end

local function rename_property(key,new_key)
	local animation = animations[current_anim_key]
	if not animation[key]
		or key == "duration"
		or animation[new_key]
	then return end
	
	animation[new_key] = animation[key]
	animation[key] = nil

	on_properties_changed()
end

--- @param key any
--- @param value string
local function set_property_by_string(key,value)
	local animation = animations[current_anim_key]

	local number = tonumber(value)
	if number then
		if key == "duration" and number <= 0 then return end
		value = number --- @type any
		goto type_found
	end
	if key == "duration" then return end

	if value == "nil" then
		value = nil --- @type any
		goto type_found
	end

	do
		local delimiter_contents = value:gsub("%s+",""):match("^%((.+)%)$")
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

		value = vec(unpack(components)) --- @type any
		goto type_found
	end
	::skip_vector::
	
	::type_found::
	
	local sel_first,sel_last = timeline_selection.first,timeline_selection.last
	if sel_first > sel_last then
		sel_first,sel_last = sel_last,sel_first
	end
	for i = sel_first,sel_last do
		animation[key][i] = value
	end
	on_properties_changed()
end

local function create_property()
	local animation = animations[current_anim_key]

	local property_count = 1
	local key = "new_1"
	while animation[key] do
		key = "new_"..property_count
		property_count += 1
	end

	animation[key] = {}

	on_properties_changed()
	return key
end

local function remove_property(key)
	if key == "duration" then return end

	local animation = animations[current_anim_key]
	if not animation[key] then return end
	animation[key] = nil

	on_properties_changed()
end

local function set_playing(value)
	if value then lock_selection_to_frame = true end
	playing = value
end

--- Fetches a sprite bitmap off the 0.gfx file by index.
--- @param anim_spr integer The index of the sprite to fetch.
--- @return userdata sprite_data The sprite bitmap data.
local function get_sprite(anim_spr)
	local sprite = gfx[anim_spr]
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

	palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100,palette:get())
		find_binary_cols()
	end
	poke4(0x5000,fetch(DATP.."pal/0.pal"):get())

	gfx = fetch("/ram/cart/gfx/0.gfx")
	
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