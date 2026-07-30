extends "res://scripts/enemies/boss_base.gd"
class_name BossFinal

# ============================================================
# FINAL BOSS — Throne Room
# HP: 1200 | Size: 5×8×5 | Gold/white with demonic glow
# ============================================================

# Phase cooldowns
@export var phase_1_cooldown: float = 2.0
@export var phase_2_cooldown: float = 1.5
@export var phase_3_cooldown: float = 1.0

# Attack values
@export var sword_damage: int = 50
@export var dark_orb_damage: int = 20
@export var dark_orb_count: int = 3
@export var rain_orb_count: int = 10
@export var dash_sword_damage: int = 60
@export var portal_laser_damage: int = 25
@export var portal_count: int = 4
@export var aoe_explosion_damage: int = 35
@export var aoe_explosion_interval: float = 10.0
@export var teleport_strike_damage: int = 55

# Internal state
var _flying: bool = false
var _flight_height: float = 5.0
var _summoned_demons: Array[Node3D] = []
var _portals_active: Array[Node3D] = []
var _aoe_explosion_timer: float = 0.0
var _charging_dash: bool = false
var _dash_charge_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _orb_volley_index: int = 0
var _teleporting: bool = false


func _setup_enemy() -> void:
	boss_name = "FINAL BOSS"
	health = 1200
	max_health = 1200
	speed = 5.0
	damage = 50
	attack_range = 25.0
	detection_range = 100.0
	attack_cooldown = phase_1_cooldown
	score_value = 20000
	max_phases = 3
	death_delay = 3.0
	can_fly = false
	boss_bar_enabled = true

	_init_phase_thresholds()


# ============================================================
# PHASE 1 (100-66%): Sword melee, summon elites, dark orbs
# ============================================================
func _phase_1_attack() -> void:
	if not player:
		return

	var dist := global_position.distance_to(player.global_position)
	var choice := randi() % 3

	match choice:
		0:
			# Sword swing (close range) or lunge
			if dist <= 4.0:
				if player.has_method("take_damage"):
					player.take_damage(sword_damage, self)
				_do_melee_aoe(sword_damage, 3.0)
			else:
				_start_dash()
		1:
			# Dark orbs
			_orb_volley_index = 0
			_fire_dark_orbs()
		2:
			# Summon 2 elite demons
			_summon_elite_demons()


func _phase_1_behavior(delta: float, distance: float) -> void:
	if _charging_dash:
		_continue_dash(delta)
		return

	if _teleporting:
		_finish_teleport()

	# Walk toward player
	if distance > 6.0:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)

	velocity.y -= 30.0 * delta

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_1_attack()
		attack_timer = phase_1_cooldown


func _fire_dark_orbs() -> void:
	if _orb_volley_index >= dark_orb_count:
		return

	if not player:
		return

	var dir := (player.global_position - global_position).normalized()
	_spawn_projectile(dir + Vector3(randf_range(-0.15, 0.15), 0.1, randf_range(-0.15, 0.15)), 7.0, dark_orb_damage, Color(0.7, 0, 1.0), 0.5)

	_orb_volley_index += 1
	if _orb_volley_index < dark_orb_count:
		var timer := get_tree().create_timer(0.3)
		timer.timeout.connect(_fire_dark_orbs)


func _summon_elite_demons() -> void:
	# Spawn 2 elite demons near the boss
	for i in range(2):
		var demon := CharacterBody3D.new()

		# Collision shape
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.5, 3, 1.5)
		col.shape = box
		demon.add_child(col)

		# Mesh
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(1.5, 3, 1.5)
		box_mesh.material = StandardMaterial3D.new()
		box_mesh.material.albedo_color = Color(0.6, 0.1, 0.8)
		box_mesh.material.emission_enabled = true
		box_mesh.material.emission = Color(0.3, 0, 0.4)
		mesh.mesh = box_mesh
		demon.add_child(mesh)

		# Position near boss
		demon.global_position = global_position + Vector3(
			randf_range(-5, 5),
			0,
			randf_range(-5, 5)
		)

		# Give basic health/damage meta
		demon.set_meta("health", 150)
		demon.set_meta("is_summoned", true)
		demon.add_to_group("enemy")

		# Attach a simple script for behavior
		var script := GDScript.new()
		script.source_code = """extends CharacterBody3D

var player: Node3D
var health: int = 150
var timer: float = 0.0
var speed: float = 8.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	health = get_meta("health", 150)
	Global.enemies_alive += 1

func _physics_process(delta):
	if health <= 0 or not player:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var dir = (player.global_position - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 30.0 * delta
	
	look_at(global_position - dir, Vector3.UP, true)
	
	timer -= delta
	if timer <= 0 and global_position.distance_to(player.global_position) <= 2.5:
		if player.has_method("take_damage"):
			player.take_damage(20)
		timer = 1.2
	
	move_and_slide()

func take_damage(amount, _src = null):
	health -= amount
	if health <= 0:
		Global.notify_kill(false)
		Global.add_score(200)
		queue_free()
"""
		script.reload()
		demon.set_script(script)

		get_tree().root.add_child(demon)
		_summoned_demons.append(demon)


# ============================================================
# PHASE 2 (66-33%): Wings (flight), dark orb rain, sword dash
# ============================================================
func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)

	if new_phase == 2:
		speed = 7.0
		attack_cooldown = phase_2_cooldown
		_flying = true
		can_fly = true
	elif new_phase == 3:
		speed = 9.0
		attack_cooldown = phase_3_cooldown
		_flying = true  # Permanent flight in phase 3
		can_fly = true
		_flight_height = 8.0
		_aoe_explosion_timer = aoe_explosion_interval
		_activate_portals()


func _phase_2_attack() -> void:
	if not player:
		return

	var choice := randi() % 3

	match choice:
		0:
			# Dark orb rain
			_do_orb_rain()
		1:
			# Sword dash
			_start_dash()
		2:
			# Descend for melee + fly back
			if player.has_method("take_damage"):
				player.take_damage(sword_damage / 2, self)
			_do_melee_aoe(sword_damage / 2, 3.5)


func _phase_2_behavior(delta: float, distance: float) -> void:
	if _charging_dash:
		_continue_dash(delta)
		return

	if _teleporting:
		_finish_teleport()

	# Flight behavior — hover and circle
	_target_flight_height(_flight_height, delta)

	if distance > 12.0:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		# Circle around player
		var to_player := (player.global_position - global_position).normalized()
		var strafe := to_player.cross(Vector3.UP).normalized()
		velocity.x = strafe.x * speed * 0.7
		velocity.z = strafe.z * speed * 0.7

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_2_attack()
		attack_timer = phase_2_cooldown


func _do_orb_rain() -> void:
	if not player:
		return
	for i in range(rain_orb_count):
		var timer := get_tree().create_timer(i * 0.2)
		# Spawn orb from above the player
		var spawn_pos := player.global_position + Vector3(randf_range(-10, 10), 15, randf_range(-10, 10))
		timer.timeout.connect(_spawn_orb_from_sky.bind(spawn_pos))


func _spawn_orb_from_sky(spawn_pos: Vector3) -> void:
	if not player:
		return
	var dir := (player.global_position - spawn_pos).normalized()
	_spawn_projectile_from_pos(spawn_pos, dir, 6.0, dark_orb_damage, Color(0.6, 0, 0.9), 0.4)


func _spawn_projectile_from_pos(pos: Vector3, direction: Vector3, spd: float, dmg: int, color: Color, size: float) -> void:
	var proj := RigidBody3D.new()
	proj.collision_layer = 0
	proj.collision_mask = 1

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
	sphere_mesh.material.emission = color * 0.6
	mesh.mesh = sphere_mesh
	proj.add_child(mesh)

	proj.global_position = pos
	proj.linear_velocity = direction * spd
	proj.set_meta("damage", dmg)
	proj.set_meta("is_boss_projectile", true)
	proj.body_entered.connect(_on_projectile_hit.bind(proj))

	get_tree().root.add_child(proj)
	var cleanup := get_tree().create_timer(6.0)
	cleanup.timeout.connect(proj.queue_free)


func _start_dash() -> void:
	_charging_dash = true
	_dash_charge_timer = 0.4
	if player:
		_dash_direction = (player.global_position - global_position).normalized()
		_dash_direction.y = 0


func _continue_dash(delta: float) -> void:
	_dash_charge_timer -= delta
	velocity.x = _dash_direction.x * speed * 6.0
	velocity.z = _dash_direction.z * speed * 6.0

	if _dash_charge_timer <= 0.0:
		_charging_dash = false
		# Hit player if close
		if player and global_position.distance_to(player.global_position) <= 3.0:
			var current_phase_dmg := sword_damage
			if current_phase >= 2:
				current_phase_dmg = dash_sword_damage
			if player.has_method("take_damage"):
				player.take_damage(current_phase_dmg, self)
			_do_melee_aoe(current_phase_dmg, 3.0)


# ============================================================
# PHASE 3 (33-0%): Permanent flight, portals, AoE, teleport strike
# ============================================================
func _phase_3_attack() -> void:
	if not player:
		return

	var choice := randi() % 4

	match choice:
		0:
			_dark_orb_barrage()
		1:
			# Teleport strike
			_do_teleport_strike()
		2:
			_start_dash()
		3:
			# Rain orbs
			_do_orb_rain()


func _phase_3_behavior(delta: float, distance: float) -> void:
	if _charging_dash:
		_continue_dash(delta)
		return

	if _teleporting:
		_finish_teleport()
		return

	# Permanent flight
	_target_flight_height(_flight_height, delta)

	# Erratic movement
	var to_player := (player.global_position - global_position).normalized()
	var strafe := to_player.cross(Vector3.UP).normalized()
	var wobble := sin(Time.get_ticks_msec() * 0.003)
	velocity.x = (to_player.x + strafe.x * wobble * 2.0) * speed
	velocity.z = (to_player.z + strafe.z * wobble * 2.0) * speed

	# AoE explosion timer
	_aoe_explosion_timer -= delta
	if _aoe_explosion_timer <= 0.0:
		_do_arena_shockwave(aoe_explosion_damage)
		_aoe_explosion_timer = aoe_explosion_interval

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_3_attack()
		attack_timer = phase_3_cooldown


func _target_flight_height(target_y: float, delta: float) -> void:
	if player:
		var desired_y := player.global_position.y + target_y
		velocity.y = (desired_y - global_position.y) * 3.0


func _dark_orb_barrage() -> void:
	# Fire 5 dark orbs in spread
	if not player:
		return
	for i in range(5):
		var angle := deg_to_rad(-30.0 + 15.0 * i)
		var base_dir := (player.global_position - global_position).normalized()
		var dir := base_dir.rotated(Vector3.UP, angle)
		_spawn_projectile(dir, 9.0, dark_orb_damage, Color(0.8, 0, 1), 0.45)


func _do_teleport_strike() -> void:
	if not player:
		return

	_teleporting = true
	# Flash out
	var flash_out := GPUParticles3D.new()
	flash_out.emitting = true
	flash_out.one_shot = true
	flash_out.amount = 30
	flash_out.lifetime = 0.3
	flash_out.explosiveness = 1.0
	flash_out.global_position = global_position
	var mat_out := ParticleProcessMaterial.new()
	mat_out.direction = Vector3.ZERO
	mat_out.spread = 180.0
	mat_out.initial_velocity_min = 3.0
	mat_out.initial_velocity_max = 10.0
	mat_out.color = Color(0.8, 0.8, 1)
	flash_out.process_material = mat_out
	var out_mesh := BoxMesh.new()
	out_mesh.size = Vector3(0.15, 0.15, 0.15)
	flash_out.draw_pass_1 = out_mesh
	get_tree().root.add_child(flash_out)
	var out_cleanup := get_tree().create_timer(1.0)
	out_cleanup.timeout.connect(flash_out.queue_free)

	# Move behind player
	var behind_player := player.global_position - player.global_transform.basis.z * 3.0
	behind_player.y = player.global_position.y + 1.0
	global_position = behind_player


func _finish_teleport() -> void:
	# Strike on appear
	if player and global_position.distance_to(player.global_position) <= 4.0:
		if player.has_method("take_damage"):
			player.take_damage(teleport_strike_damage, self)
		_do_melee_aoe(teleport_strike_damage, 5.0)

	# Flash in effect
	var flash_in := GPUParticles3D.new()
	flash_in.emitting = true
	flash_in.one_shot = true
	flash_in.amount = 30
	flash_in.lifetime = 0.3
	flash_in.explosiveness = 1.0
	flash_in.global_position = global_position
	var mat_in := ParticleProcessMaterial.new()
	mat_in.direction = Vector3.ZERO
	mat_in.spread = 180.0
	mat_in.initial_velocity_min = 3.0
	mat_in.initial_velocity_max = 10.0
	mat_in.color = Color(1, 0.9, 0.5)
	flash_in.process_material = mat_in
	var in_mesh := BoxMesh.new()
	in_mesh.size = Vector3(0.15, 0.15, 0.15)
	flash_in.draw_pass_1 = in_mesh
	get_tree().root.add_child(flash_in)
	var in_cleanup := get_tree().create_timer(1.0)
	in_cleanup.timeout.connect(flash_in.queue_free)

	_teleporting = false


func _activate_portals() -> void:
	# Spawn 4 portal nodes around the arena
	for i in range(portal_count):
		var portal := Node3D.new()
		portal.name = "LaserPortal" + str(i)

		var mesh := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.5
		ring.bottom_radius = 0.5
		ring.height = 0.1
		ring.material = StandardMaterial3D.new()
		ring.material.albedo_color = Color(0.6, 0, 1)
		ring.material.emission_enabled = true
		ring.material.emission = Color(0.4, 0, 0.8)
		mesh.mesh = ring
		portal.add_child(mesh)

		var angle := (TAU / portal_count) * i
		portal.global_position = global_position + Vector3(
			cos(angle) * 12.0,
			3.0,
			sin(angle) * 12.0
		)
		portal.set_meta("angle", angle)
		portal.set_meta("radius", 12.0)

		# Attach laser script
		var script := GDScript.new()
		script.source_code = """extends Node3D

var laser_timer: float = 0.0
var laser_interval: float = 2.0

func _ready():
	laser_timer = randf_range(0.5, laser_interval)

func _physics_process(delta):
	laser_timer -= delta
	if laser_timer <= 0:
		laser_timer = laser_interval
		_fire_portal_laser()

func _fire_portal_laser():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var dir = (player.global_position - global_position).normalized()
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + dir * 50.0)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result and result.collider and result.collider.has_method("take_damage"):
		result.collider.take_damage(25)
"""
		script.reload()
		portal.set_script(script)

		get_tree().root.add_child(portal)
		_portals_active.append(portal)


# Cleanup portals on death
func _on_death_complete() -> void:
	for portal in _portals_active:
		if portal:
			portal.queue_free()
	_portals_active.clear()
	super._on_death_complete()
