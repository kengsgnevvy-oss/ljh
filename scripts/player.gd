extends CharacterBody3D

# ============================================================
# ULTRANOKIA Player Controller
# Fast, responsive FPS movement — Ultrakill / Doom Eternal style
# ============================================================

# --- Movement Constants ---
const WALK_SPEED: float = 12.0
const GRAVITY: float = 30.0
const JUMP_VELOCITY: float = 12.0
const DOUBLE_JUMP_VELOCITY: float = 10.0
const COYOTE_TIME: float = 0.08
const JUMP_BUFFER_TIME: float = 0.08
const SLIDE_JUMP_VELOCITY: float = 14.0
const WALL_JUMP_HORIZONTAL: float = 10.0
const WALL_JUMP_VERTICAL: float = 8.0

# --- Dash Constants ---
const DASH_SPEED: float = 40.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 0.8

# --- Slide Constants ---
const SLIDE_DURATION: float = 0.5
const SLIDE_COOLDOWN: float = 0.3
const SLIDE_END_BOOST: float = 15.0

# --- Style Constants ---
const STYLE_MAX: float = 5.0
const STYLE_KILL_BONUS: float = 0.3
const STYLE_GLORY_BONUS: float = 0.5
const STYLE_DECAY_RATE: float = 0.05
const STYLE_COMBO_WINDOW: float = 2.0

# --- Glory Kill ---
const GLORY_RANGE: float = 3.0
const GLORY_HEAL: int = 25
const GLORY_INVINCIBILITY: float = 0.3

# --- State ---
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_start_velocity: Vector3 = Vector3.ZERO
var slide_jumped: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var has_double_jumped: bool = false
var was_on_floor: bool = false

var has_wall_jumped: bool = false

var is_invincible: bool = false
var invincibility_timer: float = 0.0

var is_glory_killing: bool = false
var glory_kill_timer: float = 0.0

# --- Style ---
var style_rank: float = 0.0
var last_kill_time: float = -999.0
var combo_count: int = 0

# --- Node References ---
@onready var camera: Camera3D = $Camera3D
@onready var ground_ray: RayCast3D = $GroundRay
@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight
@onready var wall_ray_forward: RayCast3D = $WallRayForward
@onready var wall_ray_back: RayCast3D = $WallRayBack
@onready var dash_trail: GPUParticles3D = $DashTrail
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var weapon_manager: Node = $Camera3D/WeaponHolder
@onready var original_camera_y: float = 0.0

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    original_camera_y = camera.position.y
    
    # Register in player group for bullet kill tracking
    add_to_group("player")
    
    # Ensure Global has style fields
    if not Global.has_method("add_style") and "player_style" not in Global:
        Global.set("player_style", 0.0)
    
    Global.player_health = Global.player_max_health
    style_rank = 0.0
    Global.set("player_style", style_rank)


func _input(event: InputEvent) -> void:
    # ESC releases mouse
    if event.is_action_pressed("pause"):
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Glory kill
    if event.is_action_pressed("glory_kill") and not is_glory_killing:
        _attempt_glory_kill()
    
    # Shooting — delegate to weapon manager for semi-auto weapons
    if event.is_action_pressed("shoot") and weapon_manager:
        weapon_manager.fire_current()
    
    # Alt-fire — right mouse button
    if event.is_action_pressed("alt_fire") and weapon_manager:
        weapon_manager.alt_fire_current()


func _physics_process(delta: float) -> void:
    if is_glory_killing:
        _process_glory_kill(delta)
        return
    
    _process_dash(delta)
    _process_slide(delta)
    _process_timers(delta)
    _process_style_decay(delta)
    _process_invincibility(delta)
    
    # Gravity
    if not is_on_floor() and not is_dashing:
        velocity.y -= GRAVITY * delta
    
    # Movement input
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    if not is_dashing and not is_sliding:
        # Instant horizontal movement — no lerp, no inertia
        var target_velocity := direction * WALK_SPEED
        velocity.x = target_velocity.x
        velocity.z = target_velocity.z
    
    # Coyote time tracking
    if is_on_floor():
        coyote_timer = COYOTE_TIME
        has_double_jumped = false
        has_wall_jumped = false
        slide_jumped = false
    elif coyote_timer > 0.0:
        coyote_timer -= delta
    
    # Jump buffer
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER_TIME
    
    if jump_buffer_timer > 0.0:
        jump_buffer_timer -= delta
    
    # Jump logic
    if jump_buffer_timer > 0.0:
        if is_on_floor() or coyote_timer > 0.0:
            # Ground jump (or coyote)
            velocity.y = JUMP_VELOCITY
            jump_buffer_timer = 0.0
            coyote_timer = 0.0
        elif is_sliding and not slide_jumped:
            # Slide jump — boosted
            velocity.y = SLIDE_JUMP_VELOCITY
            is_sliding = false
            slide_jumped = true
            jump_buffer_timer = 0.0
        elif not has_double_jumped:
            # Double jump
            velocity.y = DOUBLE_JUMP_VELOCITY
            has_double_jumped = true
            jump_buffer_timer = 0.0
        elif _is_touching_wall() and not has_wall_jumped:
            # Wall jump
            _do_wall_jump()
            jump_buffer_timer = 0.0
    
    # Dash input
    if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
        _start_dash(direction, input_dir)
    
    # Slide input
    if Input.is_action_just_pressed("slide") and not is_sliding and slide_cooldown_timer <= 0.0 and direction.length() > 0.1 and is_on_floor():
        _start_slide()
    
    # Floor check transition
    was_on_floor = is_on_floor()
    
    move_and_slide()
    
    # Head bob via camera controller
    if camera.has_method("apply_head_bob"):
        camera.apply_head_bob(velocity, is_on_floor(), delta)
    
    # Sync Global state
    Global.player_health = Global.player_health  # keep in sync
    Global.set("player_style", style_rank)


# ============================================================
# DASH SYSTEM
# ============================================================
func _start_dash(direction: Vector3, input_dir: Vector2) -> void:
    is_dashing = true
    dash_timer = DASH_DURATION
    is_invincible = true
    invincibility_timer = DASH_DURATION
    
    # Direction: WASD priority, otherwise forward by look
    if input_dir.length() > 0.1:
        dash_direction = direction
    else:
        dash_direction = -camera.global_transform.basis.z
        dash_direction.y = 0
        dash_direction = dash_direction.normalized()
    
    velocity = dash_direction * DASH_SPEED
    velocity.y = 0  # Flat dash
    dash_trail.emitting = true


func _process_dash(delta: float) -> void:
    if not is_dashing:
        return
    
    dash_timer -= delta
    if dash_timer <= 0.0:
        # End dash
        is_dashing = false
        dash_cooldown_timer = DASH_COOLDOWN
        dash_trail.emitting = false
        # Preserve some momentum, not full stop
        velocity.x *= 0.3
        velocity.z *= 0.3
    else:
        # Maintain dash velocity
        velocity.x = dash_direction.x * DASH_SPEED
        velocity.z = dash_direction.z * DASH_SPEED
        velocity.y = 0  # Flat trajectory during dash


# ============================================================
# SLIDE SYSTEM
# ============================================================
func _start_slide() -> void:
    is_sliding = true
    slide_timer = SLIDE_DURATION
    slide_start_velocity = velocity
    slide_start_velocity.y = 0
    slide_jumped = false
    # Lower camera for slide feel
    var tween := create_tween()
    tween.tween_property(camera, "position:y", original_camera_y - 0.6, 0.1)


func _process_slide(delta: float) -> void:
    if not is_sliding:
        return
    
    slide_timer -= delta
    if slide_timer <= 0.0:
        # End slide — boost forward
        var boost_dir := -camera.global_transform.basis.z
        boost_dir.y = 0
        boost_dir = boost_dir.normalized()
        velocity.x = boost_dir.x * SLIDE_END_BOOST
        velocity.z = boost_dir.z * SLIDE_END_BOOST
        velocity.y = 0
        is_sliding = false
        slide_cooldown_timer = SLIDE_COOLDOWN
        # Raise camera back
        var tween := create_tween()
        tween.tween_property(camera, "position:y", original_camera_y, 0.15)
    else:
        # Maintain slide — keep horizontal speed, slight deceleration
        var hvel := Vector2(velocity.x, velocity.z)
        if hvel.length() > 0:
            hvel = hvel.normalized() * max(hvel.length() - 5.0 * delta, WALK_SPEED * 0.8)
            velocity.x = hvel.x
            velocity.z = hvel.y
        velocity.y = 0  # Stay grounded during slide


# ============================================================
# WALL JUMP
# ============================================================
func _is_touching_wall() -> bool:
    return wall_ray_left.is_colliding() or wall_ray_right.is_colliding() or wall_ray_forward.is_colliding() or wall_ray_back.is_colliding()


func _get_wall_normal() -> Vector3:
    if wall_ray_left.is_colliding():
        return wall_ray_left.get_collision_normal()
    if wall_ray_right.is_colliding():
        return wall_ray_right.get_collision_normal()
    if wall_ray_forward.is_colliding():
        return wall_ray_forward.get_collision_normal()
    if wall_ray_back.is_colliding():
        return wall_ray_back.get_collision_normal()
    return Vector3.ZERO


func _do_wall_jump() -> void:
    var wall_normal := _get_wall_normal()
    has_wall_jumped = true
    
    # Push away from wall
    velocity.x = wall_normal.x * WALL_JUMP_HORIZONTAL
    velocity.z = wall_normal.z * WALL_JUMP_HORIZONTAL
    velocity.y = WALL_JUMP_VERTICAL


# ============================================================
# GLORY KILL
# ============================================================
func _attempt_glory_kill() -> void:
    # Find nearest enemy in range with low health
    var enemies := get_tree().get_nodes_in_group("enemy")
    var best_target: Node3D = null
    var best_dist: float = GLORY_RANGE
    
    for enemy in enemies:
        var dist := global_position.distance_to(enemy.global_position)
        if dist < best_dist:
            # Check if enemy has health < 30%
            if enemy.has_method("get_health_percent") and enemy.get_health_percent() < 0.3:
                best_target = enemy
                best_dist = dist
    
    if best_target:
        _start_glory_kill(best_target)


func _start_glory_kill(target: Node3D) -> void:
    is_glory_killing = true
    glory_kill_timer = 0.3
    is_invincible = true
    invincibility_timer = 0.3
    
    # Dash to target
    var tween := create_tween()
    tween.tween_property(self, "global_position", target.global_position, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    
    # Kill target
    if target.has_method("die"):
        target.die(true)  # true = glory kill
    elif target.has_method("kill"):
        target.kill()
    else:
        target.queue_free()
    
    # Heal
    Global.player_health = min(Global.player_health + GLORY_HEAL, Global.player_max_health)
    
    # Style bonus
    _add_style(STYLE_GLORY_BONUS)


func _process_glory_kill(delta: float) -> void:
    glory_kill_timer -= delta
    if glory_kill_timer <= 0.0:
        is_glory_killing = false
        is_invincible = false


# ============================================================
# STYLE SYSTEM
# ============================================================
func _add_style(amount: float) -> void:
    style_rank = min(style_rank + amount, STYLE_MAX)
    last_kill_time = Time.get_ticks_msec() / 1000.0
    combo_count += 1
    Global.set("player_style", style_rank)


func _process_style_decay(delta: float) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now - last_kill_time > STYLE_COMBO_WINDOW:
        combo_count = 0
        style_rank = max(style_rank - STYLE_DECAY_RATE * delta, 0.0)
        Global.set("player_style", style_rank)


# ============================================================
# TIMERS
# ============================================================
func _process_timers(delta: float) -> void:
    if dash_cooldown_timer > 0.0:
        dash_cooldown_timer -= delta
    if slide_cooldown_timer > 0.0:
        slide_cooldown_timer -= delta


func _process_invincibility(delta: float) -> void:
    if is_invincible and not is_dashing and not is_glory_killing:
        invincibility_timer -= delta
        if invincibility_timer <= 0.0:
            is_invincible = false


# ============================================================
# DAMAGE
# ============================================================
func take_damage(amount: int) -> void:
    if is_invincible:
        return
    Global.player_health = max(0, Global.player_health - amount)
    if Global.player_health <= 0:
        _die()


func _die() -> void:
    Global.is_game_over = true
    # Could emit signal, change scene, etc.
    print("PLAYER DIED — Game Over")


# ============================================================
# PUBLIC API for other systems
# ============================================================
func get_style_rank() -> float:
    return style_rank


func get_style_letter() -> String:
    match int(style_rank):
        0: return "D"
        1: return "C"
        2: return "B"
        3: return "A"
        4: return "S"
        _: return "U"


func notify_kill(is_glory: bool = false) -> void:
    if is_glory:
        _add_style(STYLE_GLORY_BONUS)
    else:
        # Combo multiplier
        var multiplier: float = 1.0 + float(min(combo_count, 10)) * 0.2
        _add_style(STYLE_KILL_BONUS * multiplier)
