extends EnemyBase
class_name EnemySniper

# ============================================================
# Sniper Demon — Long-range, keeps distance
# ============================================================

func _setup_enemy() -> void:
	health = 60
	max_health = 60
	speed = 4.0
	damage = 25
	attack_range = 30.0    # Can hit from far away
	detection_range = 50.0
	attack_cooldown = 2.5
	score_value = 150

# Sniper maintains distance — override chase to retreat if too close
func _chase_behavior(delta: float, distance: float) -> void:
	var preferred_distance := 10.0
	var direction := (player.global_position - global_position).normalized()
	direction.y = 0
	
	if distance < preferred_distance:
		# Too close — retreat
		velocity.x = -direction.x * speed
		velocity.z = -direction.z * speed
	else:
		# Too far — advance
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	
	if not can_fly:
		velocity.y -= 30.0 * delta
