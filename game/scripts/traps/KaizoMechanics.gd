class_name KaizoMechanics
extends Node
## Sight-readable Kaizo props. Positions are centers; dropper ground_y is world Y.


class Helpers:
	static func as_player(body: Object) -> CharacterBody2D:
		if not body is CharacterBody2D:
			return null
		var player_script: Script = body.get_script() as Script
		while player_script != null:
			if player_script.get_global_name() == &"KaiPlayer":
				return body as CharacterBody2D
			player_script = player_script.get_base_script()
		return null

	static func rectangle_body(owner_node: CollisionObject2D, size: Vector2) -> CollisionShape2D:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = size
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		owner_node.add_child(collision)
		return collision


	static func circle_body(owner_node: CollisionObject2D, radius: float) -> void:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = radius
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		owner_node.add_child(collision)


	static func draw_trigram(canvas: CanvasItem, center: Vector2, trigram: String, ink: Color) -> void:
		# Bits run bottom to top: yin is broken, yang is solid.
		var bits: int = 0
		match trigram:
			"heaven": bits = 7
			"lake": bits = 3
			"fire": bits = 5
			"thunder": bits = 1
			"wind": bits = 6
			"water": bits = 2
			"mountain": bits = 4
		for row: int in 3:
			var y: float = center.y + 3.0 - float(row) * 3.0
			if (bits & (1 << row)) != 0:
				canvas.draw_line(Vector2(center.x - 4.0, y), Vector2(center.x + 4.0, y), ink, 1.5)
			else:
				canvas.draw_line(Vector2(center.x - 4.0, y), Vector2(center.x - 1.0, y), ink, 1.5)
				canvas.draw_line(Vector2(center.x + 1.0, y), Vector2(center.x + 4.0, y), ink, 1.5)


class BaguaResonanceOrb extends Area2D:
	const COOLDOWN: float = 2.2
	const SHEET: String = "res://assets/tilesets/kaizo_props.png"
	var active: bool = true
	var cooldown_left: float = 0.0
	var animation_time: float = 0.0
	var texture: Texture2D = null
	var spark_time: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		Helpers.circle_body(self, 8.0)
		body_entered.connect(_on_body_entered)
		if ResourceLoader.exists(SHEET):
			texture = load(SHEET) as Texture2D
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _physics_process(delta: float) -> void:
		if not active:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			if cooldown_left == 0.0:
				active = true
				set_deferred("monitoring", true)

	func _process(delta: float) -> void:
		animation_time += delta
		spark_time = maxf(0.0, spark_time - delta)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		var player: CharacterBody2D = Helpers.as_player(body)
		if not active or player == null or bool(player.get("is_dead")):
			return
		active = false
		cooldown_left = COOLDOWN
		set_deferred("monitoring", false)
		player.call("refill_dash_and_stamina", true)
		get_node("/root/AudioManager").call("play_sfx", "crystal_refill")
		spark_time = 0.45

	func reset_trap() -> void:
		active = true
		cooldown_left = 0.0
		spark_time = 0.0
		animation_time = 0.0
		set_deferred("monitoring", true)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = Vector2(0.0, sin(animation_time * 3.0))
		var gold: Color = Color("ffd34e") if active else Color("766642")
		if active:
			draw_circle(center, 12.0, Color(1.0, 0.75, 0.16, 0.10))
			draw_circle(center, 9.5, Color(1.0, 0.8, 0.2, 0.18))
		if texture != null and texture.get_width() >= 32 and texture.get_height() >= 16:
			var cell_x: float = 0.0 if active else 16.0
			draw_texture_rect_region(texture, Rect2(center - Vector2(8, 8), Vector2(16, 16)), Rect2(cell_x, 0, 16, 16))
		else:
			draw_circle(center, 7.0, gold)
			draw_arc(center, 7.0, 0.0, TAU, 32, Color("fff0ac"), 1.0)
			Helpers.draw_trigram(self, center, "heaven", Color("634016"))
		for index: int in 12:
			if spark_time <= 0.0:
				break
			var age: float = 0.45 - spark_time
			var point: Vector2 = Vector2.from_angle(TAU * float(index) / 12.0) * age * 64.0
			point.y += 40.0 * age * age
			draw_rect(Rect2(point, Vector2(2, 2)), Color(1.0, 0.83, 0.28, spark_time / 0.45))


class SteelRailPlatform extends AnimatableBody2D:
	enum Motion { IDLE, OUTBOUND, PAUSED, RETURNING }
	@export var platform_size: Vector2 = Vector2(36, 12)
	@export var travel_offset: Vector2 = Vector2(72, 0)
	## Traversals per second; cosine easing gives zero endpoint velocity.
	@export var speed: float = 1.15
	@export var trigger_on_step: bool = false
	var origin: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	var state: Motion = Motion.IDLE
	var sensor: Area2D = null

	func _ready() -> void:
		origin = position
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		process_physics_priority = -10
		Helpers.rectangle_body(self, platform_size)
		sensor = Area2D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 2
		add_child(sensor)
		Helpers.rectangle_body(sensor, Vector2(platform_size.x, 4.0))
		sensor.position.y = -platform_size.y * 0.5 - 2.0

	func _top_riders() -> Array[CharacterBody2D]:
		var result: Array[CharacterBody2D] = []
		for body: Node2D in sensor.get_overlapping_bodies():
			var player: CharacterBody2D = Helpers.as_player(body)
			if player == null or bool(player.get("is_dead")) or not player.is_on_floor():
				continue
			var feet: Vector2 = to_local(player.global_position)
			if absf(feet.y + platform_size.y * 0.5) <= 3.0 and absf(feet.x) < platform_size.x * 0.5 + 4.0:
				result.append(player)
		return result

	func _physics_process(delta: float) -> void:
		if not trigger_on_step:
			phase = fposmod(phase + delta * maxf(speed, 0.0), 2.0)
			position = origin + travel_offset * (0.5 - 0.5 * cos(phase * PI))
		else:
			match state:
				Motion.IDLE:
					if not _top_riders().is_empty():
						state = Motion.OUTBOUND
						phase = 0.0
				Motion.OUTBOUND, Motion.RETURNING:
					phase = minf(1.0, phase + delta * maxf(speed, 0.0))
					var weight: float = 0.5 - 0.5 * cos(phase * PI)
					if state == Motion.RETURNING:
						weight = 1.0 - weight
					position = origin + travel_offset * weight
					if phase >= 1.0:
						if state == Motion.OUTBOUND:
							for player: CharacterBody2D in _top_riders():
								player.call("apply_zip_launch", travel_offset.normalized() * 35.0)
							state = Motion.PAUSED
						else:
							state = Motion.IDLE
						phase = 0.0
				Motion.PAUSED:
					phase += delta
					if phase >= 0.4:
						state = Motion.RETURNING
						phase = 0.0
		# CharacterBody2D receives platform velocity from the physics server.
		# Never translate riders manually: that would apply the movement twice.
		queue_redraw()

	func reset_trap() -> void:
		phase = 0.0
		state = Motion.IDLE
		position = origin
		reset_physics_interpolation()
		queue_redraw()

	func _draw() -> void:
		var start: Vector2 = origin - position
		var finish: Vector2 = start + travel_offset
		draw_dashed_line(start, finish, Color("76818c"), 2.0, 5.0)
		for endpoint: Vector2 in [start, finish]:
			draw_circle(endpoint, 4.0, Color("a8b4bd"))
			draw_line(endpoint - Vector2(2, 0), endpoint + Vector2(2, 0), Color("323d47"), 1.0)
		var deck: Rect2 = Rect2(-platform_size * 0.5, platform_size)
		draw_rect(deck, Color("29333d"))
		draw_rect(deck.grow(-1.0), Color("73828d"))
		var stripe: Rect2 = Rect2(deck.position + Vector2(1, platform_size.y - 5.0), Vector2(platform_size.x - 2.0, 4))
		draw_rect(stripe, Color("f5c842"))
		for index: int in int(ceilf(stripe.size.x / 8.0)):
			var x: float = stripe.position.x + float(index) * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, stripe.position.y + 4), Vector2(x + 3, stripe.position.y), Vector2(minf(x + 6, stripe.end.x), stripe.position.y), Vector2(minf(x + 3, stripe.end.x), stripe.position.y + 4)]), Color("25292c"))
		draw_line(deck.position + Vector2(1, 1), Vector2(deck.end.x - 1, deck.position.y + 1), Color("d7e2e6"), 1.0)
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * (platform_size.x * 0.5 - 4), -2), 1.0, Color("e1e7e9"))


class HexCodeCurtain extends StaticBody2D:
	@export var block_size: Vector2 = Vector2(40, 36)
	var animation_time: float = 0.0
	const TOKENS: Array[String] = ["57", "77", "1983", "JMP", "LDA"]

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 2
		add_to_group("dream_blocks")
		Helpers.rectangle_body(self, block_size)

	func contains_point(world_pos: Vector2) -> bool:
		return Rect2(-block_size * 0.5, block_size).has_point(to_local(world_pos))

	func _process(delta: float) -> void:
		animation_time += delta
		queue_redraw()

	func reset_trap() -> void:
		animation_time = 0.0
		collision_layer = 1
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(-block_size * 0.5, block_size)
		draw_rect(rect, Color("030c0b"))
		var font: Font = ThemeDB.fallback_font
		var rows: int = maxi(1, int((block_size.y - 8.0) / 9.0))
		for column: int in maxi(1, int((block_size.x - 6.0) / 22.0)):
			for row: int in rows:
				var y: float = fposmod(float(row) * 9.0 + animation_time * 9.0, maxf(1.0, block_size.y - 10.0))
				var point: Vector2 = rect.position + Vector2(4.0 + float(column) * 22.0, 8.0 + y)
				var token: String = TOKENS[(row + column + int(animation_time)) % TOKENS.size()]
				var color: Color = Color("55efd1") if row % 2 == 0 else Color("66ff75")
				draw_string(font, point, token, HORIZONTAL_ALIGNMENT_LEFT, minf(21.0, rect.end.x - point.x - 3.0), 7, color)
		draw_rect(rect, Color("50ff88"), false, 1.0)
		draw_rect(rect.grow(-2.0), Color(0.2, 1.0, 0.6, 0.3), false, 1.0)


class WindGustZone extends Area2D:
	@export var zone_size: Vector2 = Vector2(96, 80)
	@export var wind_accel: Vector2 = Vector2(220, -140)
	var animation_time: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		Helpers.rectangle_body(self, zone_size)

	func _physics_process(delta: float) -> void:
		for body: Node2D in get_overlapping_bodies():
			var player: CharacterBody2D = Helpers.as_player(body)
			if player == null or bool(player.get("is_dead")):
				continue
			if player.has_method("apply_wind_force"):
				player.call("apply_wind_force", wind_accel, delta)
			else:
				player.velocity += wind_accel * delta

	func _process(delta: float) -> void:
		animation_time += delta
		queue_redraw()

	func reset_trap() -> void:
		animation_time = 0.0
		set_deferred("monitoring", true)
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(-zone_size * 0.5, zone_size)
		draw_rect(rect, Color(0.5, 0.86, 0.8, 0.055))
		Helpers.draw_trigram(self, rect.position + Vector2(9, 9), "wind", Color(0.7, 1.0, 0.85, 0.65))
		var direction: Vector2 = wind_accel.normalized()
		var length: float = minf(18.0, wind_accel.length() * 0.045)
		for index: int in 10:
			var drift: Vector2 = Vector2(float(index * 29), float(index * 17)) + wind_accel * animation_time * 0.22
			var point: Vector2 = Vector2(fposmod(drift.x, zone_size.x), fposmod(drift.y, zone_size.y)) + rect.position
			# Clip tails to the actual force boundary instead of implying wind outside it.
			var tail: Vector2 = point - direction * length
			var distance: float = length
			if direction.x != 0.0:
				distance = minf(distance, (point.x - (rect.position.x if direction.x > 0.0 else rect.end.x)) / direction.x)
			if direction.y != 0.0:
				distance = minf(distance, (point.y - (rect.position.y if direction.y > 0.0 else rect.end.y)) / direction.y)
			tail = point - direction * maxf(0.0, distance)
			draw_line(tail, point, Color(0.65, 0.95, 0.9, 0.3), 1.0)
			if length > 0.0:
				draw_rect(Rect2(point, Vector2.ONE), Color(0.85, 1.0, 0.95, 0.65))


class DirectionalSpring extends Area2D:
	@export_enum("up", "left", "right") var dir: String = "up"
	var bounce_time: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		Helpers.rectangle_body(self, Vector2(16, 10) if dir == "up" else Vector2(10, 16))
		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node2D) -> void:
		var player: CharacterBody2D = Helpers.as_player(body)
		if player == null or bool(player.get("is_dead")):
			return
		var launch: Vector2 = Vector2(0, -305)
		if dir == "left":
			launch = Vector2(-240, -150)
		elif dir == "right":
			launch = Vector2(240, -150)
		player.call("apply_directional_spring", launch)
		player.call("refill_dash_and_stamina", true)
		bounce_time = 0.18

	func _process(delta: float) -> void:
		bounce_time = maxf(0.0, bounce_time - delta)
		queue_redraw()

	func reset_trap() -> void:
		bounce_time = 0.0
		queue_redraw()

	func _draw() -> void:
		var angle: float = -PI * 0.5 if dir == "left" else (PI * 0.5 if dir == "right" else 0.0)
		draw_set_transform(Vector2.ZERO, angle)
		var compression: float = bounce_time / 0.18 * 3.0
		draw_rect(Rect2(-8, 3, 16, 2), Color("6f7e8c"))
		var coil: PackedVector2Array = PackedVector2Array([Vector2(-5, 3), Vector2(5, 1), Vector2(-5, -1 + compression * 0.3), Vector2(5, -3 + compression * 0.6), Vector2(0, -4 + compression)])
		draw_polyline(coil, Color("d6e0e5"), 1.5)
		draw_rect(Rect2(-8, -5 + compression, 16, 3), Color("e74d46"))
		draw_line(Vector2(-7, -5 + compression), Vector2(7, -5 + compression), Color("ffb0a2"), 1.0)
		draw_set_transform(Vector2.ZERO)


class BaguaTalisman extends Area2D:
	@export var trigram_id: String = "earth"
	var spawn_position: Vector2 = Vector2.ZERO
	var followed_player: CharacterBody2D = null
	var returning: bool = false
	var banked: bool = false
	var safe_floor_time: float = 0.0
	var animation_time: float = 0.0

	func _ready() -> void:
		spawn_position = global_position
		collision_layer = 0
		collision_mask = 2
		Helpers.circle_body(self, 8.0)
		body_entered.connect(_on_body_entered)
		# Evaluate safety after CharacterBody2D's movement and hazard physics.
		process_physics_priority = 10

	func _on_body_entered(body: Node2D) -> void:
		var player: CharacterBody2D = Helpers.as_player(body)
		if banked or returning or is_instance_valid(followed_player) or player == null or bool(player.get("is_dead")):
			return
		followed_player = player
		safe_floor_time = 0.0
		set_deferred("monitoring", false)

	func _physics_process(delta: float) -> void:
		if banked:
			return
		if returning:
			global_position = global_position.lerp(spawn_position, 1.0 - exp(-9.0 * delta))
			if global_position.distance_to(spawn_position) < 0.25:
				global_position = spawn_position
				returning = false
				set_deferred("monitoring", true)
		elif is_instance_valid(followed_player):
			if bool(followed_player.get("is_dead")):
				reset_trap()
				return
			var target: Vector2 = followed_player.global_position + Vector2(-float(followed_player.get("facing")) * 18.0, -18.0)
			global_position = global_position.lerp(target, 1.0 - exp(-10.0 * delta))
			if followed_player.is_on_floor() and not bool(followed_player.get("is_dashing")) and not bool(followed_player.get("is_dream_dashing")) and followed_player.velocity.y >= 0.0:
				safe_floor_time += delta
				if safe_floor_time >= 0.12:
					banked = true
					visible = false
					followed_player = null
					get_node("/root/SecretManager").call("unlock_trigram", trigram_id)
			else:
				safe_floor_time = 0.0
		elif not monitoring:
			reset_trap()

	func _process(delta: float) -> void:
		animation_time += delta
		queue_redraw()

	func reset_trap() -> void:
		followed_player = null
		safe_floor_time = 0.0
		# Banking is persistent; restarting an attempt must not unlock twice.
		if banked:
			return
		returning = true
		set_deferred("monitoring", false)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = Vector2(0, sin(animation_time * 3.2) * 1.5)
		var flap: float = sin(animation_time * 10.0) * 2.0
		for side: float in [-1.0, 1.0]:
			for feather: int in 3:
				var point: Vector2 = center + Vector2(side * (7.0 + float(feather) * 2.0) - 1.0, -3.0 + float(feather) + flap)
				draw_rect(Rect2(point, Vector2(3, 5 - feather)), Color("fff2c4"))
		draw_circle(center, 7.0, Color("a96b1e"))
		draw_circle(center, 6.0, Color("ffd560"))
		Helpers.draw_trigram(self, center, trigram_id, Color("69421e"))


class TelegraphedDropper extends Area2D:
	enum State { HANGING, WARNING, FALLING, LANDED }
	@export_enum("coconut", "icicle") var kind: String = "coconut"
	@export var ground_y: float = 144.0
	@export var trigger_x_range: float = 34.0
	@export var telegraph_time: float = 0.34
	var state: State = State.HANGING
	var spawn_position: Vector2 = Vector2.ZERO
	var warning_left: float = 0.0
	var fall_speed: float = 0.0
	var animation_time: float = 0.0
	var proximity: Area2D = null

	func _ready() -> void:
		spawn_position = global_position
		collision_layer = 0
		collision_mask = 2
		Helpers.rectangle_body(self, Vector2(10, 14))
		body_entered.connect(_on_body_entered)
		# A separate visible-column sensor triggers without making the column lethal.
		proximity = Area2D.new()
		proximity.collision_layer = 0
		proximity.collision_mask = 2
		add_child(proximity)
		proximity.top_level = true
		var height: float = maxf(1.0, ground_y - spawn_position.y)
		proximity.global_position = spawn_position + Vector2(0, height * 0.5)
		Helpers.rectangle_body(proximity, Vector2(maxf(1.0, trigger_x_range * 2.0), height))

	func _physics_process(delta: float) -> void:
		match state:
			State.HANGING:
				for body: Node2D in proximity.get_overlapping_bodies():
					var player: CharacterBody2D = Helpers.as_player(body)
					if player != null and not bool(player.get("is_dead")) and absf(player.global_position.x - spawn_position.x) <= trigger_x_range and player.global_position.y > spawn_position.y:
						state = State.WARNING
						warning_left = maxf(0.01, telegraph_time)
						break
			State.WARNING:
				warning_left = maxf(0.0, warning_left - delta)
				if warning_left == 0.0:
					state = State.FALLING
			State.FALLING:
				var old_y: float = global_position.y
				fall_speed += 540.0 * delta
				var next_y: float = minf(ground_y - 7.0, old_y + fall_speed * delta)
				if next_y > old_y:
					# Sweep the whole step so a fast icicle cannot tunnel through Kai.
					var shape: RectangleShape2D = RectangleShape2D.new()
					shape.size = Vector2(10, next_y - old_y + 14.0)
					var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
					query.shape = shape
					query.transform = Transform2D(0.0, Vector2(global_position.x, (old_y + next_y) * 0.5))
					query.collision_mask = 2
					for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
						var player: CharacterBody2D = Helpers.as_player(hit.get("collider") as Object)
						if player != null and not bool(player.get("is_dead")):
							player.call("kill", kind)
					global_position.y = next_y
				if global_position.y >= ground_y - 7.0:
					state = State.LANDED
					fall_speed = 0.0
					set_deferred("monitoring", false)

	func _on_body_entered(body: Node2D) -> void:
		var player: CharacterBody2D = Helpers.as_player(body)
		if state == State.FALLING and player != null and not bool(player.get("is_dead")):
			player.call("kill", kind)

	func _process(delta: float) -> void:
		animation_time += delta
		queue_redraw()

	func reset_trap() -> void:
		state = State.HANGING
		warning_left = 0.0
		fall_speed = 0.0
		animation_time = 0.0
		global_position = spawn_position
		reset_physics_interpolation()
		set_deferred("monitoring", true)
		queue_redraw()

	func _draw() -> void:
		var warning: bool = state == State.WARNING
		var sight_color: Color = Color(1.0, 0.72, 0.2, 0.65 if warning else 0.24)
		var ground: Vector2 = to_local(Vector2(spawn_position.x, ground_y))
		if state == State.HANGING or warning:
			draw_dashed_line(Vector2(0, 8), ground, sight_color, 1.0, 2.0)
			draw_line(ground - Vector2(trigger_x_range, 0), ground + Vector2(trigger_x_range, 0), sight_color, 1.0)
		var shake: float = sin(animation_time * 75.0) * 2.0 if warning else 0.0
		draw_set_transform(Vector2(shake, 0))
		var flash: bool = warning and int(animation_time * 16.0) % 2 == 0
		if kind == "icicle":
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(0, 7)]), Color("ffc65b") if flash else Color("b5ecf6"))
			draw_line(Vector2(-2, -5), Vector2(0, 3), Color("f0ffff"), 1.0)
		else:
			draw_circle(Vector2.ZERO, 6.0, Color("ffc65b") if flash else Color("a76b37"))
			draw_arc(Vector2.ZERO, 4.5, -2.8, -0.7, 12, Color("dfb279"), 1.0)
			for x: float in [-2.0, 0.0, 2.0]:
				draw_circle(Vector2(x, -2 if x == 0.0 else 0), 0.8, Color("4e3428"))
		if state == State.HANGING or warning:
			draw_line(Vector2(0, -7), Vector2(0, -11), Color("a5a490"), 1.0)
		if warning:
			draw_line(Vector2(9, -9), Vector2(9, -3), Color("ffd565"), 2.0)
			draw_circle(Vector2(9, 0), 1.0, Color("ffd565"))
		draw_set_transform(Vector2.ZERO)
