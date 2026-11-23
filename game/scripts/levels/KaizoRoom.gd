class_name KaizoRoom
extends Node2D
## High-FPS Pure Kaizo Trap (孔明の罠) WYSIWYG Room Builder (14 handcrafted rooms, 8 biomes).
## 100% authentic Kaizo Trap visual world & mechanics (NO Celeste visual lookalikes!):
##   - Golden Bagua Resonance Orbs, Industrial Steel Rail Platforms, ZhugeDOS Hex Code Curtains,
##     Wind Trigram Gust Zones, Ammonite Shells, Telegraphed Coconuts & Icicles, Winged Bagua Talismans.
## Static terrain & biome art stay cached (drawn ONCE per room load) for locked 120-240+ FPS!

signal room_exit_reached(next_room_id: String, is_kaizo_fakeout: bool)
signal good_ending_triggered()
signal short_ending_triggered()
signal heart_cable_severed()

var room_id: String = "room_00"
var biome: String = "overworld"
var spawn_pos: Vector2 = Vector2(28, 144)
var room_width: int = 320
var room_height: int = 180
var is_ice_room: bool = false

var tile_rects: Array[Rect2] = []
var decorative_signs: Array = []
var palm_positions: Array[Vector2] = []
var traps: Array[Node] = []
var shells: Array[AmmoniteShell] = []
var key_blocks: Array = []
var room_data: Dictionary = {}
var tile_tex: Texture2D = null
var biome_tex: Texture2D = null
var props_tex: Texture2D = null
var zo_tex: Texture2D = null
var anim_t: float = 0.0

var boss_lasers: Array[Dictionary] = []
var boss_timer: float = 0.0
var boss_glitched: bool = false
var exit_flag: KaizoTraps.GoalFlag = null
var dynamic_fx_layer: Node2D = null


func _ready() -> void:
	if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
		tile_tex = load("res://assets/tilesets/overworld_objects.png")
	if ResourceLoader.exists("res://assets/tilesets/biomes_tiles.png"):
		biome_tex = load("res://assets/tilesets/biomes_tiles.png")
	if ResourceLoader.exists("res://assets/tilesets/kaizo_props.png"):
		props_tex = load("res://assets/tilesets/kaizo_props.png")
	if ResourceLoader.exists("res://assets/sprites/zo_and_boss.png"):
		zo_tex = load("res://assets/sprites/zo_and_boss.png")


func build_from_spec(spec: Dictionary, arrange: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	tile_rects.clear()
	decorative_signs.clear()
	palm_positions.clear()
	traps.clear()
	shells.clear()
	key_blocks.clear()
	boss_lasers.clear()
	boss_glitched = false
	exit_flag = null

	room_data = spec
	room_id = spec.get("id", "room_00")
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

	# 3. Pure Kaizo Trap Golden Bagua Resonance Orbs (Refill Dash + Stamina)
	for bo in spec.get("bagua_orbs", []):
		var orb := KaizoMechanics.BaguaResonanceOrb.new()
		orb.position = Vector2(bo["x"], bo["y"])
		add_child(orb)
		traps.append(orb)

	# 4. Pure Kaizo Trap Industrial Steel Rail Platforms
	for sp_data in spec.get("steel_platforms", []):
		var plat := KaizoMechanics.SteelRailPlatform.new()
		plat.position = Vector2(sp_data["x"], sp_data["y"])
		plat.platform_size = Vector2(sp_data.get("w", 36.0), sp_data.get("h", 12.0))
		plat.travel_offset = Vector2(sp_data.get("dx", 72.0), sp_data.get("dy", 0.0))
		plat.speed = float(sp_data.get("speed", 1.15)) * (1.2 if arrange else 1.0)
		plat.trigger_on_step = bool(sp_data.get("trigger", false))
		add_child(plat)
		traps.append(plat)

	# 5. Pure Kaizo Trap ZhugeDOS / Assembly Hex Code Curtains (Dash-through!)
	for hc in spec.get("hex_curtains", []):
		var cur := KaizoMechanics.HexCodeCurtain.new()
		cur.position = Vector2(hc["x"], hc["y"])
		cur.block_size = Vector2(hc.get("w", 40.0), hc.get("h", 36.0))
		add_child(cur)
		traps.append(cur)

	# 6. Pure Kaizo Trap Wind Trigram (☴) Gust Zones
	for wz in spec.get("wind_zones", []):
		var gust := KaizoMechanics.WindGustZone.new()
		gust.position = Vector2(wz["x"], wz["y"])
		gust.zone_size = Vector2(wz.get("w", 84.0), wz.get("h", 92.0))
		gust.wind_accel = Vector2(wz.get("ax", 180.0), wz.get("ay", -180.0))
		add_child(gust)
		traps.append(gust)

	# 7. Kaizo Trap Red/Silver Omni-Directional Springs
	for ds in spec.get("dir_springs", []):
		var spr := KaizoMechanics.DirectionalSpring.new()
		spr.position = Vector2(ds["x"], ds["y"])
		spr.dir = ds.get("dir", "up")
		add_child(spr)
		traps.append(spr)

	# 8. Fair WYSIWYG Telegraphed Coconuts & Icicles (Shake + Sightline BEFORE drop!)
	for dr in spec.get("droppers", []):
		var d := KaizoMechanics.TelegraphedDropper.new()
		d.kind = dr.get("kind", "coconut")
		d.position = Vector2(dr["x"], dr["y"])
		d.ground_y = float(dr.get("ground_y", 144.0))
		d.trigger_x_range = float(dr.get("range", 34.0))
		d.telegraph_time = float(dr.get("telegraph", 0.36))
		if d.kind == "coconut":
			palm_positions.append(Vector2(dr["x"], dr["y"] - 8.0))
		add_child(d)
		traps.append(d)

	# 9. Rising Lava (Stage 3 Volcano)
	if spec.has("lava"):
		var lv: Dictionary = spec["lava"]
		var lava := KaizoTraps.RisingLava.new()
		lava.base_y = float(lv.get("base_y", 168.0))
		lava.amplitude = float(lv.get("amplitude", 26.0))
		lava.speed = float(lv.get("speed", 1.35)) * (1.2 if arrange else 1.0)
		lava.position = Vector2(0, lava.base_y)
		add_child(lava)
		traps.append(lava)

	# 10. Patrolling Sawblades (Stage 4 Factory)
	for sw in spec.get("sawblades", []):
		var saw := KaizoTraps.SawbladeHazard.new()
		saw.position = Vector2(sw["x"], sw["y"])
		saw.patrol_delta = Vector2(sw.get("dx", 48.0), sw.get("dy", 0.0))
		saw.speed = float(sw.get("speed", 1.75)) * (1.2 if arrange else 1.0)
		add_child(saw)
		traps.append(saw)

	# 11. Crumble blocks
	for cb in spec.get("crumbles", []):
		var cblk := KaizoTraps.CrumbleBlock.new()
		cblk.position = Vector2(cb[0] * 16.0 + 8.0, cb[1] * 16.0 + 8.0)
		add_child(cblk)
		traps.append(cblk)

	# 12. Ammonite Shells (Canonical Shell Jump!)
	for sh in spec.get("shells", []):
		var shell := AmmoniteShell.new()
		shell.position = Vector2(sh[0], sh[1])
		add_child(shell)
		shells.append(shell)

	# 13. Keys & 7M01S Key Blocks
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

	# 14. Zo Heart Cable Pod (Stage 5 Core Rescue!)
	if spec.has("heart_pod"):
		var hp: Dictionary = spec["heart_pod"]
		var pod := KaizoTraps.HeartCablePod.new()
		pod.position = Vector2(hp["x"], hp["y"])
		pod.cable_pulled.connect(_on_heart_cable_pulled)
		add_child(pod)
		traps.append(pod)

	# 15. Winged Golden Bagua Talismans (Optional Skill Collectibles!)
	for bg in spec.get("baguas", []):
		var bp := KaizoMechanics.BaguaTalisman.new()
		bp.position = Vector2(bg["x"], bg["y"])
		bp.trigram_id = bg["id"]
		add_child(bp)
		traps.append(bp)

	decorative_signs = spec.get("signs", [])

	# 16. Exit Goal Flag / TV Portal / Escape Vortex
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

	# Lightweight dynamic overlay so static tiles NEVER redraw per frame!
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
	if dynamic_fx_layer and biome in ["core", "glitch_escape", "living_room", "code_vortex", "void_yn"]:
		dynamic_fx_layer.queue_redraw()


func _update_boss_lasers(delta: float) -> void:
	boss_timer += delta
	var cycle := fmod(boss_timer, 3.4)
	boss_lasers.clear()
	var beam_y := 124.0 if int(boss_timer / 3.4) % 2 == 0 else 142.0
	if cycle > 1.35 and cycle < 2.25:
		boss_lasers.append({"y": beam_y, "active": false})
	elif cycle >= 2.25 and cycle < 2.85:
		boss_lasers.append({"y": beam_y, "active": true})
		for p in get_tree().get_nodes_in_group("player"):
			if p is KaiPlayer and not p.is_dead:
				var py: float = p.global_position.y - 6.0
				if absf(py - beam_y) < 7.0:
					p.kill("laser")


func _draw() -> void:
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
		"code_vortex":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#07101e"))
		"overworld":
			draw_rect(Rect2(0, 0, room_width, room_height), Color("#38b4ff"))
			draw_rect(Rect2(36, 28, 42, 12), Color(1, 1, 1, 0.72))
			draw_rect(Rect2(44, 22, 24, 8), Color(1, 1, 1, 0.72))
			draw_rect(Rect2(188, 34, 52, 12), Color(1, 1, 1, 0.65))
			draw_rect(Rect2(0, 132, 320, 48), Color("#4c941c"))
			# Draw visible tropical palm tree behind any coconut dropper!
			for pp in palm_positions:
				draw_rect(Rect2(pp.x - 3, pp.y + 4, 6, 102), Color("#7a4a24"))
				if props_tex:
					draw_texture_rect_region(props_tex, Rect2(pp.x - 16, pp.y - 12, 32, 24), Rect2(0, 16, 16, 16))
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
			for pp in palm_positions:
				draw_rect(Rect2(pp.x - 3, pp.y + 4, 6, 102), Color("#4a2844"))
			draw_string(ThemeDB.fallback_font, Vector2(80, 28), "FOLLOW ZO! WATCH THE COCONUT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#a4e8ff"))

	for rect in tile_rects:
		_draw_terrain_rect(rect)

	for sg in decorative_signs:
		var pos: Vector2 = sg["pos"]
		var txt: String = sg.get("text", "-->")
		draw_rect(Rect2(pos.x - 1, pos.y, 2, 12), Color("#683a20"))
		draw_rect(Rect2(pos.x - 16, pos.y - 10, 32, 11), Color("#a66636"))
		draw_rect(Rect2(pos.x - 16, pos.y - 10, 32, 11), Color("#0d0c14"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(pos.x - 13, pos.y - 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#f6f8ff"))

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
			elif biome in ["core", "glitch_escape", "code_vortex"] and biome_tex:
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
	const ASM_LINES: Array[String] = [
		"LDA #$57  ; ZHUGEDOS_14",
		"STA $1983 ; KONGMING_TRAP",
		"JSR OBJ_PLAYER_FALL",
		"BNE 0x4569676874",
		"CMP #$77  ; LOOP_CHECK",
		"JMP PARADIGM_CORE"
	]

	func _init(r: KaizoRoom) -> void:
		owner_room = r

	func _draw() -> void:
		var t: float = owner_room.anim_t
		match owner_room.biome:
			"living_room":
				if owner_room.zo_tex:
					var tv_glow := Color(0.85, 0.95, 1.0, 0.85 + 0.15 * sin(t * 6.0))
					draw_texture_rect_region(owner_room.zo_tex, Rect2(236, 112, 34, 34), Rect2(96, 32, 32, 32), tv_glow)
			"code_vortex":
				# Iconic 1:23 scrolling assembly source code wall!
				for i in 12:
					var yy: float = fmod(float(i) * 16.0 - t * 44.0, 192.0)
					if yy < 0.0:
						yy += 192.0
					var line: String = ASM_LINES[i % ASM_LINES.size()]
					draw_string(ThemeDB.fallback_font, Vector2(18 + (i % 3) * 86, yy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.26, 0.86, 0.72, 0.24))
			"void_yn":
				# Subtle scrolling 'Can't Beat Air Man' katakana motif in the void (3:42!)
				for i in 6:
					var yy: float = fmod(float(i) * 32.0 + t * 18.0, 188.0)
					draw_string(ThemeDB.fallback_font, Vector2(16 + (i % 2) * 210, yy), "エアーマンが倒せない", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.10))
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
				# Blue Black-Hole Information Paradox vortex (7:09!) + Zo guiding ghost silhouette (6:12!)
				var vp := 14.0 + sin(t * 6.0) * 2.5
				draw_circle(Vector2(24, 130), vp, Color(0.22, 0.71, 1.0, 0.45))
				draw_circle(Vector2(24, 130), vp * 0.6, Color("#f6f8ff"))
				var gx := 230.0 - fmod(t * 52.0, 210.0)
				var gy := 108.0 - absf(sin(t * 3.8)) * 22.0
				if owner_room.zo_tex:
					draw_texture_rect_region(owner_room.zo_tex, Rect2(gx - 12, gy - 12, 24, 24), Rect2(96, 0, 32, 32), Color(0.64, 0.95, 1.0, 0.72))
