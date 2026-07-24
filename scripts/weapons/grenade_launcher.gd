extends "res://scripts/weapons/weapon_base.gd"
# GRENADE LAUNCHER — "Ruin"
# Arcing explosive grenades + sticky bomb alt-fire

var sticky_grenades: Array = []
var max_sticky_count: int = 8


func _setup_weapon() -> void:
    weapon_name = "Ruin"
    weapon_slot = 6
    damage = 80.0  # direct hit
    fire_rate = 1.0
    max_ammo = 4
    current_ammo = max_ammo
    reload_time = 3.0
    auto_fire = false
    spread = 3.0
    weapon_range = 60.0
    alt_fire_ammo_cost = 1


# Primary: Explosive grenade, arcing trajectory with gravity
func _do_fire() -> void:
    var bullet: Node3D = _spawn_bullet(spread, damage, 25.0)  # moderate speed, arcing
    if bullet and bullet.has_method("configure"):
        bullet.is_explosive = true
        bullet.explosion_radius = 5.0
        bullet.explosion_damage = 40.0  # splash damage
        # Arc upward
        bullet.direction.y += 0.25
        bullet.direction = bullet.direction.normalized()


# Alt-fire: Sticky grenades
func _do_alt_fire() -> void:
    var bullet: Node3D = _spawn_bullet(spread * 0.5, 20.0, 20.0)
    if bullet and bullet.has_method("configure"):
        bullet.is_explosive = true
        bullet.explosion_radius = 5.0
        bullet.explosion_damage = 60.0
        bullet.is_sticky = true
        bullet.sticky_detonation_delay = 1.5
        bullet.direction.y += 0.2
        bullet.direction = bullet.direction.normalized()
        sticky_grenades.append(bullet)


# Detonate all active sticky grenades
func detonate_all_stickies() -> void:
    for grenade in sticky_grenades:
        if is_instance_valid(grenade) and grenade.has_method("_detonate"):
            grenade._detonate()
    sticky_grenades.clear()
