extends Camera3D

# ============================================================
# ULTRANOKIA Player Camera Controller
# FPS mouse look + head bob
# ============================================================

const MOUSE_SENSITIVITY: float = 0.002
const VERTICAL_CLAMP_MIN: float = -89.0
const VERTICAL_CLAMP_MAX: float = 89.0
const HEAD_BOB_AMPLITUDE: float = 0.05
const HEAD_BOB_FREQUENCY: float = 12.0

var yaw: float = 0.0
var pitch: float = 0.0
var head_bob_time: float = 0.0
var original_y: float = 0.0


func _ready() -> void:
	original_y = position.y
	yaw = global_rotation.y
	pitch = global_rotation.x


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation — full 360
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		# Vertical rotation — clamped
		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch = clamp(pitch, deg_to_rad(VERTICAL_CLAMP_MIN), deg_to_rad(VERTICAL_CLAMP_MAX))
		
		# Apply to camera
		rotation = Vector3(pitch, 0, 0)
		# Yaw on the player body (parent), not camera
		if get_parent():
			get_parent().rotation.y = yaw


func apply_head_bob(velocity: Vector3, is_on_floor: bool, delta: float) -> void:
	if not is_on_floor:
		# Smoothly return to original
		position.y = lerp(position.y, original_y, 10.0 * delta)
		head_bob_time = 0.0
		return
	
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed > 0.5:
		head_bob_time += delta * HEAD_BOB_FREQUENCY * (h_speed / 12.0)
		var bob_offset := sin(head_bob_time) * HEAD_BOB_AMPLITUDE
		position.y = original_y + bob_offset
	else:
		position.y = lerp(position.y, original_y, 10.0 * delta)
		head_bob_time = 0.0
