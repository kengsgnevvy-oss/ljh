extends EnemyBase
class_name BossBase

# ============================================================
# ULTRANOKIA Boss Base Class
# Phase-based boss system with HP-triggered phases.
# All bosses extend this.
# ============================================================

# --- Signals ---
signal boss_defeated(boss_name)
signal phase_changed(new_phase)

# --- Boss Stats ---
@export var boss_name: String = "Unknown Boss"
@export var max_phases: int = 3
var current_phase: int = 1

# Boss-bar health tracking
@export var boss_bar_enabled: bool = true

# Death delay for dramatic effect
@export var death_delay: float = 2.0

# Phase transition HP thresholds (as fraction of max_health)
var _phase_thresholds: Array[float] = []

# Track if we're in a death sequence
var _dying: bool = false


func _ready() -> void:
	add_to_group("boss")
	super._ready()


func _setup_enemy() -> void:
	# Bosses override this; we call phase init in subclasses
	pass


# Called by subclasses AFTER they set health
func _init_phase_thresholds() -> void:
	_phase_thresholds.clear()
	for i in range(1, max_phases):
		var threshold := 1.0 - (float(i) / float(max_phases))
		_phase_thresholds.append(threshold)
	# e.g. for max_phases=3: [0.66, 0.33]
	# This means: below 66% -> phase 2, below 33% -> phase 3


# --- Health & Phase System ---
func take_damage(amount: int, source: Node3D = null) -> void:
	if is_dead or _dying:
		return

	super.take_damage(amount, source)

	if is_dead:
		return

	# Check phase transitions
	var hp_percent := get_boss_health_percent()
	for i in range(_phase_thresholds.size() - 1, -1, -1):
		var phase_num := i + 2  # threshold[0] triggers phase 2, etc.
		if hp_percent <= _phase_thresholds[i] and phase_num > current_phase:
			current_phase = phase_num
			_on_phase_change(current_phase)
			phase_changed.emit(current_phase)
			break


func get_boss_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return clampf(float(health) / float(max_health), 0.0, 1.0)


# --- Phase Virtual Methods ---
func _on_phase_change(new_phase: int) -> void:
	# Override in subclasses for phase transition effects
	_do_phase_transition_effect(new_phase)


func _phase_1_attack() -> void:
	pass


func _phase_2_attack() -> void:
	pass


func _phase_3_attack() -> void:
	pass


func _get_current_phase_attack() -> Callable:
	match current_phase:
		3: return _phase_3_attack
		2: return _phase_2_attack
		_: return _phase_1_attack


# Phase transition visual effect
func _do_phase_transition_effect(phase: int) -> void:
	# Shockwave particle burst
	var shockwave := GPUParticles3D.new()
	shockwave.emitting = true
	shockwave.one_shot = true
	shockwave.amount = 50
	shockwave.lifetime = 0.8
	shockwave.explosiveness = 1.0
	shockwave.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, 0, 0)
	mat.color = Color.ORANGE if phase == 2 else Color.RED
	shockwave.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	shockwave.draw_pass_1 = mesh

	get_tree().root.add_child(shockwave)

	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(shockwave.queue_free)


# --- Death Override ---
func die(is_glory_kill: bool = false) -> void:
	if is_dead or _dying:
		return

	_dying = true

	# Big death effects
	_spawn_boss_death_effects()

	# Delay before actual removal and signal
	var timer := get_tree().create_timer(death_delay)
	timer.timeout.connect(_on_death_complete)


func _on_death_complete() -> void:
	if is_dead:
		return
	is_dead = true
	boss_defeated.emit(boss_name)
	died.emit(self)

	Global.notify_kill(false)
	Global.add_score(score_value)

	queue_free()


func _spawn_boss_death_effects() -> void:
	# Massive particle explosion
	for i in range(3):
		var particles := GPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.amount = 60
		particles.lifetime = 1.0 + (i * 0.3)
		particles.explosiveness = 1.0
		particles.global_position = global_position + Vector3(
			randf_range(-2, 2), 
			randf_range(0, 3), 
			randf_range(-2, 2)
		)

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 90.0
		mat.initial_velocity_min = 3.0
		mat.initial_velocity_max = 12.0
		mat.gravity = Vector3(0, -5, 0)
		mat.color = Color(0.9, 0.2, 0.1)
		particles.process_material = mat

		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.15, 0.15, 0.15)
		particles.draw_pass_1 = mesh

		get_tree().root.add_child(particles)

		var timer := get_tree().create_timer(2.5)
		timer.timeout.connect(particles.queue_free)


# --- Attack utility (bosses call _do_boss_attack()) ---
func _do_boss_attack() -> void:
	_get_current_phase_attack().call()


# --- Physics Process Override for Boss AI ---
func _physics_process(delta: float) -> void:
	if is_dead or _dying:
		return

	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	var distance_to_player := global_position.distance_to(player.global_position)

	# Always face the player
	var look_dir := player.global_position - global_position
	look_dir.y = 0
	if look_dir.length() > 0.01:
		look_at(global_position - look_dir.normalized(), Vector3.UP, true)

	# Delegate to phase-specific behavior
	_boss_behavior(delta, distance_to_player)

	_process_flash(delta)

	if can_fly:
		velocity.y = 0

	move_and_slide()


func _boss_behavior(delta: float, distance_to_player: float) -> void:
	# Override in subclasses for phase-specific AI
	match current_phase:
		3: _phase_3_behavior(delta, distance_to_player)
		2: _phase_2_behavior(delta, distance_to_player)
		_: _phase_1_behavior(delta, distance_to_player)


# --- Phase behavior overrides ---
func _phase_1_behavior(delta: float, distance: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_1_attack()
		attack_timer = attack_cooldown


func _phase_2_behavior(delta: float, distance: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_2_attack()
		attack_timer = attack_cooldown


func _phase_3_behavior(delta: float, distance: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_3_attack()
		attack_timer = attack_cooldown


# --- Spawn projectile helper ---
func _spawn_projectile(direction: Vector3, speed: float, damage_amount: int, color: Color, size: float = 0.3) -> void:
	var proj := RigidBody3D.new()
	proj.collision_layer = 0
	proj.collision_mask = 1  # collide with player

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = size
	col.shape = sphere
	proj.add_child(col)

	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = size
	sphere_mesh.height = size * 2
	sphere_mesh.material = StandardMaterial3D.new()
	sphere_mesh.material.albedo_color = color
	sphere_mesh.material.emission_enabled = true
	sphere_mesh.material.emission = color * 0.5
	mesh.mesh = sphere_mesh
	proj.add_child(mesh)

	proj.global_position = global_position + Vector3(0, 2, 0)
	proj.linear_velocity = direction * speed

	# Add damage data via meta
	proj.set_meta("damage", damage_amount)
	proj.set_meta("is_boss_projectile", true)

	# Connect body entered
	proj.body_entered.connect(_on_projectile_hit.bind(proj))

	get_tree().root.add_child(proj)

	# Auto-cleanup
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(proj.queue_free)


func _on_projectile_hit(body: Node3D, projectile: RigidBody3D) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		var dmg: int = projectile.get_meta("damage", 10)
		body.take_damage(dmg, self)
	projectile.queue_free()


# --- Spawn hitscan laser ---
func _do_hitscan_laser(damage_amount: int, telegraph_time: float = 0.5, laser_color: Color = Color.RED) -> void:
	# Telegraph: draw a visible laser line after a delay
	var timer := get_tree().create_timer(telegraph_time)
	timer.timeout.connect(_fire_laser.bind(damage_amount, laser_color))


func _fire_laser(damage_amount: int, color: Color) -> void:
	if not player:
		return

	var direction := (player.global_position - global_position).normalized()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 2, 0),
		global_position + direction * 100.0
	)
	query.collision_mask = 1  # hit player
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result and result.collider:
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage_amount, self)

	# Visual laser effect
	var laser_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 100.0
	cylinder.material = StandardMaterial3D.new()
	cylinder.material.albedo_color = color
	cylinder.material.emission_enabled = true
	cylinder.material.emission = color * 2.0
	laser_mesh.mesh = cylinder

	var hit_pos := global_position + direction * 100.0
	var mid := (global_position + Vector3(0, 2, 0) + hit_pos) / 2.0
	laser_mesh.global_position = mid

	var up := Vector3.UP
	var cross := up.cross(direction)
	if cross.length() < 0.001:
		cross = Vector3.RIGHT
	var angle := up.angle_to(direction)
	laser_mesh.rotation = cross.normalized() * angle if cross.length() > 0.001 else Vector3.ZERO

	get_tree().root.add_child(laser_mesh)
	var cleanup := get_tree().create_timer(0.3)
	cleanup.timeout.connect(laser_mesh.queue_free)


# --- Melee AoE Attack ---
func _do_melee_aoe(damage_amount: int, radius: float) -> void:
	if player and global_position.distance_to(player.global_position) <= radius:
		if player.has_method("take_damage"):
			player.take_damage(damage_amount, self)

	# AoE visual
	var aoe_effect := GPUParticles3D.new()
	aoe_effect.emitting = true
	aoe_effect.one_shot = true
	aoe_effect.amount = 20
	aoe_effect.lifetime = 0.4
	aoe_effect.explosiveness = 1.0
	aoe_effect.global_position = global_position + Vector3(0, 1.5, 0)

	var aoe_mat := ParticleProcessMaterial.new()
	aoe_mat.direction = Vector3(0, 0, 0)
	aoe_mat.spread = 180.0
	aoe_mat.initial_velocity_min = 2.0
	aoe_mat.initial_velocity_max = radius
	aoe_mat.gravity = Vector3.ZERO
	aoe_mat.color = Color(1, 0.6, 0.2)
	aoe_effect.process_material = aoe_mat

	var aoe_mesh := BoxMesh.new()
	aoe_mesh.size = Vector3(0.15, 0.15, 0.15)
	aoe_effect.draw_pass_1 = aoe_mesh

	get_tree().root.add_child(aoe_effect)
	var cleanup := get_tree().create_timer(1.0)
	cleanup.timeout.connect(aoe_effect.queue_free)


# --- Global arena shockwave (hits everything on the level) ---
func _do_arena_shockwave(damage_amount: int) -> void:
	if not player:
		return
	if player.has_method("take_damage"):
		player.take_damage(damage_amount, self)

	# Screen-wide flash particles
	var shock := GPUParticles3D.new()
	shock.emitting = true
	shock.one_shot = true
	shock.amount = 80
	shock.lifetime = 0.6
	shock.explosiveness = 1.0
	shock.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(1, 0.3, 0)
	shock.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	shock.draw_pass_1 = mesh

	get_tree().root.add_child(shock)
	var cleanup := get_tree().create_timer(2.0)
	cleanup.timeout.connect(shock.queue_free)
