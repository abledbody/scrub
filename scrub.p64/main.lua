--[[pod_format="raw",created="2025-04-04 00:01:14",modified="2025-04-04 00:03:56",revision=6]]
DATP = ""
if not fetch"src/main.lua" then
	cd("/projects/scrub")
	DATP = "scrub.p64/"
end
include"src/main.lua"