extends Area3D

# ============================================================
# ULTRANOKIA Bullet / Projectile
# Generic projectile with configurable speed, damage, behavior
# ============================================================

# --- Configuration ---
var direction: Vector3 = Vector3.FORWARD
var bullet_speed: float = 60.0
var bullet_damage: float = 10.0
var bullet_range: float = 100.0
var is_explosive: bool = false
var explosion_radius: float = 3.0
var explosion_damage: float = 20.0
var is_sticky: bool = false
var sticky_detonation_delay: float = 1.5
var stuck_to: Node3D = null
var source_weapon: Node = null

# --- Internal ---
var distance_traveled: float = 0.0
var is_stuck: bool = false
var detonation_timer: float = 0.0

# --- Nodes ---
@onready var _mesh: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Auto-free after max range time
	var max_lifetime: float = bullet_range / max(bullet_speed, 1.0) + 0.5
	var t: Tween = create_tween()
	t.tween_callback(queue_free).set_delay(max_lifetime)


func configure(dir: Vector3, dmg: float, rng: float, spd: float = -1.0) -> void:
	direction = dir.normalized()
	bullet_damage = dmg
	bullet_range = rng
	if spd > 0:
		bullet_speed = spd
	
	if direction.length() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if is_stuck:
		if stuck_to and is_instance_valid(stuck_to):
			global_position = stuck_to.global_position
		detonation_timer -= delta
		if detonation_timer <= 0.0:
			_detonate()
		return
	
	var move: Vector3 = direction * bullet_speed * delta
	global_position += move
	distance_traveled += move.length()
	
	if distance_traveled >= bullet_range:
		if is_explosive:
			_detonate()
		else:
			queue_free()


func _on_body_entered(body: Node3D) -> void:
	if is_sticky and not is_stuck:
		_stick_to(body)
		return
	
	if is_explosive:
		_detonate()
		return
	
	if body.has_method("take_damage"):
		body.take_damage(bullet_damage)
		_notify_kill_if_dead(body)
	
	_impact_effect(body.global_position if body else global_position)
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if is_sticky and not is_stuck:
		_stick_to(area)
		return
	
	if is_explosive:
		_detonate()
		return
	
	var parent: Node = area.get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(bullet_damage)
		_notify_kill_if_dead(parent)
	
	_impact_effect(area.global_position)
	queue_free()


func _stick_to(target: Node3D) -> void:
	is_stuck = true
	stuck_to = target
	detonation_timer = sticky_detonation_delay
	bullet_speed = 0
	
	if _collision_shape:
		_collision_shape.disabled = true
	
	if _mesh and _mesh.mesh:
		var mat: Material = _mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			var std_mat: StandardMaterial3D = mat as StandardMaterial3D
			std_mat.emission_enabled = true
			std_mat.emission = Color(1.0, 0.2, 0.0)
			std_mat.emission_energy_multiplier = 2.0


func _detonate() -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform.origin = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results: Array = space_state.intersect_shape(query)
	for result in results:
		var collider: Variant = result.collider
		if collider and collider.has_method("take_damage"):
			var dist: float = global_position.distance_to(collider.global_position)
			var falloff: float = max(0.0, 1.0 - (dist / explosion_radius))
			collider.take_damage(int(explosion_damage * falloff))
			_notify_kill_if_dead(collider)
	
	_spawn_explosion_vfx()
	
	if source_weapon and source_weapon.has_method("_trigger_screen_shake"):
		source_weapon._trigger_screen_shake(explosion_damage * 0.5)
	
	queue_free()


func _impact_effect(pos: Vector3) -> void:
	var sparks: GPUParticles3D = GPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 5
	sparks.lifetime = 0.2
	sparks.global_position = pos
	
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.spread = 30.0
	mat.gravity = Vector3(0, -5, 0)
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(1.0, 0.7, 0.3, 1.0)
	mat.lifetime_min = 0.1
	mat.lifetime_max = 0.25
	sparks.process_material = mat
	
	get_tree().root.add_child(sparks)
	var t: Tween = create_tween()
	t.tween_callback(func(): sparks.queue_free()).set_delay(0.3)


func _spawn_explosion_vfx() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 25
	particles.lifetime = 0.4
	particles.global_position = global_position
	
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 12.0
	mat.scale_min = 0.08
	mat.scale_max = 0.3
	mat.color = Color(1.0, 0.35, 0.05, 1.0)
	mat.lifetime_min = 0.15
	mat.lifetime_max = 0.4
	particles.process_material = mat
	
	get_tree().root.add_child(particles)
	
	var flash: OmniLight3D = OmniLight3D.new()
	flash.global_position = global_position
	flash.light_energy = 6.0
	flash.light_color = Color(1.0, 0.4, 0.1)
	flash.omni_range = explosion_radius * 1.5
	get_tree().root.add_child(flash)
	
	var t: Tween = create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.25)
	t.tween_callback(func(): flash.queue_free())
	t.tween_callback(func(): particles.queue_free()).set_delay(0.5)


func _notify_kill_if_dead(target: Node) -> void:
	if target.has_method("get_health") and target.get_health() <= 0:
		var player: Node = _find_player()
		if player and player.has_method("notify_kill"):
			player.notify_kill(false)
	if target.is_in_group("enemy") and target.has_method("is_dead") and target.is_dead():
		var player: Node = _find_player()
		if player and player.has_method("notify_kill"):
			player.notify_kill(false)


func _find_player() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
