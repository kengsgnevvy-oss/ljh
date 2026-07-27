extends CharacterBody3D
class_name EnemyBase

# ============================================================
# ULTRANOKIA Enemy Base Class
# All enemy types extend this. Provides health, damage, AI.
# ============================================================

# --- Signals ---
signal died(enemy_node)

# --- Exported Stats ---
@export var health: int = 80
@export var max_health: int = 80
@export var speed: float = 6.0
@export var damage: int = 15
@export var attack_range: float = 2.0
@export var detection_range: float = 20.0
@export var attack_cooldown: float = 1.0
@export var score_value: int = 100
@export var can_fly: bool = false

# --- Internal State ---
var player: Node3D = null
var attack_timer: float = 0.0
var is_dead: bool = false
var original_material: Material = null
var flash_timer: float = 0.0

# --- Node References ---
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
    add_to_group("enemy")
    
    # Let subclass override defaults first
    _setup_enemy()
    
    # Now sync max_health after subclass has set health
    max_health = health
    
    # Find player
    player = get_tree().get_first_node_in_group("player")
    if not player:
        # Fallback: search by name or class
        var nodes := get_tree().get_nodes_in_group("player")
        if nodes.size() > 0:
            player = nodes[0]
    
    # Cache original material for flash effect
    if mesh_instance:
        original_material = mesh_instance.get_surface_override_material(0)
    
    Global.enemies_alive += 1


# Override in subclasses for custom setup
func _setup_enemy() -> void:
    pass


func _physics_process(delta: float) -> void:
    if is_dead:
        return
    
    if not player:
        # Try to find player again
        player = get_tree().get_first_node_in_group("player")
        if not player:
            return
    
    var distance_to_player := global_position.distance_to(player.global_position)
    
    # Only act if player is in detection range
    if distance_to_player > detection_range:
        _idle_behavior(delta)
        return
    
    # Face the player
    var look_dir := (player.global_position - global_position)
    look_dir.y = 0
    if look_dir.length() > 0.01:
        look_at(global_position - look_dir.normalized(), Vector3.UP, true)
    
    if distance_to_player <= attack_range:
        _attack_behavior(delta, distance_to_player)
    else:
        _chase_behavior(delta, distance_to_player)
    
    # Process flash effect
    _process_flash(delta)
    
    # Flight behavior
    if can_fly:
        velocity.y = 0  # No gravity for flying enemies
        # Maintain hover height
        var target_y: float = player.global_position.y + 2.0
        velocity.y = (target_y - global_position.y) * 3.0
    
    move_and_slide()


# --- AI Behaviors (override in subclasses) ---
func _idle_behavior(delta: float) -> void:
    velocity.x = move_toward(velocity.x, 0, speed * delta)
    velocity.z = move_toward(velocity.z, 0, speed * delta)
    if not can_fly:
        velocity.y -= 30.0 * delta  # Gravity


func _chase_behavior(delta: float, distance: float) -> void:
    var direction := (player.global_position - global_position).normalized()
    direction.y = 0
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if not can_fly:
        velocity.y -= 30.0 * delta  # Gravity


func _attack_behavior(delta: float, distance: float) -> void:
    velocity.x = move_toward(velocity.x, 0, speed * delta)
    velocity.z = move_toward(velocity.z, 0, speed * delta)
    if not can_fly:
        velocity.y -= 30.0 * delta
    
    attack_timer -= delta
    if attack_timer <= 0.0:
        _do_attack()


# --- Attack ---
func _do_attack() -> void:
    attack_timer = attack_cooldown
    if player and player.has_method("take_damage"):
        player.take_damage(damage)


# --- Damage System ---
func take_damage(amount: int, _source: Node3D = null) -> void:
    if is_dead:
        return
    
    health -= amount
    _start_flash()
    
    if health <= 0:
        die()


func die(is_glory_kill: bool = false) -> void:
    if is_dead:
        return
    is_dead = true
    
    died.emit(self)
    
    # Notify global systems
    Global.notify_kill(is_glory_kill)
    Global.add_score(score_value)
    
    # Death effects
    _spawn_death_effects()
    
    queue_free()


func get_health_percent() -> float:
    return float(health) / float(max_health)


# --- Flash Effect ---
func _start_flash() -> void:
    flash_timer = 0.1
    if mesh_instance:
        var flash_mat := StandardMaterial3D.new()
        flash_mat.albedo_color = Color.WHITE
        flash_mat.emission_enabled = true
        flash_mat.emission = Color(1, 1, 1, 1)
        mesh_instance.set_surface_override_material(0, flash_mat)


func _process_flash(delta: float) -> void:
    if flash_timer > 0.0:
        flash_timer -= delta
        if flash_timer <= 0.0 and mesh_instance and original_material:
            mesh_instance.set_surface_override_material(0, original_material)


# --- Death Effects ---
func _spawn_death_effects() -> void:
    # Spawn particle burst
    var particles := GPUParticles3D.new()
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 30
    particles.lifetime = 0.5
    particles.explosiveness = 1.0
    particles.global_position = global_position
    
    var particle_material := ParticleProcessMaterial.new()
    particle_material.direction = Vector3(0, 1, 0)
    particle_material.spread = 90.0
    particle_material.initial_velocity_min = 3.0
    particle_material.initial_velocity_max = 8.0
    particle_material.gravity = Vector3(0, -9.8, 0)
    particle_material.color = Color.RED
    particles.process_material = particle_material
    
    var particle_mesh := BoxMesh.new()
    particle_mesh.size = Vector3(0.1, 0.1, 0.1)
    particles.draw_pass_1 = particle_mesh
    
    get_tree().root.add_child(particles)
    
    # Auto-remove after lifetime
    var timer := get_tree().create_timer(1.0)
    timer.timeout.connect(particles.queue_free)
