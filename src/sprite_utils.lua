-- Sprite and graphics utilities for scrub

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

local function find_binary_cols(palette)
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

local function get_indexed_gfx(gfx_file_index, gfx_cache, DATP)
	local gfx_file = gfx_cache[gfx_file_index]
	if not gfx_file then
		local file_path = DATP and (DATP.."gfx/"..gfx_file_index..".gfx") or ("/ram/cart/gfx/"..gfx_file_index..".gfx")
		local gfx_data = fetch(file_path)
		if gfx_data then
			gfx_file = gfx_data
			gfx_cache[gfx_file_index] = gfx_file
		end
	end

	return gfx_file
end

--- @return userdata? sprite_data The sprite bitmap data.
local function get_sprite(anim_spr, gfx_cache, DATP)
	if type(anim_spr) ~= "number" then return nil end
	
	local gfx_file_index = anim_spr//256
	local gfx_spr_index = anim_spr%256
	
	local gfx_file = get_indexed_gfx(gfx_file_index, gfx_cache, DATP)
	local sprite = gfx_file and gfx_file[gfx_spr_index]
	return sprite and sprite.bmp
end

return {
	set_scanline_palette = set_scanline_palette, -- exported as global
	find_binary_cols = find_binary_cols,
	get_indexed_gfx = get_indexed_gfx,
	get_sprite = get_sprite,
}