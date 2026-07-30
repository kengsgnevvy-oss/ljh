extends "res://scripts/enemies/enemy_base.gd"
class_name EnemySpiderMine

# ============================================================
# Spider Mine — Fast, explodes on contact, AoE damage
# ============================================================

var explosion_range: float = 3.0
var explosion_damage: int = 50

func _setup_enemy() -> void:
	health = 30
	max_health = 30
	speed = 10.0
	damage = 50
	attack_range = 1.5
	detection_range = 25.0
	attack_cooldown = 0.1
	score_value = 75
	explosion_range = 3.0

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
		move_and_slide()
		_process_flash(delta)
		return
	
	# Face player
	var look_dir := (player.global_position - global_position)
	look_dir.y = 0
	if look_dir.length() > 0.01:
		look_at(global_position - look_dir.normalized(), Vector3.UP, true)
	
	# Rush toward player
	var direction := (player.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 30.0 * delta
	
	move_and_slide()
	
	# Explode on contact
	if distance_to_player <= attack_range:
		_explode()
	
	_process_flash(delta)


func _explode() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Damage player if in range
	if player and player.has_method("take_damage"):
		var dist := global_position.distance_to(player.global_position)
		if dist <= explosion_range:
			player.take_damage(explosion_damage)
	
	# Damage nearby enemies too (chain reaction!)
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= explosion_range:
			enemy.take_damage(explosion_damage / 2)
	
	# AoE visual
	_spawn_explosion_effect()
	
	Global.notify_kill(false)
	Global.add_score(score_value)
	queue_free()


func _spawn_explosion_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 50
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.global_position = global_position
	
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 5.0
	particle_material.initial_velocity_max = 15.0
	particle_material.gravity = Vector3(0, -15.0, 0)
	particle_material.color = Color(1.0, 0.5, 0.0)  # Orange explosion
	particles.process_material = particle_material
	
	var particle_mesh := BoxMesh.new()
	particle_mesh.size = Vector3(0.08, 0.08, 0.08)
	particles.draw_pass_1 = particle_mesh
	
	get_tree().root.add_child(particles)
	
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(particles.queue_free)


# Spider mines can't be glory killed — they explode
func die(_is_glory_kill: bool = false) -> void:
	_explode()
