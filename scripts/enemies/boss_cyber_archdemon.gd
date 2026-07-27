extends BossBase
class_name BossCyberArchdemon

# ============================================================
# CYBER ARCHDEMON — First Boss (Techno-Hell)
# HP: 600 | Size: 3×5×3 | Red/black with cyber details
# ============================================================

# Phase attack cooldowns
@export var phase_1_cooldown: float = 2.0
@export var phase_2_cooldown: float = 1.5
@export var phase_3_cooldown: float = 1.0

# Attack values
@export var punch_damage: int = 40
@export var punch_aoe_radius: float = 3.0
@export var fireball_damage: int = 20
@export var laser_damage: int = 30
@export var laser_telegraph: float = 0.5
@export var stomp_damage: int = 15

# Internal
var _fireball_volley_count: int = 0
var _is_charging: bool = false
var _charge_direction: Vector3 = Vector3.ZERO
var _charge_timer: float = 0.0
var _phase_1_step_timer: float = 0.0


func _ready() -> void:
	super._ready()


func _setup_enemy() -> void:
	boss_name = "Cyber Archdemon"
	health = 600
	max_health = 600
	speed = 4.0
	damage = 40
	attack_range = 12.0
	detection_range = 50.0
	attack_cooldown = phase_1_cooldown
	score_value = 5000
	max_phases = 3
	death_delay = 2.0
	can_fly = false

	_init_phase_thresholds()


# ============================================================
# PHASE 1 (100-66%): Slow steps, punch, fireball
# ============================================================
func _phase_1_attack() -> void:
	if not player:
		return

	var dist := global_position.distance_to(player.global_position)

	if dist <= punch_aoe_radius + 1.0:
		# Close range: punch
		_do_melee_aoe(punch_damage, punch_aoe_radius)
	else:
		# Ranged: fireball
		var dir := (player.global_position - global_position).normalized()
		_spawn_projectile(dir + Vector3(0, 0.2, 0), 8.0, fireball_damage, Color(1, 0.3, 0))


func _phase_1_behavior(delta: float, distance: float) -> void:
	# Slow walk toward player
	if distance > attack_range:
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


# ============================================================
# PHASE 2 (66-33%): Faster, laser eye, dash
# ============================================================
func _on_phase_change(new_phase: int) -> void:
	super._on_phase_change(new_phase)

	if new_phase == 2:
		speed = 7.0
		attack_cooldown = phase_2_cooldown
	elif new_phase == 3:
		speed = 9.0
		attack_cooldown = phase_3_cooldown
		_fireball_volley_count = 0


func _phase_2_attack() -> void:
	if not player:
		return

	var dist := global_position.distance_to(player.global_position)
	var choice := randi() % 3

	match choice:
		0:
			# Punch
			_do_melee_aoe(punch_damage, punch_aoe_radius)
		1:
			# Laser eye
			_do_hitscan_laser(laser_damage, laser_telegraph, Color.RED)
		2:
			# Charge/dash at player
			_start_charge()


func _phase_2_behavior(delta: float, distance: float) -> void:
	if _is_charging:
		_continue_charge(delta)
		return

	# Fast chase
	if distance > attack_range:
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
		_phase_2_attack()
		attack_timer = phase_2_cooldown


func _start_charge() -> void:
	_is_charging = true
	_charge_timer = 0.8
	if player:
		_charge_direction = (player.global_position - global_position).normalized()
		_charge_direction.y = 0


func _continue_charge(delta: float) -> void:
	_charge_timer -= delta
	velocity.x = _charge_direction.x * speed * 4.0
	velocity.z = _charge_direction.z * speed * 4.0
	velocity.y -= 30.0 * delta

	if _charge_timer <= 0.0:
		_is_charging = false
		# Impact at end of charge
		if player and global_position.distance_to(player.global_position) <= punch_aoe_radius + 2.0:
			if player.has_method("take_damage"):
				player.take_damage(punch_damage / 2, self)


# ============================================================
# PHASE 3 (33-0%): Laser sweep, fireball volley, stomp wave
# ============================================================
func _phase_3_attack() -> void:
	if not player:
		return

	match _fireball_volley_count:
		0, 1:
			# Fireball volley (3 shots)
			var dir := (player.global_position - global_position).normalized()
			_spawn_projectile(dir + Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2)), 10.0, fireball_damage, Color(1, 0.2, 0))
			_fireball_volley_count += 1
			if _fireball_volley_count >= 3:
				_fireball_volley_count = 0
			attack_timer = 0.3  # Quick volley
		2:
			# Laser sweep
			_do_hitscan_laser(laser_damage, 0.3, Color(1, 0, 0))
			_fireball_volley_count = 0
			attack_timer = phase_3_cooldown

	# 30% chance for stomp
	if randf() < 0.3:
		_do_arena_shockwave(stomp_damage)


func _phase_3_behavior(delta: float, distance: float) -> void:
	if _is_charging:
		_continue_charge(delta)
		return

	# Aggressive chase
	if distance > 8.0:
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		# Circle-strafe around player
		var to_player := (player.global_position - global_position).normalized()
		var strafe_dir := to_player.cross(Vector3.UP).normalized()
		velocity.x = strafe_dir.x * speed * 0.6
		velocity.z = strafe_dir.z * speed * 0.6

	velocity.y -= 30.0 * delta

	attack_timer -= delta
	if attack_timer <= 0.0:
		_phase_3_attack()
		if attack_timer <= 0.0:  # In case _phase_3_attack didn't set timer
			attack_timer = phase_3_cooldown
