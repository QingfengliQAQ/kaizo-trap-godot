class_name KaizoTraps
extends Node
## Collection of factory helpers & lightweight trap classes for Kaizo Trap (孔明の罠):
##   - InvisibleBaguaBlock (golden Bagua block, materializes only when hit from below!)
##   - SpikeStrip (electric blue spikes, lethal on contact)
##   - FallingCoconut (Stage 1 iconic overhead trap + return-trip dodge callback)
##   - CrumbleTile (collapses after stepping on it)
##   - SpringPad (high vertical boost)
##   - KeyBlock701 (unlockable via carried key OR CRT Cursor click -> Ending 1!)
##   - GoalFlag (normal goal OR Victory-Cutscene Kaizo Trap fakeout!)
##   - BaguaEmblem (hidden collectible trigram)


class InvisibleBaguaBlock extends StaticBody2D:
	var revealed: bool = false
	var trigram_symbol: String = "☷"
	var trigger_area: Area2D
	var col_shape: CollisionShape2D
	var bump_offset: float = 0.0
	var tile_tex: Texture2D = null

	func _ready() -> void:
		collision_layer = 0 # Ghost until hit from below!
		collision_mask = 0
		col_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 16)
		col_shape.shape = rect
		col_shape.disabled = true
		add_child(col_shape)

		trigger_area = Area2D.new()
		trigger_area.collision_layer = 8
		trigger_area.collision_mask = 2
		var t_shape := CollisionShape2D.new()
		var t_rect := RectangleShape2D.new()
		t_rect.size = Vector2(14, 6)
		t_shape.shape = t_rect
		t_shape.position = Vector2(0, 8)
		trigger_area.add_child(t_shape)
		trigger_area.body_entered.connect(_on_body_entered)
		add_child(trigger_area)

		if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
			tile_tex = load("res://assets/tilesets/overworld_objects.png")

	func reset_trap() -> void:
		revealed = false
		collision_layer = 0
		col_shape.set_deferred("disabled", true)
		bump_offset = 0.0
		queue_redraw()

	func _on_body_entered(body: Node) -> void:
		if revealed:
			return
		if body is KaiPlayer and not body.is_dead and body.velocity.y < -15.0:
			reveal(body)

	func reveal(player: KaiPlayer) -> void:
		revealed = true
		collision_layer = 8 # KaizoHidden now solid!
		col_shape.set_deferred("disabled", false)
		player.velocity.y = 45.0 # Classic Kaizo bonk straight into the pit!
		bump_offset = -4.0
		AudioManager.play_sfx("kaizo_block", 0.04, -2.0)
		queue_redraw()

	func _process(delta: float) -> void:
		if bump_offset < 0.0:
			bump_offset = min(0.0, bump_offset + 28.0 * delta)
			queue_redraw()
		elif GameState.assist_show_hidden_blocks and not revealed:
			queue_redraw()

	func _draw() -> void:
		if not revealed:
			if GameState.difficulty == GameState.DifficultyMode.ASSIST and GameState.assist_show_hidden_blocks:
				draw_rect(Rect2(-8, -8, 16, 16), Color(1.0, 0.83, 0.11, 0.45), false, 1.0)
			return
		var rect := Rect2(-8, -8 + bump_offset, 16, 16)
		if tile_tex:
			# Cell (2, 0): golden Bagua Kaizo block
			draw_texture_rect_region(tile_tex, rect, Rect2(32, 0, 16, 16))
		else:
			draw_rect(rect, Color("#0d0c14"))
			draw_rect(rect.grow(-1), Color("#ffd41c"))
			# Draw Earth trigram ☷ (six horizontal bars)
			for row in 3:
				var yy := -4 + row * 4 + bump_offset
				draw_rect(Rect2(-5, yy, 4, 1.5), Color("#ce8a12"))
				draw_rect(Rect2(1, yy, 4, 1.5), Color("#ce8a12"))


class SpikeHazard extends Area2D:
	var width_tiles: int = 1
	var direction: String = "up" # up, down, left, right
	var death_kind: String = "spike"
	var tile_tex: Texture2D = null

	func _ready() -> void:
		collision_layer = 4 # Hazards
		collision_mask = 2 # Player
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		if direction in ["up", "down"]:
			rect.size = Vector2(width_tiles * 16 - 4, 7)
			shape.position = Vector2((width_tiles * 16) * 0.5, 4 if direction == "up" else -4)
		else:
			rect.size = Vector2(7, width_tiles * 16 - 4)
			shape.position = Vector2(4 if direction == "left" else -4, (width_tiles * 16) * 0.5)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_body_entered)
		if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
			tile_tex = load("res://assets/tilesets/overworld_objects.png")

	func _on_body_entered(body: Node) -> void:
		if body is KaiPlayer:
			body.kill(death_kind)

	func _draw() -> void:
		var col := Color("#a4e8ff") if death_kind == "spike" else Color("#f64830")
		var outline := Color("#0d0c14")
		for i in width_tiles:
			if direction == "up":
				var x := i * 16.0
				for k in 2:
					var bx := x + k * 8.0
					var pts := PackedVector2Array([Vector2(bx, 8), Vector2(bx + 4, -2), Vector2(bx + 8, 8)])
					draw_colored_polygon(pts, col)
					draw_polyline(pts, outline, 1.0)
			elif direction == "down":
				var x := i * 16.0
				for k in 2:
					var bx := x + k * 8.0
					var pts := PackedVector2Array([Vector2(bx, -8), Vector2(bx + 4, 2), Vector2(bx + 8, -8)])
					draw_colored_polygon(pts, col)
					draw_polyline(pts, outline, 1.0)
			elif direction == "left":
				var y := i * 16.0
				for k in 2:
					var by := y + k * 8.0
					var pts := PackedVector2Array([Vector2(8, by), Vector2(-2, by + 4), Vector2(8, by + 8)])
					draw_colored_polygon(pts, col)
					draw_polyline(pts, outline, 1.0)
			elif direction == "right":
				var y := i * 16.0
				for k in 2:
					var by := y + k * 8.0
					var pts := PackedVector2Array([Vector2(-8, by), Vector2(2, by + 4), Vector2(-8, by + 8)])
					draw_colored_polygon(pts, col)
					draw_polyline(pts, outline, 1.0)


class FallingCoconut extends Area2D:
	var spawn_pos: Vector2 = Vector2.ZERO
	var triggered: bool = false
	var landed: bool = false
	var fall_vy: float = 0.0
	var trigger_x_range: float = 18.0
	var ground_y: float = 148.0
	var tile_tex: Texture2D = null

	func _ready() -> void:
		spawn_pos = position
		collision_layer = 4
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 5.5
		shape.shape = circ
		add_child(shape)
		body_entered.connect(_on_hit)
		if ResourceLoader.exists("res://assets/tilesets/overworld_objects.png"):
			tile_tex = load("res://assets/tilesets/overworld_objects.png")

	func reset_trap() -> void:
		position = spawn_pos
		triggered = false
		landed = false
		fall_vy = 0.0
		queue_redraw()

	func _physics_process(delta: float) -> void:
		if landed:
			return
		if not triggered:
			var players := get_tree().get_nodes_in_group("player")
			for p in players:
				if p is KaiPlayer and not p.is_dead:
					if abs(p.global_position.x - global_position.x) < trigger_x_range and p.global_position.y > global_position.y:
						triggered = true
						fall_vy = 35.0
						break
		else:
			fall_vy = min(fall_vy + 680.0 * delta, 320.0)
			position.y += fall_vy * delta
			if position.y >= ground_y:
				position.y = ground_y
				landed = true
				AudioManager.play_sfx("land", 0.1, -4.0)

	func _on_hit(body: Node) -> void:
		if triggered and not landed and body is KaiPlayer:
			body.kill("coconut")

	func _draw() -> void:
		if tile_tex:
			draw_texture_rect_region(tile_tex, Rect2(-8, -8, 16, 16), Rect2(16, 32, 16, 16))
		else:
			draw_circle(Vector2.ZERO, 6.0, Color("#0d0c14"))
			draw_circle(Vector2.ZERO, 5.0, Color("#a66636"))
			draw_circle(Vector2(-1.5, -1.5), 1.0, Color("#683a20"))
			draw_circle(Vector2(1.5, -1.5), 1.0, Color("#683a20"))


class CrumbleBlock extends StaticBody2D:
	var triggered: bool = false
	var broken: bool = false
	var timer: float = 0.0
	var col_shape: CollisionShape2D
	var sensor: Area2D

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		col_shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 16)
		col_shape.shape = rect
		add_child(col_shape)

		sensor = Area2D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 2
		var s_shape := CollisionShape2D.new()
		var s_rect := RectangleShape2D.new()
		s_rect.size = Vector2(16, 4)
		s_shape.shape = s_rect
		s_shape.position = Vector2(0, -9)
		sensor.add_child(s_shape)
		sensor.body_entered.connect(_on_stepped)
		add_child(sensor)

	func reset_trap() -> void:
		triggered = false
		broken = false
		timer = 0.0
		col_shape.set_deferred("disabled", false)
		visible = true
		queue_redraw()

	func _on_stepped(body: Node) -> void:
		if not triggered and body is KaiPlayer:
			triggered = true
			timer = 0.36
			AudioManager.play_sfx("kaizo_block", 0.25, -8.0)

	func _process(delta: float) -> void:
		if triggered and not broken:
			timer -= delta
			queue_redraw()
			if timer <= 0.0:
				broken = true
				col_shape.set_deferred("disabled", true)
				visible = false

	func _draw() -> void:
		if broken:
			return
		var jitter := Vector2(randf_range(-1.0, 1.0), 0) if triggered else Vector2.ZERO
		draw_rect(Rect2(Vector2(-8, -8) + jitter, Vector2(16, 16)), Color("#0d0c14"))
		draw_rect(Rect2(Vector2(-7, -7) + jitter, Vector2(14, 14)), Color("#646a7e"))
		draw_line(Vector2(-4, -5) + jitter, Vector2(2, 1) + jitter, Color("#1c223e"), 1.0)
		draw_line(Vector2(2, 1) + jitter, Vector2(-1, 6) + jitter, Color("#1c223e"), 1.0)


class SpringPad extends Area2D:
	var boost: float = -335.0
	var bounce_anim: float = 0.0

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 8)
		shape.shape = rect
		shape.position = Vector2(0, 4)
		add_child(shape)
		body_entered.connect(_on_enter)

	func _on_enter(body: Node) -> void:
		if body is KaiPlayer and not body.is_dead:
			body.apply_spring(boost)
			bounce_anim = 1.0

	func _process(delta: float) -> void:
		if bounce_anim > 0.0:
			bounce_anim = max(0.0, bounce_anim - 5.0 * delta)
			queue_redraw()

	func _draw() -> void:
		var stretch := bounce_anim * 4.0
		draw_rect(Rect2(-7, 4, 14, 4), Color("#646a7e"))
		draw_rect(Rect2(-6, -1 - stretch, 12, 4), Color("#f64830"))
		draw_line(Vector2(-4, 4), Vector2(4, 2 - stretch), Color("#aab2c6"), 1.5)


class KeyBlock701 extends Area2D:
	signal secret_ending_triggered()
	var key_id: String = "stage1_key"
	var unlocked: bool = false
	var hover_glow: float = 0.0

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 16)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_touch)

	func _on_touch(body: Node) -> void:
		if body is KaiPlayer and (GameState.has_key(key_id) or SecretManager.key_block_701_clicked):
			_trigger_good_ending()

	func try_crt_click(world_click: Vector2) -> bool:
		if global_position.distance_to(world_click) <= 18.0:
			SecretManager.key_block_701_clicked = true
			SecretManager.unlock_secret("crt_click_keyblock", "Clicked the 7M01S Key Block Annotation!")
			_trigger_good_ending()
			return true
		return false

	func _trigger_good_ending() -> void:
		if unlocked:
			return
		unlocked = true
		AudioManager.play_sfx("secret", 0.0, -2.0)
		SecretManager.unlock_ending("good")
		secret_ending_triggered.emit()
		queue_redraw()

	func _process(delta: float) -> void:
		hover_glow += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(hover_glow)
		# Classic white keyhole pedestal from manual 1:44 / ref_07.png
		draw_rect(Rect2(-10, -6, 20, 14), Color("#1c223e"))
		draw_rect(Rect2(-9, -5, 18, 12), Color("#f6f8ff"))
		draw_circle(Vector2(0, -1), 2.2, Color("#1c223e"))
		draw_rect(Rect2(-1, 0, 2, 4), Color("#1c223e"))
		if SecretManager.key_block_701_clicked or GameState.has_key(key_id):
			draw_rect(Rect2(-12, -8, 24, 18), Color(0.96, 0.53, 0.21, 0.35 + 0.45 * pulse), false, 1.5)


class GoalFlag extends Area2D:
	signal room_cleared(is_kaizo_fakeout: bool)
	var is_kaizo_fakeout: bool = false
	var triggered: bool = false

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 28)
		shape.shape = rect
		shape.position = Vector2(0, -14)
		add_child(shape)
		body_entered.connect(_on_enter)

	func reset_trap() -> void:
		triggered = false

	func _on_enter(body: Node) -> void:
		if triggered:
			return
		if body is KaiPlayer and not body.is_dead:
			triggered = true
			if is_kaizo_fakeout:
				# Iconic Hope Spot -> Victory Cutscene Kaizo Trap!
				AudioManager.play_sfx("death_glitch", 0.02, -1.0)
				SecretManager.unlock_ending("normal")
			else:
				AudioManager.play_sfx("key_get", 0.0, -3.0)
			room_cleared.emit(is_kaizo_fakeout)

	func _draw() -> void:
		draw_rect(Rect2(-1, -28, 2, 28), Color("#aab2c6"))
		draw_circle(Vector2(0, -29), 2.5, Color("#ffd41c"))
		var pts := PackedVector2Array([Vector2(1, -27), Vector2(14, -22), Vector2(1, -17)])
		draw_colored_polygon(pts, Color("#f64830") if not is_kaizo_fakeout else Color("#c21834"))


class KeyPickup extends Area2D:
	var key_id: String = "stage1_key"
	var collected: bool = false
	var t: float = 0.0

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 7.0
		shape.shape = circ
		add_child(shape)
		body_entered.connect(_on_collect)

	func _on_collect(body: Node) -> void:
		if collected or not (body is KaiPlayer):
			return
		collected = true
		GameState.collect_key(key_id)
		AudioManager.play_sfx("key_get", 0.0, -2.0)
		visible = false

	func _process(delta: float) -> void:
		t += delta * 4.0
		queue_redraw()

	func _draw() -> void:
		if collected:
			return
		var y := sin(t) * 2.0
		draw_rect(Rect2(-4, -6 + y, 8, 6), Color("#1c223e"))
		draw_rect(Rect2(-3, -5 + y, 6, 4), Color("#f6f8ff"))
		draw_rect(Rect2(-1, 0 + y, 2, 6), Color("#aab2c6"))
		draw_rect(Rect2(1, 3 + y, 2, 2), Color("#aab2c6"))


class BaguaPickup extends Area2D:
	var trigram_id: String = "earth"
	var t: float = 0.0

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 8.0
		shape.shape = circ
		add_child(shape)
		body_entered.connect(_on_collect)

	func _on_collect(body: Node) -> void:
		if body is KaiPlayer and not SecretManager.discovered_trigrams.get(trigram_id, false):
			SecretManager.unlock_trigram(trigram_id)
			AudioManager.play_sfx("secret", 0.04, -3.0)
			queue_redraw()

	func _process(delta: float) -> void:
		t += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var found: bool = bool(SecretManager.discovered_trigrams.get(trigram_id, false))
		var alpha: float = 0.25 if found else (0.75 + 0.25 * sin(t))
		var col := Color(1.0, 0.83, 0.11, alpha)
		draw_circle(Vector2.ZERO, 7.0, Color(0.11, 0.13, 0.24, alpha * 0.7))
		for r in 3:
			var yy := -3.5 + r * 3.0
			draw_rect(Rect2(-4, yy, 3.2, 1.4), col)
			draw_rect(Rect2(0.8, yy, 3.2, 1.4), col)


class FallingIcicle extends Area2D:
	var spawn_pos: Vector2 = Vector2.ZERO
	var triggered: bool = false
	var landed: bool = false
	var fall_vy: float = 0.0
	var ground_y: float = 148.0
	var biome_tex: Texture2D = null

	func _ready() -> void:
		spawn_pos = position
		collision_layer = 4
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 13)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(func(b):
			if triggered and not landed and b is KaiPlayer:
				b.kill("spike")
		)
		if ResourceLoader.exists("res://assets/tilesets/biomes_tiles.png"):
			biome_tex = load("res://assets/tilesets/biomes_tiles.png")

	func reset_trap() -> void:
		position = spawn_pos
		triggered = false
		landed = false
		fall_vy = 0.0
		queue_redraw()

	func _physics_process(delta: float) -> void:
		if landed:
			return
		if not triggered:
			for p in get_tree().get_nodes_in_group("player"):
				if p is KaiPlayer and not p.is_dead:
					if absf(p.global_position.x - global_position.x) < 22.0 and p.global_position.y > global_position.y:
						triggered = true
						fall_vy = 45.0
						break
		else:
			fall_vy = minf(fall_vy + 760.0 * delta, 340.0)
			position.y += fall_vy * delta
			if position.y >= ground_y:
				position.y = ground_y
				landed = true
				AudioManager.play_sfx("land", 0.15, -6.0)

	func _draw() -> void:
		if biome_tex:
			draw_texture_rect_region(biome_tex, Rect2(-8, -8, 16, 16), Rect2(32, 0, 16, 16))
		else:
			var pts := PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(0, 8)])
			draw_colored_polygon(pts, Color("#a4e8ff"))


class RisingLava extends Area2D:
	var base_y: float = 166.0
	var amplitude: float = 24.0
	var speed: float = 1.6
	var t: float = 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(320, 40)
		shape.shape = rect
		shape.position = Vector2(160, 20)
		add_child(shape)
		body_entered.connect(func(b):
			if b is KaiPlayer:
				b.kill("lava")
		)

	func reset_trap() -> void:
		t = 0.0
		position.y = base_y

	func _physics_process(delta: float) -> void:
		t += delta * speed
		var wave := 0.5 - 0.5 * cos(t)
		position.y = base_y - wave * amplitude
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 320, 6), Color("#ffd41c"))
		draw_rect(Rect2(0, 4, 320, 56), Color("#f64830"))
		for i in 16:
			var bx := i * 20.0 + sin(t * 2.0 + float(i)) * 4.0
			draw_circle(Vector2(bx, 3.0), 2.5, Color("#ffd41c"))


class SawbladeHazard extends Area2D:
	var origin: Vector2 = Vector2.ZERO
	var patrol_delta: Vector2 = Vector2(48, 0)
	var speed: float = 2.0
	var t: float = 0.0
	var biome_tex: Texture2D = null

	func _ready() -> void:
		origin = position
		collision_layer = 4
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 6.5
		shape.shape = circ
		add_child(shape)
		body_entered.connect(func(b):
			if b is KaiPlayer:
				b.kill("spike")
		)
		if ResourceLoader.exists("res://assets/tilesets/biomes_tiles.png"):
			biome_tex = load("res://assets/tilesets/biomes_tiles.png")

	func reset_trap() -> void:
		t = 0.0
		position = origin

	func _physics_process(delta: float) -> void:
		t += delta * speed
		position = origin + patrol_delta * (0.5 - 0.5 * cos(t))
		rotation += delta * 12.0
		queue_redraw()

	func _draw() -> void:
		if biome_tex:
			draw_texture_rect_region(biome_tex, Rect2(-8, -8, 16, 16), Rect2(32, 32, 16, 16))
		else:
			draw_circle(Vector2.ZERO, 7.0, Color("#aab2c6"))
			draw_circle(Vector2.ZERO, 3.0, Color("#c21834"))


class HeartCablePod extends Area2D:
	signal cable_pulled()
	var pulled: bool = false
	var t: float = 0.0
	var zo_tex: Texture2D = null

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(26, 30)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_touch)
		if ResourceLoader.exists("res://assets/sprites/zo_and_boss.png"):
			zo_tex = load("res://assets/sprites/zo_and_boss.png")

	func reset_trap() -> void:
		pulled = false
		queue_redraw()

	func _on_touch(body: Node) -> void:
		if pulled or not (body is KaiPlayer):
			return
		pulled = true
		SecretManager.unlock_secret("heart_cable_pulled", "Zo pulled the Heart Cable! Boss glitching!")
		AudioManager.play_sfx("death_glitch", 0.0, -1.0)
		cable_pulled.emit()
		queue_redraw()

	func _process(delta: float) -> void:
		t += delta * 4.0
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t)
		if not pulled:
			# Glowing heart cable line to Core Boss
			draw_line(Vector2(10, 0), Vector2(44, -28), Color(0.95, 0.25, 0.35, 0.65 + 0.35 * pulse), 2.0)
		if zo_tex:
			# Cell (2, 0): Zo in containment pod
			var mod := Color(0.65, 1.0, 0.9, 0.6) if pulled else Color.WHITE
			draw_texture_rect_region(zo_tex, Rect2(-16, -16, 32, 32), Rect2(64, 0, 32, 32), mod)
		else:
			draw_rect(Rect2(-12, -14, 24, 28), Color("#282c42"))
			draw_rect(Rect2(-10, -12, 20, 24), Color("#4ab8ff"))
