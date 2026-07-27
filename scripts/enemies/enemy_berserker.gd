extends EnemyBase
class_name EnemyBerserker

# ============================================================
# Berserker Demon — Ultra-fast rush-down melee
# ============================================================

var is_charging: bool = false
var charge_timer: float = 0.0
var charge_cooldown: float = 2.0
var charge_speed: float = 30.0
var charge_duration: float = 0.4

func _setup_enemy() -> void:
	health = 100
	max_health = 100
	speed = 14.0
	damage = 25
	attack_range = 3.0
	detection_range = 25.0
	attack_cooldown = 0.6
	score_value = 175
	charge_cooldown = 2.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	var distance_to_player := global_position.distance_to(player.global_position)
	
	if distance_to_player > detection_range:
		_idle_behavior(delta)
		return
	
	# Face player
	var look_dir := (player.global_position - global_position)
	look_dir.y = 0
	if look_dir.length() > 0.01:
		look_at(global_position - look_dir.normalized(), Vector3.UP, true)
	
	# Charge logic
	charge_cooldown -= delta
	
	if is_charging:
		charge_timer -= delta
		if charge_timer <= 0.0:
			is_charging = false
		else:
			# Maintain charge velocity
			var dir := (player.global_position - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * charge_speed
			velocity.z = dir.z * charge_speed
			velocity.y -= 30.0 * delta
			
			# Damage on contact during charge
			if distance_to_player <= attack_range:
				attack_timer -= delta
				if attack_timer <= 0.0:
					_do_attack()
			move_and_slide()
			_process_flash(delta)
			return
	
	# Normal behavior
	if charge_cooldown <= 0.0 and distance_to_player < 15.0:
		_start_charge()
	elif distance_to_player <= attack_range:
		_attack_behavior(delta, distance_to_player)
	else:
		_chase_behavior(delta, distance_to_player)
	
	_process_flash(delta)
	
	if not can_fly:
		velocity.y -= 30.0 * delta
	
	move_and_slide()


func _start_charge() -> void:
	is_charging = true
	charge_timer = charge_duration
	charge_cooldown = 2.0
	attack_timer = 0.0  # Immediate damage on contact
