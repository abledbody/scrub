--[[pod_format="raw",created="2025-04-08 23:03:23",modified="2025-04-08 23:03:23",revision=0]]
include"src/require.lua"

------------------------------------Constants-------------------------------------
DT = 1 / 60

-----------------------------------Dependencies-----------------------------------
local Animation = require"src/animation"
local Gui = require"src/gui"
local Editor = require"src/editor/editor"
local Graphics = require"src/graphics"
local StringUtils = require"src/string_utils"

-----------------------------------Editor state-----------------------------------
ScreenSize = nil ---@type userdata
Lightest = 7
Darkest = 0

local state

---@return AppState
local function new_app_state(editor_state)
	-- gui_data = Gui.initialize(
	-- 	editor_state
	-- )
	
	-- editor_state.on_animations_changed = gui_data.on_animations_changed
	-- editor_state.on_frames_changed = function(self)
	-- 	self:set_timeline_selection(self.timeline_selection.first, self.timeline_selection.last)
	-- 	gui_data.on_frames_changed()
	-- end
	-- editor_state.on_frame_change = gui_data.on_frame_change
	-- editor_state.on_properties_changed = gui_data.on_properties_changed
	-- editor_state.on_selection_changed = gui_data.on_selection_changed
	-- editor_state.on_events_changed = gui_data.on_events_changed
	
	---@class AppState
	local state = {
		editor_state = editor_state,
		-- gui_data = gui_data,
	}
	return state
end

local animator ---@type Animator
local animations ---@type table<string,Animation>
local current_anim_key ---@type string
local gui_data
local gfx_cache ---@type table<number, [{bmp:userdata}]>
local palette ---@type userdata
local playing ---@type boolean
local timeline_selection ---@type {first:integer, last:integer}
local lock_selection_to_frame ---@type boolean

local on_animations_changed ---@type function
local on_frames_changed ---@type function
local on_frame_change ---@type function
local on_properties_changed ---@type function
local on_selection_changed ---@type function
local on_events_changed ---@type function

---@return table<string, Animation>
local function save_working_file()
	return animations
end

---@param item_1 table<string, Animation>?
local function load_working_file(item_1)
	if item_1 and type(item_1) ~= "table" then
		notify("Failed to load working file.")
		item_1 = nil
	end
	animations = item_1 or {animation_1 = {sprite = {0}, duration = {0.1}}}
end

local function iterate_selection()
	local sel_first, sel_last = timeline_selection.first, timeline_selection.last
	if sel_first > sel_last then
		sel_first, sel_last = sel_last, sel_first
	end
	
	local i = sel_first
	return function()
		if i > sel_last then return nil end
		local frame = i
		i += 1
		return frame
	end
end

local function initialize_events()
	local animation = animations[current_anim_key]
	if animation.events then return end
	
	local events = {}
	for i = 1, #animation.duration do
		events[i] = {}
	end
	animation.events = events
end

local function clean_events()
	local animation = animations[current_anim_key]
	local events = animation.events
	if not events then return end
	
	local event_found = false
	for i = 1, #animation.duration do
		if events[i] and next(events[i]) then
			event_found = true
			break
		end
	end
	
	if event_found then
		for i = 1, #animation.duration do
			if not events[i] then
				events[i] = {}
			end
		end
	else
		animation.events = nil
	end
end

------------------------------------Accessors-------------------------------------

local function set_timeline_selection(first, last)
	local length = #animations[current_anim_key].duration
	first = mid(1, first, length)
	last = mid(1, last, length)
	
	if first == timeline_selection.first
		and last == timeline_selection.last
	then
		return
	end
	
	timeline_selection = {first = first, last = last}
	on_selection_changed()
end

local function set_frame(frame_i)
	animator:reset(mid(1, frame_i, #animations[current_anim_key].duration))
	on_frame_change()
end

local function select_frame(frame_i)
	if not playing then
		set_frame(frame_i)
	end
	
	if key("shift") then
		local sel_first = timeline_selection.first
		set_timeline_selection(sel_first, frame_i)
	else
		set_timeline_selection(frame_i, frame_i)
	end
	lock_selection_to_frame = false
end

local function insert_frame()
	if playing then return end
	local animation = animations[current_anim_key]
	
	local sel_last = timeline_selection.last
	
	for k, v in pairs(animation) do
		if k == "events" then
			add(v, {}, sel_last + 1)
		else
			add(v, v[sel_last], sel_last + 1)
		end
	end
	
	select_frame(sel_last + 1)
	on_frames_changed()
end

local function remove_frame()
	if playing then return end
	local animation = animations[current_anim_key]
	
	local sel_first, sel_last = timeline_selection.first, timeline_selection.last
	if sel_first > sel_last then
		sel_first, sel_last = sel_last, sel_first
	end
	
	for _, v in pairs(animation) do
		for i = sel_last, sel_first, -1 do
			if #v == 1 then break end
			deli(v, i)
		end
	end
	
	clean_events()
	playing = false
	
	select_frame(sel_first)
	--Have to trigger this manually, because technically the selection is still
	--pointing to the same indices.
	on_selection_changed()
	
	on_frames_changed()
end

---Sets the current animation to the one with the given key.
---@param key string The key of the animation to switch to.
local function set_animation(key)
	animator.anim = animations[key]
	current_anim_key = key
	set_timeline_selection(1, 1)
	on_selection_changed()
	set_frame(1)
	on_frames_changed()
end

---Renames the current animation to the given name.
---@param name string The new name for the current animation.
local function rename_animation(name)
	if animations[name] then return end
	animations[name], animations[current_anim_key] = animations[current_anim_key], nil
	current_anim_key = name
	
	on_animations_changed()
end

---Creates a new animation with a unique name and sets it as the current animation.
---@return string anim_name The name of the newly created animation.
local function create_animation()
	local anim_name = StringUtils.next_name("new", function(key) return animations[key] end)
	
	animations[anim_name] = {sprite = {0}, duration = {0.1}}
	set_animation(anim_name)
	
	on_animations_changed()
	return anim_name
end

---Removes the animation with the given key.
---@param key string The key of the animation to remove.
local function remove_animation(key)
	if not animations[key] then return end
	
	if key == current_anim_key then
		local next_key = next(animations, key) or next(animations)
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
	for k, v in pairs(animations[current_anim_key]) do
		if k ~= "events" then
			add(properties, {key = k, value = StringUtils.value_to_string(v[source_frame])})
		end
	end
	return properties
end

local function rename_property(key, new_key)
	local animation = animations[current_anim_key]
	if not animation[key] or key == "events" then return end
	if key == "duration" then
		notify("You cannot rename the duration property.")
		return
	end
	if new_key == "events" then
		notify("'events' is a reserved property name.")
		return
	end
	if animation[new_key] then
		notify("The " .. new_key .. " property already exists.")
		return
	end
	
	animation[new_key] = animation[key]
	animation[key] = nil
	
	on_properties_changed()
end

---@param key string
---@param str string
local function set_property_by_string(key, str)
	local value = StringUtils.string_to_value(str)
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
	
	local key = StringUtils.next_name("new", function(key) return animation[key] end)
	
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
	
	for k, v in pairs(frame_events) do
		add(event_strings, {key = k, value = StringUtils.value_to_string(v)})
	end
	return event_strings
end

local function create_event()
	local animation = animations[current_anim_key]
	if not animation.events then initialize_events() end
	local events = animation.events
	
	local key = StringUtils.next_name("new", function(key)
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

---@param key string
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

---@param key string
---@param new_key string
local function rename_event(key, new_key)
	local events = animations[current_anim_key].events
	if not events then return end
	
	--Double loop to prevent mutation if the rename fails.
	for i in iterate_selection() do
		local frame_events = events[i]
		if frame_events and frame_events[key] and frame_events[new_key] then
			notify("The " .. new_key .. " event already exists somewhere in the selection.")
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

---@param key string
---@param str string
local function set_event_by_string(key, str)
	local events = animations[current_anim_key].events
	if not events then return end
	
	local value = StringUtils.string_to_value(str)
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

local function previous_frame()
	set_playing(false)
	local duration_count = #animations[current_anim_key].duration
	select_frame((animator.frame_i - 2) % duration_count + 1)
end

local function next_frame()
	set_playing(false)
	local duration_count = #animations[current_anim_key].duration
	select_frame((animator.frame_i % duration_count) + 1)
end

local function first_frame()
	set_playing(false)
	select_frame(1)
end

local function last_frame()
	set_playing(false)
	local duration_count = #animations[current_anim_key].duration
	select_frame(duration_count)
end

---Fetches a sprite bitmap from the loaded cartridge by its index.
---@param anim_spr integer The index of the sprite to fetch.
---@return userdata? sprite_data The sprite bitmap data.
local function get_sprite(anim_spr)
	if type(anim_spr) ~= "number" then return nil end
	
	local gfx_file_index = anim_spr // 256
	local gfx_spr_index = anim_spr % 256
	
	local gfx_file = Graphics.get_indexed_gfx(gfx_cache, gfx_file_index)
	local sprite = gfx_file and gfx_file[gfx_spr_index]
	return sprite and sprite.bmp
end

--------------------------------Picotron callbacks--------------------------------
function _init()
	window{
		tabbed = true,
		icon = --[[pod_type="gfx"]] unpod("b64:bHo0ACkAAAAsAAAA8AJweHUAQyAICASABwAHAAcgFwYAYQA3AAcARwoAARAAcCAHAAcAB4A=")
	}
	
	local sw, sh = get_display():attribs()
	ScreenSize = vec(sw, sh)
	
	mkdir("/ram/cart/anm")
	
	wrangle_working_file(
		save_working_file,
		load_working_file,
		"/ram/cart/anm/0.anm"
	)
	
	palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100, palette:get())
		Graphics.find_binary_cols(palette)
	end
	poke4(0x5000, fetch(DATP .. "pal/0.pal"):get())
	
	local editor_state = Editor.new_editor_state(animations, palette)
	state = new_app_state(editor_state)
	
	on_event("gained_focus", function()
		--There's a chance the gfx or pal files have been updated.
		gfx_cache = {}
		poke4(0x5000, fetch(DATP .. "pal/0.pal"):get())
	end)
	
	current_anim_key = next(animations) or "new_1"
	animator = Animation.new_animator(animations[current_anim_key])
	playing = false
	timeline_selection = {first = 1, last = 1}
	clean_events()
	
	gfx_cache = {}
	
	local accessors = {
		set_frame = set_frame,
		insert_frame = insert_frame,
		remove_frame = remove_frame,
		
		get_animation_key = function() return current_anim_key end,
		set_animation_key = rename_animation,
		get_animation_keys = function()
			local keys = {}
			for k in pairs(animations) do
				add(keys, k)
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
		
		previous_frame = previous_frame,
		next_frame = next_frame,
		first_frame = first_frame,
		last_frame = last_frame,
		
		get_sprite = get_sprite,
		
		animator = animator,
	}
	
	gui_data = Gui.initialize(
		accessors
	)
	
	on_animations_changed = gui_data.on_animations_changed
	on_frames_changed = function()
		set_timeline_selection(timeline_selection.first, timeline_selection.last)
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
		if keyp("left") then
			previous_frame()
		end
		if keyp("right") then
			next_frame()
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
		set_timeline_selection(animator.frame_i, animator.frame_i)
	end
end

function _draw()
	cls()
	gui_data.gui:draw_all()
end

include"src/error_explorer.lua"
