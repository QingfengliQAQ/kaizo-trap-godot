class_name StageCatalog
extends RefCounted
## Full 10-Room Celeste-Style Sight-Readable Flow Campaign (320x180 = 20x11.25 tiles).
## Design Philosophy (Celeste > I Wanna):
##   - 100% sight-readable layouts — ZERO blind cheap pixel traps!
##   - Teaches & combines: 8-Way Dash, Green Dash Crystals, Wall Climb & Wall Bounce,
##     Traffic Zip-Mover Blocks, Starry Glitch Dream Blocks, and Omni-Springs!
##   - Optional Bagua Trigrams act as Celeste Strawberries (follow Kai until landing on safe floor!).
##   - Preserves iconic Kaizo Trap story beats, biomes, playful nods, and full ZhugeDOS ARG!

static func get_room_spec(room_id: String) -> Dictionary:
	match room_id:
		"room_00": return _room_00_living_room()
		"room_01": return _room_01_forsaken_overworld()
		"room_02": return _room_02_zip_canyon()
		"room_03": return _room_03_dream_site()
		"room_04": return _room_04_frozen_ridge()
		"room_05": return _room_05_molten_core()
		"room_06": return _room_06_signal_factory()
		"room_07": return _room_07_void_yn()
		"room_08": return _room_08_corrupted_core()
		"room_09": return _room_09_summit_escape()
		_: return _room_01_forsaken_overworld()


static func get_all_room_ids() -> Array[String]:
	return [
		"room_00", "room_01", "room_02", "room_03", "room_04",
		"room_05", "room_06", "room_07", "room_08", "room_09"
	]


static func _room_00_living_room() -> Dictionary:
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
			{"pos": Vector2(118, 132), "text": "DASH ->"},
		],
		"goal": {"x": 252.0, "y": 144.0, "next": "room_01", "fakeout": false, "is_tv": true},
	}


static func _room_01_forsaken_overworld() -> Dictionary:
	# Celeste Ch.1 inspired opener: clean sight-readable jumps + floating Dash Crystal across scenic chasm,
	# optional elevated Earth Bagua Strawberry challenge, and one clearly telegraphed playful coconut!
	return {
		"id": "room_01",
		"title": "1-1 OVERWORLD FLOW",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 6, 3],     # Generous starting terrace
			[9, 8, 4, 4],     # Mid climbable outcrop (jump or dash across!)
			[15, 7, 5, 5],    # Elevated goal terrace (use Dash Crystal!)
			[10, 4, 2, 1],    # Optional Strawberry perch for Earth Bagua
			[0, 0, 1, 9],
		],
		"dash_crystals": [
			{"x": 120.0, "y": 112.0}, # Teaches midair Dash Refill cleanly!
			{"x": 224.0, "y": 96.0},
		],
		"coconuts": [
			{"x": 74.0, "y": 46.0, "ground_y": 140.0, "range": 14.0}, # Playful visible homage
		],
		"dir_springs": [
			{"x": 168.0, "y": 122.0, "dir": "up"}, # Launches easily to Earth Bagua or goal!
		],
		"baguas": [
			{"id": "earth", "x": 176.0, "y": 48.0}, # Optional Celeste Strawberry challenge!
		],
		"arrange_kaizo_blocks": [
			[14, 5], # Only in optional 2nd Loop Arrange Mode!
		],
		"signs": [
			{"pos": Vector2(44, 132), "text": "X:DASH"},
		],
		"goal": {"x": 292.0, "y": 112.0, "next": "room_02", "fakeout": false},
	}


static func _room_02_zip_canyon() -> Dictionary:
	# Celeste Ch.1 Traffic Zip-Mover Canyon! Grab/ride the zip-mover to fling across the valley,
	# plus a safe low dash-tunnel & optional hidden lower alcove for the Silver Key + Lake Bagua!
	return {
		"id": "room_02",
		"title": "1-2 ZIP CANYON",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 6, 3],     # Left launch ledge
			[3, 6, 3, 2],     # Low dash/crouch arch (clean, NO spikes inside!)
			[14, 7, 6, 5],    # Right receiving cliff
			[7, 10, 5, 2],    # Optional secret lower platform with Silver Key & Lake Bagua
			[0, 0, 1, 9],
		],
		"zip_movers": [
			{"x": 112.0, "y": 128.0, "w": 32.0, "h": 16.0, "dx": 82.0, "dy": -24.0},
		],
		"dash_crystals": [
			{"x": 196.0, "y": 84.0},
		],
		"dir_springs": [
			{"x": 182.0, "y": 154.0, "dir": "up"}, # Clean return bounce out of secret key alcove!
		],
		"keys": [
			{"id": "stage1_key", "x": 134.0, "y": 148.0},
		],
		"baguas": [
			{"id": "lake", "x": 156.0, "y": 148.0},
		],
		"signs": [
			{"pos": Vector2(80, 132), "text": "RIDE!"},
		],
		"goal": {"x": 292.0, "y": 112.0, "next": "room_03", "fakeout": false},
	}


static func _room_03_dream_site() -> Dictionary:
	# Celeste Ch.2 Old Site homage! Introduces Starry Glitch Dream Blocks:
	# Dash STRAIGHT THROUGH corrupted code blocks to burst out with bonus momentum!
	# Includes optional Ammonite Shell toy + 7M01S Key Block on upper secret shelf!
	return {
		"id": "room_03",
		"title": "1-3 GLITCH DREAM",
		"biome": "overworld",
		"bgm": "overworld",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 6, 3],
			[15, 8, 5, 4],
			[1, 4, 4, 1],     # Upper secret shelf holding 7M01S Key Block
			[0, 0, 1, 9],
		],
		"dream_blocks": [
			{"x": 104.0, "y": 98.0, "w": 48.0, "h": 40.0},
			{"x": 176.0, "y": 76.0, "w": 48.0, "h": 44.0},
		],
		"dash_crystals": [
			{"x": 86.0, "y": 112.0},
			{"x": 164.0, "y": 92.0},
			{"x": 88.0, "y": 56.0}, # Optional crystal leading left to 7M01S Key Block!
		],
		"shells": [
			[56.0, 136.0], # Optional Kaizo Shell toy for stylish clears
		],
		"key_blocks": [
			{"x": 46.0, "y": 56.0},
		],
		"signs": [
			{"pos": Vector2(72, 132), "text": "DASH IN"},
		],
		"goal": {"x": 292.0, "y": 128.0, "next": "room_04", "fakeout": false},
	}


static func _room_04_frozen_ridge() -> Dictionary:
	# Celeste Ch.1/4 Frozen Mountain Climb! Wall-Climb, Wall-Bounce, Dash Crystals & Zip Mover
	# with rhythmic telegraphed icicles & optional Wind/Water Bagua Followers!
	return {
		"id": "room_04",
		"title": "2-1 FROZEN RIDGE",
		"biome": "ice",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[7, 4, 2, 7],     # Climbable vertical ice pillar (Wall-Bounce / Climb!)
			[12, 6, 2, 5],    # Second vertical climb pillar
			[16, 5, 4, 7],    # High mountain summit exit
			[0, 0, 1, 9],
		],
		"dash_crystals": [
			{"x": 92.0, "y": 106.0},
			{"x": 168.0, "y": 78.0},
			{"x": 236.0, "y": 66.0},
		],
		"dir_springs": [
			{"x": 148.0, "y": 104.0, "dir": "right"}, # Wall spring flings Kai cleanly to pillar 2!
		],
		"icicles": [
			{"x": 168.0, "y": 30.0, "ground_y": 152.0},
		],
		"crumbles": [
			[5, 9],
			[6, 9],
		],
		"baguas": [
			{"id": "wind", "x": 124.0, "y": 46.0},
			{"id": "water", "x": 208.0, "y": 52.0},
		],
		"goal": {"x": 292.0, "y": 80.0, "next": "room_05", "fakeout": false},
	}


static func _room_05_molten_core() -> Dictionary:
	# Celeste Ch.8 Core flow: Dash Crystal + Glitch Dream Block chain high above rhythmic rising lava,
	# with generous safe resting obsidian islands!
	return {
		"id": "room_05",
		"title": "3-1 MOLTEN CORE",
		"biome": "volcano",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 128),
		"solids": [
			[0, 8, 4, 4],
			[9, 7, 3, 2],     # Mid obsidian rest island
			[16, 6, 4, 6],    # High exit cliff
			[0, 0, 1, 8],
		],
		"dream_blocks": [
			{"x": 86.0, "y": 84.0, "w": 42.0, "h": 34.0},
			{"x": 204.0, "y": 68.0, "w": 40.0, "h": 36.0},
		],
		"dash_crystals": [
			{"x": 72.0, "y": 104.0},
			{"x": 184.0, "y": 84.0},
		],
		"lava": {"base_y": 168.0, "amplitude": 26.0, "speed": 1.35},
		"baguas": [
			{"id": "fire", "x": 168.0, "y": 46.0},
		],
		"goal": {"x": 292.0, "y": 96.0, "next": "room_06", "fakeout": false},
	}


static func _room_06_signal_factory() -> Dictionary:
	# Celeste Industrial Flow: Chained Traffic Zip-Movers + Climb Wall weaving cleanly around
	# clearly readable patrolling sawblades, featuring Japanese tanks (液体痛み/敗者の涙/濃厚苦しみ) & 1983 NES!
	return {
		"id": "room_06",
		"title": "4-1 SIGNAL FACTORY",
		"biome": "factory",
		"bgm": "ice_factory",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 5, 3],
			[15, 8, 5, 4],
			[3, 4, 3, 1],     # High Mountain Bagua perch
			[0, 0, 1, 9],
		],
		"zip_movers": [
			{"x": 92.0, "y": 124.0, "w": 32.0, "h": 16.0, "dx": 72.0, "dy": -30.0},
			{"x": 192.0, "y": 116.0, "w": 32.0, "h": 16.0, "dx": 42.0, "dy": -12.0},
		],
		"dash_crystals": [
			{"x": 176.0, "y": 78.0},
			{"x": 76.0, "y": 78.0},
		],
		"sawblades": [
			{"x": 146.0, "y": 134.0, "dx": 48.0, "dy": 0.0, "speed": 1.8},
		],
		"baguas": [
			{"id": "mountain", "x": 72.0, "y": 46.0},
			{"id": "thunder", "x": 212.0, "y": 64.0},
		],
		"signs": [
			{"pos": Vector2(54, 132), "text": "1983"},
		],
		"goal": {"x": 292.0, "y": 128.0, "next": "room_07", "fakeout": false},
	}


static func _room_07_void_yn() -> Dictionary:
	return {
		"id": "room_07",
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
		"goal": {"x": 90.0, "y": 144.0, "next": "room_08", "fakeout": false},
		"n_door": {"x": 230.0, "y": 124.0},
	}


static func _room_08_corrupted_core() -> Dictionary:
	# Celeste Ch.6 Badeline-inspired Boss Arena:
	# Chain Glitch Dream Blocks & Dash Crystals upward while weaving between rhythmic white beams
	# to reach Zo's Heart Cable Pod (upper right) and shatter the Core!
	return {
		"id": "room_08",
		"title": "5-1 CORE CLIMAX",
		"biome": "core",
		"bgm": "core_boss",
		"spawn": Vector2(24, 144),
		"solids": [
			[0, 9, 20, 3],
			[14, 5, 4, 1],    # Upper Heart Cable Pod terrace
			[0, 0, 1, 9],
			[19, 0, 1, 9],
		],
		"dream_blocks": [
			{"x": 72.0, "y": 98.0, "w": 42.0, "h": 34.0},
			{"x": 144.0, "y": 72.0, "w": 42.0, "h": 34.0},
		],
		"dash_crystals": [
			{"x": 58.0, "y": 116.0},
			{"x": 128.0, "y": 88.0},
			{"x": 204.0, "y": 70.0},
		],
		"heart_pod": {"x": 248.0, "y": 64.0},
		"goal": {"x": 286.0, "y": 144.0, "next": "room_09", "fakeout": true},
	}


static func _room_09_summit_escape() -> Dictionary:
	# Celeste Summit-style High-Speed Glitch Escape!
	# Follow Zo's cyan ghost silhouette from RIGHT -> LEFT chaining Dream Blocks & Dash Crystals
	# back through Stage 1, dodging the iconic final callback Coconut into the Blue Escape Vortex!
	return {
		"id": "room_09",
		"title": "5-2 SUMMIT ESCAPE",
		"biome": "glitch_escape",
		"bgm": "core_boss",
		"spawn": Vector2(292, 144),
		"solids": [
			[0, 9, 6, 3],
			[15, 9, 5, 3],
			[19, 0, 1, 9],
		],
		"dream_blocks": [
			{"x": 182.0, "y": 96.0, "w": 44.0, "h": 36.0},
			{"x": 112.0, "y": 96.0, "w": 44.0, "h": 36.0},
		],
		"dash_crystals": [
			{"x": 244.0, "y": 114.0},
			{"x": 168.0, "y": 112.0},
			{"x": 96.0, "y": 114.0},
		],
		"coconuts": [
			{"x": 68.0, "y": 46.0, "ground_y": 140.0, "range": 15.0},
		],
		"goal": {"x": 24.0, "y": 144.0, "next": "__TRUE_ENDING__", "fakeout": false, "is_vortex": true},
	}
