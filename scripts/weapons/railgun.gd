extends "res://scripts/weapons/weapon_base.gd"
# RAILGUN — "Judgment"
# Penetrating hitscan with charge-shot alt-fire

var is_charging: bool = false
var charge_time: float = 0.0
var max_charge: float = 2.0  # seconds for full charge
var charge_multiplier: float = 1.0


func _setup_weapon() -> void:
    weapon_name = "Judgment"
    weapon_slot = 5
    damage = 100.0
    fire_rate = 1.5
    max_ammo = 5
    current_ammo = max_ammo
    reload_time = 2.5
    auto_fire = false
    spread = 0.0  # pinpoint
    weapon_range = 300.0
    alt_fire_ammo_cost = 3


# Primary: Instant penetrating hitscan
func _do_fire() -> void:
    _do_hitscan(damage, true)  # penetrating


# Alt-fire: Hold to charge up to 2s, release for 3x damage
func _process(delta: float) -> void:
    super(delta)
    
    if Input.is_action_pressed("alt_fire") and can_alt_fire() and not is_charging:
        is_charging = true
        charge_time = 0.0
    
    if is_charging:
        charge_time += delta
        if not Input.is_action_pressed("alt_fire"):
            # Release — fire charged shot
            is_charging = false
            charge_multiplier = lerp(1.0, 3.0, min(charge_time / max_charge, 1.0))
            if can_alt_fire():
                alt_fire()
            charge_multiplier = 1.0
        elif charge_time >= max_charge:
            # Auto-fire at max charge
            is_charging = false
            charge_multiplier = 3.0
            if can_alt_fire():
                alt_fire()
            charge_multiplier = 1.0


func _do_alt_fire() -> void:
    _do_hitscan(damage * charge_multiplier, true)  # penetrating, up to 300 damage


func _do_hitscan(dmg: float = -1.0, penetration: bool = false) -> Dictionary:
    # Override to add thick tracer for railgun
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
    var use_dmg: float = damage if dmg < 0 else dmg
    
    if not result.is_empty():
        var collider: Variant = result.collider
        if collider and collider.has_method("take_damage"):
            collider.take_damage(use_dmg)
        
        _spawn_impact(result.position, result.normal)
        _trigger_screen_shake(use_dmg)
        _draw_thick_tracer(from, result.position)
        return {"hit": true, "position": result.position, "target": collider}
    else:
        var end_pos: Vector3 = from + dir * weapon_range
        _draw_thick_tracer(from, end_pos)
        return {"hit": false, "position": end_pos, "target": null}


func _draw_thick_tracer(from: Vector3, to: Vector3) -> void:
    # Thick railgun beam effect
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var cylinder_mesh: CylinderMesh = CylinderMesh.new()
    cylinder_mesh.top_radius = 0.04
    cylinder_mesh.bottom_radius = 0.04
    
    var mid: Vector3 = (from + to) / 2.0
    var dist: float = from.distance_to(to)
    cylinder_mesh.height = dist
    
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.3, 0.7, 1.0, 1.0)
    material.emission_enabled = true
    material.emission = Color(0.2, 0.5, 1.0)
    material.emission_energy_multiplier = 5.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    
    mesh_instance.mesh = cylinder_mesh
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_instance.global_position = mid
    
    # Orient cylinder to point from->to
    var look_dir: Vector3 = (to - from).normalized()
    if look_dir.length() > 0.001:
        var up: Vector3 = Vector3.UP
        var axis: Vector3 = up.cross(look_dir).normalized()
        var angle: float = acos(up.dot(look_dir))
        if axis.length() > 0.001:
            mesh_instance.rotation = axis * angle
    
    get_tree().root.add_child(mesh_instance)
    
    var t: Tween = create_tween()
    t.tween_property(mesh_instance, "scale", Vector3(0.01, 1.0, 0.01), 0.15).from(Vector3(1.0, 1.0, 1.0))
    t.parallel().tween_property(material, "albedo_color:a", 0.0, 0.15)
    t.tween_callback(func(): mesh_instance.queue_free())
