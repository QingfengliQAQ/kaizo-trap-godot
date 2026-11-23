class_name StageCatalog
extends RefCounted
## Full 14-Room Pure Kaizo Trap (孔明の罠) Campaign with Celeste-Grade WYSIWYG Fairness!
## Philosophy:
##   - 100% AUTHENTIC Kaizo Trap visual world, lore, props & mechanics
##     (Golden Bagua Resonance Orbs, Ammonite Shells, Electric Spikes, Steel Rail Platforms,
##      ZhugeDOS Hex Code Curtains, Wind Gusts, Japanese Factory Tanks, 1983 NES, Heart Cable Pod).
##   - 100% WYSIWYG ("所见即所得") fair sight-readable layouts:
##     ZERO cheap blind invisible traps! Every hazard, drop sightline, and path is crystal clear.

static func get_room_spec(room_id: String) -> Dictionary:
	match room_id:
		"room_00": return _room_00_living_room()
		"room_01": return _room_01_assembly_vortex()
		"room_02": return _room_02_palm_overworld()
		"room_03": return _room_03_electric_slide()
		"room_04": return _room_04_shell_shaft()
		"room_05": return _room_05_gale_peaks()
		"room_06": return _room_06_frozen_cavern()
		"room_07": return _room_07_basalt_bridge()
		"room_08": return _room_08_lava_ascent()
		"room_09": return _room_09_liquid_pain_lab()
		"room_10": return _room_10_thunder_conduit()
		"room_11": return _room_11_void_yn()
		"room_12": return _room_12_corrupted_core()
		"room_13": return _room_13_glitch_escape()
		_: return _room_00_living_room()


static func get_all_room_ids() -> Array[String]:
	return [
		"room_00", "room_01", "room_02", "room_03", "room_04",
		"room_05", "room_06", "room_07", "room_08", "room_09",
		"room_10", "room_11", "room_12", "room_13"
	]


static func _room_00_living_room() -> Dictionary:
	# Stage 0-0: Living Room Intro — Zhuge Liang portrait, Kaizo Mario & Y/N paintings, NES & CRT TV!
	return {
		"id": "room_00",
		"title": "0-0 LIVING ROOM",
		"biome": "living_room",
		"bgm": "overworld",
		"spawn": Vector2(44, 144),
		"solids": [
			[0, 9, 20, 3],
			[0, 0, 1, 9],
			[19, 0, 1, 9],
		],
		"signs": [
			{"pos": Vector2(118, 132), "text": "ENTER TV"},
		],
		"goal": {"x": 252.0, "y": 144.0, "next": "room_01", "fakeout": false, "is_tv": true},
	}


static func _room_01_assembly_vortex() -> Dictionary:
	# Stage 0-1: Authentic 1:23 Falling Assembly Code Vortex!
	# Navigate cleanly through scrolling 68000/6502 code curtains and visible Bagua orbs into Stage 1!
	return {
		"id": "room_01",
		"title": "0-1 CODE VORTEX",
		"biome": "code_vortex",
		"bgm": "overworld",
		"spawn": Vector2(40, 56),
		"solids": [
			[1, 4, 4, 1],
			[8, 6, 4, 1],
			[14, 9, 6, 3],
			[0, 0, 1, 11],
		],
		"hex_curtains": [
			{"x": 168.0, "y": 82.0, "w": 36.0, "h": 40.0},
		],
		"bagua_orbs": [
			{"x": 110.0, "y": 78.0},
			{"x": 218.0, "y": 106.0},
		],
		"spikes": [
			{"tx": 8, "ty": 5, "w": 1, "dir": "up"},
		],
		"signs": [
			{"pos": Vector2(64, 52), "text": "X:DASH"},
		],
		"goal": {"x": 292.0, "y": 144.0, "next": "room_02", "fakeout": false},
	}


static func _room_02_palm_overworld() -> Dictionary:
	# Stage 1-1: Tropical Palm Overworld — 100% sight-readable flow!
	# Visible palm tree with telegraphed shaking coconut + Golden Bagua Orbs + optional Earth Bagua!
	return {
		"id": "room_02",
		"title": "1-1 PALM OVERWORLD",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 6, 3],
			[9, 8, 4, 4],
			[15, 7, 5, 5],
			[10, 4, 2, 1],
			[0, 0, 1, 9],
		],
		"bagua_orbs": [
			{"x": 122.0, "y": 110.0},
			{"x": 222.0, "y": 96.0},
		],
		"droppers": [
			{"kind": "coconut", "x": 74.0, "y": 46.0, "ground_y": 140.0, "range": 32.0, "telegraph": 0.36},
		],
		"dir_springs": [
			{"x": 170.0, "y": 122.0, "dir": "up"},
		],
		"baguas": [
			{"id": "earth", "x": 176.0, "y": 46.0},
		],
		"signs": [
			{"pos": Vector2(44, 132), "text": "RUN ->"},
		],
		"goal": {"x": 292.0, "y": 112.0, "next": "room_03", "fakeout": false},
	}


static func _room_03_electric_slide() -> Dictionary:
	# Stage 1-2: Sight-readable Low Slide Arch + Crumble Bridge + Honest Secret Path below 'GO ->' sign!
	return {
		"id": "room_03",
		"title": "1-2 ELECTRIC SLIDE",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 8, 3],
			[4, 6, 3, 2],     # Clean low slide/dash arch (no unfair ceiling spikes!)
			[12, 8, 3, 4],
			[16, 7, 4, 5],
			[8, 11, 6, 1],    # Visible secret lower floor holding Silver Key & Lake Bagua!
			[0, 0, 1, 9],
		],
		"crumbles": [[8, 9], [9, 9], [10, 9]],
		"bagua_orbs": [
			{"x": 182.0, "y": 96.0},
		],
		"dir_springs": [
			{"x": 212.0, "y": 168.0, "dir": "up"}, # Fair bounce out of secret key alcove!
		],
		"keys": [{"id": "stage1_key", "x": 164.0, "y": 164.0}],
		"baguas": [{"id": "lake", "x": 186.0, "y": 164.0}],
		"signs": [
			{"pos": Vector2(204, 116), "text": "KEY v"},
		],
		"goal": {"x": 292.0, "y": 112.0, "next": "room_04", "fakeout": false},
	}


static func _room_04_shell_shaft() -> Dictionary:
	# Stage 1-3: Canonical Ammonite Shell Jump & Wall-Climb Shaft (ref_25.png) + 7M01S Key Block!
	# Both Shell-Jump AND clean Wall-Climb/Spring paths work fairly!
	return {
		"id": "room_04",
		"title": "1-3 SHELL SHAFT",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 8, 3],
			[8, 4, 1, 8],     # Climbable shaft wall left
			[13, 2, 1, 8],    # Climbable shaft wall right
			[14, 8, 6, 4],
			[1, 4, 4, 1],     # Upper shelf holding 7M01S Key Block
			[0, 0, 1, 9],
		],
		"spikes": [
			{"tx": 9, "ty": 10, "w": 4, "dir": "up"},
		],
		"dir_springs": [
			{"x": 116.0, "y": 138.0, "dir": "up"},
		],
		"bagua_orbs": [
			{"x": 176.0, "y": 82.0},
			{"x": 96.0, "y": 56.0},
		],
		"shells": [
			[68.0, 136.0], # Coiled metallic Ammonite Shell (Up+C / Right+C)
		],
		"key_blocks": [
			{"x": 46.0, "y": 56.0}, # 7M01S Key Block (touch w/ Key OR Right-Click CRT Inspect!)
		],
		"signs": [
			{"pos": Vector2(46, 132), "text": "SHELL"},
		],
		"goal": {"x": 292.0, "y": 128.0, "next": "room_05", "fakeout": false},
	}


static func _room_05_gale_peaks() -> Dictionary:
	# Stage 2-1: Canonical Wind Trigram (☴) Gale Peaks!
	# Visible flowing wind gusts carry Kai's jumps & dashes across misty alpine chasms!
	return {
		"id": "room_05",
		"title": "2-1 GALE PEAKS",
		"biome": "ice",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[10, 7, 3, 5],
			[16, 6, 4, 6],
			[0, 0, 1, 9],
		],
		"wind_zones": [
			{"x": 80.0, "y": 52.0, "w": 84.0, "h": 92.0, "ax": 175.0, "ay": -210.0},
			{"x": 196.0, "y": 40.0, "w": 72.0, "h": 88.0, "ax": 185.0, "ay": -180.0},
		],
		"bagua_orbs": [
			{"x": 120.0, "y": 98.0},
			{"x": 230.0, "y": 78.0},
		],
		"baguas": [
			{"id": "wind", "x": 176.0, "y": 52.0},
		],
		"signs": [
			{"pos": Vector2(54, 132), "text": "WIND^"},
		],
		"goal": {"x": 292.0, "y": 96.0, "next": "room_06", "fakeout": false},
	}


static func _room_06_frozen_cavern() -> Dictionary:
	# Stage 2-2: Frozen Cavern — Slippery ice, climbable pillars, telegraphed shaking icicles,
	# Water Trigram (☵), and Arrange Mode atmospheric Blizzard!
	return {
		"id": "room_06",
		"title": "2-2 FROZEN CAVERN",
		"biome": "ice",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[7, 5, 2, 6],
			[12, 6, 2, 5],
			[16, 5, 4, 7],
			[0, 0, 1, 9],
		],
		"droppers": [
			{"kind": "icicle", "x": 168.0, "y": 32.0, "ground_y": 156.0, "range": 34.0, "telegraph": 0.36},
		],
		"dir_springs": [
			{"x": 148.0, "y": 106.0, "dir": "right"},
		],
		"bagua_orbs": [
			{"x": 92.0, "y": 104.0},
			{"x": 236.0, "y": 68.0},
		],
		"crumbles": [[5, 9], [6, 9]],
		"baguas": [
			{"id": "water", "x": 208.0, "y": 52.0},
		],
		"goal": {"x": 292.0, "y": 80.0, "next": "room_07", "fakeout": false},
	}


static func _room_07_basalt_bridge() -> Dictionary:
	# Stage 3-1: Volcanic Basalt Bridge — Crumble obsidian + Bagua Orbs over rhythmic lava tide!
	return {
		"id": "room_07",
		"title": "3-1 BASALT BRIDGE",
		"biome": "volcano",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 128),
		"solids": [
			[0, 8, 4, 4],
			[8, 7, 3, 2],
			[16, 6, 4, 6],
			[0, 0, 1, 8],
		],
		"crumbles": [[4, 8], [5, 8], [12, 7], [13, 7]],
		"bagua_orbs": [
			{"x": 104.0, "y": 96.0},
			{"x": 220.0, "y": 82.0},
		],
		"lava": {"base_y": 168.0, "amplitude": 26.0, "speed": 1.35},
		"baguas": [
			{"id": "fire", "x": 152.0, "y": 50.0},
		],
		"goal": {"x": 292.0, "y": 96.0, "next": "room_08", "fakeout": false},
	}


static func _room_08_lava_ascent() -> Dictionary:
	# Stage 3-2: Vertical Volcanic Climb — Fair wall-climb + directional springs over lava!
	return {
		"id": "room_08",
		"title": "3-2 LAVA ASCENT",
		"biome": "volcano",
		"bgm": "ice_factory",
		"spawn": Vector2(28, 128),
		"solids": [
			[0, 8, 5, 4],
			[7, 4, 2, 6],
			[12, 3, 2, 7],
			[16, 4, 4, 8],
			[0, 0, 1, 8],
		],
		"dir_springs": [
			{"x": 64.0, "y": 122.0, "dir": "up"},
			{"x": 148.0, "y": 92.0, "dir": "right"},
		],
		"bagua_orbs": [
			{"x": 176.0, "y": 70.0},
			{"x": 236.0, "y": 54.0},
		],
		"lava": {"base_y": 170.0, "amplitude": 28.0, "speed": 1.45},
		"goal": {"x": 292.0, "y": 64.0, "next": "room_09", "fakeout": false},
	}


static func _room_09_liquid_pain_lab() -> Dictionary:
	# Stage 4-1: Mechanical Factory Lab — Industrial Steel Rail Platforms, Sawblades,
	# Japanese Containment Tanks (液体痛み / 敗者の涙 / 濃厚苦しみ), buried 1983 NES & Mountain Bagua!
	return {
		"id": "room_09",
		"title": "4-1 LIQUID PAIN LAB",
		"biome": "factory",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[15, 8, 5, 4],
			[3, 4, 3, 1],
			[0, 0, 1, 9],
		],
		"steel_platforms": [
			{"x": 92.0, "y": 126.0, "w": 36.0, "h": 12.0, "dx": 70.0, "dy": -26.0, "speed": 1.15, "trigger": true},
			{"x": 192.0, "y": 116.0, "w": 36.0, "h": 12.0, "dx": 40.0, "dy": -10.0, "speed": 1.0, "trigger": false},
		],
		"bagua_orbs": [
			{"x": 76.0, "y": 82.0},
			{"x": 176.0, "y": 78.0},
		],
		"sawblades": [
			{"x": 146.0, "y": 138.0, "dx": 48.0, "dy": 0.0, "speed": 1.75},
		],
		"baguas": [
			{"id": "mountain", "x": 72.0, "y": 46.0},
		],
		"signs": [
			{"pos": Vector2(54, 132), "text": "1983"},
		],
		"goal": {"x": 292.0, "y": 128.0, "next": "room_10", "fakeout": false},
	}


static func _room_10_thunder_conduit() -> Dictionary:
	# Stage 4-2: Electric Conduit & ZhugeDOS 57/77 Hex Code Curtains + Thunder Bagua (☳)!
	return {
		"id": "room_10",
		"title": "4-2 THUNDER CONDUIT",
		"biome": "factory",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[15, 7, 5, 5],
			[0, 0, 1, 9],
		],
		"hex_curtains": [
			{"x": 100.0, "y": 96.0, "w": 42.0, "h": 38.0},
			{"x": 176.0, "y": 74.0, "w": 42.0, "h": 38.0},
		],
		"bagua_orbs": [
			{"x": 86.0, "y": 114.0},
			{"x": 162.0, "y": 94.0},
		],
		"spikes": [
			{"tx": 5, "ty": 10, "w": 10, "dir": "up"},
		],
		"baguas": [
			{"id": "thunder", "x": 210.0, "y": 48.0},
		],
		"signs": [
			{"pos": Vector2(56, 132), "text": "57 77"},
		],
		"goal": {"x": 292.0, "y": 112.0, "next": "room_11", "fakeout": false},
	}


static func _room_11_void_yn() -> Dictionary:
	# Void Intermission: Iconic CONTINUE? ☰ 10 ☰ with Air Man katakana & Red Y / Blue N Doors!
	return {
		"id": "room_11",
		"title": "CONTINUE? (Y/N)",
		"biome": "void_yn",
		"bgm": "core_boss",
		"spawn": Vector2(160, 144),
		"solids": [
			[0, 9, 20, 3],
			[0, 0, 1, 9],
			[19, 0, 1, 9],
		],
		"baguas": [{"id": "heaven", "x": 160.0, "y": 74.0}],
		"goal": {"x": 90.0, "y": 144.0, "next": "room_12", "fakeout": false},
		"n_door": {"x": 230.0, "y": 124.0},
	}


static func _room_12_corrupted_core() -> Dictionary:
	# Stage 5-1: Corrupted Zo Core Boss!
	# Dash through ZhugeDOS Hex Code Curtains & Golden Bagua Orbs dodging telegraphed lasers
	# to pull Zo's Heart Cable Pod (upper right) -> triggers Glitch Escape!
	return {
		"id": "room_12",
		"title": "5-1 CORRUPTED CORE",
		"biome": "core",
		"bgm": "core_boss",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 20, 3],
			[14, 5, 4, 1],
			[0, 0, 1, 9],
			[19, 0, 1, 9],
		],
		"hex_curtains": [
			{"x": 72.0, "y": 98.0, "w": 40.0, "h": 34.0},
			{"x": 144.0, "y": 72.0, "w": 40.0, "h": 34.0},
		],
		"bagua_orbs": [
			{"x": 58.0, "y": 116.0},
			{"x": 128.0, "y": 88.0},
			{"x": 204.0, "y": 70.0},
		],
		"heart_pod": {"x": 248.0, "y": 64.0},
		"goal": {"x": 286.0, "y": 144.0, "next": "room_13", "fakeout": true},
	}


static func _room_13_glitch_escape() -> Dictionary:
	# Stage 5-2: Glitch Escape back through Stage 1 (RIGHT -> LEFT)!
	# Follow Zo's cyan silhouette through Hex Code Curtains & Golden Bagua Orbs,
	# dodge the final telegraphed Return Coconut (6:53 callback!), leap into the Blue Vortex!
	return {
		"id": "room_13",
		"title": "5-2 GLITCH ESCAPE",
		"biome": "glitch_escape",
		"bgm": "core_boss",
		"spawn": Vector2(292, 144),
		"solids": [
			[0, 9, 6, 3],
			[15, 9, 5, 3],
			[19, 0, 1, 9],
		],
		"hex_curtains": [
			{"x": 182.0, "y": 96.0, "w": 40.0, "h": 36.0},
			{"x": 112.0, "y": 96.0, "w": 40.0, "h": 36.0},
		],
		"bagua_orbs": [
			{"x": 244.0, "y": 114.0},
			{"x": 168.0, "y": 112.0},
			{"x": 96.0, "y": 114.0},
		],
		"droppers": [
			{"kind": "coconut", "x": 68.0, "y": 46.0, "ground_y": 140.0, "range": 34.0, "telegraph": 0.36},
		],
		"goal": {"x": 24.0, "y": 144.0, "next": "__TRUE_ENDING__", "fakeout": false, "is_vortex": true},
	}
