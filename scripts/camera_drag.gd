extends Camera3D
## Mouse-drag orbit camera, attached directly to a Camera3D.
##
## The camera position is kept as an offset vector from `target`. Each drag
## rotates that vector with an orthogonal (rotation) matrix derived from the
## mouse delta, then re-normalizes its length back to `_distance` so repeated
## small rotations don't accumulate floating-point drift.

@export var target := Vector3.ZERO
@export var min_distance := 0.5
@export var max_distance := 40.0
@export var min_pitch_deg := 5.0
@export var max_pitch_deg := 89.0
@export var sensitivity := 0.3          # degrees per pixel
@export var zoom_step := 0.1            # fraction per wheel notch

var _distance := 8.0
var _dragging := false


func _ready() -> void:
	_distance = (global_position - target).length()
	look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(1.0)
	elif event is InputEventMouseMotion and _dragging:
		_rotate(event.relative)


func _rotate(rel: Vector2) -> void:
	var offset := global_position - target
	if offset.length_squared() < 0.000001:
		return

	# Horizontal drag -> rotate the offset around the world up axis.
	var yaw_angle := -rel.x * deg_to_rad(sensitivity)
	if yaw_angle != 0.0:
		offset = Basis(Vector3.UP, yaw_angle) * offset

	# Vertical drag -> rotate around the camera's right axis, clamped so the
	# elevation stays within [min_pitch, max_pitch] (no flipping over the poles).
	var right := offset.cross(Vector3.UP)
	if right.length_squared() > 0.000001:
		right = right.normalized()
		var elev := atan2(offset.y, Vector2(offset.x, offset.z).length())
		var new_elev := clampf(
			elev - rel.y * deg_to_rad(sensitivity),
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		offset = Basis(right, new_elev - elev) * offset

	# Re-set the length to preserve precision across many small rotations.
	offset = offset.normalized() * _distance

	global_position = target + offset
	look_at(target, Vector3.UP)


func _zoom(dir: float) -> void:
	_distance = clampf(_distance * (1.0 + dir * zoom_step), min_distance, max_distance)
	global_position = target + (global_position - target).normalized() * _distance
	look_at(target, Vector3.UP)
