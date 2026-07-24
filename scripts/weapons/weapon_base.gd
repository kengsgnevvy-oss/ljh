extends Node3D

# ============================================================
# ULTRANOKIA Weapon Base Class
# All weapons inherit from this. Handles stats, ammo, reload.
# ============================================================

# --- Exported Stats ---
@export var weapon_name: String = "Unnamed"
@export var weapon_slot: int = 1
@export var damage: float = 10.0
@export var fire_rate: float = 0.3
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var reload_time: float = 1.5
@export var auto_fire: bool = false
@export var spread: float = 0.0
@export var weapon_range: float = 100.0
@export var alt_fire_ammo_cost: int = 1

# --- Internal State ---
var fire_timer: float = 0.0
var reload_timer: float = 0.0
var is_reloading: bool = false
var is_alt_firing: bool = false
var weapon_manager: Node = null

# --- Node References ---
@onready var muzzle_point: Marker3D = $MuzzlePoint if has_node("MuzzlePoint") else null
@onready var muzzle_flash_light: OmniLight3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var fire_sound: AudioStreamPlayer3D = $FireSound if has_node("FireSound") else null
@onready var alt_fire_sound: AudioStreamPlayer3D = $AltFireSound if has_node("AltFireSound") else null
@onready var reload_sound: AudioStreamPlayer3D = $ReloadSound if has_node("ReloadSound") else null

# --- Signals ---
signal fired()
signal alt_fired()
signal reloaded()
signal ammo_changed(current_ammo: int, max_ammo: int)

# --- Bullet Scene ---
var bullet_scene: PackedScene = preload("res://scenes/weapons/bullet.tscn")


func _ready() -> void:
	_setup_weapon()
	fire_timer = 0.0
	reload_timer = 0.0


func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
	
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
	
	if auto_fire and Input.is_action_pressed("shoot") and can_fire():
		fire()


func _setup_weapon() -> void:
	current_ammo = max_ammo


# ============================================================
# FIRING
# ============================================================
func fire() -> bool:
	if not can_fire():
		return false
	
	_spend_ammo(1)
	_do_fire()
	fire_timer = fire_rate
	
	_show_muzzle_flash()
	_play_fire_sound()
	fired.emit()
	ammo_changed.emit(current_ammo, max_ammo)
	
	return true


func _do_fire() -> void:
	_spawn_bullet(spread)


# ============================================================
# ALT FIRE
# ============================================================
func alt_fire() -> bool:
	if not can_alt_fire():
		return false
	
	_spend_ammo(alt_fire_ammo_cost)
	_do_alt_fire()
	fire_timer = fire_rate
	
	_show_muzzle_flash()
	_play_alt_fire_sound()
	alt_fired.emit()
	ammo_changed.emit(current_ammo, max_ammo)
	
	return true


func _do_alt_fire() -> void:
	_spawn_bullet(spread * 2.0)


# ============================================================
# RELOAD
# ============================================================
func reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	
	is_reloading = true
	reload_timer = reload_time
	_play_reload_sound()


func _finish_reload() -> void:
	current_ammo = max_ammo
	is_reloading = false
	reloaded.emit()
	ammo_changed.emit(current_ammo, max_ammo)


# ============================================================
# AMMO
# ============================================================
func _spend_ammo(amount: int) -> void:
	current_ammo = max(0, current_ammo - amount)


func can_fire() -> bool:
	return current_ammo > 0 and fire_timer <= 0.0 and not is_reloading


func can_alt_fire() -> bool:
	return current_ammo >= alt_fire_ammo_cost and fire_timer <= 0.0 and not is_reloading


func get_ammo_percent() -> float:
	if max_ammo <= 0:
		return 0.0
	return float(current_ammo) / float(max_ammo)


# ============================================================
# BULLET SPAWNING
# ============================================================
func _spawn_bullet(bullet_spread: float = 0.0, override_damage: float = -1.0, override_speed: float = -1.0) -> Node3D:
	if not bullet_scene:
		return null
	
	var bullet: Node3D = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	var spawn_pos: Vector3 = global_position
	var spawn_dir: Vector3 = -global_transform.basis.z
	
	if muzzle_point:
		spawn_pos = muzzle_point.global_position
		spawn_dir = -muzzle_point.global_transform.basis.z
	
	if bullet_spread > 0.0:
		var spread_rad: float = deg_to_rad(bullet_spread)
		spawn_dir = spawn_dir.rotated(Vector3.RIGHT, randf_range(-spread_rad, spread_rad))
		spawn_dir = spawn_dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
		spawn_dir = spawn_dir.normalized()
	
	bullet.global_position = spawn_pos
	
	if bullet.has_method("configure"):
		var dmg: float = damage if override_damage < 0 else override_damage
		bullet.configure(spawn_dir, dmg, weapon_range)
	elif "direction" in bullet:
		bullet.set("direction", spawn_dir)
		if "bullet_damage" in bullet:
			bullet.set("bullet_damage", damage if override_damage < 0 else override_damage)
	
	if "source_weapon" in bullet:
		bullet.set("source_weapon", self)
	
	return bullet


# ============================================================
# HITSCAN
# ============================================================
func _do_hitscan(dmg: float = -1.0, _penetration: bool = false) -> Dictionary:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	
	if muzzle_point:
		from = muzzle_point.global_position
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * weapon_range)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_pos: Vector3 = result.position
		var collider: Variant = result.collider
		var use_dmg: float = damage if dmg < 0 else dmg
		
		if collider and collider.has_method("take_damage"):
			collider.take_damage(use_dmg)
		
		_spawn_impact(hit_pos, result.normal)
		_trigger_screen_shake(use_dmg)
		_draw_tracer(from if muzzle_point else cam.global_position, hit_pos)
		
		return {"hit": true, "position": hit_pos, "target": collider}
	else:
		var end_pos: Vector3 = from + dir * weapon_range
		_draw_tracer(from if muzzle_point else cam.global_position, end_pos)
		return {"hit": false, "position": end_pos, "target": null}


# ============================================================
# EFFECTS
# ============================================================
func _show_muzzle_flash() -> void:
	if muzzle_flash_light:
		muzzle_flash_light.visible = true
		var t: Tween = create_tween()
		t.tween_property(muzzle_flash_light, "light_energy", 0.0, 0.05).from_current()
		t.tween_callback(func(): muzzle_flash_light.visible = false)


func _spawn_impact(pos: Vector3, _normal: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.3
	particles.global_position = pos
	particles.process_material = _create_spark_material()
	
	get_tree().root.add_child(particles)
	
	var t: Tween = create_tween()
	t.tween_callback(func(): particles.queue_free()).set_delay(0.5)


func _create_spark_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.spread = 45.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color(1.0, 0.6, 0.1, 1.0)
	mat.lifetime_min = 0.15
	mat.lifetime_max = 0.35
	return mat


func _draw_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.0)
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()
	
	get_tree().root.add_child(mesh_instance)
	
	var t: Tween = create_tween()
	t.tween_callback(func(): mesh_instance.queue_free()).set_delay(0.08)


func _trigger_screen_shake(strength_factor: float = 1.0) -> void:
	var shake_amount: float = clamp(strength_factor / 50.0, 0.02, 0.15)
	if Global.has_method("shake_screen"):
		Global.shake_screen(shake_amount)
	elif "shake_screen" in Global:
		Global.shake_screen(shake_amount)
	elif weapon_manager and weapon_manager.has_method("shake_camera"):
		weapon_manager.shake_camera(shake_amount)


# ============================================================
# SOUND PLACEHOLDERS
# ============================================================
func _play_fire_sound() -> void:
	if fire_sound:
		fire_sound.play()


func _play_alt_fire_sound() -> void:
	if alt_fire_sound:
		alt_fire_sound.play()


func _play_reload_sound() -> void:
	if reload_sound:
		reload_sound.play()


# ============================================================
# WEAPON VISIBILITY
# ============================================================
func set_weapon_visible(v: bool) -> void:
	visible = v
	set_process(v)
	set_physics_process(v)


# ============================================================
# EXPLOSION
# ============================================================
func _do_explosion(center: Vector3, radius: float, dmg: float) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = center
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results: Array = space_state.intersect_shape(query)
	for result in results:
		var collider: Variant = result.collider
		if collider and collider.has_method("take_damage"):
			var dist: float = center.distance_to(collider.global_position)
			var falloff: float = max(0.0, 1.0 - (dist / radius))
			collider.take_damage(int(dmg * falloff))
	
	var explosion_particles: GPUParticles3D = GPUParticles3D.new()
	explosion_particles.emitting = true
	explosion_particles.one_shot = true
	explosion_particles.amount = 30
	explosion_particles.lifetime = 0.5
	explosion_particles.global_position = center
	explosion_particles.process_material = _create_explosion_material()
	get_tree().root.add_child(explosion_particles)
	
	var flash: OmniLight3D = OmniLight3D.new()
	flash.global_position = center
	flash.light_energy = 8.0
	flash.light_color = Color(1.0, 0.4, 0.1)
	flash.omni_range = radius * 2
	get_tree().root.add_child(flash)
	
	var t: Tween = create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.3)
	t.tween_callback(func(): flash.queue_free())
	t.tween_callback(func(): explosion_particles.queue_free()).set_delay(0.5)
	
	_trigger_screen_shake(dmg * 0.5)


func _create_explosion_material() -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.spread = 180.0
	mat.gravity = Vector3(0, 0, 0)
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.scale_min = 0.1
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.3, 0.05, 1.0)
	mat.color_ramp = _create_fire_color_ramp()
	mat.lifetime_min = 0.2
	mat.lifetime_max = 0.5
	return mat


func _create_fire_color_ramp() -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = gradient
	tex.width = 32
	return tex
