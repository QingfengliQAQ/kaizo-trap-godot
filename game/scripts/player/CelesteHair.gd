class_name CelesteHair
extends Node2D
## Six world-space spring particles, simulated and redrawn at display frequency.
## Attach behind Kai's sprite and feed the head position through set_anchor().

const NODE_COUNT: int = 6
const SEGMENT_LENGTH: float = 3.0
const STEP_LIMIT: float = 1.0 / 240.0
const OUTLINE: Color = Color("#392238")
const BOW: Color = Color("#b880ff")

var _points: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _anchor: Vector2 = Vector2.ZERO
var _display_anchor: Vector2 = Vector2.ZERO
var _facing: int = 1
var _color: Color = Color("#e8562a")
var _low_stamina: bool = false
var _clock: float = 0.0


func _ready() -> void:
	# This node already interpolates its anchor; avoid a second physics interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _points.is_empty():
		reset_to(global_position)


func set_anchor(world_pos: Vector2, facing_dir: int, dash_count: int,
		max_dashes: int, stamina_low: bool, flash_white: bool) -> void:
	_facing = -1 if facing_dir < 0 else 1
	_low_stamina = stamina_low
	var available: int = clampi(dash_count, 0, maxi(0, max_dashes))
	_color = Color("#e8562a")
	if available == 0:
		_color = Color("#5ce6ff")
	elif available >= 2:
		_color = Color("#ff66cc")
	if flash_white:
		_color = Color.WHITE
	if _points.is_empty() or _anchor.distance_squared_to(world_pos) > 4096.0:
		reset_to(world_pos)
	_anchor = world_pos


func reset_to(world_pos: Vector2) -> void:
	_anchor = world_pos
	_display_anchor = world_pos
	_points.resize(NODE_COUNT)
	_velocities.resize(NODE_COUNT)
	for i: int in range(NODE_COUNT):
		_points[i] = world_pos + Vector2(-float(_facing) * 2.4, 1.8) * float(i)
		_velocities[i] = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	if _points.is_empty():
		return
	# Bound catch-up after pauses and substep springs at >= 240 Hz for stability.
	var elapsed: float = clampf(delta, 0.0, 0.05)
	var steps: int = maxi(1, int(ceil(elapsed / STEP_LIMIT)))
	var dt: float = elapsed / float(steps)
	_clock += elapsed
	for step: int in range(steps):
		_simulate(dt)
	queue_redraw()


func _simulate(dt: float) -> void:
	_display_anchor = _display_anchor.lerp(_anchor, 1.0 - exp(-65.0 * dt))
	_points[0] = _display_anchor
	for i: int in range(1, NODE_COUNT):
		var rest: Vector2 = Vector2(-float(_facing) * 2.4, 1.8)
		var spring: Vector2 = (_points[i - 1] + rest - _points[i]) * 420.0
		var breeze: float = sin(_clock * 3.5 - float(i) * 0.65) * 14.0
		_velocities[i] = (_velocities[i] + (spring + Vector2(breeze, 55.0)) * dt) * exp(-12.0 * dt)
		_points[i] += _velocities[i] * dt
		var offset: Vector2 = _points[i] - _points[i - 1]
		if offset.length() > SEGMENT_LENGTH * 1.35:
			_points[i] = _points[i - 1] + offset.normalized() * SEGMENT_LENGTH * 1.35


func _draw() -> void:
	if _points.is_empty():
		return
	var tint: Color = _color
	if _low_stamina and _color != Color.WHITE:
		tint = tint.darkened(0.08 + 0.06 * sin(_clock * 12.0))
	for i: int in range(NODE_COUNT - 1, 0, -1):
		var a: Vector2 = to_local(_points[i - 1])
		var b: Vector2 = to_local(_points[i])
		var radius: float = 3.3 - float(i) * 0.39
		draw_line(a, b, OUTLINE, radius * 2.0 + 1.2, true)
		draw_circle(b, radius + 0.6, OUTLINE, true, -1.0, true)
		draw_line(a, b, tint, radius * 2.0, true)
		draw_circle(b, radius, tint, true, -1.0, true)
	var root: Vector2 = to_local(_points[0])
	var bow_points: PackedVector2Array = PackedVector2Array([
		root + Vector2(-5, -4), root + Vector2(0, -1), root + Vector2(5, -4),
		root + Vector2(5, 2), root + Vector2(0, 0), root + Vector2(-5, 2)])
	draw_colored_polygon(bow_points, BOW)
	bow_points.append(bow_points[0])
	draw_polyline(bow_points, OUTLINE, 0.7, true)
	draw_line(root, root + Vector2(-3, 5), BOW, 2.0, true)
	draw_line(root, root + Vector2(3, 4), BOW, 2.0, true)
	draw_circle(root + Vector2(0, -0.5), 1.5, Color("#e4c9ff"), true, -1.0, true)
