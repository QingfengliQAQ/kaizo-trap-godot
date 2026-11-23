class_name KaizoRoom
extends Node2D
## High-FPS Celeste-Style Kaizo Trap Room Builder (10 handcrafted rooms, 7 biomes).
## Separates static terrain/background into a cached draw layer (drawn ONCE per room load)
## so display FPS stays locked at 120-240+ FPS, while dynamic traps & Celeste objects
## (DashCrystals, ZipMoverBlocks, GlitchDreamBlocks, DirectionalSprings, BaguaFollowers)
## animate smoothly!

signal room_exit_reached(next_room_id: String, is_kaizo_fakeout: bool)
signal good_ending_triggered()
signal short_ending_triggered()
signal heart_cable_severed()

var room_id: String = "room_01"
var biome: String = "overworld"
var spawn_pos: Vector2 = Vector2(28, 144)
var room_width: int = 320
var room_height: int = 180
var is_ice_room: bool = false

var tile_rects: Array[Rect2] = []
var decorative_signs: Array = []
var traps: Array[Node] = []
var shells: Array[AmmoniteShell] = []
var key_blocks: Array = []
var room_data: Dictionary = {}
var tile_tex: Texture2D = null
var biome_tex: Texture2D = null
var zo_tex: Texture2D = null
var anim_t: float = 0.0

var boss_lasers: Array[Dictionary] = []
var boss_timer: float = 0.0
var boss_glitched: bool = false
var exit_flag: KaizoTraps.GoalFlag = null
var dynamic_fx_layer: Node2D = null
var _static_dirty: bool = true


func _ready() -> void:
	if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
		tile_tex = load("res://assets/tilesets/overworld_objects.png")
	if ResourceLoader.exists("res://assets/tilesets/biomes_tiles.png"):
		biome_tex = load("res://assets/tilesets/biomes_tiles.png")
	if ResourceLoader.exists("res://assets/sprites/zo_and_boss.png"):
		zo_tex = load("res://assets/sprites/zo_and_boss.png")


func build_from_spec(spec: Dictionary, arrange: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	tile_rects.clear()
	decorative_signs.clear()
	traps.clear()
	shells.clear()
	key_blocks.clear()
	boss_lasers.clear()
	boss_glitched = false
	exit_flag = null
	_static_dirty = true

	room_data = spec
	room_id = spec.get("id", "room_01")
	biome = spec.get("biome", "overworld")
	is_ice_room = (biome == "ice")
	spawn_pos = spec.get("spawn", Vector2(28, 144))

	# 1. Solid blocks
	for s in spec.get("solids", []):
		_add_solid_rect(Rect2(s[0] * 16.0, s[1] * 16.0, s[2] * 16.0, s[3] * 16.0))

	# 2. Spikes
	for sp in spec.get("spikes", []):
		var h := KaizoTraps.SpikeHazard.new()
		h.width_tiles = sp.get("w", 1)
		h.direction = sp.get("dir", "up")
		h.death_kind = sp.get("kind", "spike")
		h.position = Vector2(sp["tx"] * 16.0, sp["ty"] * 16.0 + 8.0)
		add_child(h)
		traps.append(h)

	# 3. Celeste Green Dash Refill Crystals
	for dc in spec.get("dash_crystals", []):
		var crys := CelesteObjects.DashCrystal.new()
		crys.position = Vector2(dc["x"], dc["y"])
		add_child(crys)
		traps.append(crys)

	# 4. Celeste Traffic Zip-Mover Momentum Blocks
	for zm in spec.get("zip_movers", []):
		var blk := CelesteObjects.ZipMoverBlock.new()
		blk.position = Vector2(zm["x"], zm["y"])
		blk.block_size = Vector2(zm.get("w", 32.0), zm.get("h", 16.0))
		blk.target_offset = Vector2(zm.get("dx", 80.0), zm.get("dy", 0.0))
		add_child(blk)
		traps.append(blk)

	# 5. Celeste Chapter 2 Starry Glitch Dream Blocks
	for db in spec.get("dream_blocks", []):
		var dblk := CelesteObjects.GlitchDreamBlock.new()
		dblk.position = Vector2(db["x"], db["y"])
		dblk.block_size = Vector2(db.get("w", 48.0), db.get("h", 32.0))
		add_child(dblk)
		traps.append(dblk)

	# 6. Celeste Omni-Directional Springs (Refill Dash + Stamina!)
	for ds in spec.get("dir_springs", []):
		var spr := CelesteObjects.DirectionalSpring.new()
		spr.position = Vector2(ds["x"], ds["y"])
		spr.dir = ds.get("dir", "up")
		add_child(spr)
		traps.append(spr)

	# 7. Invisible Bagua Kaizo Blocks (Only in Arrange Mode unless explicitly placed!)
	var kb_list: Array = spec.get("kaizo_blocks", []).duplicate()
	if arrange:
		kb_list.append_array(spec.get("arrange_kaizo_blocks", []))
	for kb in kb_list:
		var b := KaizoTraps.InvisibleBaguaBlock.new()
		b.position = Vector2(kb[0] * 16.0 + 8.0, kb[1] * 16.0 + 8.0)
		add_child(b)
		traps.append(b)

	# 8. Falling Coconuts (Playful telegraphed homage!)
	for cc in spec.get("coconuts", []):
		var c := KaizoTraps.FallingCoconut.new()
		c.position = Vector2(cc["x"], cc["y"])
		c.ground_y = cc.get("ground_y", 148.0)
		c.trigger_x_range = cc.get("range", 16.0)
		add_child(c)
		traps.append(c)

	# 9. Falling Icicles
	for ic in spec.get("icicles", []):
		var ice := KaizoTraps.FallingIcicle.new()
		ice.position = Vector2(ic["x"], ic["y"])
		ice.ground_y = ic.get("ground_y", 144.0)
		add_child(ice)
		traps.append(ice)

	# 10. Rising Lava
	if spec.has("lava"):
		var lv: Dictionary = spec["lava"]
		var lava := KaizoTraps.RisingLava.new()
		lava.base_y = lv.get("base_y", 168.0)
		lava.amplitude = lv.get("amplitude", 26.0)
		lava.speed = lv.get("speed", 1.35) * (1.25 if arrange else 1.0)
		lava.position = Vector2(0, lava.base_y)
		add_child(lava)
		traps.append(lava)

	# 11. Patrolling Sawblades
	for sw in spec.get("sawblades", []):
		var saw := KaizoTraps.SawbladeHazard.new()
		saw.position = Vector2(sw["x"], sw["y"])
		saw.patrol_delta = Vector2(sw.get("dx", 48.0), sw.get("dy", 0.0))
		saw.speed = sw.get("speed", 1.8) * (1.25 if arrange else 1.0)
		add_child(saw)
		traps.append(saw)

	# 12. Crumble blocks
	for cb in spec.get("crumbles", []):
		var cblk := KaizoTraps.CrumbleBlock.new()
		cblk.position = Vector2(cb[0] * 16.0 + 8.0, cb[1] * 16.0 + 8.0)
		add_child(cblk)
		traps.append(cblk)

	# 13. Classic Springs (if any)
	for sr in spec.get("springs", []):
		var p := KaizoTraps.SpringPad.new()
		p.position = Vector2(sr[0] * 16.0 + 8.0, sr[1] * 16.0 + 8.0)
		p.boost = sr[2] if sr.size() > 2 else -315.0
		add_child(p)
		traps.append(p)

	# 14. Ammonite Shells
	for sh in spec.get("shells", []):
		var shell := AmmoniteShell.new()
		shell.position = Vector2(sh[0], sh[1])
		add_child(shell)
		shells.append(shell)

	# 15. Keys & 7M01S Key Blocks
	for kp in spec.get("keys", []):
		var k := KaizoTraps.KeyPickup.new()
		k.position = Vector2(kp["x"], kp["y"])
		k.key_id = kp.get("id", "stage1_key")
		add_child(k)

	for kbl in spec.get("key_blocks", []):
		var kb701 := KaizoTraps.KeyBlock701.new()
		kb701.position = Vector2(kbl["x"], kbl["y"])
		kb701.secret_ending_triggered.connect(func(): good_ending_triggered.emit())
		add_child(kb701)
		key_blocks.append(kb701)

	# 16. Zo Heart Cable Pod
	if spec.has("heart_pod"):
		var hp: Dictionary = spec["heart_pod"]
		var pod := KaizoTraps.HeartCablePod.new()
		pod.position = Vector2(hp["x"], hp["y"])
		pod.cable_pulled.connect(_on_heart_cable_pulled)
		add_child(pod)
		traps.append(pod)

	# 17. Celeste Strawberry-style Bagua Trigram Followers!
	for bg in spec.get("baguas", []):
		var bp := CelesteObjects.BaguaFollower.new()
		bp.position = Vector2(bg["x"], bg["y"])
		bp.trigram_id = bg["id"]
		add_child(bp)
		traps.append(bp)

	decorative_signs = spec.get("signs", [])

	# 18. Exit Goal Flag / TV Portal / Escape Vortex
	if spec.has("goal"):
		var g_spec: Dictionary = spec["goal"]
		var flag := KaizoTraps.GoalFlag.new()
		flag.position = Vector2(g_spec["x"], g_spec["y"])
		flag.is_kaizo_fakeout = bool(g_spec.get("fakeout", false)) and (not arrange)
		var next_id: String = g_spec.get("next", "")
		flag.room_cleared.connect(func(is_fake): room_exit_reached.emit(next_id, is_fake))
		add_child(flag)
		traps.append(flag)
		exit_flag = flag

	# Optional "N" early exit door (Short End!)
	if spec.has("n_door"):
		var nd: Dictionary = spec["n_door"]
		var door := Area2D.new()
		door.position = Vector2(nd["x"], nd["y"])
		door.collision_layer = 16
		door.collision_mask = 2
		var ds := CollisionShape2D.new()
		var dr := RectangleShape2D.new()
		dr.size = Vector2(20, 30)
		ds.shape = dr
		door.add_child(ds)
		door.body_entered.connect(func(b):
			if b is KaiPlayer:
				SecretManager.unlock_ending("short")
				short_ending_triggered.emit()
		)
		add_child(door)

	# Dedicated dynamic FX overlay so static terrain does NOT redraw every frame!
	dynamic_fx_layer = _RoomDynamicOverlay.new(self)
	dynamic_fx_layer.z_index = 4
	add_child(dynamic_fx_layer)

	queue_redraw()


func _on_heart_cable_pulled() -> void:
	boss_glitched = true
	boss_lasers.clear()
	if exit_flag:
		exit_flag.is_kaizo_fakeout = false
	heart_cable_severed.emit()
	if dynamic_fx_layer:
		dynamic_fx_layer.queue_redraw()


func _add_solid_rect(rect: Rect2) -> void:
	tile_rects.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)


func reset_traps() -> void:
	for t in traps:
		if is_instance_valid(t) and t.has_method("reset_trap"):
			t.reset_trap()
	for s in shells:
		if is_instance_valid(s):
			s.reset_shell()
	boss_timer = 0.0
	boss_lasers.clear()
	queue_redraw()
	if dynamic_fx_layer:
		dynamic_fx_layer.queue_redraw()


func handle_crt_inspect_click(world_pos: Vector2) -> bool:
	for kb in key_blocks:
		if is_instance_valid(kb) and kb.try_crt_click(world_pos):
			return true
	return false


func _physics_process(delta: float) -> void:
	anim_t += delta
	if biome == "core" and not boss_glitched:
		_update_boss_lasers(delta)


func _process(_delta: float) -> void:
	# Only lightweight dynamic overlay redraws at high FPS; static tiles stay cached!
	if dynamic_fx_layer and biome in ["core", "glitch_escape", "living_room"]:
		dynamic_fx_layer.queue_redraw()


func _update_boss_lasers(delta: float) -> void:
	boss_timer += delta
	var cycle := fmod(boss_timer, 3.2)
	boss_lasers.clear()
	var beam_y := 124.0 if int(boss_timer / 3.2) % 2 == 0 else 142.0
	if cycle > 1.3 and cycle < 2.15:
		boss_lasers.append({"y": beam_y, "active": false})
	elif cycle >= 2.15 and cycle < 2.75:
		boss_lasers.append({"y": beam_y, "active": true})
		for p in get_tree().get_nodes_in_group("player"):
			if p is KaiPlayer and not p.is_dead:
				var py: float = p.global_position.y - 6.0
				if absf(py - beam_y) < 7.0:
					p.kill("laser")


func _draw() -> void:
	# Cached static background, biome architecture, tiles, signs, and death splats!
	match biome:
		"living_room":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#2c2238"))
			draw_rect(Rect2(0, 128, room_width, 16), Color("#42304e"))
			draw_rect(Rect2(44, 42, 34, 44), Color("#683a20"))
			draw_rect(Rect2(47, 45, 28, 38), Color("#f6f8ff"))
			draw_string(ThemeDB.fallback_font, Vector2(51, 66), "孔明", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#1c223e"))
			draw_rect(Rect2(104, 48, 30, 24), Color("#1c223e"))
			draw_rect(Rect2(106, 50, 26, 20), Color("#38b4ff"))
			draw_rect(Rect2(114, 54, 6, 4), Color("#f64830"))
			draw_rect(Rect2(114, 58, 6, 6), Color("#266098"))
			draw_rect(Rect2(150, 48, 30, 24), Color("#1c223e"))
			draw_rect(Rect2(152, 50, 26, 20), Color("#0d0c14"))
			draw_rect(Rect2(156, 55, 7, 12), Color("#f68636"))
			draw_rect(Rect2(167, 55, 7, 12), Color("#a4e8ff"))
			if zo_tex:
				draw_texture_rect_region(zo_tex, Rect2(204, 118, 28, 28), Rect2(64, 32, 32, 32))
			draw_string(ThemeDB.fallback_font, Vector2(186, 104), "ENTER TV ->", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#a4e8ff"))
		"overworld":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#38b4ff"))
			draw_rect(Rect2(36, 28, 42, 12), Color(1, 1, 1, 0.72))
			draw_rect(Rect2(44, 22, 24, 8), Color(1, 1, 1, 0.72))
			draw_rect(Rect2(188, 34, 52, 12), Color(1, 1, 1, 0.65))
			draw_rect(Rect2(0, 132, 320, 48), Color("#4c941c"))
		"ice":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#1c2d4a"))
			draw_rect(Rect2(0, 124, 320, 56), Color("#2c4a72"))
		"volcano":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#220e12"))
			draw_rect(Rect2(0, 110, 320, 70), Color("#3c1418"))
		"factory":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#181c28"))
			var labels := ["液体痛み", "敗者の涙", "濃厚苦しみ"]
			for idx in 3:
				var tx := 44.0 + idx * 84.0
				if biome_tex:
					draw_texture_rect_region(biome_tex, Rect2(tx, 52, 36, 48), Rect2(16, 32, 16, 16))
				else:
					draw_rect(Rect2(tx, 52, 36, 48), Color("#18704e"))
				draw_string(ThemeDB.fallback_font, Vector2(tx - 2, 108), labels[idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#44eca8"))
			if zo_tex:
				draw_texture_rect_region(zo_tex, Rect2(16, 120, 26, 26), Rect2(64, 32, 32, 32))
		"void_yn":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#0d0c14"))
			draw_string(ThemeDB.fallback_font, Vector2(104, 34), "CONTINUE?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f6f8ff"))
			draw_string(ThemeDB.fallback_font, Vector2(124, 50), "=== 10 ===", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f6f8ff"))
			draw_rect(Rect2(76, 98, 28, 46), Color("#f68636"))
			draw_string(ThemeDB.fallback_font, Vector2(86, 92), "Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f6f8ff"))
			draw_rect(Rect2(216, 98, 28, 46), Color("#a4e8ff"))
			draw_string(ThemeDB.fallback_font, Vector2(226, 92), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f6f8ff"))
		"core":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#090810"))
		"glitch_escape":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#160c24"))
			draw_string(ThemeDB.fallback_font, Vector2(86, 28), "FOLLOW ZO! WATCH THE COCONUT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#a4e8ff"))

	for rect in tile_rects:
		_draw_terrain_rect(rect)

	for sg in decorative_signs:
		var pos: Vector2 = sg["pos"]
		var txt: String = sg.get("text", "-->")
		draw_rect(Rect2(pos.x - 1, pos.y, 2, 12), Color("#683a20"))
		draw_rect(Rect2(pos.x - 14, pos.y - 10, 28, 11), Color("#a66636"))
		draw_rect(Rect2(pos.x - 14, pos.y - 10, 28, 11), Color("#0d0c14"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(pos.x - 11, pos.y - 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#f6f8ff"))

	for sp in GameState.get_splats(room_id):
		var p: Vector2 = sp["pos"]
		var col: Color = sp["color"]
		draw_circle(p, 3.2, col)
		draw_circle(p + Vector2(-4, 2), 1.6, col)
		draw_circle(p + Vector2(3, -2), 1.4, col)


func _draw_terrain_rect(rect: Rect2) -> void:
	var cols := int(rect.size.x / 16.0)
	var rows := int(rect.size.y / 16.0)
	for r in rows:
		for c in cols:
			var tr := Rect2(rect.position.x + c * 16.0, rect.position.y + r * 16.0, 16.0, 16.0)
			if biome == "overworld" and tile_tex:
				var src_rect := Rect2(0, 0, 16, 16) if r == 0 else Rect2(16, 0, 16, 16)
				draw_texture_rect_region(tile_tex, tr, src_rect)
			elif biome == "ice" and biome_tex:
				var src_rect := Rect2(0, 0, 16, 16) if r == 0 else Rect2(16, 0, 16, 16)
				draw_texture_rect_region(biome_tex, tr, src_rect)
			elif biome == "volcano" and biome_tex:
				var src_rect := Rect2(0, 16, 16, 16) if r == 0 else Rect2(48, 16, 16, 16)
				draw_texture_rect_region(biome_tex, tr, src_rect)
			elif biome == "factory" and biome_tex:
				draw_texture_rect_region(biome_tex, tr, Rect2(0, 32, 16, 16))
			elif biome in ["core", "glitch_escape"] and biome_tex:
				draw_texture_rect_region(biome_tex, tr, Rect2(48, 32, 16, 16))
			elif biome == "living_room":
				draw_rect(tr, Color("#3a2820"))
				draw_rect(tr.grow(-1), Color("#684836") if r == 0 else Color("#4a3224"))
			else:
				draw_rect(tr, Color("#121422"))
				draw_rect(tr.grow(-1), Color("#282c42"))
				if r == 0:
					draw_rect(Rect2(tr.position.x, tr.position.y, 16.0, 4.0), Color("#646a7e"))


class _RoomDynamicOverlay extends Node2D:
	var owner_room: KaizoRoom

	func _init(r: KaizoRoom) -> void:
		owner_room = r

	func _draw() -> void:
		var t: float = owner_room.anim_t
		match owner_room.biome:
			"living_room":
				if owner_room.zo_tex:
					var tv_glow := Color(0.85, 0.95, 1.0, 0.85 + 0.15 * sin(t * 6.0))
					draw_texture_rect_region(owner_room.zo_tex, Rect2(236, 112, 34, 34), Rect2(96, 32, 32, 32), tv_glow)
			"core":
				var boss_y := 46.0 + sin(t * 2.5) * 3.0
				var boss_col := Color(0.65, 0.25, 0.95, 0.55) if owner_room.boss_glitched else Color.WHITE
				if owner_room.zo_tex:
					draw_texture_rect_region(owner_room.zo_tex, Rect2(262, boss_y, 44, 44), Rect2(0, 32, 32, 32), boss_col)
				if owner_room.boss_glitched:
					draw_string(ThemeDB.fallback_font, Vector2(142, 30), "CABLE SEVERED -> ESCAPE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#44eca8"))
				else:
					draw_string(ThemeDB.fallback_font, Vector2(146, 30), "PULL ZO'S HEART CABLE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#ffd41c"))
				for b in owner_room.boss_lasers:
					var ly: float = b["y"]
					if b["active"]:
						draw_rect(Rect2(0, ly - 5, 266, 10), Color(0.76, 0.11, 0.21, 0.55))
						draw_rect(Rect2(0, ly - 2.5, 266, 5), Color("#f6f8ff"))
					else:
						draw_line(Vector2(0, ly), Vector2(266, ly), Color(0.96, 0.28, 0.18, 0.65), 1.0)
			"glitch_escape":
				var vp := 14.0 + sin(t * 6.0) * 2.5
				draw_circle(Vector2(24, 130), vp, Color(0.22, 0.71, 1.0, 0.45))
				draw_circle(Vector2(24, 130), vp * 0.6, Color("#f6f8ff"))
				var gx := 230.0 - fmod(t * 52.0, 210.0)
				var gy := 108.0 - absf(sin(t * 3.8)) * 22.0
				if owner_room.zo_tex:
					draw_texture_rect_region(owner_room.zo_tex, Rect2(gx - 12, gy - 12, 24, 24), Rect2(96, 0, 32, 32), Color(0.64, 0.95, 1.0, 0.72))
