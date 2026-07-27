extends BossBase
class_name BossHellMech

# ============================================================
# HELL MECH — Second Boss (Hell Forge)
# HP: 800 | Size: 4×6×4 | Dark metal with orange glow
# ============================================================

# Phase cooldowns
@export var phase_1_cooldown: float = 2.5
@export var phase_2_cooldown: float = 2.0
@export var phase_3_cooldown: float = 1.2

# Attack values
@export var mg_burst_count: int = 5
@export var mg_damage_per_shot: int = 8
@export var rocket_count: int = 3
@export var rocket_damage: int = 25
@export var flamethrower_damage: int = 10
@export var flamethrower_range: float = 10.0
@export var jump_slam_radius: float = 8.0
@export var jump_slam_damage: int = 30
@export var overheat_explosion_radius: float = 15.0
@export var overheat_explosion_damage: int = 40
@export var overheat_self_damage: int = 50

# Overheat mechanic
var _overheat_explosion_timer: float = 0.0
var _overheat_interval: float = 5.0
var _takes_extra_damage: bool = false

# Internal state
var _mg_shot_index: int = 0
var _rocket_index: int = 0
var _is_jumping: bool = false
var _jump_timer: float = 0.0
var _jump_target: Vector3 = Vector3.ZERO
var _flame_active: bool = false
var _flame_timer: float = 0.0


func _setup_enemy() -> void:
	boss_name = "Hell Mech"
	health = 800
	max_health = 800
	speed = 4.0
	damage = 25
	attack_range = 20.0
	detection_range = 60.0
	attack_cooldown = phase_1_cooldown
	score_value = 8000
	max_phases = 3
	death_delay = 2.0
	can_fly = false

	_init_phase_thresholds()


# ============================================================
# PHASE 1 (100-66%): Machine gun bursts, rocket salvos
# ============================================================
func _phase_1_attack() -> void:
	if not player:
		return

	var choice := randi() % 2

	match choice:
		0:
			# Machine gun burst
			_mg_shot_index = 0
			_fire_mg_burst()
		1:
			# Rocket salvo
			_rocket_index = 0
			_fire_rocket_salvo()


func _fire_mg_burst() -> void:
	if _mg_shot_index >= mg_burst_count:
		return

	var dir := (player.global_position - global_position).normalized()
	dir += Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))

	# Hitscan for each bullet
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 2.5, 0),
		global_position + dir * 100.0
	)
	query.collision_mask = 1
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result and result.collider and result.collider.has_method("take_damage"):
		result.collider.take_damage(mg_damage_per_shot, self)

	# Muzzle flash
	_spawn_muzzle_flash(global_position + Vector3(0, 2.5, 0) + dir * 1.5)

	_mg_shot_index += 1
	if _mg_shot_index < mg_burst_count:
		var timer := get_tree().create_timer(0.1)
		timer.timeout.connect(_fire_mg_burst)


func _fire_rocket_salvo() -> void:
	if _rocket_index >= rocket_count:
		return

	var dir := (player.global_position - global_position).normalized()
	_spawn_projectile(dir, 6.0, rocket_damage, Color(1, 0.5, 0.1), 0.4)

	_rocket_index += 1
	if _rocket_index < rocket_count:
		var timer := get_tree().create_timer(0.35)
		timer.timeout.connect(_fire_rocket_salvo)


func _spawn_muzzle_flash(pos: Vector3) -> void:
	var flash := GPUParticles3D.new()
	flash.emitting = true
	flash.one_shot = true
	flash.amount = 5
	flash.lifetime = 0.1
	flash.explosiveness = 1.0
	flash.global_position = pos

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.color = Color(1, 1, 0.5)
	flash.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	flash.draw_pass_1 = mesh

	get_tree().root.add_child(flash)
	var cleanup := get_tree().create_timer(0.3)
	cleanup.timeout.connect(flash.queue_free)


func _phase_1_behavior(delta: float, distance: float) -> void:
	if _is_jumping:
		_continue_jump(delta)
		return

	# Maintain medium distance
	if distance > 18.0:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	elif distance < 8.0:
		var dir := (global_position - player.global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		# Strafe
		var strafe := (player.global_position - global_position).cross(Vector3.UP).normalized()
		velocity.x = strafe.x * speed * 0.4
		velocity.z = strafe.z * speed * 0.4

	velocity.y -= 30.0 * delta

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_1_attack()
		attack_timer = phase_1_cooldown


# ============================================================
# PHASE 2 (66-33%): Adds flamethrower, jump-slam
# ============================================================
func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)

	if new_phase == 2:
		speed = 5.5
		attack_cooldown = phase_2_cooldown
	elif new_phase == 3:
		speed = 6.5
		attack_cooldown = phase_3_cooldown
		_takes_extra_damage = true
		_overheat_explosion_timer = _overheat_interval


func _phase_2_attack() -> void:
	if not player:
		return

	var choice := randi() % 4

	match choice:
		0:
			_mg_shot_index = 0
			_fire_mg_burst()
		1:
			_rocket_index = 0
			_fire_rocket_salvo()
		2:
			# Flamethrower
			_flame_active = true
			_flame_timer = 2.0
		3:
			# Jump slam
			if not _is_jumping:
				_start_jump()


func _phase_2_behavior(delta: float, distance: float) -> void:
	if _is_jumping:
		_continue_jump(delta)
		return

	# Flamethrower active
	if _flame_active:
		_process_flamethrower(delta)
	else:
		# Maintain distance for ranged attacks
		if distance > 15.0:
			var dir := (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		elif distance < 6.0:
			var dir := (global_position - player.global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
			velocity.z = move_toward(velocity.z, 0, speed * delta)

	velocity.y -= 30.0 * delta

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_2_attack()
		attack_timer = phase_2_cooldown


func _process_flamethrower(delta: float) -> void:
	_flame_timer -= delta

	# Face player during flame
	var dir := (player.global_position - global_position).normalized()
	var dist := global_position.distance_to(player.global_position)

	if dist <= flamethrower_range:
		if player.has_method("take_damage"):
			player.take_damage(flamethrower_damage, self)

		# Flame particles
		if randf() < 0.3:
			var flame := GPUParticles3D.new()
			flame.emitting = true
			flame.one_shot = true
			flame.amount = 3
			flame.lifetime = 0.5
			flame.explosiveness = 1.0
			flame.global_position = global_position + Vector3(0, 2, 0) + dir * 2.0

			var mat := ParticleProcessMaterial.new()
			mat.direction = dir
			mat.spread = 15.0
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 8.0
			mat.color = Color(1, 0.4, 0)
			flame.process_material = mat

			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.1, 0.1, 0.1)
			flame.draw_pass_1 = mesh

			get_tree().root.add_child(flame)
			var cleanup := get_tree().create_timer(1.0)
			cleanup.timeout.connect(flame.queue_free)

	velocity.x = 0
	velocity.z = 0

	if _flame_timer <= 0.0:
		_flame_active = false


func _start_jump() -> void:
	if not player:
		return
	_is_jumping = true
	_jump_timer = 0.0
	_jump_target = player.global_position
	velocity.y = 20.0  # Launch upward


func _continue_jump(delta: float) -> void:
	_jump_timer += delta

	if _jump_timer < 0.5:
		# Ascend toward target horizontally
		var to_target := _jump_target - global_position
		to_target.y = 0
		velocity.x = to_target.normalized().x * speed * 3.0
		velocity.z = to_target.normalized().z * speed * 3.0
		velocity.y -= 20.0 * delta  # Still some upward momentum
	else:
		# Descend fast
		var to_target := _jump_target - global_position
		to_target.y = 0
		velocity.x = to_target.normalized().x * speed * 4.0
		velocity.z = to_target.normalized().z * speed * 4.0
		velocity.y = -25.0

	# Impact on landing
	if _jump_timer > 0.8 and global_position.y <= _jump_target.y:
		_is_jumping = false
		velocity.y = 0
		# Slam AoE
		_do_melee_aoe(jump_slam_damage, jump_slam_radius)

		# Slam shockwave
		var slam := GPUParticles3D.new()
		slam.emitting = true
		slam.one_shot = true
		slam.amount = 40
		slam.lifetime = 0.5
		slam.explosiveness = 1.0
		slam.global_position = global_position

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 5.0
		mat.initial_velocity_max = 15.0
		mat.gravity = Vector3.ZERO
		mat.color = Color(1, 0.5, 0.1)
		slam.process_material = mat

		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 0.2, 0.2)
		slam.draw_pass_1 = mesh

		get_tree().root.add_child(slam)
		var cleanup := get_tree().create_timer(1.5)
		cleanup.timeout.connect(slam.queue_free)


# ============================================================
# PHASE 3 (33-0%): Overheat — attacks without pause, +50% damage taken
# ============================================================
func _phase_3_behavior(delta: float, distance: float) -> void:
	if _is_jumping:
		_continue_jump(delta)
		return

	if _flame_active:
		_process_flamethrower(delta)
		attack_timer = 0.1  # Keep attacking
	else:
		# Constantly moving, no pauses
		if distance > 12.0:
			var dir := (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			var strafe := (player.global_position - global_position).cross(Vector3.UP).normalized()
			velocity.x = strafe.x * speed * 0.7
			velocity.z = strafe.z * speed * 0.7

	velocity.y -= 30.0 * delta

	# Overheat explosion
	_overheat_explosion_timer -= delta
	if _overheat_explosion_timer <= 0.0:
		_trigger_overheat_explosion()
		_overheat_explosion_timer = _overheat_interval

	# Attack without pauses
	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_3_attack()
		attack_timer = phase_3_cooldown


func _phase_3_attack() -> void:
	if not player:
		return

	var choice := randi() % 4

	match choice:
		0:
			_mg_shot_index = 0
			_fire_mg_burst()
		1:
			_rocket_index = 0
			_fire_rocket_salvo()
		2:
			_flame_active = true
			_flame_timer = 1.5
		3:
			if not _is_jumping:
				_start_jump()


func _trigger_overheat_explosion() -> void:
	# Self-damage
	health -= overheat_self_damage

	# Damage player in radius
	if player and global_position.distance_to(player.global_position) <= overheat_explosion_radius:
		if player.has_method("take_damage"):
			player.take_damage(overheat_explosion_damage, self)

	# Big orange explosion
	for i in range(3):
		var exp := GPUParticles3D.new()
		exp.emitting = true
		exp.one_shot = true
		exp.amount = 50
		exp.lifetime = 0.8
		exp.explosiveness = 1.0
		exp.global_position = global_position + Vector3(0, 2 + i, 0)

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 8.0
		mat.initial_velocity_max = 25.0
		mat.color = Color(1, 0.5, 0)
		exp.process_material = mat

		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 0.2, 0.2)
		exp.draw_pass_1 = mesh

		get_tree().root.add_child(exp)
		var cleanup := get_tree().create_timer(2.0)
		cleanup.timeout.connect(exp.queue_free)

	# Check if boss died from self-damage
	if health <= 0:
		die()


func take_damage(amount: int, source: Node3D = null) -> void:
	var actual_amount := amount
	if _takes_extra_damage:
		actual_amount = int(ceil(float(amount) * 1.5))
	super.take_damage(actual_amount, source)
