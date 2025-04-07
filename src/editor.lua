include"src/require.lua"

-- Constants
DT = 1/60

-- Dependencies
local Animation = require"src/animation"
local Gui = require"src/gui"

-- Editor state
ScreenSize = nil --- @type userdata
Lightest = 0
Darkest = 0

local animator --- @type Animator
local animations --- @type table<string,Animation>
local current_anim_key --- @type string
local gui_data
local gfx --- @type [{bmp:userdata}]
local palette --- @type userdata
local playing --- @type boolean

local on_animations_changed --- @type function

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
	animations = item_1 or {animation_1 = {spr = {0}, duration = {0.1}}}
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

-- Accessors

--- Sets the current animation to the one with the given key.
--- @param key string The key of the animation to switch to.
local function set_animation(key)
	animator.anim = animations[key]
	current_anim_key = key
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

	animations[anim_name] = {spr = {0},duration = {0.1}}
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

--- Fetches a sprite bitmap off the 0.gfx file by index.
--- @param anim_spr integer The index of the sprite to fetch.
--- @return userdata sprite_data The sprite bitmap data.
local function get_sprite(anim_spr)
	local sprite = gfx[anim_spr]
	return sprite and sprite.bmp
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

	palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100,palette:get())
	end
	poke4(0x5000,fetch(DATP.."pal/0.pal"):get())
	find_binary_cols()

	gfx = fetch("/ram/cart/gfx/0.gfx")
	
	local accessors = {
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

		get_playing = function() return playing end,
		set_playing = function(value) playing = value end,

		get_sprite = get_sprite,

		animator = animator,
	}

	gui_data = Gui.initialize(
		accessors
	)
	on_animations_changed = gui_data.on_animations_changed
end

function _update()
	gui_data.gui:update_all()
	if playing then
		animator:advance(DT)
	end
end

function _draw()
	cls()
	gui_data.gui:draw_all()
end

include"src/error_explorer.lua"