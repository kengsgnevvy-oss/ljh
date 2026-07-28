extends Camera3D

# ============================================================
# ULTRANOKIA Player Camera Controller
# FPS mouse look + head bob + screen shake
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
var shake_offset: Vector3 = Vector3.ZERO
var is_shaking: bool = false


func _ready() -> void:
    original_y = position.y
    yaw = global_rotation.y
    pitch = global_rotation.x
    
    # Subscribe to screen shake signal
    if Global.has_signal("screen_shake_requested"):
        if not Global.screen_shake_requested.is_connected(_on_screen_shake_requested):
            Global.screen_shake_requested.connect(_on_screen_shake_requested)


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


func _on_screen_shake_requested(intensity: float, duration: float) -> void:
    # Use a tween to animate shake offset
    var shake_tween := create_tween()
    shake_tween.set_loops()
    shake_tween.set_trans(Tween.TRANS_SINE)
    shake_tween.set_ease(Tween.EASE_IN_OUT)
    
    var elapsed: float = 0.0
    var step: float = 0.016  # ~60fps steps
    
    while elapsed < duration:
        var current_intensity := intensity * (1.0 - elapsed / duration)
        shake_offset = Vector3(
            randf_range(-current_intensity, current_intensity),
            randf_range(-current_intensity, current_intensity),
            randf_range(-current_intensity, current_intensity)
        )
        await get_tree().process_frame
        elapsed += step
    
    shake_offset = Vector3.ZERO


func _process(_delta: float) -> void:
    # Apply shake offset on top of position
    if shake_offset.length() > 0.001:
        position = Vector3(position.x, original_y, position.z) + shake_offset


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
