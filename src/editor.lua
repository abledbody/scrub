include"src/require.lua"

-- Constants
DT = 1/60
PANEL_HEIGHT = 60

-- Dependencies
local Animation = require"src/animation"
local Gui = require"src/gui"

-- Editor state
local animations --- @type table<string,Animation>
local current_anim_key --- @type string
local screen_size --- @type userdata
local gui_data

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
local function set_scanline_palette(palette_i,first_y,last_y)
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

-- Picotron hooks
function _init()
	window{
		tabbed = true,
		icon = --[[pod_type="gfx"]]unpod("b64:bHo0ACkAAAAsAAAA8AJweHUAQyAICASABwAHAAcgFwYAYQA3AAcARwoAARAAcCAHAAcAB4A=")
	}

	local sw,sh = get_display():attribs()
	screen_size = vec(sw,sh)

	mkdir("/ram/cart/anm")

	wrangle_working_file(
		save_working_file,
		load_working_file,
		"/ram/cart/anm/0.anm"
	)

	current_anim_key = next(animations) or "animation_1"

	local palette = fetch("/ram/cart/pal/0.pal")
	if palette then
		poke4(0x5100,palette:get())
	end
	poke4(0x5000,fetch(DATP.."pal/0.pal"):get())
	set_scanline_palette(1,11,209)

	gui_data = Gui.initialize(
		screen_size,
		{
			get_animation_key = function(self) return current_anim_key end,
			set_animation_key = function(self,key) current_anim_key = key end
		}
	)
end

function _update()
	gui_data.gui:update_all()
end

function _draw()
	cls()

	gui_data.gui:draw_all()
end

include"src/error_explorer.lua"