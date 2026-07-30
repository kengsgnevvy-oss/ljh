extends "res://scripts/enemies/enemy_base.gd"
class_name EnemyElite

# ============================================================
# Elite Demon — Fast, shoots projectiles + dash attack
# ============================================================

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_speed: float = 25.0
var dash_duration: float = 0.25
var dash_cooldown: float = 3.0
var shoot_cooldown: float = 1.2
var shoot_timer: float = 0.0
var projectile_scene: PackedScene = null

func _setup_enemy() -> void:
	health = 180
	max_health = 180
	speed = 10.0
	damage = 30
	attack_range = 3.0
	detection_range = 25.0
	attack_cooldown = 1.0
	score_value = 300

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
	
	# Dash logic
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		else:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed
			velocity.y -= 30.0 * delta
			move_and_slide()
			_process_flash(delta)
			return
	
	dash_cooldown -= delta
	shoot_timer -= delta
	
	# Shoot at range
	if distance_to_player > 5.0 and shoot_timer <= 0.0:
		_shoot_projectile()
		shoot_timer = shoot_cooldown
	elif distance_to_player <= attack_range:
		# Melee attack
		attack_timer -= delta
		if attack_timer <= 0.0:
			_do_attack()
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
	else:
		# Chase
		var direction := (player.global_position - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	
	# Initiate dash
	if dash_cooldown <= 0.0 and distance_to_player > 6.0 and distance_to_player < 18.0:
		_start_dash()
	
	velocity.y -= 30.0 * delta
	move_and_slide()
	_process_flash(delta)


func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown = 3.0
	dash_direction = (player.global_position - global_position).normalized()
	dash_direction.y = 0


func _shoot_projectile() -> void:
	var bullet := CharacterBody3D.new()
	bullet.name = "EliteProjectile"
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	col.shape = sphere
	bullet.add_child(col)
	
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.9, 1.0)  # White-ish
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	mesh.set_surface_override_material(0, mat)
	bullet.add_child(mesh)
	
	bullet.global_position = global_position + Vector3(0, 1, 0)
	
	var dir := (player.global_position - global_position).normalized()
	
	var script := GDScript.new()
	script.source_code = """extends CharacterBody3D
var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var lifetime: float = 3.0
var damage: int = 15

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)
	if collision:
		var col = collision.get_collider()
		if col.has_method("take_damage"):
			col.take_damage(damage, self)
		queue_free()
"""
	script.reload()
	bullet.set_script(script)
	bullet.set("direction", dir)
	bullet.set("damage", 15)
	
	get_tree().root.add_child(bullet)
