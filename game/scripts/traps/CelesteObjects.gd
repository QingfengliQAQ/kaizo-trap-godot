class_name CelesteObjects
extends Node
## Celeste-inspired interactive objects used by Kaizo rooms.


class DashCrystal extends Area2D:
	const TEXTURE_PATH: String = "res://assets/tilesets/celeste_objects.png"
	const COOLDOWN: float = 2.4

	var active: bool = true
	var cooldown_left: float = 0.0
	var animation_time: float = 0.0
	var crystal_texture: Texture2D = null
	var burst_positions: Array[Vector2] = []
	var burst_velocities: Array[Vector2] = []
	var burst_lifetimes: Array[float] = []

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 2
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 8.0
		collision.shape = shape
		add_child(collision)
		body_entered.connect(_on_body_entered)
		if ResourceLoader.exists(TEXTURE_PATH):
			crystal_texture = load(TEXTURE_PATH) as Texture2D
		queue_redraw()

	func _process(delta: float) -> void:
		animation_time += delta
		if not active:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			if cooldown_left <= 0.0:
				active = true
				set_deferred("monitoring", true)
				AudioManager.play_sfx("crystal_refill", 0.03, -5.0)
		for index: int in range(burst_positions.size() - 1, -1, -1):
			burst_lifetimes[index] -= delta
			if burst_lifetimes[index] <= 0.0:
				burst_positions.remove_at(index)
				burst_velocities.remove_at(index)
				burst_lifetimes.remove_at(index)
			else:
				burst_velocities[index].y += 90.0 * delta
				burst_positions[index] += burst_velocities[index] * delta
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not active or not body is KaiPlayer:
			return
		var player: KaiPlayer = body as KaiPlayer
		if player.is_dead:
			return
		if player.has_method("refill_dash_and_stamina"):
			player.call("refill_dash_and_stamina")
		AudioManager.play_sfx("crystal_refill", 0.03, -2.0)
		_spawn_shatter()
		active = false
		set_deferred("monitoring", false)
		cooldown_left = COOLDOWN
		queue_redraw()

	func _spawn_shatter() -> void:
		burst_positions.clear()
		burst_velocities.clear()
		burst_lifetimes.clear()
		for index: int in 12:
			var angle: float = TAU * float(index) / 12.0 + randf_range(-0.16, 0.16)
			var speed: float = randf_range(38.0, 82.0)
			burst_positions.append(Vector2.ZERO)
			burst_velocities.append(Vector2.from_angle(angle) * speed)
			burst_lifetimes.append(randf_range(0.25, 0.48))

	func reset_trap() -> void:
		active = true
		set_deferred("monitoring", true)
		cooldown_left = 0.0
		burst_positions.clear()
		burst_velocities.clear()
		burst_lifetimes.clear()
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(animation_time * 3.1) * 2.0
		var crystal_rect: Rect2 = Rect2(-8.0, -8.0 + bob, 16.0, 16.0)
		if active:
			if crystal_texture != null:
				draw_texture_rect_region(crystal_texture, crystal_rect, Rect2(0.0, 0.0, 16.0, 16.0))
			else:
				var crystal: PackedVector2Array = PackedVector2Array([
					Vector2(0.0, -10.0 + bob), Vector2(7.0, -3.0 + bob),
					Vector2(5.0, 7.0 + bob), Vector2(0.0, 11.0 + bob),
					Vector2(-5.0, 7.0 + bob), Vector2(-7.0, -3.0 + bob),
				])
				draw_colored_polygon(crystal, Color("#66ff9a"))
				draw_polyline(crystal, Color("#163b3d"), 1.4, true)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0.0, -8.0 + bob), Vector2(5.0, -2.0 + bob),
					Vector2(0.0, 7.0 + bob),
				]), Color("#c8ffd6"))
		else:
			var alpha: float = 0.18 + 0.14 * sin(animation_time * 5.0)
			draw_polyline(PackedVector2Array([
				Vector2(0.0, -10.0 + bob), Vector2(7.0, -3.0 + bob),
				Vector2(5.0, 7.0 + bob), Vector2(0.0, 11.0 + bob),
				Vector2(-5.0, 7.0 + bob), Vector2(-7.0, -3.0 + bob),
			]), Color(0.4, 1.0, 0.62, alpha), 1.2, true)
		for index: int in burst_positions.size():
			var life_alpha: float = clampf(burst_lifetimes[index] / 0.48, 0.0, 1.0)
			var shard_color: Color = Color(0.38, 1.0, 0.74, life_alpha)
			draw_circle(burst_positions[index], 1.2, shard_color)


class ZipMoverBlock extends AnimatableBody2D:
	enum MotionState { IDLE, ZIPPING, PAUSED, RETURNING }

	@export var block_size: Vector2 = Vector2(32.0, 16.0)
	@export var target_offset: Vector2 = Vector2(80.0, 0.0)

	var origin_position: Vector2 = Vector2.ZERO
	var motion_state: MotionState = MotionState.IDLE
	var state_time: float = 0.0
	var sensor: Area2D
	var riders: Array[KaiPlayer] = []
	var launch_direction: Vector2 = Vector2.RIGHT

	func _ready() -> void:
		origin_position = position
		sync_to_physics = true
		collision_layer = 1
		collision_mask = 2
		var collision: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = block_size
		collision.shape = rectangle
		add_child(collision)
		sensor = Area2D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 2
		var sensor_collision: CollisionShape2D = CollisionShape2D.new()
		var sensor_rectangle: RectangleShape2D = RectangleShape2D.new()
		sensor_rectangle.size = block_size + Vector2(8.0, 8.0)
		sensor_collision.shape = sensor_rectangle
		sensor.add_child(sensor_collision)
		sensor.body_entered.connect(_on_sensor_body_entered)
		sensor.body_exited.connect(_on_sensor_body_exited)
		add_child(sensor)
		launch_direction = target_offset.normalized() if target_offset.length_squared() > 0.01 else Vector2.RIGHT
		queue_redraw()

	func _physics_process(delta: float) -> void:
		state_time += delta
		match motion_state:
			MotionState.IDLE:
				_refresh_contacts()
			MotionState.ZIPPING:
				var zip_progress: float = clampf(state_time / 0.38, 0.0, 1.0)
				var eased_zip: float = zip_progress * zip_progress * zip_progress
				var previous_position: Vector2 = position
				position = origin_position + target_offset * eased_zip
				_carry_side_riders(position - previous_position)
				if zip_progress >= 1.0:
					position = origin_position + target_offset
					motion_state = MotionState.PAUSED
					state_time = 0.0
					_launch_riders()
					AudioManager.play_sfx("zip_move", 0.02, -3.0)
			MotionState.PAUSED:
				if state_time >= 0.45:
					motion_state = MotionState.RETURNING
					state_time = 0.0
					AudioManager.play_sfx("zip_move", 0.04, -8.0)
			MotionState.RETURNING:
				var return_progress: float = clampf(state_time / 1.1, 0.0, 1.0)
				var smooth_return: float = return_progress * return_progress * (3.0 - 2.0 * return_progress)
				position = origin_position + target_offset * (1.0 - smooth_return)
				if return_progress >= 1.0:
					position = origin_position
					motion_state = MotionState.IDLE
					state_time = 0.0
		queue_redraw()

	func _on_sensor_body_entered(body: Node2D) -> void:
		if not body is KaiPlayer:
			return
		var player: KaiPlayer = body as KaiPlayer
		if player.is_dead or not _qualifies_contact(player):
			return
		if not riders.has(player):
			riders.append(player)
		if motion_state == MotionState.IDLE:
			motion_state = MotionState.ZIPPING
			state_time = 0.0
			AudioManager.play_sfx("zip_move", 0.02, -3.0)

	func _on_sensor_body_exited(body: Node2D) -> void:
		if body is KaiPlayer:
			riders.erase(body as KaiPlayer)

	func _refresh_contacts() -> void:
		for index: int in range(riders.size() - 1, -1, -1):
			if not is_instance_valid(riders[index]) or riders[index].is_dead or not _qualifies_contact(riders[index]):
				riders.remove_at(index)
		for body: Node2D in sensor.get_overlapping_bodies():
			if body is KaiPlayer:
				var player: KaiPlayer = body as KaiPlayer
				if not player.is_dead and _qualifies_contact(player) and not riders.has(player):
					riders.append(player)
		if motion_state == MotionState.IDLE and not riders.is_empty():
			motion_state = MotionState.ZIPPING
			state_time = 0.0
			AudioManager.play_sfx("zip_move", 0.02, -3.0)

	func _qualifies_contact(player: KaiPlayer) -> bool:
		var local_feet: Vector2 = to_local(player.global_position)
		var on_top: bool = _is_top_contact(player)
		var near_side: bool = absf(absf(local_feet.x) - block_size.x * 0.5) <= 7.0 and local_feet.y <= block_size.y * 0.5 + 3.0 and local_feet.y >= -block_size.y * 0.5 - 12.0
		return on_top or (near_side and player.is_wall_sliding)

	func _is_top_contact(player: KaiPlayer) -> bool:
		var local_feet: Vector2 = to_local(player.global_position)
		return absf(local_feet.y + block_size.y * 0.5) <= 5.5 and absf(local_feet.x) <= block_size.x * 0.5 + 5.0

	func _carry_side_riders(movement: Vector2) -> void:
		for player: KaiPlayer in riders:
			if is_instance_valid(player) and player.is_wall_sliding and not _is_top_contact(player):
				player.global_position += movement

	func _launch_riders() -> void:
		_refresh_contacts()
		for player: KaiPlayer in riders:
			if not is_instance_valid(player) or player.is_dead or not _qualifies_contact(player):
				continue
			var launch: Vector2 = launch_direction * 190.0
			if absf(launch_direction.x) > 0.4:
				launch.y = minf(launch.y, -105.0)
			player.velocity = launch
		riders.clear()

	func reset_trap() -> void:
		position = origin_position
		motion_state = MotionState.IDLE
		state_time = 0.0
		riders.clear()
		queue_redraw()

	func _draw() -> void:
		var start_local: Vector2 = origin_position - position
		var end_local: Vector2 = origin_position + target_offset - position
		var track_length: float = start_local.distance_to(end_local)
		var track_direction: Vector2 = (end_local - start_local).normalized() if track_length > 0.01 else Vector2.RIGHT
		var segment_start: float = 0.0
		while segment_start < track_length:
			var segment_end: float = minf(segment_start + 5.0, track_length)
			draw_line(start_local + track_direction * segment_start, start_local + track_direction * segment_end, Color("#596273"), 2.0)
			segment_start += 9.0
		draw_circle(start_local, 4.0, Color("#aab2c4"))
		draw_circle(start_local, 1.8, Color("#252b39"))
		draw_circle(end_local, 4.0, Color("#aab2c4"))
		draw_circle(end_local, 1.8, Color("#252b39"))
		var block_rect: Rect2 = Rect2(-block_size * 0.5, block_size)
		draw_rect(block_rect, Color("#161b25"))
		draw_rect(block_rect.grow(-2.0), Color("#697486"))
		draw_line(Vector2(-block_size.x * 0.5 + 3.0, -block_size.y * 0.5 + 3.0), Vector2(block_size.x * 0.5 - 3.0, -block_size.y * 0.5 + 3.0), Color("#b8c0ce"), 1.0)
		var light_color: Color = Color("#ffc44d")
		if motion_state == MotionState.ZIPPING:
			light_color = Color("#62f58a")
		elif motion_state == MotionState.RETURNING:
			light_color = Color("#ff5964")
		draw_circle(Vector2.ZERO, 3.0, Color("#171923"))
		draw_circle(Vector2.ZERO, 2.0, light_color)


class GlitchDreamBlock extends StaticBody2D:
	@export var block_size: Vector2 = Vector2(48.0, 32.0)

	var animation_time: float = 0.0
	var sensor: Area2D
	var stars: Array[Vector2] = []
	var star_colors: Array[Color] = []
	var dream_players: Array[KaiPlayer] = []
	var dream_directions: Array[Vector2] = []
	var dream_timers: Array[float] = []
	var dream_physics_enabled: Array[bool] = []

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 2
		add_to_group("dream_blocks")
		var collision: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = block_size
		collision.shape = rectangle
		add_child(collision)
		sensor = Area2D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 2
		var sensor_collision: CollisionShape2D = CollisionShape2D.new()
		var sensor_rectangle: RectangleShape2D = RectangleShape2D.new()
		sensor_rectangle.size = block_size + Vector2(5.0, 5.0)
		sensor_collision.shape = sensor_rectangle
		sensor.add_child(sensor_collision)
		sensor.body_entered.connect(_on_sensor_body_entered)
		add_child(sensor)
		for index: int in 24:
			var x_position: float = fposmod(float(index * 17 + 5), block_size.x - 6.0) - block_size.x * 0.5 + 3.0
			var y_position: float = fposmod(float(index * 11 + 3), block_size.y - 6.0) - block_size.y * 0.5 + 3.0
			stars.append(Vector2(x_position, y_position))
			match index % 3:
				0: star_colors.append(Color("#5ce6ff"))
				1: star_colors.append(Color("#ff66cc"))
				_: star_colors.append(Color.WHITE)
		queue_redraw()

	func _physics_process(delta: float) -> void:
		animation_time += delta
		for body: Node2D in sensor.get_overlapping_bodies():
			_on_sensor_body_entered(body)
		for index: int in range(dream_players.size() - 1, -1, -1):
			var player: KaiPlayer = dream_players[index]
			if not is_instance_valid(player) or player.is_dead:
				_finish_dream_dash(index, false)
				continue
			dream_timers[index] += delta
			var travel_velocity: Vector2 = dream_directions[index] * 230.0
			player.velocity = travel_velocity
			player.global_position += travel_velocity * delta
			var player_center: Vector2 = player.global_position + Vector2(0.0, -9.0)
			if dream_timers[index] >= 0.04 and not _expanded_contains_point(player_center):
				_finish_dream_dash(index, true)
		queue_redraw()

	func contains_point(world_point: Vector2) -> bool:
		var local_point: Vector2 = to_local(world_point)
		return Rect2(-block_size * 0.5, block_size).has_point(local_point)

	func _expanded_contains_point(world_point: Vector2) -> bool:
		var local_point: Vector2 = to_local(world_point)
		return Rect2(-block_size * 0.5, block_size).grow(10.0).has_point(local_point)

	func can_dream_dash(player: KaiPlayer = null) -> bool:
		return player == null or (not player.is_dead and not bool(player.get_meta("dream_dash", false)))

	func start_dream_dash(player: KaiPlayer, dash_direction: Vector2) -> void:
		if not is_instance_valid(player) or not can_dream_dash(player):
			return
		var direction: Vector2 = dash_direction.normalized()
		if direction.length_squared() <= 0.01:
			direction = Vector2(float(player.facing), 0.0)
		dream_players.append(player)
		dream_directions.append(direction)
		dream_timers.append(0.0)
		dream_physics_enabled.append(player.is_physics_processing())
		add_collision_exception_with(player)
		player.set_meta("dream_dash", true)
		player.set_physics_process(false)
		player.velocity = direction * 230.0
		AudioManager.play_sfx("dream_through", 0.03, -3.0)

	func _on_sensor_body_entered(body: Node2D) -> void:
		if not body is KaiPlayer:
			return
		var player: KaiPlayer = body as KaiPlayer
		if _player_is_dashing(player):
			start_dream_dash(player, player.velocity)

	func _player_is_dashing(player: KaiPlayer) -> bool:
		if player.has_meta("is_dashing"):
			return bool(player.get_meta("is_dashing"))
		if player.has_method("is_dashing"):
			var result: Variant = player.call("is_dashing")
			return bool(result)
		for property_info: Dictionary in player.get_property_list():
			if String(property_info.get("name", "")) == "is_dashing":
				var property_value: Variant = player.get("is_dashing")
				return bool(property_value)
		return false

	func _finish_dream_dash(index: int, successful: bool) -> void:
		var player: KaiPlayer = dream_players[index]
		if is_instance_valid(player):
			remove_collision_exception_with(player)
			player.set_meta("dream_dash", false)
			player.set_physics_process(dream_physics_enabled[index])
			if successful:
				player.velocity = dream_directions[index] * 245.0
				if player.has_method("refill_dash_and_stamina"):
					player.call("refill_dash_and_stamina")
				AudioManager.play_sfx("dream_through", 0.02, -1.0)
		dream_players.remove_at(index)
		dream_directions.remove_at(index)
		dream_timers.remove_at(index)
		dream_physics_enabled.remove_at(index)

	func _exit_tree() -> void:
		reset_trap()

	func reset_trap() -> void:
		for index: int in dream_players.size():
			var player: KaiPlayer = dream_players[index]
			if is_instance_valid(player):
				remove_collision_exception_with(player)
				player.set_meta("dream_dash", false)
				player.set_physics_process(dream_physics_enabled[index])
		dream_players.clear()
		dream_directions.clear()
		dream_timers.clear()
		dream_physics_enabled.clear()

	func _draw() -> void:
		var interior: Rect2 = Rect2(-block_size * 0.5, block_size)
		draw_rect(interior, Color("#090925"))
		draw_rect(interior.grow(-2.0), Color("#161044"))
		var inner: Rect2 = interior.grow(-3.0)
		for index: int in stars.size():
			var star_position: Vector2 = stars[index]
			star_position.y = fposmod(star_position.y + block_size.y * 0.5 - 3.0 + animation_time * (4.0 + float(index % 4)), block_size.y - 6.0) - block_size.y * 0.5 + 3.0
			if inner.has_point(star_position):
				var pixel_size: float = 1.0 if index % 5 != 0 else 1.7
				draw_rect(Rect2(star_position, Vector2(pixel_size, pixel_size)), star_colors[index])
		draw_rect(interior, Color("#5ce6ff"), false, 1.5)
		draw_line(interior.position + Vector2(3.0, 2.0), interior.position + Vector2(block_size.x - 5.0, 2.0), Color("#ff66cc"), 1.0)


class DirectionalSpring extends Area2D:
	@export_enum("up", "left", "right") var dir: String = "up"

	var bounce_time: float = 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 2
		var collision: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(10.0, 16.0) if dir == "left" or dir == "right" else Vector2(16.0, 10.0)
		collision.shape = rectangle
		add_child(collision)
		body_entered.connect(_on_body_entered)
		queue_redraw()

	func _process(delta: float) -> void:
		bounce_time = maxf(0.0, bounce_time - delta)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not body is KaiPlayer:
			return
		var player: KaiPlayer = body as KaiPlayer
		if player.is_dead:
			return
		if player.has_method("refill_dash_and_stamina"):
			player.call("refill_dash_and_stamina")
		match dir:
			"left": player.velocity = Vector2(-240.0, -150.0)
			"right": player.velocity = Vector2(240.0, -150.0)
			_: player.velocity.y = -305.0
		bounce_time = 0.18
		AudioManager.play_sfx("spring", 0.04, -2.0)
		queue_redraw()

	func reset_trap() -> void:
		bounce_time = 0.0
		queue_redraw()

	func _draw() -> void:
		var squash: float = 1.0 - 0.35 * (bounce_time / 0.18)
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(-7.0, 4.0), Vector2(-5.0, -3.0 * squash),
			Vector2(0.0, -6.0 * squash), Vector2(5.0, -3.0 * squash),
			Vector2(7.0, 4.0),
		])
		var rotation_angle: float = 0.0
		if dir == "left":
			rotation_angle = -PI * 0.5
		elif dir == "right":
			rotation_angle = PI * 0.5
		for index: int in points.size():
			points[index] = points[index].rotated(rotation_angle)
		draw_polyline(points, Color("#261b39"), 3.6)
		draw_polyline(points, Color("#ff66cc"), 2.0)
		draw_circle(Vector2(0.0, 4.0).rotated(rotation_angle), 2.3, Color("#5ce6ff"))


class BaguaFollower extends Area2D:
	@export var trigram_id: String = "earth"

	var spawn_position: Vector2 = Vector2.ZERO
	var followed_player: KaiPlayer = null
	var attached: bool = false
	var returning: bool = false
	var celebrating: bool = false
	var safe_floor_time: float = 0.0
	var animation_time: float = 0.0
	var celebration_time: float = 0.0
	var trail_velocity: Vector2 = Vector2.ZERO

	func _ready() -> void:
		spawn_position = global_position
		collision_layer = 4
		collision_mask = 2
		var collision: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 8.0
		collision.shape = circle
		add_child(collision)
		body_entered.connect(_on_body_entered)
		queue_redraw()

	func _physics_process(delta: float) -> void:
		animation_time += delta
		if celebrating:
			celebration_time += delta
			global_position.y -= 26.0 * delta
			if celebration_time >= 0.55:
				queue_free()
			queue_redraw()
			return
		if attached:
			if not is_instance_valid(followed_player) or followed_player.is_dead:
				reset_trap()
			else:
				var target: Vector2 = followed_player.global_position + Vector2(-float(followed_player.facing) * 18.0, -17.0)
				var offset: Vector2 = target - global_position
				trail_velocity += offset * 28.0 * delta
				trail_velocity *= exp(-8.0 * delta)
				global_position += trail_velocity * delta * 8.0
				if followed_player.is_on_floor() and followed_player.velocity.y >= 0.0:
					safe_floor_time += delta
					if safe_floor_time >= 0.12:
						_bank_collectible()
				else:
					safe_floor_time = 0.0
		elif returning:
			global_position = global_position.lerp(spawn_position, 1.0 - exp(-8.0 * delta))
			if global_position.distance_to(spawn_position) <= 0.5:
				global_position = spawn_position
				returning = false
				set_deferred("monitoring", true)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if attached or returning or celebrating or not body is KaiPlayer:
			return
		var player: KaiPlayer = body as KaiPlayer
		if player.is_dead:
			return
		followed_player = player
		attached = true
		set_deferred("monitoring", false)
		safe_floor_time = 0.0
		trail_velocity = Vector2.ZERO

	func _bank_collectible() -> void:
		if followed_player == null or followed_player.is_dead:
			reset_trap()
			return
		attached = false
		celebrating = true
		celebration_time = 0.0
		SecretManager.unlock_trigram(trigram_id)
		AudioManager.play_sfx("secret", 0.03, -1.0)

	func reset_trap() -> void:
		followed_player = null
		attached = false
		celebrating = false
		celebration_time = 0.0
		safe_floor_time = 0.0
		trail_velocity = Vector2.ZERO
		returning = true
		set_deferred("monitoring", false)
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(animation_time * 3.3) * 1.8
		var wing_flap: float = 2.0 + absf(sin(animation_time * 11.0)) * 3.0
		var fade: float = clampf(1.0 - celebration_time / 0.55, 0.0, 1.0) if celebrating else 1.0
		var wing_color: Color = Color(0.88, 0.94, 1.0, fade)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6.0, -2.0 + bob), Vector2(-12.0, -wing_flap + bob), Vector2(-9.0, 3.0 + bob),
		]), wing_color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(6.0, -2.0 + bob), Vector2(12.0, -wing_flap + bob), Vector2(9.0, 3.0 + bob),
		]), wing_color)
		draw_circle(Vector2(0.0, bob), 7.0, Color(0.12, 0.10, 0.18, fade))
		draw_circle(Vector2(0.0, bob), 5.5, Color(0.96, 0.76, 0.18, fade))
		var ink: Color = Color(0.25, 0.15, 0.10, fade)
		for row: int in 3:
			var y_position: float = -2.5 + float(row) * 2.5 + bob
			if trigram_id == "earth" or row == 1:
				draw_line(Vector2(-3.8, y_position), Vector2(-0.8, y_position), ink, 1.0)
				draw_line(Vector2(0.8, y_position), Vector2(3.8, y_position), ink, 1.0)
			else:
				draw_line(Vector2(-3.8, y_position), Vector2(3.8, y_position), ink, 1.0)
