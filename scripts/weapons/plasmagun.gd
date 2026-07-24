extends "res://scripts/weapons/weapon_base.gd"
# PLASMA GUN — "Soul Burner"
# Energy weapon: slow plasma balls + continuous beam alt-fire

var beam_active: bool = false
var beam_ammo_per_second: int = 3
var beam_damage_per_tick: float = 8.0
var beam_tick_rate: float = 0.1
var beam_tick_timer: float = 0.0
var beam_mesh: MeshInstance3D = null
var beam_ray: RayCast3D = null


func _setup_weapon() -> void:
    weapon_name = "Soul Burner"
    weapon_slot = 4
    damage = 22.0
    fire_rate = 0.3
    max_ammo = 40
    current_ammo = max_ammo
    reload_time = 2.0
    auto_fire = false
    spread = 2.0
    weapon_range = 80.0
    alt_fire_ammo_cost = beam_ammo_per_second  # per-second burn


# Primary: Plasma ball — slow projectile with small explosion
func _do_fire() -> void:
    var bullet: Node3D = _spawn_bullet(spread, damage, 20.0)  # slow speed
    if bullet and bullet.has_method("configure"):
        bullet.is_explosive = true
        bullet.explosion_radius = 2.0
        bullet.explosion_damage = 15.0


# Alt-fire: Continuous plasma beam
func _process(delta: float) -> void:
    super(delta)
    
    # Beam handling
    if Input.is_action_pressed("alt_fire") and can_beam():
        if not beam_active:
            _start_beam()
        _update_beam(delta)
    else:
        if beam_active:
            _stop_beam()


func can_beam() -> bool:
    return current_ammo > 0 and not is_reloading


func _start_beam() -> void:
    beam_active = true
    beam_tick_timer = 0.0
    _show_muzzle_flash()


func _update_beam(delta: float) -> void:
    # Consume ammo over time
    beam_tick_timer += delta
    if beam_tick_timer >= beam_tick_rate:
        beam_tick_timer -= beam_tick_rate
        _spend_ammo(1)
        ammo_changed.emit(current_ammo, max_ammo)
        
        # Hitscan tick
        var result: Dictionary = _do_hitscan(beam_damage_per_tick, false)
        
        if current_ammo <= 0:
            _stop_beam()


func _stop_beam() -> void:
    beam_active = false


func _do_alt_fire() -> void:
    # Beam is handled in _process — this is called once on press
    pass
