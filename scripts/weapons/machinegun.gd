extends "res://scripts/weapons/weapon_base.gd"
# MACHINE GUN — "Inferno Spitter"
# Rapid-fire bullet hose with underslung grenade launcher

var current_spread: float = 0.0
var max_spread: float = 6.0
var spread_recovery: float = 15.0  # degrees per second
var spread_gain: float = 0.6  # per shot


func _setup_weapon() -> void:
    weapon_name = "Inferno Spitter"
    weapon_slot = 3
    damage = 12.0
    fire_rate = 0.08
    max_ammo = 60
    current_ammo = max_ammo
    reload_time = 2.5
    auto_fire = true
    spread = 3.0  # starting spread
    weapon_range = 150.0
    alt_fire_ammo_cost = 5


func _process(delta: float) -> void:
    super(delta)
    
    # Spread recovery when not firing
    if not Input.is_action_pressed("shoot"):
        current_spread = max(spread, current_spread - spread_recovery * delta)


# Primary: auto-fire hitscan with growing spread
func _do_fire() -> void:
    current_spread = min(max_spread, current_spread + spread_gain)
    var effective_spread: float = current_spread
    _do_hitscan(damage, false)


# Override can_fire to use current_spread
func can_fire() -> bool:
    return current_ammo > 0 and fire_timer <= 0.0 and not is_reloading


# Alt-fire: Grenade launcher — arcing explosive projectile
func _do_alt_fire() -> void:
    var bullet: Node3D = _spawn_bullet(2.0, 60.0, 25.0)  # damage, override spread/speed
    if bullet and bullet.has_method("configure"):
        bullet.is_explosive = true
        bullet.explosion_radius = 4.0
        bullet.explosion_damage = 60.0
        # Arc: add upward initial velocity
        bullet.direction.y += 0.3
        bullet.direction = bullet.direction.normalized()
